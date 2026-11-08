import json
import logging
from decimal import Decimal
from datetime import datetime
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.db.models import Sum, Count, Q

from .models import (
    Category, Product, Order, OrderItem, Customer,
    RestaurantTable, WaiterProfile, CourierProfile, BotSettings
)
from .printer_service import (
    DEPARTMENT_CONFIG, categorize_order_items, 
    auto_print_order_to_network, format_escpos_slip, send_escpos_socket
)

logger = logging.getLogger(__name__)


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

    # 2. Kategoriyalar
    categories = []
    cat_qs = Category.objects.filter(is_active=True).order_by('name')
    for cat in cat_qs:
        categories.append({
            'id': cat.id,
            'name': cat.name,
            'department': cat.get_department(),
            'description': cat.description or '',
        })

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
    tables = []
    tables_qs = RestaurantTable.objects.filter(is_active=True).order_by('number')
    
    # Joriy yopilmagan stol buyurtmalari
    active_orders = Order.objects.filter(
        service_type='dine_in',
        is_paid=False
    ).exclude(status='bekor_qilingan').prefetch_related('items', 'items__product', 'items__product__category')
    order_by_table = {str(o.table_number): o for o in active_orders if o.table_number}

    for tbl in tables_qs:
        tbl_num_str = str(tbl.number)
        active_order = order_by_table.get(tbl_num_str)
        is_occupied = active_order is not None

        tables.append({
            'id': tbl.id,
            'number': tbl.number,
            'name': tbl.name or f"Stol #{tbl.number}",
            'capacity': tbl.capacity,
            'guests_count': active_order.guests_count if active_order else tbl.guests_count,
            'is_occupied': is_occupied,
            'opened_at': (active_order.created_at.isoformat() if active_order else (tbl.opened_at.isoformat() if tbl.opened_at else None)),
            'assigned_waiter': tbl.assigned_waiter.name if tbl.assigned_waiter else None,
            'active_order': _serialize_order(active_order) if active_order else None,
        })

    # 5. Sozlamalar
    settings_data = {
        'service_fee_type': settings.service_fee_type,
        'service_fee_percent': float(settings.service_fee_percent or 10.0),
        'service_fee_per_person': float(settings.service_fee_per_person or 5000.0),
        'auto_print_network': settings.auto_print_network,
        'delivery_base_cost': float(settings.delivery_base_cost or 5000),
        'printers': {
            'shashlik': settings.printer_shashlik_ip or '',
            'somsa': settings.printer_somsa_ip or '',
            'kitchen': settings.printer_kitchen_ip or '',
            'fastfood': settings.printer_fastfood_ip or '',
            'bar': settings.printer_bar_ip or '',
            'kassa': settings.printer_kassa_ip or '',
        }
    }

    return JsonResponse({
        'status': 'ok',
        'server_time': timezone.now().isoformat(),
        'settings': settings_data,
        'departments': departments,
        'categories': categories,
        'products': products,
        'stop_list': stop_list_ids,
        'tables': tables,
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
        tables_qs = RestaurantTable.objects.filter(is_active=True).order_by('number')
        active_orders = Order.objects.filter(
            service_type='dine_in',
            is_paid=False
        ).exclude(status='bekor_qilingan').prefetch_related('items', 'items__product')
        order_by_table = {str(o.table_number): o for o in active_orders if o.table_number}

        data = []
        for tbl in tables_qs:
            tbl_num_str = str(tbl.number)
            active_order = order_by_table.get(tbl_num_str)
            data.append({
                'id': tbl.id,
                'number': tbl.number,
                'name': tbl.name or f"Stol #{tbl.number}",
                'capacity': tbl.capacity,
                'guests_count': active_order.guests_count if active_order else tbl.guests_count,
                'is_occupied': active_order is not None,
                'opened_at': active_order.created_at.isoformat() if active_order else None,
                'active_order': _serialize_order(active_order) if active_order else None,
            })
        return JsonResponse({'status': 'ok', 'tables': data})

    if request.method == 'POST':
        try:
            body = json.loads(request.body.decode('utf-8'))
        except Exception:
            return JsonResponse({'error': 'Noto\'g\'ri JSON format'}, status=400)

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
        try:
            data = json.loads(request.body.decode('utf-8'))
        except Exception:
            return JsonResponse({'error': 'Noto\'g\'ri JSON format'}, status=400)

        order_id = data.get('id')
        offline_id = data.get('offline_id')
        service_type = data.get('service_type', 'dine_in')
        table_number = str(data.get('table_number', '')).strip()
        guests_count = int(data.get('guests_count', 1))
        payment_method = data.get('payment_method', 'naqd')
        is_paid = bool(data.get('is_paid', False))
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
            customer, _ = Customer.objects.get_or_create(
                phone_number=customer_phone,
                defaults={'full_name': customer_name, 'telegram_id': int(datetime.now().timestamp() * 1000) % 1000000000}
            )

            if not order:
                order = Order(
                    customer=customer,
                    service_type=service_type,
                    table_number=table_number if service_type == 'dine_in' else None,
                    guests_count=guests_count,
                    status='tasdiqlangan' if is_paid else 'yangi',
                    payment_method=payment_method,
                    is_paid=is_paid,
                    offline_id=offline_id,
                    notes=notes,
                    products_total=0,
                    delivery_cost=0,
                    service_fee_amount=0,
                    total_amount=0,
                )
                order.save()
            else:
                order.guests_count = guests_count
                order.notes = notes
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

                # 3. Xizmat haqini hisoblash (Faqat dine_in stollar uchun yoki sozlamaga qarab)
                service_fee = Decimal('0')
                if service_type == 'dine_in':
                    if settings.service_fee_type == 'percent':
                        pct = Decimal(str(settings.service_fee_percent or 10)) / Decimal('100')
                        service_fee = (products_total * pct).quantize(Decimal('100'))
                    elif settings.service_fee_type == 'per_person':
                        per_person = Decimal(str(settings.service_fee_per_person or 5000))
                        service_fee = (Decimal(guests_count) * per_person)

                order.service_fee_amount = service_fee
                order.total_amount = products_total + service_fee + Decimal(str(order.delivery_cost or 0))
                order.save()

            # Agar bu to'langan Saboy bo'lsa, holati 'olib_ketildi'
            if service_type == 'pickup' and is_paid:
                order.status = 'olib_ketildi'
                order.picked_up_at = timezone.now()
                order.save()

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
    try:
        body = json.loads(request.body.decode('utf-8'))
    except Exception:
        body = {}

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

    # Kassa printeriga hisob chekini chiqarish
    settings = BotSettings.get_settings()
    if settings.printer_kassa_ip:
        categorized = categorize_order_items(order)
        slip_bytes = format_escpos_slip(order, 'kassa', categorized['departments']['kassa'])
        send_escpos_socket(settings.printer_kassa_ip, slip_bytes, timeout=0.8)

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

    try:
        body = json.loads(request.body.decode('utf-8'))
    except Exception:
        body = {}

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
        status__in=['yangi', 'tasdiqlangan'],
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
    try:
        body = json.loads(request.body.decode('utf-8'))
    except Exception:
        body = {}

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
    Offline-First Sinxronizatsiya:
    Internet uzilgan vaqtda C# kassa ilovasida yaratilgan va yopilgan buyurtmalarni
    serverga ommaviy yuklash (Batch sync).
    """
    if request.method != 'POST':
        return JsonResponse({'error': 'Faqat POST qabul qilinadi'}, status=405)

    try:
        data = json.loads(request.body.decode('utf-8'))
    except Exception:
        return JsonResponse({'error': 'Noto\'g\'ri JSON format'}, status=400)

    orders_batch = data.get('orders', [])
    synced_ids = []

    for o_data in orders_batch:
        offline_id = o_data.get('offline_id')
        if not offline_id:
            continue

        existing = Order.objects.filter(offline_id=offline_id).first()
        if existing:
            synced_ids.append(offline_id)
            continue

        service_type = o_data.get('service_type', 'pickup')
        table_number = o_data.get('table_number')
        guests_count = int(o_data.get('guests_count', 1))
        customer_phone = o_data.get('customer_phone', '+998000000000')
        customer_name = o_data.get('customer_name', 'Kassa (Offline)')

        customer, _ = Customer.objects.get_or_create(
            phone_number=customer_phone,
            defaults={'full_name': customer_name, 'telegram_id': int(datetime.now().timestamp() * 1000) % 1000000000}
        )

        with transaction.atomic():
            order = Order.objects.create(
                customer=customer,
                offline_id=offline_id,
                service_type=service_type,
                table_number=table_number,
                guests_count=guests_count,
                status=o_data.get('status', 'olib_ketildi'),
                payment_method=o_data.get('payment_method', 'naqd'),
                is_paid=o_data.get('is_paid', True),
                notes=o_data.get('notes', 'Offline kassa orqali yopilgan'),
                products_total=Decimal(str(o_data.get('products_total', 0))),
                service_fee_amount=Decimal(str(o_data.get('service_fee_amount', 0))),
                total_amount=Decimal(str(o_data.get('total_amount', 0))),
                delivery_cost=0,
                is_synced=True
            )

            for item_d in o_data.get('items', []):
                prod_id = item_d.get('product_id')
                qty = int(item_d.get('quantity', 1))
                price = Decimal(str(item_d.get('price', 0)))
                prod = Product.objects.filter(id=prod_id).first()
                if prod:
                    OrderItem.objects.create(
                        order=order,
                        product=prod,
                        quantity=qty,
                        price=price,
                        total=price * qty
                    )

            synced_ids.append(offline_id)

    return JsonResponse({
        'status': 'ok',
        'synced_count': len(synced_ids),
        'synced_ids': synced_ids,
        'server_time': timezone.now().isoformat(),
    })

