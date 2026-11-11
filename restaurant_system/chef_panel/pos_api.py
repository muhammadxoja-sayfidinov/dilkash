import base64
import datetime
import hashlib
import json
import logging
import uuid
from decimal import Decimal
from django.core.files.base import ContentFile
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone
from django.db import transaction, connection
from django.shortcuts import get_object_or_404
from django.db.models import Sum, Count, Q

from .models import (
    Category, Product, Order, OrderItem, Customer,
    RestaurantTable, WaiterProfile, CourierProfile, BotSettings, WaiterCall
)
from .printer_service import (
    DEPARTMENT_CONFIG, categorize_order_items, 
    auto_print_order_to_network, async_print_kassa_slip,
    format_escpos_slip, send_escpos_socket
)

logger = logging.getLogger(__name__)


def _infer_table_zone(number):
    """Stol raqamidan zal zonasini aniqlash."""
    if number <= 6:
        return 'Zal'
    if number <= 9:
        return 'Terrasa'
    return 'VIP'


def _get_or_create_pos_customer(phone, full_name):
    """Telefon raqam bo'yicha xavfsiz mijoz topish yoki yaratish."""
    normalized_phone = (phone or '+998000000000').strip() or '+998000000000'
    customer = Customer.objects.filter(phone_number=normalized_phone).first()
    if customer:
        return customer
    for _ in range(5):
        synthetic_tg_id = -(uuid.uuid4().int % 899999999 + 100000000)
        if not Customer.objects.filter(telegram_id=synthetic_tg_id).exists():
            return Customer.objects.create(
                phone_number=normalized_phone,
                full_name=(full_name or 'Kassadan Mijoz').strip() or 'Kassadan Mijoz',
                telegram_id=synthetic_tg_id,
            )
    raise RuntimeError("Noyob Telegram ID yaratib bo'lmadi")


def _parse_json_body(request):
    try:
        return json.loads(request.body.decode('utf-8')) if request.body else {}
    except Exception:
        return None


def _replace_order_items(order, items_in):
    """Offline/POS buyurtma elementlarini ID yoki nom bo'yicha yaratish."""
    for item_d in items_in:
        prod_id = item_d.get('product_id')
        prod_name = (item_d.get('product_name') or '').strip()
        qty = int(item_d.get('quantity', 1))
        price = Decimal(str(item_d.get('price', 0)))
        prod = Product.objects.filter(id=prod_id).first()
        if not prod and prod_name:
            prod = Product.objects.filter(name__iexact=prod_name).first()
        if prod and qty > 0:
            OrderItem.objects.create(
                order=order,
                product=prod,
                quantity=qty,
                price=price,
                total=price * qty,
            )


def _norm_table_num(raw):
    s = str(raw or '').strip().upper()
    if s.startswith('T-'):
        s = s[2:]
    s = s.lstrip('#').strip()
    if s.isdigit():
        return str(int(s))
    return s or ''


def _serialize_waiter_calls():
    """Hali hal qilinmagan QR/ofitsiant chaqiruvlari."""
    calls = []
    for c in WaiterCall.objects.filter(is_resolved=False).order_by('-created_at'):
        calls.append({
            'id': c.id,
            'table_number': _norm_table_num(c.table_number) or str(c.table_number),
            'reason': c.reason,
            'created_at': c.created_at.strftime('%H:%M'),
        })
    return calls


def _serialize_staff_accounts():
    """Xodimlar ro'yxati (PIN faqat SHA-256 xesh ko'rinishda, POS admin + offline login uchun)."""
    staff = []
    for w in WaiterProfile.objects.order_by('-is_active', 'name', 'id'):
        staff.append({
            'id': w.id,
            'role': 'waiter',
            'name': w.name,
            'phone': w.phone or '',
            'pin_hash': hashlib.sha256((w.pin_code or '1234').encode('utf-8')).hexdigest(),
            'staff_code': f"DIL-{w.id}",
            'token': w.auth_token or f"wait_{w.id}",
            'vehicle_info': '',
            'is_active': w.is_active,
            'telegram_id': w.telegram_id,
        })
    for c in CourierProfile.objects.order_by('-is_active', 'name', 'id'):
        staff.append({
            'id': c.id,
            'role': 'courier',
            'name': c.name,
            'phone': c.phone or '',
            'pin_hash': hashlib.sha256((c.pin_code or '1234').encode('utf-8')).hexdigest(),
            'staff_code': f"DIL-{c.id}",
            'token': c.auth_token or f"cour_{c.id}",
            'vehicle_info': c.vehicle_info or '',
            'is_active': c.is_active,
            'telegram_id': None,
        })
    return staff


def _serialize_category(cat):
    return {
        'id': cat.id,
        'name': cat.name,
        'department': cat.get_department(),
        'description': cat.description or '',
        'is_active': cat.is_active,
        'products_count': cat.product_set.count(),
    }


def _serialize_settings(settings):
    return {
        'service_fee_type': settings.service_fee_type,
        'service_fee_percent': float(settings.service_fee_percent or 10.0),
        'service_fee_per_person': float(settings.service_fee_per_person or 5000.0),
        'auto_print_network': settings.auto_print_network,
        'service_start_time': settings.service_start_time.strftime('%H:%M') if settings.service_start_time else '10:00',
        'service_end_time': settings.service_end_time.strftime('%H:%M') if settings.service_end_time else '22:00',
        'delivery_base_cost': float(settings.delivery_base_cost or 5000),
        'delivery_cost_per_extra_km_block': float(settings.delivery_cost_per_extra_km_block or 6000),
        'delivery_max_radius_km': float(settings.delivery_max_radius_km or 10.0),
        'broadcast_message_text': settings.broadcast_message_text or '',
        'click_service_id': settings.click_service_id or '',
        'click_merchant_id': settings.click_merchant_id or '',
        'payme_merchant_id': settings.payme_merchant_id or '',
        'has_click_secret': bool(settings.click_secret_key),
        'has_payme_secret': bool(settings.payme_secret_key),
        'printers': {
            'shashlik': settings.printer_shashlik_ip or '',
            'somsa': settings.printer_somsa_ip or '',
            'kitchen': settings.printer_kitchen_ip or '',
            'fastfood': settings.printer_fastfood_ip or '',
            'bar': settings.printer_bar_ip or '',
            'kassa': settings.printer_kassa_ip or '',
        }
    }


def _serialize_tables():
    """Faol restoran stollari va joriy band buyurtmalarni JSON ko'rinishda qaytarish."""
    tables_qs = RestaurantTable.objects.filter(is_active=True).order_by('number')
    active_orders = Order.objects.filter(
        service_type='dine_in',
        is_paid=False
    ).exclude(status='bekor_qilingan').prefetch_related('items', 'items__product', 'items__product__category')
    order_by_table = {_norm_table_num(o.table_number): o for o in active_orders if o.table_number}

    calls_list = _serialize_waiter_calls()
    calls_by_table = {}
    for c in calls_list:
        if c['table_number'] not in calls_by_table:
            calls_by_table[c['table_number']] = c

    tables = []
    for tbl in tables_qs:
        t_key = str(tbl.number)
        active_order = order_by_table.get(t_key)
        active_call = calls_by_table.get(t_key)
        is_occupied = active_order is not None
        status = 'empty'
        if active_call and ('hisob' in active_call['reason'].lower() or 'chek' in active_call['reason'].lower()):
            status = 'bill_printed'
        elif is_occupied:
            status = 'occupied'

        tables.append({
            'id': tbl.id,
            'number': tbl.number,
            'name': tbl.name or f"Stol #{tbl.number}",
            'zone': _infer_table_zone(tbl.number),
            'capacity': tbl.capacity,
            'guests_count': active_order.guests_count if active_order else tbl.guests_count,
            'is_occupied': is_occupied,
            'status': status,
            'order_status': active_order.status if active_order else None,
            'opened_at': (active_order.created_at.isoformat() if active_order else (tbl.opened_at.isoformat() if tbl.opened_at else None)),
            'assigned_waiter': tbl.assigned_waiter.name if tbl.assigned_waiter else (active_order.waiter_name if active_order else None),
            'active_order': _serialize_order(active_order) if active_order else None,
            'active_call': active_call,
        })
    return tables


@csrf_exempt
def health_check_api(request):
    """Cloud / reverse-proxy healthcheck endpoint."""
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
        return JsonResponse({
            'status': 'ok',
            'service': 'dilkash-backend',
            'products_count': Product.objects.count(),
            'tables_count': RestaurantTable.objects.filter(is_active=True).count(),
            'server_time': timezone.now().isoformat(),
        })
    except Exception as exc:
        logger.exception("Healthcheck failed")
        return JsonResponse({'status': 'error', 'detail': str(exc)}, status=500)


def _serialize_product(product):
    """Mahsulotni POS uchun to'liq JSON formatida shakllantirish"""
    cat_dept = product.get_department()
    return {
        'id': product.id,
        'name': product.name,
        'price': float(product.price),
        'category_id': product.category_id,
        'category_name': product.category.name if product.category else '',
        'department': cat_dept,
        'department_name': DEPARTMENT_CONFIG.get(cat_dept, {}).get('name', cat_dept),
        'is_available': product.is_available,
        'description': product.description or '',
        'image_url': product.image.url if product.image else None,
    }


def _serialize_order(order):
    """Buyurtmani POS uchun JSON formatida shakllantirish"""
    items = []
    for item in order.items.select_related('product', 'product__category').all():
        dept = item.product.get_department() if item.product else 'kitchen'
        items.append({
            'id': item.id,
            'product_id': item.product_id,
            'product_name': item.product.name if item.product else 'Noma\'lum',
            'quantity': item.quantity,
            'price': float(item.price),
            'total': float(item.total),
            'department': dept,
            'category_name': item.product.category.name if (item.product and item.product.category) else '',
        })

    elapsed_minutes = 0
    if order.created_at:
        elapsed = timezone.now() - order.created_at
        elapsed_minutes = int(elapsed.total_seconds() // 60)

    return {
        'id': order.id,
        'order_number': order.order_number,
        'offline_id': order.offline_id,
        'status': order.status,
        'service_type': order.service_type,
        'table_number': order.table_number,
        'guests_count': order.guests_count,
        'customer_name': order.customer.full_name if order.customer else 'Kassadan Mijoz',
        'customer_phone': order.customer.phone_number if order.customer else '',
        'waiter_name': order.waiter_name or (order.waiter.name if order.waiter else None),
        'courier_name': order.courier_name,
        'notes': order.notes or '',
        'is_paid': order.is_paid,
        'payment_method': order.payment_method,
        'products_total': float(order.products_total or 0),
        'delivery_cost': float(order.delivery_cost or 0),
        'service_fee_amount': float(order.service_fee_amount or 0),
        'discount_percent': float(order.discount_percent or 0),
        'discount_amount': float(order.discount_amount or 0),
        'total_amount': float(order.total_amount or 0),
        'created_at': order.created_at.isoformat() if order.created_at else None,
        'elapsed_minutes': elapsed_minutes,
        'items': items,
        'items_count': sum(i['quantity'] for i in items),
    }


@csrf_exempt
def pos_bootstrap_api(request):
    """
    POS dasturi yuklanganda barcha kerakli ma'lumotlarni bitta paketda beruvchi API:
    - Bo'limlar va ularning LAN printer IP-lari
    - Xizmat haqi va umumiy tizim sozlamalari
    - Faol kategoriyalar va barcha taomlar (Stop-list belgilari bilan)
    - Restoran stollari xaritasi va joriy ochiq stollar
    - Stop-list ID lari
    """
    if request.method != 'GET':
        return JsonResponse({'error': 'Faqat GET so\'rovlari qabul qilinadi'}, status=405)

    settings = BotSettings.get_settings()

    # 1. Bo'limlar ro'yxati va printer IP-lari
    departments = []
    for code, cfg in DEPARTMENT_CONFIG.items():
        printer_ip = getattr(settings, f"printer_{code}_ip", '') or ''
        departments.append({
            'code': code,
            'name': cfg['name'],
            'title': cfg['title'],
            'subtitle': cfg.get('subtitle', ''),
            'icon': cfg.get('icon', '🧾'),
            'printer_ip': printer_ip,
            'badge_color': cfg.get('badge_color', '#10b981'),
        })

    # 2. Kategoriyalar (faol va arxivlanganlari bilan boshqarish uchun)
    categories = [_serialize_category(cat) for cat in Category.objects.all().order_by('name')]

    # 3. Mahsulotlar va Stop-list
    products = []
    stop_list_ids = []
    prod_qs = Product.objects.select_related('category').order_by('category__name', 'name')
    for prod in prod_qs:
        prod_data = _serialize_product(prod)
        products.append(prod_data)
        if not prod.is_available:
            stop_list_ids.append(prod.id)

    # 4. Stollar xaritasi va joriy holati
    tables = _serialize_tables()

    # 5. Sozlamalar
    settings_data = _serialize_settings(settings)

    return JsonResponse({
        'status': 'ok',
        'server_time': timezone.now().isoformat(),
        'settings': settings_data,
        'departments': departments,
        'categories': categories,
        'products': products,
        'stop_list': stop_list_ids,
        'tables': tables,
        'waiter_calls': _serialize_waiter_calls(),
        'staff': _serialize_staff_accounts(),
    })


@csrf_exempt
def pos_tables_api(request):
    """
    Stollar xaritasini boshqarish:
    GET: Barcha stollar va ularning joriy holatlari
    POST:
      - action='open': Stolni ochish (mehmon soni bilan)
      - action='transfer': Stolni boshqa stolga yoki ofitsiantga ko'chirish
    """
    if request.method == 'GET':
        return JsonResponse({'status': 'ok', 'tables': _serialize_tables()})

    if request.method == 'POST':
        body = _parse_json_body(request)
        if body is None:
            return JsonResponse({'error': "Noto'g'ri JSON format"}, status=400)

        action = body.get('action', 'open')
        table_number = str(body.get('table_number', '')).strip()

        if not table_number:
            return JsonResponse({'error': 'table_number parametri kiritilishi shart'}, status=400)

        table = RestaurantTable.objects.filter(number=int(table_number) if table_number.isdigit() else 0).first()

        if action == 'open':
            guests_count = int(body.get('guests_count', 2))
            waiter_name = body.get('waiter_name', '')
            
            # Agar oldin ochiq bo'lmasa, yangi stol buyurtmasi ochamiz
            existing = Order.objects.filter(
                table_number=table_number,
                service_type='dine_in',
                is_paid=False
            ).exclude(status='bekor_qilingan').first()

            if existing:
                return JsonResponse({'status': 'ok', 'message': 'Stol allaqachon ochiq', 'order': _serialize_order(existing)})

            # Standart Kassa mijozi
            customer, _ = Customer.objects.get_or_create(
                telegram_id=900000000 + (int(table_number) if table_number.isdigit() else 1),
                defaults={'full_name': f"Stol #{table_number} Mijozi", 'phone_number': '+998000000000'}
            )

            order = Order.objects.create(
                customer=customer,
                service_type='dine_in',
                table_number=table_number,
                guests_count=guests_count,
                waiter_name=waiter_name or (table.assigned_waiter.name if (table and table.assigned_waiter) else 'Kassir'),
                status='yangi',
                payment_method='naqd',
                products_total=0,
                delivery_cost=0,
                service_fee_amount=0,
                total_amount=0,
                notes=body.get('notes', '')
            )

            if table:
                table.guests_count = guests_count
                table.opened_at = timezone.now()
                table.save()

            return JsonResponse({'status': 'ok', 'message': f"Stol #{table_number} ochildi", 'order': _serialize_order(order)})

        elif action == 'transfer':
            target_table_number = str(body.get('target_table_number', '')).strip()
            if not target_table_number:
                return JsonResponse({'error': 'target_table_number talab qilinadi'}, status=400)

            active_order = Order.objects.filter(
                table_number=table_number,
                service_type='dine_in',
                is_paid=False
            ).exclude(status='bekor_qilingan').first()

            if not active_order:
                return JsonResponse({'error': f"Stol #{table_number} da faol buyurtma topilmadi"}, status=404)

            active_order.table_number = target_table_number
            active_order.notes = (active_order.notes or '') + f" (Stol #{table_number} dan ko'chirildi)"
            active_order.save()

            # Stol vaqtlarini yangilash
            if table:
                table.guests_count = 0
                table.opened_at = None
                table.save()

            target_table = RestaurantTable.objects.filter(number=int(target_table_number) if target_table_number.isdigit() else 0).first()
            if target_table:
                target_table.guests_count = active_order.guests_count
                target_table.opened_at = active_order.created_at
                target_table.save()

            return JsonResponse({'status': 'ok', 'message': f"Buyurtma Stol #{target_table_number} ga ko'chirildi", 'order': _serialize_order(active_order)})

        return JsonResponse({'error': f"Noma'lum action: {action}"}, status=400)


@csrf_exempt
def pos_orders_api(request):
    """
    Buyurtmalar API:
    GET: Buyurtmalar ro'yxati (filtrlar: status, service_type, date, is_paid)
    POST: Yangi buyurtma yaratish yoki yangilash (Stol buyurtmasi yoki Tezkor Saboy)
    """
    if request.method == 'GET':
        qs = Order.objects.select_related('customer').prefetch_related('items', 'items__product').order_by('-created_at')
        
        status_param = request.GET.get('status')
        if status_param:
            qs = qs.filter(status=status_param)

        service_type = request.GET.get('service_type')
        if service_type:
            qs = qs.filter(service_type=service_type)

        is_paid = request.GET.get('is_paid')
        if is_paid is not None:
            qs = qs.filter(is_paid=is_paid in ['1', 'true', 'True'])

        limit = int(request.GET.get('limit', 50))
        orders_data = [_serialize_order(o) for o in qs[:limit]]
        return JsonResponse({'status': 'ok', 'orders': orders_data})

    if request.method == 'POST':
        data = _parse_json_body(request)
        if data is None:
            return JsonResponse({'error': "Noto'g'ri JSON format"}, status=400)

        order_id = data.get('id')
        offline_id = data.get('offline_id')
        service_type = data.get('service_type', 'dine_in')
        table_number = str(data.get('table_number', '')).strip()
        guests_count = int(data.get('guests_count', 1))
        waiter_name = data.get('waiter_name')
        payment_method = data.get('payment_method', 'naqd')
        is_paid = bool(data.get('is_paid', False))
        discount_percent = Decimal(str(data.get('discount_percent', 0) or 0))
        discount_amount_input = Decimal(str(data.get('discount_amount', 0) or 0))
        items_data = data.get('items', [])
        notes = data.get('notes', '')
        customer_phone = data.get('customer_phone', '+998000000000')
        customer_name = data.get('customer_name', 'Kassadan Mijoz')

        settings = BotSettings.get_settings()

        with transaction.atomic():
            # 1. Buyurtmani topish yoki yaratish
            order = None
            if order_id:
                order = Order.objects.filter(id=order_id).first()
            elif offline_id:
                order = Order.objects.filter(offline_id=offline_id).first()
            elif service_type == 'dine_in' and table_number:
                order = Order.objects.filter(
                    table_number=table_number,
                    service_type='dine_in',
                    is_paid=False
                ).exclude(status='bekor_qilingan').first()

            # Mijozni aniqlash
            customer = _get_or_create_pos_customer(customer_phone, customer_name)

            if not order:
                order = Order(
                    customer=customer,
                    service_type=service_type,
                    table_number=table_number if service_type == 'dine_in' else None,
                    guests_count=guests_count,
                    waiter_name=waiter_name or None,
                    status='tasdiqlangan' if is_paid else 'yangi',
                    payment_method=payment_method,
                    is_paid=is_paid,
                    offline_id=offline_id,
                    notes=notes,
                    products_total=0,
                    delivery_cost=0,
                    service_fee_amount=0,
                    discount_percent=discount_percent,
                    discount_amount=0,
                    total_amount=0,
                )
                order.save()
            else:
                order.guests_count = guests_count
                order.notes = notes
                if waiter_name:
                    order.waiter_name = waiter_name
                if discount_percent or discount_amount_input:
                    order.discount_percent = discount_percent
                if is_paid:
                    order.is_paid = is_paid
                    order.payment_method = payment_method

            # 2. Buyurtma elementlarini kiritish/yangilash
            if items_data:
                # Agar elementlar berilgan bo'lsa, eskilari bilan sinxronlaymiz
                order.items.all().delete()
                products_total = Decimal('0')

                for it in items_data:
                    prod_id = it.get('product_id')
                    qty = int(it.get('quantity', 1))
                    if not prod_id or qty <= 0:
                        continue
                    product = Product.objects.filter(id=prod_id).first()
                    if not product:
                        continue

                    unit_price = Decimal(str(it.get('price', product.price)))
                    item_total = unit_price * qty
                    products_total += item_total

                    OrderItem.objects.create(
                        order=order,
                        product=product,
                        quantity=qty,
                        price=unit_price,
                        total=item_total
                    )

                order.products_total = products_total

                # Chegirma hisoblash
                if discount_percent > 0:
                    discount_amt = (products_total * (discount_percent / Decimal('100'))).quantize(Decimal('1'))
                else:
                    discount_amt = max(Decimal('0'), discount_amount_input)
                discount_amt = min(discount_amt, products_total)
                order.discount_percent = discount_percent
                order.discount_amount = discount_amt

                # 3. Xizmat haqini hisoblash (Faqat dine_in stollar uchun yoki sozlamaga qarab)
                service_fee = Decimal('0')
                if service_type == 'dine_in':
                    if settings.service_fee_type == 'percent':
                        pct = Decimal(str(settings.service_fee_percent or 10)) / Decimal('100')
                        service_fee = (products_total * pct).quantize(Decimal('1'))
                    elif settings.service_fee_type == 'per_person':
                        per_person = Decimal(str(settings.service_fee_per_person or 5000))
                        service_fee = (Decimal(guests_count) * per_person)

                order.service_fee_amount = service_fee
                order.total_amount = max(
                    Decimal('0'),
                    (products_total - discount_amt) + service_fee + Decimal(str(order.delivery_cost or 0)),
                )
                order.save()

            # Agar bu to'langan Saboy bo'lsa, holati 'olib_ketildi'
            if service_type == 'pickup' and is_paid:
                order.status = 'olib_ketildi'
                order.picked_up_at = timezone.now()
                order.save()
            elif service_type == 'dine_in':
                norm_t = _norm_table_num(table_number)
                tbl = RestaurantTable.objects.filter(number=int(norm_t) if norm_t.isdigit() else 0).first()
                if is_paid:
                    order.status = 'yetkazildi'
                    order.delivered_at = timezone.now()
                    order.save()
                    if tbl:
                        tbl.guests_count = 0
                        tbl.opened_at = None
                        tbl.assigned_waiter = None
                        tbl.save()
                    WaiterCall.objects.filter(table_number=norm_t, is_resolved=False).update(
                        is_resolved=True, resolved_at=timezone.now()
                    )
                elif tbl:
                    if not tbl.opened_at:
                        tbl.opened_at = timezone.now()
                    tbl.guests_count = guests_count
                    if waiter_name and not tbl.assigned_waiter:
                        tbl.assigned_waiter = WaiterProfile.objects.filter(name__iexact=waiter_name).first()
                    tbl.save()

        # 4. Tarmoq printerlariga avtomatik yuborish (agar so'ralgan yoki yoqilgan bo'lsa)
        print_to_network = data.get('print_to_network', settings.auto_print_network)
        if print_to_network and items_data:
            try:
                auto_print_order_to_network(order)
            except Exception as e:
                logger.warning(f"POS orqali avtomatik printerga chiqarishda xatolik: {e}")

        return JsonResponse({
            'status': 'ok',
            'message': 'Buyurtma saqlandi',
            'order': _serialize_order(order)
        })


@csrf_exempt
def pos_order_pay_api(request, order_id):
    """
    Kassada buyurtmani to'lash va yopish API:
    - To'lov usullari: 'naqd', 'karta', 'aralash' (Split payment)
    - Stolni bo'shatadi (agar stolda bo'lsa)
    - Kassa chekini chop etish uchun ma'lumotlarni qaytaradi
    """
    if request.method != 'POST':
        return JsonResponse({'error': 'Faqat POST qabul qilinadi'}, status=405)

    order = get_object_or_404(Order, id=order_id)
    body = _parse_json_body(request) or {}

    payment_method = body.get('payment_method', 'naqd')
    paid_cash = Decimal(str(body.get('paid_cash', 0)))
    paid_card = Decimal(str(body.get('paid_card', 0)))

    order.payment_method = payment_method
    order.is_paid = True
    
    if order.service_type == 'dine_in':
        order.status = 'yetkazildi'
        # Stolni bo'shatish
        if order.table_number:
            tbl = RestaurantTable.objects.filter(number=int(order.table_number) if str(order.table_number).isdigit() else 0).first()
            if tbl:
                tbl.guests_count = 0
                tbl.opened_at = None
                tbl.save()
    elif order.service_type == 'pickup':
        order.status = 'olib_ketildi'
        order.picked_up_at = timezone.now()
    
    order.save()

    # Kassa printeriga hisob chekini orqa fonda chiqarish (HTTP ni kutdirmasdan)
    async_print_kassa_slip(order)

    return JsonResponse({
        'status': 'ok',
        'message': f"Buyurtma #{order.order_number} to'landi va yopildi",
        'order': _serialize_order(order),
        'payment': {
            'method': payment_method,
            'paid_cash': float(paid_cash),
            'paid_card': float(paid_card),
            'total': float(order.total_amount),
        }
    })


@csrf_exempt
def pos_stop_list_api(request):
    """
    Stop-list boshqaruvi:
    GET: Hozirda to'xtatilgan (mavjud bo'lmagan) barcha taomlar
    """
    if request.method != 'GET':
        return JsonResponse({'error': 'Faqat GET qabul qilinadi'}, status=405)

    unavailable_prods = Product.objects.filter(is_available=False).select_related('category')
    data = [_serialize_product(p) for p in unavailable_prods]
    return JsonResponse({
        'status': 'ok',
        'count': len(data),
        'stop_list': data
    })


@csrf_exempt
def pos_toggle_stop_api(request, product_id):
    """
    Bitta taomni Stop-Listga kiritish yoki undan chiqarish:
    Kassir bitta bosish bilan yoqadi/o'chiradi.
    Bot, Sayt va Ofitsiant ilovasida darhol aks etadi.
    """
    if request.method != 'POST':
        return JsonResponse({'error': 'Faqat POST qabul qilinadi'}, status=405)

    product = get_object_or_404(Product, id=product_id)
    body = _parse_json_body(request) or {}

    if 'is_available' in body:
        product.is_available = bool(body['is_available'])
    else:
        product.is_available = not product.is_available

    product.save()

    return JsonResponse({
        'status': 'ok',
        'message': f"Taom holati yangilandi: {product.name}",
        'product': _serialize_product(product)
    })


@csrf_exempt
def pos_online_orders_api(request):
    """
    Telegram bot va mobil ilovadan tushgan online buyurtmalarni kassaga qabul qilish API:
    GET: Yangi tushgan buyurtmalar navbati (status='yangi')
    """
    if request.method != 'GET':
        return JsonResponse({'error': 'Faqat GET qabul qilinadi'}, status=405)

    online_qs = Order.objects.filter(
        status='yangi',
        service_type__in=['delivery', 'pickup']
    ).select_related('customer').prefetch_related('items', 'items__product').order_by('-created_at')[:30]

    return JsonResponse({
        'status': 'ok',
        'count': online_qs.count(),
        'orders': [_serialize_order(o) for o in online_qs]
    })


@csrf_exempt
def pos_online_order_action_api(request, order_id):
    """
    Online buyurtmani qabul qilish yoki rad etish:
    - action='accept': Buyurtmani tasdiqlaydi va oshxona printerlariga chek yuboradi
    - action='reject': Buyurtmani bekor qiladi
    """
    if request.method != 'POST':
        return JsonResponse({'error': 'Faqat POST qabul qilinadi'}, status=405)

    order = get_object_or_404(Order, id=order_id)
    body = _parse_json_body(request) or {}

    action = body.get('action', 'accept')

    if action == 'accept':
        order.status = 'tasdiqlangan'
        order.confirmed_at = timezone.now()
        order.save()

        # Oshxona/Somsa/Shashlik tarmoq printerlariga avtomatik chek chiqarish
        auto_print_order_to_network(order)

        return JsonResponse({
            'status': 'ok',
            'message': f"Online buyurtma #{order.order_number} qabul qilindi va printerlarga yuborildi",
            'order': _serialize_order(order)
        })

    elif action == 'reject':
        reason = body.get('reason', 'Kassa tomonidan rad etildi')
        order.status = 'bekor_qilingan'
        order.notes = (order.notes or '') + f" [Rad etildi: {reason}]"
        order.save()

        return JsonResponse({
            'status': 'ok',
            'message': f"Buyurtma #{order.order_number} bekor qilindi",
            'order': _serialize_order(order)
        })

    return JsonResponse({'error': f"Noma'lum action: {action}"}, status=400)


@csrf_exempt
def pos_sync_push_api(request):
    """
    Offline-First Sinxronizatsiya (POS Hub <-> Cloud Django):
    - Internet uzilgan vaqtda C# POS / Ofitsiant Wi-Fi Hub da yaratilgan,
      o'zgartirilgan yoki yopilgan buyurtmalarni serverga ommaviy sinxronlash.
    - Hal qilingan QR chaqiruvlar (dismissed_call_ids) va hisob so'rovlarini ham sinxronlaydi.
    """
    if request.method != 'POST':
        return JsonResponse({'error': 'Faqat POST qabul qilinadi'}, status=405)

    data = _parse_json_body(request)
    if data is None:
        return JsonResponse({'error': "Noto'g'ri JSON format"}, status=400)

    orders_batch = data.get('orders', [])
    dismissed_call_ids = data.get('dismissed_call_ids', [])
    bill_requested_tables = data.get('bill_requested_tables', [])
    synced_ids = []
    server_id_map = {}

    if dismissed_call_ids:
        valid_ids = [int(cid) for cid in dismissed_call_ids if str(cid).isdigit()]
        if valid_ids:
            WaiterCall.objects.filter(id__in=valid_ids, is_resolved=False).update(
                is_resolved=True,
                resolved_at=timezone.now(),
            )

    for tbl_raw in bill_requested_tables:
        norm_t = _norm_table_num(tbl_raw)
        if norm_t and not WaiterCall.objects.filter(table_number=norm_t, is_resolved=False, reason__icontains='Hisob').exists():
            WaiterCall.objects.create(table_number=norm_t, reason="Hisob (Pre-chek) so'raldi", is_resolved=False)

    for o_data in orders_batch:
        offline_id = o_data.get('offline_id')
        server_id = o_data.get('id')
        if not offline_id and not server_id:
            continue

        service_type = o_data.get('service_type', 'pickup')
        table_number = _norm_table_num(o_data.get('table_number')) if service_type == 'dine_in' else o_data.get('table_number')
        guests_count = int(o_data.get('guests_count', 1) or 1)
        customer_phone = o_data.get('customer_phone', '+998000000000')
        customer_name = o_data.get('customer_name', 'Kassa (Offline)')
        is_paid = bool(o_data.get('is_paid', True))
        waiter_name = o_data.get('waiter_name')
        payment_method = o_data.get('payment_method', 'naqd')

        existing = None
        if offline_id:
            existing = Order.objects.filter(offline_id=offline_id).first()
        if not existing and server_id:
            existing = Order.objects.filter(id=server_id).first()
        if not existing and service_type == 'dine_in' and table_number and not is_paid:
            existing = Order.objects.filter(
                table_number=table_number,
                service_type='dine_in',
                is_paid=False,
            ).exclude(status='bekor_qilingan').order_by('-created_at').first()

        with transaction.atomic():
            if existing:
                order = existing
                if offline_id and not order.offline_id:
                    order.offline_id = offline_id
                order.guests_count = guests_count
                if waiter_name:
                    order.waiter_name = waiter_name
                if o_data.get('notes'):
                    order.notes = o_data.get('notes')
                order.payment_method = payment_method
                if is_paid:
                    order.is_paid = True
                    order.status = 'yetkazildi' if service_type == 'dine_in' else 'olib_ketildi'
                    if service_type == 'dine_in':
                        order.delivered_at = order.delivered_at or timezone.now()
                    else:
                        order.picked_up_at = order.picked_up_at or timezone.now()
                elif o_data.get('status'):
                    order.status = o_data.get('status')
                order.products_total = Decimal(str(o_data.get('products_total', order.products_total or 0)))
                order.service_fee_amount = Decimal(str(o_data.get('service_fee_amount', order.service_fee_amount or 0)))
                order.discount_percent = Decimal(str(o_data.get('discount_percent', order.discount_percent or 0) or 0))
                order.discount_amount = Decimal(str(o_data.get('discount_amount', order.discount_amount or 0) or 0))
                order.total_amount = Decimal(str(o_data.get('total_amount', order.total_amount or 0)))
                order.is_synced = True
                order.save()

                items_in = o_data.get('items', [])
                if items_in:
                    order.items.all().delete()
                    _replace_order_items(order, items_in)
            else:
                customer = _get_or_create_pos_customer(customer_phone, customer_name)
                default_status = ('yetkazildi' if service_type == 'dine_in' else 'olib_ketildi') if is_paid else 'yangi'
                order = Order.objects.create(
                    customer=customer,
                    offline_id=offline_id,
                    service_type=service_type,
                    table_number=table_number,
                    guests_count=guests_count,
                    waiter_name=waiter_name,
                    status=o_data.get('status') or default_status,
                    payment_method=payment_method,
                    is_paid=is_paid,
                    notes=o_data.get('notes', 'Offline kassa orqali yopilgan'),
                    products_total=Decimal(str(o_data.get('products_total', 0))),
                    service_fee_amount=Decimal(str(o_data.get('service_fee_amount', 0))),
                    discount_percent=Decimal(str(o_data.get('discount_percent', 0) or 0)),
                    discount_amount=Decimal(str(o_data.get('discount_amount', 0) or 0)),
                    total_amount=Decimal(str(o_data.get('total_amount', 0))),
                    delivery_cost=0,
                    is_synced=True,
                )

                _replace_order_items(order, o_data.get('items', []))

            if service_type == 'dine_in' and table_number:
                t_int = int(table_number) if str(table_number).isdigit() else 0
                tbl = RestaurantTable.objects.filter(number=t_int).first()
                if tbl:
                    if is_paid or order.status == 'bekor_qilingan':
                        tbl.guests_count = 0
                        tbl.opened_at = None
                        tbl.assigned_waiter = None
                        tbl.save()
                        WaiterCall.objects.filter(table_number=str(table_number), is_resolved=False).update(
                            is_resolved=True, resolved_at=timezone.now()
                        )
                    else:
                        tbl.guests_count = guests_count
                        if not tbl.opened_at:
                            tbl.opened_at = timezone.now()
                        if waiter_name and not tbl.assigned_waiter:
                            tbl.assigned_waiter = WaiterProfile.objects.filter(name__iexact=waiter_name).first()
                        tbl.save()

            if offline_id:
                synced_ids.append(offline_id)
                server_id_map[offline_id] = order.id

    return JsonResponse({
        'status': 'ok',
        'synced_count': len(synced_ids),
        'synced_ids': synced_ids,
        'server_id_map': server_id_map,
        'server_time': timezone.now().isoformat(),
    })


def _normalize_uz_phone(raw_phone):
    digits = ''.join(ch for ch in (raw_phone or '') if ch.isdigit())
    last_9 = digits[-9:] if len(digits) >= 9 else digits
    return f"+998{last_9}" if len(last_9) == 9 else (raw_phone or '').strip()


@csrf_exempt
def pos_category_save_api(request):
    """POS Desktop orqali Kategoriya (guruh) qo'shish yoki tahrirlash."""
    if request.method != 'POST':
        return JsonResponse({'error': 'Faqat POST qabul qilinadi'}, status=405)
    body = _parse_json_body(request)
    if body is None:
        return JsonResponse({'error': "Noto'g'ri JSON format"}, status=400)

    cat_id = body.get('id')
    name = (body.get('name') or '').strip()
    dept = (body.get('department') or 'kitchen').strip()
    desc = (body.get('description') or '').strip()
    is_active = bool(body.get('is_active', True))

    if not name:
        return JsonResponse({'error': 'Kategoriya nomi kiritilishi shart'}, status=400)
    if dept not in DEPARTMENT_CONFIG:
        dept = 'kitchen'

    if cat_id and int(cat_id) > 0:
        cat = Category.objects.filter(id=int(cat_id)).first()
        if not cat:
            return JsonResponse({'error': 'Kategoriya topilmadi'}, status=404)
        cat.name = name
        cat.department = dept
        cat.description = desc
        cat.is_active = is_active
        cat.save()
    else:
        cat, _ = Category.objects.update_or_create(
            name=name,
            defaults={'department': dept, 'description': desc, 'is_active': is_active},
        )

    return JsonResponse({'status': 'ok', 'category': _serialize_category(cat)})


@csrf_exempt
def pos_category_delete_api(request, category_id):
    """POS Desktop orqali bo'sh Kategoriyani o'chirish."""
    if request.method != 'POST':
        return JsonResponse({'error': 'Faqat POST qabul qilinadi'}, status=405)
    cat = Category.objects.filter(id=category_id).first()
    if not cat:
        return JsonResponse({'error': 'Kategoriya topilmadi'}, status=404)
    prod_count = cat.product_set.count()
    if prod_count > 0:
        return JsonResponse(
            {'error': f"'{cat.name}' guruhida {prod_count} ta taom mavjud. Avval taomlarni o'chiring yoki boshqa guruhga o'tkazing."},
            status=400,
        )
    cat.delete()
    return JsonResponse({'status': 'ok', 'deleted_id': category_id})


@csrf_exempt
def pos_product_save_api(request):
    """POS Desktop orqali Taom/Mahsulot qo'shish yoki tahrirlash."""
    if request.method != 'POST':
        return JsonResponse({'error': 'Faqat POST qabul qilinadi'}, status=405)
    body = _parse_json_body(request)
    if body is None:
        return JsonResponse({'error': "Noto'g'ri JSON format"}, status=400)

    prod_id = body.get('id')
    name = (body.get('name') or '').strip()
    price_raw = body.get('price', 0)
    cat_id = body.get('category_id')
    cat_name = (body.get('category_name') or '').strip()
    desc = (body.get('description') or '').strip()
    is_available = bool(body.get('is_available', True))
    img_b64 = (body.get('image_base64') or '').strip()
    img_name = (body.get('image_filename') or 'dish.jpg').strip()

    if not name:
        return JsonResponse({'error': 'Taom nomi kiritilishi shart'}, status=400)
    try:
        price = Decimal(str(price_raw))
        if price < 0:
            raise ValueError()
    except Exception:
        return JsonResponse({'error': "Narx noto'g'ri formatda"}, status=400)

    cat = None
    if cat_id and int(cat_id) > 0:
        cat = Category.objects.filter(id=int(cat_id)).first()
    if not cat and cat_name:
        cat = Category.objects.filter(name__iexact=cat_name).first()
    if not cat:
        cat = Category.objects.filter(is_active=True).first()
    if not cat:
        return JsonResponse({'error': 'Avval kamida bitta kategoriya yarating'}, status=400)

    if prod_id and int(prod_id) > 0:
        prod = Product.objects.filter(id=int(prod_id)).first()
        if not prod:
            return JsonResponse({'error': 'Mahsulot topilmadi'}, status=404)
        prod.category = cat
        prod.name = name
        prod.price = price
        prod.description = desc
        prod.is_available = is_available
    else:
        prod = Product(
            category=cat,
            name=name,
            price=price,
            description=desc,
            is_available=is_available,
        )

    if img_b64:
        try:
            if ',' in img_b64 and img_b64.startswith('data:'):
                img_b64 = img_b64.split(',', 1)[1]
            raw_bytes = base64.b64decode(img_b64)
            ext = (img_name.rsplit('.', 1)[-1] if '.' in img_name else 'jpg').lower()
            if ext not in ('jpg', 'jpeg', 'png', 'webp'):
                ext = 'jpg'
            prod.image.save(f"pos_{uuid.uuid4().hex[:8]}.{ext}", ContentFile(raw_bytes), save=False)
        except Exception as exc:
            logger.warning("Rasmni saqlashda xatolik: %s", exc)

    prod.save()
    return JsonResponse({'status': 'ok', 'product': _serialize_product(prod)})


@csrf_exempt
def pos_product_delete_api(request, product_id):
    """POS Desktop orqali Taomni o'chirish (tarixiy buyurtmalarda bo'lsa Stop-listga tushiradi)."""
    if request.method != 'POST':
        return JsonResponse({'error': 'Faqat POST qabul qilinadi'}, status=405)
    prod = Product.objects.filter(id=product_id).first()
    if not prod:
        return JsonResponse({'error': 'Mahsulot topilmadi'}, status=404)

    if OrderItem.objects.filter(product=prod).exists():
        prod.is_available = False
        prod.save()
        return JsonResponse({
            'status': 'ok',
            'archived': True,
            'message': f"'{prod.name}' oldingi buyurtmalarda qatnashgani uchun o'chirilmadi, Stop-listga olindi.",
            'product': _serialize_product(prod),
        })

    prod.delete()
    return JsonResponse({'status': 'ok', 'archived': False, 'deleted_id': product_id})


@csrf_exempt
def pos_staff_save_api(request):
    """POS Desktop orqali Ofitsiant yoki Kuryer qo'shish / tahrirlash."""
    if request.method != 'POST':
        return JsonResponse({'error': 'Faqat POST qabul qilinadi'}, status=405)
    body = _parse_json_body(request)
    if body is None:
        return JsonResponse({'error': "Noto'g'ri JSON format"}, status=400)

    staff_id = body.get('id')
    role = (body.get('role') or 'waiter').strip().lower()
    name = (body.get('name') or '').strip()
    phone = _normalize_uz_phone(body.get('phone') or '')
    pin_code = (body.get('pin_code') or body.get('pin') or '').strip()
    vehicle = (body.get('vehicle_info') or '').strip()
    is_active = bool(body.get('is_active', True))

    if not name or not phone:
        return JsonResponse({'error': 'Xodim ismi va telefon raqami kiritilishi shart'}, status=400)

    if role == 'courier':
        if staff_id and int(staff_id) > 0:
            obj = CourierProfile.objects.filter(id=int(staff_id)).first()
            if not obj:
                return JsonResponse({'error': 'Kuryer topilmadi'}, status=404)
            obj.name = name
            obj.phone = phone
            obj.vehicle_info = vehicle
            obj.is_active = is_active
            if pin_code:
                obj.pin_code = pin_code
            obj.save()
        else:
            effective_pin = pin_code or '1234'
            obj, _ = CourierProfile.objects.update_or_create(
                phone=phone,
                defaults={
                    'name': name,
                    'pin_code': effective_pin,
                    'vehicle_info': vehicle,
                    'is_active': is_active,
                },
            )
    elif role == 'waiter':
        if staff_id and int(staff_id) > 0:
            obj = WaiterProfile.objects.filter(id=int(staff_id)).first()
            if not obj:
                return JsonResponse({'error': 'Ofitsiant topilmadi'}, status=404)
            obj.name = name
            obj.phone = phone
            obj.is_active = is_active
            if pin_code:
                obj.pin_code = pin_code
            obj.save()
        else:
            effective_pin = pin_code or '1234'
            obj, _ = WaiterProfile.objects.update_or_create(
                phone=phone,
                defaults={
                    'name': name,
                    'pin_code': effective_pin,
                    'is_active': is_active,
                },
            )
    else:
        return JsonResponse({'error': "Noto'g'ri rol (waiter yoki courier)"}, status=400)

    staff_list = _serialize_staff_accounts()
    saved_item = next((s for s in staff_list if s['role'] == role and s['id'] == obj.id), None)
    return JsonResponse({'status': 'ok', 'staff': saved_item})


@csrf_exempt
def pos_staff_toggle_api(request, role, staff_id):
    """POS Desktop orqali Xodim faolligini yoqish/o'chirish."""
    if request.method != 'POST':
        return JsonResponse({'error': 'Faqat POST qabul qilinadi'}, status=405)
    model = CourierProfile if role == 'courier' else WaiterProfile
    obj = model.objects.filter(id=staff_id).first()
    if not obj:
        return JsonResponse({'error': 'Xodim topilmadi'}, status=404)
    obj.is_active = not obj.is_active
    obj.save()
    return JsonResponse({'status': 'ok', 'id': obj.id, 'role': role, 'is_active': obj.is_active})


@csrf_exempt
def pos_staff_delete_api(request, role, staff_id):
    """POS Desktop orqali Xodimni o'chirish."""
    if request.method != 'POST':
        return JsonResponse({'error': 'Faqat POST qabul qilinadi'}, status=405)
    if role == 'courier':
        obj = CourierProfile.objects.filter(id=staff_id).first()
    else:
        obj = WaiterProfile.objects.filter(id=staff_id).first()
    if not obj:
        return JsonResponse({'error': 'Xodim topilmadi'}, status=404)
    if role == 'waiter':
        RestaurantTable.objects.filter(assigned_waiter=obj).update(assigned_waiter=None)
    obj.delete()
    return JsonResponse({'status': 'ok', 'deleted_id': staff_id, 'role': role})


@csrf_exempt
def pos_table_save_api(request):
    """POS Desktop orqali Stol qo'shish yoki tahrirlash."""
    if request.method != 'POST':
        return JsonResponse({'error': 'Faqat POST qabul qilinadi'}, status=405)
    body = _parse_json_body(request)
    if body is None:
        return JsonResponse({'error': "Noto'g'ri JSON format"}, status=400)

    tbl_id = body.get('id')
    try:
        number = int(body.get('number') or 0)
        capacity = int(body.get('capacity') or 4)
    except Exception:
        return JsonResponse({'error': "Stol raqami va o'rinlar soni butun son bo'lishi kerak"}, status=400)
    if number <= 0:
        return JsonResponse({'error': "Stol raqami 1 dan katta bo'lishi shart"}, status=400)

    name = (body.get('name') or f"Stol #{number}").strip()
    is_active = bool(body.get('is_active', True))

    if tbl_id and int(tbl_id) > 0:
        tbl = RestaurantTable.objects.filter(id=int(tbl_id)).first()
        if not tbl:
            return JsonResponse({'error': 'Stol topilmadi'}, status=404)
        conflict = RestaurantTable.objects.filter(number=number).exclude(id=tbl.id).exists()
        if conflict:
            return JsonResponse({'error': f"#{number} raqamli stol allaqachon mavjud"}, status=400)
        tbl.number = number
        tbl.name = name
        tbl.capacity = max(1, capacity)
        tbl.is_active = is_active
        tbl.save()
    else:
        tbl, _ = RestaurantTable.objects.update_or_create(
            number=number,
            defaults={'name': name, 'capacity': max(1, capacity), 'is_active': is_active},
        )

    all_tables = _serialize_tables()
    saved_tbl = next((t for t in all_tables if t['number'] == tbl.number), None)
    return JsonResponse({'status': 'ok', 'table': saved_tbl})


@csrf_exempt
def pos_table_delete_api(request, table_id):
    """POS Desktop orqali Stolni o'chirish."""
    if request.method != 'POST':
        return JsonResponse({'error': 'Faqat POST qabul qilinadi'}, status=405)
    tbl = RestaurantTable.objects.filter(id=table_id).first()
    if not tbl:
        return JsonResponse({'error': 'Stol topilmadi'}, status=404)
    has_open = Order.objects.filter(
        table_number=str(tbl.number), service_type='dine_in', is_paid=False
    ).exclude(status='bekor_qilingan').exists()
    if has_open:
        return JsonResponse({'error': f"Stol #{tbl.number} da hali yopilmagan buyurtma bor!"}, status=400)
    tbl.delete()
    return JsonResponse({'status': 'ok', 'deleted_id': table_id})


@csrf_exempt
def pos_settings_save_api(request):
    """POS Desktop orqali barcha Bot, Printer, Xizmat haqi, Yetkazish va To'lov sozlamalarini saqlash."""
    if request.method != 'POST':
        return JsonResponse({'error': 'Faqat POST qabul qilinadi'}, status=405)
    body = _parse_json_body(request)
    if body is None:
        return JsonResponse({'error': "Noto'g'ri JSON format"}, status=400)

    settings_obj = BotSettings.get_settings()

    if 'service_fee_type' in body and body['service_fee_type'] in ('percent', 'per_person', 'none'):
        settings_obj.service_fee_type = body['service_fee_type']
    if 'service_fee_percent' in body:
        settings_obj.service_fee_percent = Decimal(str(body['service_fee_percent'] or 0))
    if 'service_fee_per_person' in body:
        settings_obj.service_fee_per_person = Decimal(str(body['service_fee_per_person'] or 0))
    if 'auto_print_network' in body:
        settings_obj.auto_print_network = bool(body['auto_print_network'])

    printers = body.get('printers')
    if isinstance(printers, dict):
        for dept_key in ('kassa', 'shashlik', 'somsa', 'kitchen', 'fastfood', 'bar'):
            if dept_key in printers:
                setattr(settings_obj, f"printer_{dept_key}_ip", (printers.get(dept_key) or '').strip())

    for time_field in ('service_start_time', 'service_end_time'):
        raw_t = (body.get(time_field) or '').strip()
        if raw_t:
            try:
                parsed_t = datetime.datetime.strptime(raw_t, '%H:%M').time()
                setattr(settings_obj, time_field, parsed_t)
            except ValueError:
                return JsonResponse({'error': f"{time_field} HH:MM formatda bo'lishi kerak"}, status=400)

    if 'delivery_base_cost' in body:
        settings_obj.delivery_base_cost = Decimal(str(body['delivery_base_cost'] or 0))
    if 'delivery_cost_per_extra_km_block' in body:
        settings_obj.delivery_cost_per_extra_km_block = Decimal(str(body['delivery_cost_per_extra_km_block'] or 0))
    if 'delivery_max_radius_km' in body:
        rad = float(body['delivery_max_radius_km'] or 10.0)
        settings_obj.delivery_max_radius_km = max(1.0, min(100.0, rad))

    if 'broadcast_message_text' in body:
        settings_obj.broadcast_message_text = (body.get('broadcast_message_text') or '').strip()

    if 'click_service_id' in body:
        settings_obj.click_service_id = (body.get('click_service_id') or '').strip()
    if 'click_merchant_id' in body:
        settings_obj.click_merchant_id = (body.get('click_merchant_id') or '').strip()
    if (body.get('click_secret_key') or '').strip():
        settings_obj.click_secret_key = body['click_secret_key'].strip()

    if 'payme_merchant_id' in body:
        settings_obj.payme_merchant_id = (body.get('payme_merchant_id') or '').strip()
    if (body.get('payme_secret_key') or '').strip():
        settings_obj.payme_secret_key = body['payme_secret_key'].strip()

    settings_obj.save()
    return JsonResponse({'status': 'ok', 'settings': _serialize_settings(settings_obj)})


