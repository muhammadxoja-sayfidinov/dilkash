from django.shortcuts import render, get_object_or_404, redirect
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone
from django.db.models import Count, Q, Sum
from django.core.paginator import Paginator
import json
import logging
from decimal import Decimal
from datetime import timedelta, datetime, time


from django.conf import settings
from .utils import send_telegram_message, send_telegram_location
from .models import Order, Product, Category, OrderItem, OrderStatusHistory, Customer, RestaurantTable, BotSettings, WaiterCall, WaiterProfile, CourierProfile
from .forms import ProductForm, CategoryForm
from .payments import generate_click_url, generate_payme_url
from .printer_service import (
    categorize_order_items, 
    DEPARTMENT_CONFIG, 
    send_escpos_socket, 
    format_escpos_slip, 
    format_escpos_test_slip,
    auto_print_order_to_network
)

logger = logging.getLogger(__name__)

def dashboard(request):
    """Oshpaz dashboard"""
    # Statistika
    today = timezone.now().date()
    
    stats = {
        'yangi_buyurtmalar': Order.objects.filter(status='yangi').count(),
        'tasdiqlangan_buyurtmalar': Order.objects.filter(status='tasdiqlangan').count(),
        'tayor_buyurtmalar': Order.objects.filter(status='tayor').count(),
        'bugungi_buyurtmalar': Order.objects.filter(created_at__date=today).count(),
        'pickup_buyurtmalar': Order.objects.filter(service_type='pickup', status__in=['yangi', 'tasdiqlangan', 'tayor']).count(),
        'dine_in_buyurtmalar': Order.objects.filter(service_type='dine_in', status__in=['yangi', 'tasdiqlangan', 'tayor']).count(),
        'delivery_buyurtmalar': Order.objects.filter(service_type='delivery', status__in=['yangi', 'tasdiqlangan', 'tayor', 'yolda']).count(),
    }
    
    # Oxirgi buyurtmalar
    recent_orders = Order.objects.filter(
        Q(status__in=['yangi', 'tasdiqlangan']) |
        Q(status='tayor', service_type__in=['pickup', 'dine_in'])
    ).order_by('-created_at')[:10]
    
    # Mijozlar statistikasi: eng ko'p buyurtma bergan mijozlar
    top_customers = Customer.objects.annotate(
        order_count=Count('order')
    ).order_by('-order_count')[:10]

    # Haftalik buyurtmalar statistikasi
    seven_days_ago = timezone.now() - timedelta(days=7)
    weekly_orders_queryset = Order.objects.filter(created_at__gte=seven_days_ago)
    
    weekly_stats = {
        'total_orders': weekly_orders_queryset.count(),
        'total_amount': weekly_orders_queryset.aggregate(Sum('total_amount'))['total_amount__sum'] or 0,
        'pickup_orders': weekly_orders_queryset.filter(service_type='pickup').count(),
        'delivery_orders': weekly_orders_queryset.filter(service_type='delivery').count(),
    }

    # Bugungi umumiy savdo
    today_sales = Order.objects.filter(created_at__date=today).aggregate(Sum('total_amount'))['total_amount__sum'] or 0

    # Holatlar bo'yicha savdo
    sales_by_status = Order.objects.values('status').annotate(total_sales=Sum('total_amount')).order_by('status')
    
    # Status nomlarini olish uchun lug'at yaratamiz
    status_display_map = dict(Order.STATUS_CHOICES)
    sales_by_status_display = []
    for item in sales_by_status:
        sales_by_status_display.append({
            'status': status_display_map.get(item['status'], item['status']),
            'total_sales': item['total_sales']
        })

    # Service type bo'yicha statistika
    service_stats = Order.objects.values('service_type').annotate(
        total_orders=Count('id'),
        total_sales=Sum('total_amount')
    ).order_by('service_type')
    
    service_display_map = dict(Order.SERVICE_TYPE_CHOICES)
    service_stats_display = []
    for item in service_stats:
        service_stats_display.append({
            'service_type': service_display_map.get(item['service_type'], item['service_type']),
            'total_orders': item['total_orders'],
            'total_sales': item['total_sales']
        })

    context = {
        'stats': stats,
        'recent_orders': recent_orders,
        'top_customers': top_customers,
        'weekly_stats': weekly_stats,
        'today_sales': today_sales,
        'sales_by_status': sales_by_status_display,
        'service_stats': service_stats_display,
    }
    return render(request, 'chef_panel/dashboard.html', context)

def order_list(request):
    """Barcha buyurtmalar ro'yxati"""
    status_filter = request.GET.get('status', '')
    service_type_filter = request.GET.get('service_type', '')
    search = request.GET.get('search', '')
    
    orders = Order.objects.all().order_by('-created_at')
    
    if status_filter:
        orders = orders.filter(status=status_filter)
    
    if service_type_filter:
        orders = orders.filter(service_type=service_type_filter)
    
    if search:
        orders = orders.filter(
            Q(order_number__icontains=search) |
            Q(customer__full_name__icontains=search) |
            Q(customer__phone_number__icontains=search)
        )
    
    paginator = Paginator(orders, 20)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    context = {
        'page_obj': page_obj,
        'status_filter': status_filter,
        'service_type_filter': service_type_filter,
        'search': search,
        'status_choices': Order.STATUS_CHOICES,
        'service_type_choices': Order.SERVICE_TYPE_CHOICES,
    }
    return render(request, 'chef_panel/order_list.html', context)

def new_orders(request):
    """Yangi buyurtmalar - pickup va dine_in buyurtmalar yakunlanmaguncha ko'rinadi"""
    orders = Order.objects.filter(
        Q(status__in=['yangi', 'tasdiqlangan']) |
        Q(status='tayor', service_type__in=['pickup', 'dine_in'])
    ).order_by('-created_at')
    
    context = {
        'orders': orders,
        'title': 'Yangi buyurtmalar',
    }
    return render(request, 'chef_panel/new_orders.html', context)

def order_detail(request, order_id):
    """Buyurtma tafsilotlari"""
    order = get_object_or_404(Order, id=order_id)
    order_items = order.items.all()
    status_history = order.status_history.all()
    
    context = {
        'order': order,
        'order_items': order_items,
        'status_history': status_history,
    }
    return render(request, 'chef_panel/order_detail.html', context)

@csrf_exempt
def create_order_api(request):
    """Telegram botdan yangi buyurtma qabul qilish API"""
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            
            # Mijozni topish yoki yaratish
            telegram_id = data.get('user_id')
            full_name = data.get('full_name', 'Noma\'lum')
            phone_number = data.get('phone', 'Noma\'lum')
            
            if not telegram_id:
                digits = ''.join(c for c in str(phone_number) if c.isdigit())
                telegram_id = int(digits[-9:]) if len(digits) >= 7 else int(timezone.now().timestamp())
            
            customer, created = Customer.objects.get_or_create(
                telegram_id=telegram_id,
                defaults={'full_name': full_name, 'phone_number': phone_number}
            )
            if not created:
                # Agar mijoz mavjud bo'lsa, ma'lumotlarini yangilash
                customer.full_name = full_name
                customer.phone_number = phone_number
                customer.save()

            # Buyurtma yaratish
            service_type = data.get('service_type', 'delivery')
            raw_table = data.get('table_number')
            table_number = None
            if raw_table and str(raw_table).strip().lower() not in ['none', 'null', '0', '']:
                table_number = str(raw_table).strip()

            # Mini ilova orqali stolga buyurtma qabul qilinmaydi (faqat ofitsiant orqali olinadi)
            if service_type == 'dine_in' or table_number:
                return JsonResponse({
                    'status': 'error',
                    'success': False,
                    'message': "Mini ilova orqali stolga buyurtma qabul qilinmaydi. Stolga buyurtmalar faqat ofitsiant orqali qabul qilinadi."
                }, status=400)

            table_obj = None
            if table_number and table_number.isdigit():
                table_obj = RestaurantTable.objects.filter(number=int(table_number)).first()

            # Agar bu dine_in bo'lsa va shu stolda faol buyurtma mavjud bo'lsa, taomlarni unga qo'shamiz
            existing_active_order = None
            if service_type == 'dine_in' and table_number:
                existing_active_order = Order.objects.filter(
                    service_type='dine_in',
                    table_number=str(table_number),
                    status__in=['yangi', 'tasdiqlangan', 'tayor']
                ).first()

            if existing_active_order:
                order = existing_active_order
                added_total = Decimal(str(data.get('products_total') or data.get('total') or 0))
                order.products_total = (order.products_total or Decimal('0')) + added_total
                order.total_amount = (order.total_amount or Decimal('0')) + added_total
                order.save()

                for item_data in data.get('products', []):
                    product_name, quantity, item_price = item_data
                    product = Product.objects.filter(name=product_name).first()
                    if product:
                        order_item, item_created = OrderItem.objects.get_or_create(
                            order=order,
                            product=product,
                            defaults={
                                'quantity': quantity,
                                'price': item_price,
                                'total': quantity * item_price
                            }
                        )
                        if not item_created:
                            order_item.quantity += quantity
                            order_item.total = order_item.quantity * order_item.price
                            order_item.save()

                OrderStatusHistory.objects.create(
                    order=order,
                    old_status=order.status,
                    new_status=order.status,
                    notes=f"Mijoz QR menyudan qo'shimcha taom qo'shdi (+{added_total:,.0f} so'm)"
                )
            else:
                order = Order.objects.create(
                    customer=customer,
                    telegram_user_id=telegram_id,
                    status='yangi',
                    payment_method=data.get('payment_method', 'naqd'),
                    service_type=service_type,
                    table_number=table_number,
                    waiter=table_obj.assigned_waiter if table_obj else None,
                    waiter_name=table_obj.assigned_waiter.name if (table_obj and table_obj.assigned_waiter) else None,
                    latitude=(data.get('latitude') or (data.get('location', {}) or {}).get('latitude')) if service_type == 'delivery' else None,
                    longitude=(data.get('longitude') or (data.get('location', {}) or {}).get('longitude')) if service_type == 'delivery' else None,
                    address=data.get('address', '') if service_type == 'delivery' else None,
                    products_total=Decimal(str(data.get('products_total') or data.get('total') or 0)),
                    delivery_cost=Decimal(str(data.get('delivery_cost') or 0)),
                    total_amount=Decimal(str(data.get('total') or data.get('products_total') or 0)),
                )

                # Buyurtma elementlarini qo'shish
                for item_data in data.get('products', []):
                    product_name, quantity, item_price = item_data
                    product = Product.objects.filter(name=product_name).first()
                    if product:
                        OrderItem.objects.create(
                            order=order,
                            product=product,
                            quantity=quantity,
                            price=item_price,
                            total=quantity * item_price
                        )
                    else:
                        logger.warning(f"Mahsulot topilmadi: {product_name} (Buyurtma ID: {order.id})")

                # Holat tarixini saqlash
                OrderStatusHistory.objects.create(
                    order=order,
                    old_status='',
                    new_status='yangi',
                    notes='Telegram WebApp / Sayt orqali yaratildi'
                )

            # Oshpazga xabar yuborish
            if existing_active_order:
                chef_text = f"➕ <b>STOL #{order.table_number} GA QO'SHIMCHA TAOM!</b>\n\n"
                chef_text += f"📋 Buyurtma: #{order.order_number}\n"
                chef_text += f"⏰ Vaqt: {timezone.now().strftime('%H:%M')}\n"
                chef_text += f"\n🍽 <b>Yangi qo'shilgan taomlar:</b>\n"
                for item_data in data.get('products', []):
                    chef_text += f"• {item_data[1]} dona {item_data[0]} - {int(item_data[1])*float(item_data[2]):,.0f} so'm\n"
                chef_text += f"\n💰 Yangilangan jami hisob: {order.total_amount:,.0f} so'm"
            else:
                chef_text = f"🍽 **Yangi buyurtma #{order.order_number}**\n\n"
                chef_text += f"👨‍💼 Ism: {full_name}\n"
                chef_text += f"📱 Telefon: {phone_number}\n"
                chef_text += f"💳 To'lov usuli: {order.get_payment_method_display()}\n"
                
                if order.service_type == 'dine_in':
                    chef_text += f"🍽 **STOL: #{order.table_number or '1'} (Restoranda)**\n"
                elif order.service_type == 'delivery':
                    chef_text += f"🚀 Xizmat turi: {order.get_service_type_display()}\n"
                    if order.address:
                        chef_text += f"🏠 Manzil: {order.address}\n"
                    else:
                        chef_text += "📍 Manzil: Faqat lokatsiya\n"
                else:
                    chef_text += "🏪 Olib ketish uchun: Restoranidan\n"
                    
                chef_text += f"\n🍽 **Mahsulotlar:**\n"
                for item in order.items.all():
                    chef_text += f"• {item.quantity} dona {item.product.name} - {item.total:,} so'm\n"
                chef_text += f"\n💰 Jami: {order.total_amount:,} so'm"

            # Foydalanuvchiga xabar
            user_text = f"✅ **Buyurtmangiz qabul qilindi!**\n\n"
            user_text += f"📋 Buyurtma ID: **{order.order_number}**\n"
            user_text += f"👨‍💼 Ism: {full_name}\n"
            user_text += f"📱 Telefon: {phone_number}\n"
            user_text += f"💳 To'lov usuli: {order.get_payment_method_display()}\n"
            user_text += f"🚀 Xizmat turi: {order.get_service_type_display()}\n"
            
            if order.service_type == 'delivery':
                if order.address:
                    user_text += f"🏠 Manzil: {order.address}\n"
                else:
                    user_text += "📍 Manzil: Faqat lokatsiya\n"
                if order.latitude and order.longitude:
                    user_text += f"📍 Lokatsiya: https://www.google.com/maps?q={order.latitude},{order.longitude}\n"
            elif order.service_type == 'dine_in':
                user_text += f"🍽 Stol: #{order.table_number or '1'} (Restoranda)\n"
            else:
                user_text += "🏪 Olib ketish uchun: Restoranidan\n"
                
            user_text += f"\n🍽 **Mahsulotlar:**\n"
            for item in order.items.all():
                user_text += f"• {item.quantity} dona {item.product.name} - {item.total:,} so'm\n"
            user_text += f"\n💰 Jami: {order.total_amount:,} so'm\n🆕 Status: **Yangi**"

            user_keyboard = [[{'text': "⬅️ Bosh menu", 'callback_data': "main_menu"}]]
            user_msg_response = send_telegram_message(
                chat_id=telegram_id,
                text=user_text,
                reply_markup={'inline_keyboard': user_keyboard}
            )
            if user_msg_response and user_msg_response.get('ok'):
                order.user_message_id = user_msg_response['result']['message_id']
            
            order.save() # Save message IDs

            # Agar to'lov usuli Click yoki Payme bo'lsa, to'lov havolasini qaytarish
            payment_url = None
            if order.payment_method == 'click':
                payment_url = generate_click_url(order)
            elif order.payment_method == 'payme':
                payment_url = generate_payme_url(order)

            return JsonResponse({
                'success': True, 
                'order_id': order.id, 
                'order_number': order.order_number,
                'payment_url': payment_url
            })
        except Exception as e:
            logger.error(f"Buyurtma yaratishda xato: {e}", exc_info=True)
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'success': False, 'message': 'Faqat POST so\'rov qabul qilinadi'}, status=405)

def _update_telegram_messages(order, old_status, new_status, changed_by_user=None):
    """Buyurtma holati o'zgarganda Telegram xabarlarini yangilash"""
    status_emoji = {
        "yangi": "🆕",
        "tasdiqlangan": "✅",
        "tayor": "🍽",
        "yolda": "🚚",
        "yetkazildi": "✅",
        "olib_ketildi": "✅",
        "bekor_qilingan": "❌"
    }
    emoji = status_emoji.get(new_status, "📋")

    # Foydalanuvchi xabarini yangilash
    user_text = f"✅ **Buyurtmangiz qabul qilindi!**\n\n"
    user_text += f"📋 Buyurtma ID: **{order.order_number}**\n"
    user_text += f"👨‍💼 Ism: {order.customer.full_name}\n"
    user_text += f"📱 Telefon: {order.customer.phone_number}\n"
    user_text += f"💳 To'lov usuli: {order.get_payment_method_display()}\n"
    user_text += f"🚀 Xizmat turi: {order.get_service_type_display()}\n"
    
    if order.service_type == 'delivery':
        if order.address:
            user_text += f"🏠 Manzil: {order.address}\n"
        else:
            user_text += "📍 Manzil: Faqat lokatsiya\n"
        if order.latitude and order.longitude:
            user_text += f"📍 Lokatsiya: https://www.google.com/maps?q={order.latitude},{order.longitude}\n"
    else:
        user_text += "🏪 Olib ketish uchun: Restoranidan\n"
        
    user_text += f"\n🍽 **Mahsulotlar:**\n"
    for item in order.items.all():
        user_text += f"• {item.quantity} dona {item.product.name} - {item.total:,} so'm\n"
    user_text += f"\n💰 Jami: {order.total_amount:,} so'm\n"
    user_text += f"{emoji} Status: **{order.get_status_display()}**"

    user_keyboard = [[{'text': "⬅️ Bosh menu", 'callback_data': "main_menu"}]]
    
    if order.user_message_id and order.telegram_user_id:
        send_telegram_message(
            chat_id=order.telegram_user_id,
            text=user_text,
            reply_markup={'inline_keyboard': user_keyboard},
            message_id=order.user_message_id
        )
    else:
        # Agar message_id yo'q bo'lsa, yangi xabar yuborish
        if order.telegram_user_id:
            response = send_telegram_message(
                chat_id=order.telegram_user_id,
                text=user_text,
                reply_markup={'inline_keyboard': user_keyboard}
            )
            if response and response.get('ok'):
                order.user_message_id = response['result']['message_id']
                order.save()

def is_valid_status_transition(service_type, old_status, new_status):
    """Buyurtma holatini o'zgartirish qoidalari (dine_in, pickup, delivery)"""
    if old_status == new_status:
        return True, "Holat allaqachon o'rnatilgan"

    if new_status == 'bekor_qilingan' and old_status not in ['yetkazildi', 'olib_ketildi', 'bekor_qilingan']:
        return True, "Bekor qilish mumkin"

    valid_transitions = {
        'pickup': {
            'yangi': ['tasdiqlangan', 'tayor'],
            'tasdiqlangan': ['tayor'],
            'tayor': ['olib_ketildi'],
        },
        'dine_in': {
            'yangi': ['tasdiqlangan', 'tayor', 'yetkazildi'],
            'tasdiqlangan': ['tayor', 'yetkazildi'],
            'tayor': ['yetkazildi', 'olib_ketildi'],
            'yetkazildi': [],
        },
        'delivery': {
            'yangi': ['tasdiqlangan', 'tayor'],
            'tasdiqlangan': ['tayor'],
            'tayor': ['yolda', 'yetkazildi'],
            'yolda': ['yetkazildi'],
        }
    }

    transitions_for_type = valid_transitions.get(service_type, valid_transitions['delivery'])
    allowed = transitions_for_type.get(old_status, [])
    if new_status in allowed:
        return True, "O'tishga ruxsat berildi"

    return False, f"Holat '{old_status}' dan '{new_status}' ga o'zgartirishga ruxsat berilmagan."

@csrf_exempt
def update_order_status(request):
    """Buyurtma holatini yangilash API"""
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            order_id = data.get('order_id')
            new_status = data.get('status')
            
            order = get_object_or_404(Order, id=order_id)
            old_status = order.status
            
            if old_status == new_status:
                return JsonResponse({
                    'success': True,
                    'message': f"Buyurtma holati allaqachon '{new_status}'"
                })

            is_valid, msg = is_valid_status_transition(order.service_type, old_status, new_status)
            if not is_valid:
                return JsonResponse({'success': False, 'message': msg}, status=400)
            
            # Holatni yangilash
            order.status = new_status
            
            # Vaqt belgilarini yangilash
            if new_status == 'tasdiqlangan':
                order.confirmed_at = timezone.now()
            elif new_status == 'tayor':
                order.ready_at = timezone.now()
            elif new_status == 'yetkazildi':
                order.delivered_at = timezone.now()
            elif new_status == 'olib_ketildi':
                order.picked_up_at = timezone.now()
            
            order.save()
            
            # Holat tarixini saqlash
            OrderStatusHistory.objects.create(
                order=order,
                old_status=old_status,
                new_status=new_status,
                changed_by=request.user if request.user.is_authenticated else None,
                notes=f'Web panel orqali yangilandi'
            )
            
            # Telegram xabarlarini yangilash
            _update_telegram_messages(order, old_status, new_status, request.user)
            
            return JsonResponse({
                'success': True, 
                'message': f'Buyurtma holati {old_status} dan {new_status} ga o\'zgartirildi.'
            })
        except Exception as e:
            logger.error(f"Buyurtma holatini yangilashda xato: {e}", exc_info=True)
            return JsonResponse({'success': False, 'message': str(e)}, status=500)
    return JsonResponse({'success': False, 'message': 'Faqat POST so\'rov qabul qilinadi'}, status=405)

@csrf_exempt
def confirm_order(request, order_id):
    """Buyurtmani tasdiqlash"""
    if request.method == 'POST':
        order = get_object_or_404(Order, id=order_id)
        
        if order.status == 'yangi':
            old_status = order.status
            order.status = 'tasdiqlangan'
            order.confirmed_at = timezone.now()
            order.save()
            
            # Holat tarixini saqlash
            OrderStatusHistory.objects.create(
                order=order,
                old_status=old_status,
                new_status='tasdiqlangan',
                changed_by=request.user if request.user.is_authenticated else None,
                notes='Oshpaz tomonidan tasdiqlandi'
            )
            
            _update_telegram_messages(order, old_status, 'tasdiqlangan', request.user)
            
            messages.success(request, f'Buyurtma #{order.order_number} tasdiqlandi!')
            return JsonResponse({'success': True, 'message': 'Buyurtma tasdiqlandi'})
        else:
            return JsonResponse({'success': False, 'message': 'Buyurtma allaqachon tasdiqlangan'})
    
    return JsonResponse({'success': False, 'message': 'Noto\'g\'ri so\'rov'})

@csrf_exempt
def mark_ready(request, order_id):
    """Buyurtmani tayor deb belgilash"""
    if request.method == 'POST':
        order = get_object_or_404(Order, id=order_id)
        
        if order.status == 'tasdiqlangan':
            old_status = order.status
            order.status = 'tayor'
            order.ready_at = timezone.now()
            order.save()
            
            # Holat tarixini saqlash
            OrderStatusHistory.objects.create(
                order=order,
                old_status=old_status,
                new_status='tayor',
                changed_by=request.user if request.user.is_authenticated else None,
                notes='Oshpaz tomonidan tayor deb belgilandi'
            )
            
            _update_telegram_messages(order, old_status, 'tayor', request.user)
            
            messages.success(request, f'Buyurtma #{order.order_number} tayor!')
            return JsonResponse({'success': True, 'message': 'Buyurtma tayor'})
        else:
            return JsonResponse({'success': False, 'message': 'Buyurtma avval tasdiqlanishi kerak'})
    
    return JsonResponse({'success': False, 'message': 'Noto\'g\'ri so\'rov'})

@csrf_exempt
def mark_picked_up(request, order_id):
    """Pickup buyurtmani olib ketildi deb belgilash"""
    if request.method == 'POST':
        order = get_object_or_404(Order, id=order_id)
        
        if order.status == 'tayor' and order.service_type == 'pickup':
            old_status = order.status
            order.status = 'olib_ketildi'
            order.picked_up_at = timezone.now()
            order.save()
            
            # Holat tarixini saqlash
            OrderStatusHistory.objects.create(
                order=order,
                old_status=old_status,
                new_status='olib_ketildi',
                changed_by=request.user if request.user.is_authenticated else None,
                notes='Oshpaz tomonidan olib ketildi deb belgilandi'
            )
            
            _update_telegram_messages(order, old_status, 'olib_ketildi', request.user)
            
            messages.success(request, f'Buyurtma #{order.order_number} olib ketildi!')
            return JsonResponse({'success': True, 'message': 'Buyurtma olib ketildi'})
        else:
            return JsonResponse({'success': False, 'message': 'Buyurtma tayor holatida bo\'lishi va pickup turi bo\'lishi kerak'})
    
    return JsonResponse({'success': False, 'message': 'Noto\'g\'ri so\'rov'})

@csrf_exempt
def cancel_order(request, order_id):
    """Buyurtmani bekor qilish"""
    if request.method == 'POST':
        order = get_object_or_404(Order, id=order_id)
        
        if order.status not in ['yetkazildi', 'olib_ketildi', 'bekor_qilingan']:
            old_status = order.status
            order.status = 'bekor_qilingan'
            order.save()
            
            # Holat tarixini saqlash
            OrderStatusHistory.objects.create(
                order=order,
                old_status=old_status,
                new_status='bekor_qilingan',
                changed_by=request.user if request.user.is_authenticated else None,
                notes='Oshpaz tomonidan bekor qilindi'
            )
            
            _update_telegram_messages(order, old_status, 'bekor_qilingan', request.user)
            
            messages.success(request, f'Buyurtma #{order.order_number} bekor qilindi!')
            return JsonResponse({'success': True, 'message': 'Buyurtma bekor qilindi'})
        else:
            return JsonResponse({'success': False, 'message': 'Bu buyurtmani bekor qilib bo\'lmaydi'})
    
    return JsonResponse({'success': False, 'message': 'Noto\'g\'ri so\'rov'})

# Mahsulotlar boshqaruvi
def product_list(request):
    """Mahsulotlar ro'yxati"""
    products = Product.objects.all().order_by('category', 'name')
    categories = Category.objects.filter(is_active=True)
    
    category_filter = request.GET.get('category')
    if category_filter:
        products = products.filter(category_id=category_filter)
    
    context = {
        'products': products,
        'categories': categories,
        'selected_category': int(category_filter) if category_filter else None,
    }
    return render(request, 'chef_panel/product_list.html', context)

def add_product(request):
    """Yangi mahsulot qo'shish"""
    if request.method == 'POST':
        form = ProductForm(request.POST, request.FILES)
        if form.is_valid():
            form.save()
            messages.success(request, 'Mahsulot muvaffaqiyatli qo\'shildi!')
            return redirect('chef_panel:product_list')
    else:
        form = ProductForm()
    return render(request, 'chef_panel/add_product.html', {'form': form})

def edit_product(request, product_id):
    """Mahsulotni tahrirlash"""
    product = get_object_or_404(Product, id=product_id)
    if request.method == 'POST':
        form = ProductForm(request.POST, request.FILES, instance=product)
        if form.is_valid():
            form.save()
            messages.success(request, 'Mahsulot muvaffaqiyatli yangilandi!')
            return redirect('chef_panel:product_list')
    else:
        form = ProductForm(instance=product)
    return render(request, 'chef_panel/edit_product.html', {'form': form, 'product': product})

# Kategoriyalar boshqaruvi
def category_list(request):
    """Kategoriyalar ro'yxati"""
    categories = Category.objects.all().order_by('name')
    return render(request, 'chef_panel/category_list.html', {'categories': categories})

def add_category(request):
    """Yangi kategoriya qo'shish"""
    if request.method == 'POST':
        form = CategoryForm(request.POST)
        if form.is_valid():
            form.save()
            messages.success(request, 'Kategoriya muvaffaqiyatli qo\'shildi!')
            return redirect('chef_panel:category_list')
    else:
        form = CategoryForm()
    return render(request, 'chef_panel/add_category.html', {'form': form})

@csrf_exempt
def update_order_status_api(request):
    """API: Buyurtma holatini yangilash (Telegram botdan keladigan so'rovlar uchun)"""
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            order_id = data.get('order_id')
            new_status = data.get('status')
            
            order = get_object_or_404(Order, id=order_id)
            old_status = order.status
            
            if old_status == new_status:
                return JsonResponse({
                    'success': True,
                    'message': f"Buyurtma holati allaqachon '{new_status}'"
                })

            is_valid, msg = is_valid_status_transition(order.service_type, old_status, new_status)
            if not is_valid:
                return JsonResponse({'success': False, 'message': msg}, status=400)

            order.status = new_status
            
            # Vaqt belgilarini yangilash
            if new_status == 'tasdiqlangan':
                order.confirmed_at = timezone.now()
            elif new_status == 'tayor':
                order.ready_at = timezone.now()
            elif new_status == 'yetkazildi':
                order.delivered_at = timezone.now()
            elif new_status == 'olib_ketildi':
                order.picked_up_at = timezone.now()
            
            order.save()
            
            # Holat tarixini saqlash
            OrderStatusHistory.objects.create(
                order=order,
                old_status=old_status,
                new_status=new_status,
                notes=f'Telegram bot orqali yangilandi'
            )
            
            _update_telegram_messages(order, old_status, new_status) # Update messages after status change
            
            return JsonResponse({
                'success': True, 
                'message': f'Buyurtma holati {new_status}ga o\'zgartirildi'
            })
            
        except Exception as e:
            logger.error(f"API orqali buyurtma holatini yangilashda xato: {e}", exc_info=True)
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    
    return JsonResponse({'success': False, 'message': 'Faqat POST so\'rov qabul qilinadi'}, status=405)

@csrf_exempt
def get_user_orders_api(request, telegram_id):
    """API: Foydalanuvchining buyurtmalarini olish"""
    if request.method == 'GET':
        try:
            customer = get_object_or_404(Customer, telegram_id=telegram_id)
            orders = Order.objects.filter(customer=customer).order_by('-created_at')
            
            orders_data = []
            for order in orders:
                orders_data.append({
                    'order_id': order.order_number,
                    'date': order.created_at.strftime("%Y-%m-%d %H:%M"),
                    'total': float(order.total_amount),
                    'status': order.status,
                    'status_display': order.get_status_display(),
                    'service_type': order.service_type,
                    'service_type_display': order.get_service_type_display(),
                })
            
            return JsonResponse({'success': True, 'orders': orders_data})
        except Exception as e:
            logger.error(f"Foydalanuvchi buyurtmalarini olishda xato: {e}", exc_info=True)
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'success': False, 'message': 'Faqat GET so\'rov qabul qilinadi'}, status=405)

@csrf_exempt
def get_order_details_api(request, order_id):
    """API: Buyurtma tafsilotlarini olish (popup uchun)"""
    if request.method == 'GET':
        try:
            order = get_object_or_404(Order, id=order_id)
            
            order_items_data = []
            for item in order.items.all():
                order_items_data.append({
                    'product_name': item.product.name,
                    'quantity': item.quantity,
                    'price': float(item.price),
                    'total': float(item.total),
                })
                
            status_history_data = []
            for history in order.status_history.all().order_by('changed_at'):
                status_history_data.append({
                    'old_status': history.old_status,
                    'new_status': history.new_status,
                    'new_status_display': dict(Order.STATUS_CHOICES).get(history.new_status, history.new_status),
                    'timestamp': history.changed_at.strftime("%Y-%m-%d %H:%M:%S"),
                    'notes': history.notes,
                    'changed_by': history.changed_by.username if history.changed_by else 'Tizim',
                })

            order_data = {
                'id': order.id,
                'order_number': order.order_number,
                'created_at': order.created_at.strftime("%Y-%m-%d %H:%M:%S"),
                'status': order.status,
                'status_display': order.get_status_display(),
                'payment_method': order.payment_method,
                'payment_method_display': order.get_payment_method_display(),
                'service_type': order.service_type,
                'service_type_display': order.get_service_type_display(),
                'latitude': float(order.latitude) if order.latitude else None,
                'longitude': float(order.longitude) if order.longitude else None,
                'address': order.address,
                'products_total': float(order.products_total),
                'delivery_cost': float(order.delivery_cost),
                'total_amount': float(order.total_amount),
                'customer': {
                    'full_name': order.customer.full_name,
                    'phone_number': order.customer.phone_number,
                },
                'items': order_items_data,
                'status_history': status_history_data,
            }
            
            return JsonResponse({'success': True, 'order': order_data})
        except Exception as e:
            logger.error(f"Buyurtma tafsilotlarini olishda xato: {e}", exc_info=True)
            return JsonResponse({'success': False, 'message': str(e)}, status=400)
    return JsonResponse({'success': False, 'message': 'Faqat GET so\'rov qabul qilinadi'}, status=405)

@csrf_exempt
def toggle_product_availability(request, product_id):
    """API: Mahsulot mavjudligini almashtirish"""
    if request.method == 'POST':
        try:
            product = get_object_or_404(Product, id=product_id)
            product.is_available = not product.is_available
            product.save()
            
            return JsonResponse({
                'success': True,
                'is_available': product.is_available,
                'message': f'Mahsulot "{product.name}" holati muvaffaqiyatli yangilandi.'
            })
        except Product.DoesNotExist:
            logger.error(f"Mahsulot topilmadi: ID {product_id}")
            return JsonResponse({'success': False, 'message': 'Mahsulot topilmadi.'}, status=404)
        except Exception as e:
            logger.error(f"Mahsulot mavjudligini yangilashda xato: {e}", exc_info=True)
            return JsonResponse({'success': False, 'message': str(e)}, status=500)
    return JsonResponse({'success': False, 'message': 'Faqat POST so\'rov qabul qilinadi'}, status=405)


def menu_app(request):
    """2026/2027 Zamonaviy Telegram Mini App & Stoldan elektron buyurtma berish sahifasi"""
    categories = Category.objects.filter(is_active=True).order_by('name')
    products = Product.objects.filter(is_available=True).select_related('category').order_by('category', 'name')
    table_param = request.GET.get('table', '')
    tables = RestaurantTable.objects.filter(is_active=True).order_by('number')

    context = {
        'categories': categories,
        'products': products,
        'tables': tables,
        'table_number': table_param,
    }
    return render(request, 'chef_panel/menu_app.html', context)


@csrf_exempt
def call_waiter_api(request):
    """Stoldan ofitsiant chaqirish API (2026/2027 QR menyu xizmati)"""
    if request.method == 'POST':
        try:
            if request.content_type == 'application/json':
                data = json.loads(request.body.decode('utf-8'))
            else:
                data = request.POST
        except Exception:
            data = request.POST

        table_number = data.get('table_number', '')
        reason = data.get('reason', 'Ofitsiant kerak')
        now_str = timezone.now().strftime('%H:%M')

        if table_number:
            WaiterCall.objects.create(
                table_number=str(table_number),
                reason=reason
            )

        return JsonResponse({
            'success': True,
            'message': f"#{table_number}-stolga ofitsiant chaqirildi. Tez orada xizmat ko'rsatiladi!"
        })
    return JsonResponse({'success': False, 'message': 'Faqat POST so\'rov qabul qilinadi'}, status=405)


def thermal_receipt(request, order_id, department=None):
    """80mm / 58mm POS Termal printer uchun bo'limlar bo'yicha chek chiqarish sahifasi"""
    order = get_object_or_404(Order, id=order_id)
    dept_param = department or request.GET.get('dept', 'all')
    
    categorized = categorize_order_items(order)
    
    waiter_display_name = order.waiter_name or (order.waiter.name if order.waiter else "Ofitsiant")
    
    context = {
        'order': order,
        'waiter_display_name': waiter_display_name,
        'department_filter': dept_param,
        'departments': categorized['departments'],
        'active_stations': categorized['active_stations'],
        'has_shashlik': categorized['has_shashlik'],
        'has_kitchen': categorized['has_kitchen'],
        'has_bar': categorized['has_bar'],
        'shashlik_data': categorized['departments']['shashlik'],
        'kitchen_data': categorized['departments']['kitchen'],
        'bar_data': categorized['departments']['bar'],
        'kassa_data': categorized['departments']['kassa'],
        'dept_configs': DEPARTMENT_CONFIG,
    }
    return render(request, 'chef_panel/thermal_receipt.html', context)


@csrf_exempt
def api_print_order_dept(request, order_id, department='all'):
    """Muayyan bo'lim yoki barcha bo'limlar chekini tarmoq printeriga yuborish API"""
    order = get_object_or_404(Order, id=order_id)
    settings_obj = BotSettings.get_settings()
    categorized = categorize_order_items(order)
    
    results = {}
    target_depts = ['shashlik', 'kitchen', 'bar', 'kassa'] if department == 'all' else [department]
    
    for dept_key in target_depts:
        if dept_key in categorized['departments']:
            dept_data = categorized['departments'][dept_key]
            if dept_data['total_qty'] > 0 or dept_key == 'kassa':
                printer_ip = getattr(settings_obj, f"printer_{dept_key}_ip", None)
                if printer_ip:
                    slip_bytes = format_escpos_slip(order, dept_key, dept_data)
                    success, msg = send_escpos_socket(printer_ip, slip_bytes)
                    results[dept_key] = {'success': success, 'message': msg, 'ip': printer_ip}
                else:
                    results[dept_key] = {'success': False, 'message': f"Printer IP sozlanmagan ({dept_key})"}
                    
    return JsonResponse({
        'success': True,
        'order_id': order.id,
        'order_number': order.order_number,
        'results': results
    })


def table_qrs_view(request):
    """Restoran stollari uchun QR-kodli kartochkalar generatori"""
    tables = RestaurantTable.objects.filter(is_active=True).order_by('number')
    host = request.get_host()
    scheme = 'https' if request.is_secure() else 'http'
    base_url = f"{scheme}://{host}"

    context = {
        'tables': tables,
        'base_url': base_url
    }
    return render(request, 'chef_panel/table_qrs.html', context)


# ====================================================
# OFITSIANT (WAITER) WEB APP VA API (2026/2027)
# ====================================================

def waiter_app(request):
    """Ofitsiantlar uchun alohida zamonaviy Handheld POS Web App"""
    tables = RestaurantTable.objects.filter(is_active=True).order_by('number')
    categories = Category.objects.filter(is_active=True).prefetch_related('product_set').order_by('name')
    products = Product.objects.filter(is_available=True).select_related('category').order_by('name')

    context = {
        'tables': tables,
        'categories': categories,
        'products': products,
    }
    return render(request, 'chef_panel/waiter_app.html', context)


def waiter_floor_status_api(request):
    """Ofitsiant terminali uchun stollar xaritasi va jonli statuslar API"""
    tables = RestaurantTable.objects.filter(is_active=True).order_by('number')
    active_orders = Order.objects.filter(
        service_type='dine_in',
        status__in=['yangi', 'tasdiqlangan', 'tayor']
    ).prefetch_related('items__product').order_by('-created_at')

    # Faol chaqiruvlar
    active_calls = WaiterCall.objects.filter(is_resolved=False).order_by('-created_at')
    calls_map = {}
    for c in active_calls:
        if c.table_number not in calls_map:
            calls_map[c.table_number] = {
                'id': c.id,
                'reason': c.reason,
                'created_at': c.created_at.strftime('%H:%M')
            }

    orders_map = {}
    for o in active_orders:
        if o.table_number and o.table_number not in orders_map:
            items_list = []
            for it in o.items.all():
                items_list.append({
                    'name': it.product.name,
                    'quantity': it.quantity,
                    'price': float(it.price),
                    'total': float(it.total)
                })
            orders_map[o.table_number] = {
                'id': o.id,
                'order_number': o.order_number,
                'status': o.status,
                'status_display': o.get_status_display(),
                'created_at': o.created_at.strftime('%H:%M'),
                'total_amount': float(o.total_amount),
                'items': items_list
            }

    tables_data = []
    for t in tables:
        t_num = str(t.number)
        tables_data.append({
            'number': t.number,
            'name': t.name or f"Stol #{t.number}",
            'capacity': t.capacity,
            'is_occupied': t_num in orders_map,
            'assigned_waiter_id': t.assigned_waiter.id if t.assigned_waiter else None,
            'assigned_waiter_name': t.assigned_waiter.name if t.assigned_waiter else None,
            'assigned_waiter_phone': t.assigned_waiter.phone if t.assigned_waiter else None,
            'order': orders_map.get(t_num),
            'call': calls_map.get(t_num)
        })

    return JsonResponse({
        'success': True,
        'tables': tables_data,
        'total_tables': len(tables_data),
        'occupied_count': len(orders_map),
        'calls_count': len(calls_map)
    })


@csrf_exempt
def waiter_create_order_api(request):
    """Ofitsiant terminalidan to'g'ridan-to'g'ri stolga buyurtma yaratish"""
    if request.method != 'POST':
        return JsonResponse({'success': False, 'message': 'Faqat POST so\'rov qabul qilinadi'}, status=405)

    try:
        data = json.loads(request.body.decode('utf-8')) if request.body else {}
    except Exception:
        data = request.POST

    table_number = str(data.get('table_number', '1'))
    table_num_int = int(table_number) if table_number.isdigit() else 1
    table_obj = RestaurantTable.objects.filter(number=table_num_int).first()

    if not table_obj:
        return JsonResponse({'success': False, 'message': f"Stol #{table_number} mavjud emas"}, status=404)

    waiter_name = data.get('waiter_name', 'Ofitsiant')
    waiter_id = data.get('waiter_id')
    waiter_token = request.headers.get('Authorization', '').replace('Bearer ', '').strip() or data.get('token')

    current_waiter = None
    if waiter_id:
        current_waiter = WaiterProfile.objects.filter(id=waiter_id).first()
    elif waiter_token:
        current_waiter = WaiterProfile.objects.filter(auth_token=waiter_token).first()
    elif waiter_name and waiter_name != 'Ofitsiant':
        current_waiter = WaiterProfile.objects.filter(name__iexact=waiter_name).first()

    # Bo'sh stolga zakaz olinganda darhol shu ofitsiantga avtomatik belgilanadi
    if not table_obj.assigned_waiter:
        if not current_waiter and waiter_name and waiter_name != 'Ofitsiant':
            current_waiter, _ = WaiterProfile.objects.get_or_create(name=waiter_name)
        if current_waiter:
            table_obj.assigned_waiter = current_waiter
            table_obj.save()

    assigned_waiter = table_obj.assigned_waiter or current_waiter
    waiter_name = assigned_waiter.name if assigned_waiter else waiter_name
    products_raw = data.get('products', [])

    if not products_raw:
        return JsonResponse({'success': False, 'message': 'Savatcha bo\'sh'}, status=400)

    # Mijoz yaratish yoki olish
    customer, _ = Customer.objects.get_or_create(
        telegram_id=1000000000 + table_num_int,
        defaults={'full_name': f"Stol #{table_number}", 'phone_number': "+998900000000"}
    )

    total_amount = Decimal('0')
    items_to_create = []

    for item in products_raw:
        # [id or name, qty, price]
        p_identifier = item[0]
        qty = int(item[1])
        if isinstance(p_identifier, int) or (isinstance(p_identifier, str) and p_identifier.isdigit()):
            prod = Product.objects.filter(id=int(p_identifier)).first()
        else:
            prod = Product.objects.filter(name=str(p_identifier)).first()

        if prod:
            price = prod.price
            subtotal = price * qty
            total_amount += subtotal
            items_to_create.append((prod, qty, price, subtotal))

    order = Order.objects.create(
        customer=customer,
        status='yangi',
        payment_method='naqd',
        service_type='dine_in',
        table_number=table_number,
        waiter=assigned_waiter,
        waiter_name=waiter_name,
        products_total=total_amount,
        delivery_cost=Decimal('0'),
        total_amount=total_amount
    )

    for prod, qty, price, subtotal in items_to_create:
        OrderItem.objects.create(
            order=order,
            product=prod,
            quantity=qty,
            price=price,
            total=subtotal
        )

    notes = data.get('notes', '')
    history_note = f'Ofitsiant terminali orqali qabul qilindi ({waiter_name})'
    if notes:
        history_note += f" | Izoh: {notes}"

    OrderStatusHistory.objects.create(
        order=order,
        old_status='',
        new_status='yangi',
        notes=history_note
    )

    # Taomlarni bo'limlar bo'yicha ajratish
    categorized = categorize_order_items(order)
    depts = categorized['departments']

    # Tarmoq printerlariga avtomatik yuborish (agar yoqilgan bo'lsa)
    print_res = {'printed': False}
    try:
        print_res = auto_print_order_to_network(order)
    except Exception as e:
        logger.warning(f"Avtomatik printerga chiqarishda xatolik: {e}")

    # Oshpaz chatiga bildirishnoma (Bo'limlar bo'yicha chiroyli formatda)
    chef_text = (
        f"🔔 <b>OFITSIANT BUYURTMASI #{order.order_number}</b>\n\n"
        f"🪑 <b>Stol:</b> #{table_number}\n"
        f"🤵 <b>Ofitsiant:</b> {waiter_name}\n"
        f"⏰ <b>Vaqt:</b> {timezone.now().strftime('%H:%M')}\n\n"
    )

    if depts['shashlik']['items']:
        chef_text += "🥩 <b>SHASHLIKXONA / MANGAL:</b>\n"
        for item in depts['shashlik']['items']:
            chef_text += f"• {item['quantity']} x {item['product_name']}\n"
        chef_text += "\n"

    if depts['kitchen']['items']:
        chef_text += "🍲 <b>OSHXONA (TAOMLAR):</b>\n"
        for item in depts['kitchen']['items']:
            chef_text += f"• {item['quantity']} x {item['product_name']}\n"
        chef_text += "\n"

    if depts['bar']['items']:
        chef_text += "☕ <b>DESERT VA BAR:</b>\n"
        for item in depts['bar']['items']:
            chef_text += f"• {item['quantity']} x {item['product_name']}\n"
        chef_text += "\n"

    if notes:
        chef_text += f"📝 <b>Izoh:</b> {notes}\n\n"
    chef_text += f"💰 <b>Jami hisob:</b> {order.total_amount:,.0f} so'm"

    depts_summary = {}
    for d_key in ['shashlik', 'kitchen', 'bar', 'kassa']:
        d_val = depts[d_key]
        if d_val['total_qty'] > 0 or d_key == 'kassa':
            depts_summary[d_key] = {
                'title': d_val['config']['title'],
                'name': d_val['config']['name'],
                'icon': d_val['config']['icon'],
                'count': d_val['total_qty'],
                'items': [f"{it['quantity']}x {it['product_name']}" for it in d_val['items']],
                'total_sum': d_val['total_sum']
            }

    return JsonResponse({
        'success': True,
        'order_id': order.id,
        'order_number': order.order_number,
        'table_number': table_number,
        'total_amount': float(order.total_amount),
        'network_printed': print_res.get('printed', False),
        'departments': depts_summary,
        'has_shashlik': categorized['has_shashlik'],
        'has_kitchen': categorized['has_kitchen'],
        'has_bar': categorized['has_bar'],
        'receipt_urls': {
            'all': f'/chef_panel/orders/{order.id}/receipt/all/',
            'shashlik': f'/chef_panel/orders/{order.id}/receipt/shashlik/',
            'kitchen': f'/chef_panel/orders/{order.id}/receipt/kitchen/',
            'bar': f'/chef_panel/orders/{order.id}/receipt/bar/',
            'kassa': f'/chef_panel/orders/{order.id}/receipt/kassa/',
        }
    })


@csrf_exempt
def waiter_dismiss_call_api(request, call_id):
    """Ofitsiant chaqiruvini hal qilingan deb belgilash"""
    if request.method != 'POST':
        return JsonResponse({'success': False, 'message': 'Faqat POST so\'rov qabul qilinadi'}, status=405)

    call = get_object_or_404(WaiterCall, id=call_id)
    call.is_resolved = True
    call.resolved_at = timezone.now()
    call.save()

    return JsonResponse({'success': True, 'message': f'Stol #{call.table_number} chaqiruvi qabul qilindi'})


@csrf_exempt
def waiter_close_table_api(request, order_id):
    """Stol hisobini yopish va stolni bo'shatish (Kassir)"""
    if request.method != 'POST':
        return JsonResponse({'success': False, 'message': 'Faqat POST so\'rov qabul qilinadi'}, status=405)

    order = get_object_or_404(Order, id=order_id)
    order.status = 'yetkazildi'
    order.is_paid = True
    order.delivered_at = timezone.now()
    order.save()

    # Stolga tegishli barcha ochiq buyurtmalar va chaqiruvlarni yopish (stolni to'liq bo'shatish)
    if order.table_number:
        Order.objects.filter(
            service_type='dine_in',
            table_number=str(order.table_number),
            status__in=['yangi', 'tasdiqlangan', 'tayor']
        ).update(
            status='yetkazildi',
            is_paid=True,
            delivered_at=timezone.now()
        )

        WaiterCall.objects.filter(table_number=str(order.table_number), is_resolved=False).update(
            is_resolved=True,
            resolved_at=timezone.now()
        )

        # Stolni ofitsiantdan to'liq bo'shatish (kassir hisobni yopganda stol yana bo'sh qolishi uchun)
        t_int = int(order.table_number) if str(order.table_number).isdigit() else None
        if t_int is not None:
            RestaurantTable.objects.filter(number=t_int).update(assigned_waiter=None)

    return JsonResponse({
        'success': True,
        'message': f'Stol #{order.table_number} hisobi yopildi va stol to\'liq bo\'shatildi.'
    })


def table_order_status_api(request, table_number):
    """Mijoz QR menyusida yoki QR chekida stolning barcha faol buyurtmalari va hisobini ko'rish"""
    active_orders = Order.objects.filter(
        service_type='dine_in',
        table_number=str(table_number),
        status__in=['yangi', 'tasdiqlangan', 'tayor']
    ).prefetch_related('items__product').order_by('created_at')

    active_call = WaiterCall.objects.filter(
        table_number=str(table_number),
        is_resolved=False
    ).first()

    if not active_orders.exists():
        return JsonResponse({
            'success': True,
            'has_active_order': False,
            'has_active_call': bool(active_call),
            'table_number': table_number
        })

    items_data = []
    total_amount = 0
    order_nums = []
    statuses = []
    waiter_name = None

    for order in active_orders:
        order_nums.append(f"#{order.order_number}")
        statuses.append(order.get_status_display())
        if not waiter_name:
            waiter_name = order.waiter_name or (order.waiter.name if order.waiter else None)
        for it in order.items.all():
            items_data.append({
                'name': it.product.name,
                'quantity': it.quantity,
                'price': float(it.price),
                'total': float(it.total)
            })
            total_amount += float(it.total)

    first_ord = active_orders.first()
    return JsonResponse({
        'success': True,
        'has_active_order': True,
        'has_active_call': bool(active_call),
        'table_number': table_number,
        'order': {
            'id': first_ord.id,
            'order_number': ", ".join(order_nums),
            'status': first_ord.status,
            'status_display': statuses[-1] if statuses else first_ord.get_status_display(),
            'waiter_name': waiter_name or "Biriktirilgan ofitsiant",
            'total_amount': total_amount,
            'created_at': first_ord.created_at.strftime('%H:%M'),
            'items': items_data
        }
    })


@csrf_exempt
def waiter_request_bill_api(request, table_number):
    """Ofitsiant yoki mijoz tomonidan kassirga hisob-kitob so'rovi yuborish"""
    active_order = Order.objects.filter(
        service_type='dine_in',
        table_number=str(table_number),
        status__in=['yangi', 'tasdiqlangan', 'tayor']
    ).first()

    return JsonResponse({
        'success': True,
        'message': f"Stol #{table_number} bo'yicha kassirga hisob so'rovi yuborildi."
    })


@csrf_exempt
def table_item_update_api(request, item_id):
    """Mijoz QR menyudan taom sonini o'zgartirish yoki bekor qilish (faqat 'yangi' holatda)"""
    if request.method != 'POST':
        return JsonResponse({'success': False, 'message': 'Faqat POST so\'rov qabul qilinadi'}, status=405)

    try:
        data = json.loads(request.body.decode('utf-8')) if request.body else {}
    except Exception:
        data = request.POST

    action = data.get('action', 'remove')  # 'decrease', 'increase', 'remove'
    item = get_object_or_404(OrderItem, id=item_id)
    order = item.order

    if order.status not in ['yangi']:
        return JsonResponse({
            'success': False,
            'message': 'Taom oshxonada tayyorlanmoqda. O\'zgartirish uchun ofitsiantni chaqiring.'
        }, status=400)

    if action == 'remove' or (action == 'decrease' and item.quantity <= 1):
        removed_total = item.total
        item.delete()
        order.products_total = max(Decimal('0'), (order.products_total or Decimal('0')) - removed_total)
        order.total_amount = max(Decimal('0'), (order.total_amount or Decimal('0')) - removed_total)
        order.save()
    elif action == 'decrease':
        item.quantity -= 1
        item.total = item.quantity * item.price
        item.save()
        order.products_total = max(Decimal('0'), (order.products_total or Decimal('0')) - item.price)
        order.total_amount = max(Decimal('0'), (order.total_amount or Decimal('0')) - item.price)
        order.save()
    elif action == 'increase':
        item.quantity += 1
        item.total = item.quantity * item.price
        item.save()
        order.products_total = (order.products_total or Decimal('0')) + item.price
        order.total_amount = (order.total_amount or Decimal('0')) + item.price
        order.save()

    return JsonResponse({
        'success': True,
        'message': 'Buyurtma muvaffaqiyatli tahrirlandi',
        'new_total': float(order.total_amount)
    })


# ==============================================================================
# 1. KASSIR BOSHQARUV TIZIMI (DESKTOP COMPUTER POS & FLOOR SYSTEM)
# ==============================================================================

def cashier_pos_view(request):
    """Kassir Asosiy Oynasi (Kompyuter / Desktop):
    - Hamma stollarni ko'rib tura oladi
    - Qaysi stolga qaysi ofitsiant qaraganini ko'rsatadi
    - Stol hisobini ko'rish va yopish
    - Obqatlarni bor/yo'q qilish (Stop-List)
    - Qo'shimcha oynaga (Dastavka & Olib ketish) o'tish imkoniyati
    """
    tables = RestaurantTable.objects.filter(is_active=True).order_by('number')
    active_orders = Order.objects.filter(
        service_type='dine_in',
        status__in=['yangi', 'tasdiqlangan', 'tayor']
    ).select_related('customer', 'waiter').prefetch_related('items__product').order_by('-created_at')

    orders_by_table = {}
    for o in active_orders:
        if o.table_number and str(o.table_number) not in orders_by_table:
            orders_by_table[str(o.table_number)] = o

    calls_by_table = {}
    active_calls = WaiterCall.objects.filter(is_resolved=False)
    for c in active_calls:
        calls_by_table[str(c.table_number)] = c

    table_cards = []
    occupied_count = 0
    bill_requested_count = 0
    calling_count = len(calls_by_table)

    for t in tables:
        t_num = str(t.number)
        ord_obj = orders_by_table.get(t_num)
        call_obj = calls_by_table.get(t_num)

        waiter_name = None
        if ord_obj:
            waiter_name = ord_obj.waiter_name or (ord_obj.waiter.name if ord_obj.waiter else None)
        if not waiter_name and t.assigned_waiter:
            waiter_name = t.assigned_waiter.name

        is_occupied = ord_obj is not None
        if is_occupied:
            occupied_count += 1

        is_bill_requested = False
        if call_obj and "hisob" in call_obj.reason.lower():
            is_bill_requested = True
            bill_requested_count += 1

        table_cards.append({
            'table': t,
            'order': ord_obj,
            'call': call_obj,
            'waiter_name': waiter_name or "Biriktirilmagan",
            'is_occupied': is_occupied,
            'is_bill_requested': is_bill_requested,
            'total_amount': ord_obj.total_amount if ord_obj else Decimal('0'),
        })

    delivery_active_count = Order.objects.filter(service_type='delivery', status__in=['yangi', 'tasdiqlangan', 'tayor', 'yolda']).count()
    pickup_active_count = Order.objects.filter(service_type='pickup', status__in=['yangi', 'tasdiqlangan', 'tayor']).count()

    categories = Category.objects.filter(is_active=True).prefetch_related('product_set')
    waiters = WaiterProfile.objects.filter(is_active=True)
    products = Product.objects.all().select_related('category').order_by('category__name', 'name')

    context = {
        'table_cards': table_cards,
        'total_tables': len(tables),
        'occupied_count': occupied_count,
        'free_count': max(0, len(tables) - occupied_count),
        'calling_count': calling_count,
        'bill_requested_count': bill_requested_count,
        'delivery_active_count': delivery_active_count,
        'pickup_active_count': pickup_active_count,
        'categories': categories,
        'products': products,
        'waiters': waiters,
        'title': "Kassir Asosiy Oynasi (Desktop POS)"
    }
    return render(request, 'chef_panel/cashier_pos.html', context)


def cashier_delivery_view(request):
    """Kassir Qo'shimcha Oynasi:
    Yetkazib berish (Delivery) va Olib ketish (Pickup) buyurtmalarini boshqarish.
    Kuryerlarni biriktirish, yo'lga chiqarish va to'lovni tasdiqlash.
    """
    delivery_orders = Order.objects.filter(
        service_type='delivery',
        status__in=['yangi', 'tasdiqlangan', 'tayor', 'yolda']
    ).select_related('customer', 'courier').prefetch_related('items__product').order_by('-created_at')

    pickup_orders = Order.objects.filter(
        service_type='pickup',
        status__in=['yangi', 'tasdiqlangan', 'tayor']
    ).select_related('customer').prefetch_related('items__product').order_by('-created_at')

    couriers = CourierProfile.objects.filter(is_active=True)
    categories = Category.objects.filter(is_active=True).prefetch_related('product_set')
    products = Product.objects.filter(is_available=True).select_related('category')

    context = {
        'delivery_orders': delivery_orders,
        'pickup_orders': pickup_orders,
        'couriers': couriers,
        'categories': categories,
        'products': products,
        'delivery_count': delivery_orders.count(),
        'pickup_count': pickup_orders.count(),
        'title': "Kassa: Dastavka va Olib Ketish"
    }
    return render(request, 'chef_panel/cashier_delivery.html', context)


@csrf_exempt
def cashier_table_data_api(request, table_number):
    """Kassir POS uchun bitta stolning barcha tafsilotlarini JSON formatida olish"""
    active_order = Order.objects.filter(
        service_type='dine_in',
        table_number=str(table_number),
        status__in=['yangi', 'tasdiqlangan', 'tayor']
    ).prefetch_related('items__product').order_by('-created_at').first()

    table_obj = RestaurantTable.objects.filter(number=int(table_number) if str(table_number).isdigit() else 1).first()

    if not active_order:
        waiter_name = table_obj.assigned_waiter.name if (table_obj and table_obj.assigned_waiter) else "Biriktirilmagan"
        return JsonResponse({
            'success': True,
            'is_occupied': False,
            'table_number': str(table_number),
            'waiter_name': waiter_name,
            'items': [],
            'total_amount': 0
        })

    items = []
    for it in active_order.items.all():
        items.append({
            'id': it.id,
            'name': it.product.name,
            'price': float(it.price),
            'quantity': it.quantity,
            'total': float(it.total)
        })

    waiter_name = active_order.waiter_name or (active_order.waiter.name if active_order.waiter else None)
    if not waiter_name and table_obj and table_obj.assigned_waiter:
        waiter_name = table_obj.assigned_waiter.name

    return JsonResponse({
        'success': True,
        'is_occupied': True,
        'order_id': active_order.id,
        'order_number': active_order.order_number,
        'table_number': str(table_number),
        'waiter_name': waiter_name or "Biriktirilmagan",
        'status': active_order.status,
        'status_display': active_order.get_status_display(),
        'created_at': active_order.created_at.strftime('%H:%M'),
        'items': items,
        'total_amount': float(active_order.total_amount),
        'is_paid': active_order.is_paid
    })


@csrf_exempt
def cashier_assign_waiter_api(request):
    """Kassir tomonidan stolga ofitsiant biriktirish"""
    if request.method != 'POST':
        return JsonResponse({'success': False, 'message': 'Faqat POST'}, status=405)

    try:
        data = json.loads(request.body.decode('utf-8')) if request.body else {}
    except Exception:
        data = request.POST

    table_number = str(data.get('table_number', '1'))
    waiter_id = data.get('waiter_id')

    waiter = get_object_or_404(WaiterProfile, id=waiter_id) if waiter_id else None

    # Stol modeliga biriktiramiz
    table_obj = RestaurantTable.objects.filter(number=int(table_number) if table_number.isdigit() else 1).first()
    if table_obj and waiter:
        table_obj.assigned_waiter = waiter
        table_obj.save()

    # Faol buyurtma bo'lsa unga ham biriktiramiz
    active_order = Order.objects.filter(
        service_type='dine_in',
        table_number=table_number,
        status__in=['yangi', 'tasdiqlangan', 'tayor']
    ).first()
    if active_order and waiter:
        active_order.waiter = waiter
        active_order.waiter_name = waiter.name
        active_order.save()

    return JsonResponse({
        'success': True,
        'message': f"Stol #{table_number} ga {waiter.name if waiter else ''} muvaffaqiyatli biriktirildi.",
        'waiter_name': waiter.name if waiter else ""
    })


@csrf_exempt
def cashier_assign_courier_api(request):
    """Kassir tomonidan dastavka buyurtmasini kuryerga biriktirish va yo'lga chiqarish"""
    if request.method != 'POST':
        return JsonResponse({'success': False, 'message': 'Faqat POST'}, status=405)

    try:
        data = json.loads(request.body.decode('utf-8')) if request.body else {}
    except Exception:
        data = request.POST

    order_id = data.get('order_id')
    courier_id = data.get('courier_id')

    order = get_object_or_404(Order, id=order_id)
    courier = get_object_or_404(CourierProfile, id=courier_id)

    order.courier = courier
    order.courier_name = courier.name
    order.status = 'yolda'
    order.save()

    OrderStatusHistory.objects.create(
        order=order,
        old_status='tayor',
        new_status='yolda',
        notes=f"Kassir buyurtmani kuryerga topshirdi ({courier.name})"
    )

    return JsonResponse({
        'success': True,
        'message': f"Buyurtma #{order.order_number} {courier.name} ga topshirildi va 'Yo'lda' holatiga o'tkazildi.",
        'courier_name': courier.name
    })


@csrf_exempt
def cashier_staff_list_api(request):
    """Kassir uchun barcha Kuryerlar va Ofitsiantlar ro'yxati"""
    couriers = CourierProfile.objects.all().order_by('-id')
    waiters = WaiterProfile.objects.all().order_by('-id')

    couriers_data = []
    for c in couriers:
        couriers_data.append({
            'id': c.id,
            'name': c.name,
            'phone': c.phone,
            'pin_code': c.pin_code,
            'vehicle_info': c.vehicle_info,
            'is_active': c.is_active,
            'created_at': c.created_at.strftime('%d.%m.%Y')
        })

    waiters_data = []
    for w in waiters:
        waiters_data.append({
            'id': w.id,
            'name': w.name,
            'phone': w.phone,
            'pin_code': w.pin_code,
            'is_active': w.is_active,
            'created_at': w.created_at.strftime('%d.%m.%Y')
        })

    return JsonResponse({
        'status': 'success',
        'success': True,
        'couriers': couriers_data,
        'waiters': waiters_data
    })


@csrf_exempt
def cashier_staff_create_api(request):
    """Kassir tomonidan yangi Kuryer yoki Ofitsiant qo'shish (Login va PIN-kod berish)"""
    if request.method != 'POST':
        return JsonResponse({'status': 'error', 'message': 'Faqat POST'}, status=405)

    try:
        data = json.loads(request.body.decode('utf-8')) if request.body else {}
    except Exception:
        data = request.POST

    role = data.get('role', 'courier')  # 'courier' or 'waiter'
    name = data.get('name', '').strip()
    phone = data.get('phone', '').strip()
    pin = data.get('pin', '1234').strip()
    vehicle = data.get('vehicle_info', '').strip()

    if not name or not phone:
        return JsonResponse({'status': 'error', 'message': 'Ism va telefon kiritilishi shart'}, status=400)

    clean_digits = ''.join(c for c in phone if c.isdigit())
    last_9 = clean_digits[-9:] if len(clean_digits) >= 9 else clean_digits
    formatted_phone = f"+998{last_9}" if len(last_9) == 9 else phone

    if role == 'courier':
        courier, _ = CourierProfile.objects.update_or_create(
            phone=formatted_phone,
            defaults={'name': name, 'pin_code': pin, 'vehicle_info': vehicle, 'is_active': True}
        )
        return JsonResponse({
            'status': 'success',
            'success': True,
            'message': f"Kuryer '{name}' muvaffaqiyatli saqlandi! PIN-kod: {pin}",
            'staff': {'id': courier.id, 'name': courier.name, 'phone': courier.phone, 'pin': courier.pin_code, 'role': 'courier'}
        })
    elif role == 'waiter':
        waiter, _ = WaiterProfile.objects.update_or_create(
            phone=formatted_phone,
            defaults={'name': name, 'pin_code': pin, 'is_active': True}
        )
        return JsonResponse({
            'status': 'success',
            'success': True,
            'message': f"Ofitsiant '{name}' muvaffaqiyatli saqlandi! PIN-kod: {pin}",
            'staff': {'id': waiter.id, 'name': waiter.name, 'phone': waiter.phone, 'pin': waiter.pin_code, 'role': 'waiter'}
        })
    else:
        return JsonResponse({'status': 'error', 'message': "Noto'g'ri rol"}, status=400)


@csrf_exempt
def cashier_staff_toggle_api(request, staff_type, staff_id):
    """Kassir tomonidan xodim faolligini yoqish/o'chirish"""
    if staff_type == 'courier':
        obj = get_object_or_404(CourierProfile, id=staff_id)
    else:
        obj = get_object_or_404(WaiterProfile, id=staff_id)

    obj.is_active = not obj.is_active
    obj.save()
    return JsonResponse({
        'status': 'success',
        'success': True,
        'is_active': obj.is_active,
        'message': f"Xodim holati {'Faol' if obj.is_active else 'Nofaol'} qilindi"
    })


def settings_hub_view(request):
    """
    Restoran tizimining barcha sozlamalarini jamlagan yagona, toza boshqaruv markazi:
    1. Chek printerlari va bo'limlar (kategoriyalar marshrutizatsiyasi)
    2. Xodimlar (Ofitsiant va Kuryerlar, PIN-kodlar, holati)
    3. Stop-List (Taomlar mavjudligi)
    4. Menyu va Kategoriyalar boshqaruvi
    5. Yetkazib berish narxlari va ish vaqtlari
    6. Raqamli xizmatlar (Stollar QR kodlari va Mini App)
    """
    settings_obj = BotSettings.get_settings()
    active_tab = request.GET.get('tab', 'printers')

    if request.method == 'POST':
        action = request.POST.get('action', 'printers')

        if action == 'printers':
            auto_print = request.POST.get('auto_print_network') in ['on', '1', 'true', True]
            settings_obj.auto_print_network = auto_print
            settings_obj.printer_shashlik_ip = request.POST.get('printer_shashlik_ip', '').strip()
            settings_obj.printer_kitchen_ip = request.POST.get('printer_kitchen_ip', '').strip()
            settings_obj.printer_bar_ip = request.POST.get('printer_bar_ip', '').strip()
            settings_obj.printer_kassa_ip = request.POST.get('printer_kassa_ip', '').strip()
            settings_obj.save()

            for key, val in request.POST.items():
                if key.startswith('cat_dept_'):
                    cat_id_str = key.replace('cat_dept_', '')
                    if cat_id_str.isdigit() and val in ['shashlik', 'kitchen', 'bar', 'kassa']:
                        Category.objects.filter(id=int(cat_id_str)).update(department=val)
            messages.success(request, "Chek printerlari va taom guruhlari sozlamalari saqlandi!")
            active_tab = 'printers'

        elif action == 'delivery':
            try:
                base_cost = request.POST.get('delivery_base_cost')
                if base_cost is not None:
                    settings_obj.delivery_base_cost = Decimal(base_cost)

                extra_km = request.POST.get('delivery_cost_per_extra_km_block')
                if extra_km is not None:
                    settings_obj.delivery_cost_per_extra_km_block = Decimal(extra_km)

                max_rad = request.POST.get('delivery_max_radius_km')
                if max_rad is not None:
                    settings_obj.delivery_max_radius_km = float(max_rad)

                start_str = request.POST.get('service_start_time')
                if start_str:
                    settings_obj.service_start_time = datetime.strptime(start_str.strip(), '%H:%M').time()

                end_str = request.POST.get('service_end_time')
                if end_str:
                    settings_obj.service_end_time = datetime.strptime(end_str.strip(), '%H:%M').time()

                settings_obj.save()
                messages.success(request, "Yetkazib berish va ish vaqti sozlamalari saqlandi!")
            except Exception as e:
                messages.error(request, f"Sozlamalarni saqlashda xatolik: {e}")
            active_tab = 'delivery'

        elif action == 'staff_create':
            name = request.POST.get('name', '').strip()
            phone = request.POST.get('phone', '').strip()
            pin_code = request.POST.get('pin_code', '').strip()
            role = request.POST.get('role', 'waiter')

            if name and pin_code:
                if role == 'courier':
                    CourierProfile.objects.create(name=name, phone=phone, pin_code=pin_code, is_active=True)
                else:
                    WaiterProfile.objects.create(name=name, phone=phone, pin_code=pin_code, is_active=True)
                messages.success(request, f"Yangi {role} muvaffaqiyatli qo'shildi: {name}")
            else:
                messages.error(request, "Ism va PIN-kod kiritilishi shart!")
            active_tab = 'staff'

        return redirect(f"{request.path}?tab={active_tab}")

    categories = Category.objects.filter(is_active=True).annotate(prod_count=Count('product')).order_by('name')
    products = Product.objects.select_related('category').order_by('category__name', 'name')
    waiters = WaiterProfile.objects.order_by('-is_active', 'name')
    couriers = CourierProfile.objects.order_by('-is_active', 'name')

    context = {
        'settings': settings_obj,
        'categories': categories,
        'products': products,
        'waiters': waiters,
        'couriers': couriers,
        'departments': DEPARTMENT_CONFIG,
        'active_tab': active_tab,
    }
    return render(request, 'chef_panel/settings_hub.html', context)


def printer_settings_view(request):
    """Eski printer-settings havolasini ham yagona Sozlamalar oynasiga yo'naltirish"""
    return settings_hub_view(request)


@csrf_exempt
def cashier_printer_settings_api(request):
    """Kassir uchun printerlar va taom guruhlari sozlamalarini olish"""
    settings_obj = BotSettings.get_settings()
    categories = Category.objects.filter(is_active=True).annotate(prod_count=Count('product')).order_by('name')
    
    cats_data = []
    for c in categories:
        cats_data.append({
            'id': c.id,
            'name': c.name,
            'department': c.department or 'kitchen',
            'product_count': c.prod_count,
        })
        
    depts_data = []
    for code, cfg in DEPARTMENT_CONFIG.items():
        depts_data.append({
            'code': code,
            'title': cfg['title'],
            'name': cfg['name'],
            'icon': cfg['icon'],
            'badge_color': cfg['badge_color']
        })
        
    return JsonResponse({
        'success': True,
        'auto_print_network': bool(settings_obj.auto_print_network),
        'printers': {
            'shashlik': settings_obj.printer_shashlik_ip or '',
            'kitchen': settings_obj.printer_kitchen_ip or '',
            'bar': settings_obj.printer_bar_ip or '',
            'kassa': settings_obj.printer_kassa_ip or '',
        },
        'categories': cats_data,
        'departments': depts_data,
    })


@csrf_exempt
def cashier_save_printer_settings_api(request):
    """Kassir tomonidan printerlar va guruhlarni saqlash"""
    if request.method != 'POST':
        return JsonResponse({'success': False, 'message': 'Faqat POST'}, status=405)
        
    try:
        data = json.loads(request.body.decode('utf-8')) if request.body else {}
    except Exception:
        data = request.POST
        
    settings_obj = BotSettings.get_settings()
    
    if 'auto_print_network' in data:
        settings_obj.auto_print_network = bool(data['auto_print_network'])
        
    printers = data.get('printers', {})
    if 'shashlik' in printers:
        settings_obj.printer_shashlik_ip = str(printers.get('shashlik', '')).strip()
    if 'kitchen' in printers:
        settings_obj.printer_kitchen_ip = str(printers.get('kitchen', '')).strip()
    if 'bar' in printers:
        settings_obj.printer_bar_ip = str(printers.get('bar', '')).strip()
    if 'kassa' in printers:
        settings_obj.printer_kassa_ip = str(printers.get('kassa', '')).strip()
        
    settings_obj.save()
    
    # Guruhlar (Kategoriyalar) biriktirilishi
    cat_mapping = data.get('category_mapping', {})
    for cat_id_str, dept in cat_mapping.items():
        if cat_id_str.isdigit() and dept in ['kitchen', 'shashlik', 'bar', 'kassa']:
            Category.objects.filter(id=int(cat_id_str)).update(department=dept)
            
    return JsonResponse({
        'success': True,
        'message': "Printerlar va guruhlar sozlamalari muvaffaqiyatli saqlandi!"
    })


@csrf_exempt
def cashier_test_print_api(request):
    """Kassir panelidan tanlangan printerga sinov cheki chiqarish"""
    if request.method != 'POST':
        return JsonResponse({'success': False, 'message': 'Faqat POST'}, status=405)
        
    try:
        data = json.loads(request.body.decode('utf-8')) if request.body else {}
    except Exception:
        data = request.POST
        
    department = data.get('department', 'kassa')
    custom_ip = data.get('ip', '').strip()
    
    settings_obj = BotSettings.get_settings()
    printer_ip = custom_ip or getattr(settings_obj, f"printer_{department}_ip", None) or settings_obj.printer_kassa_ip
    
    if not printer_ip:
        return JsonResponse({
            'success': False,
            'message': f"'{department}' bo'limi uchun printer IP manzili ko'rsatilmagan!"
        }, status=400)
        
    raw_bytes = format_escpos_test_slip(department, printer_ip)
    success, msg = send_escpos_socket(printer_ip, raw_bytes)
    
    return JsonResponse({
        'success': success,
        'message': msg,
        'ip': printer_ip,
        'department': department
    })


@csrf_exempt
def mobile_staff_login_api(request):
    """Yagona Xodimlar Mobil Ilovasi: Kuryer va Ofitsiant kirishi (PIN-kod)"""
    if request.method != 'POST':
        return JsonResponse({'status': 'error', 'message': 'Faqat POST'}, status=405)

    try:
        data = json.loads(request.body.decode('utf-8')) if request.body else {}
    except Exception:
        data = request.POST

    role = data.get('role', 'courier')  # 'courier' or 'waiter'
    phone = data.get('phone', '').strip()
    pin = data.get('pin', '').strip()

    clean_digits = ''.join(c for c in phone if c.isdigit())
    last_9 = clean_digits[-9:] if len(clean_digits) >= 9 else clean_digits

    import uuid
    if role == 'courier':
        courier = CourierProfile.objects.filter(phone__icontains=last_9, is_active=True).first()
        if not courier or courier.pin_code != pin:
            return JsonResponse({'status': 'error', 'success': False, 'message': "Kuryer telefon raqami yoki PIN-kod noto'g'ri!"}, status=401)
        if not courier.auth_token:
            courier.auth_token = f"cour_{uuid.uuid4().hex[:16]}"
            courier.save()
        return JsonResponse({
            'status': 'success',
            'success': True,
            'role': 'courier',
            'user': {
                'id': courier.id,
                'name': courier.name,
                'phone': courier.phone,
                'vehicle_info': courier.vehicle_info,
                'token': courier.auth_token,
            },
            'courier': {
                'id': courier.id,
                'name': courier.name,
                'phone': courier.phone,
                'vehicle_info': courier.vehicle_info,
                'token': courier.auth_token,
            },
            'message': f"Xush kelibsiz, {courier.name}!"
        })
    elif role == 'waiter':
        waiter = WaiterProfile.objects.filter(phone__icontains=last_9, is_active=True).first()
        if not waiter or waiter.pin_code != pin:
            return JsonResponse({'status': 'error', 'success': False, 'message': "Ofitsiant telefon raqami yoki PIN-kod noto'g'ri!"}, status=401)
        if not waiter.auth_token:
            waiter.auth_token = f"wait_{uuid.uuid4().hex[:16]}"
            waiter.save()
        return JsonResponse({
            'status': 'success',
            'success': True,
            'role': 'waiter',
            'user': {
                'id': waiter.id,
                'name': waiter.name,
                'phone': waiter.phone,
                'token': waiter.auth_token,
            },
            'waiter': {
                'id': waiter.id,
                'name': waiter.name,
                'phone': waiter.phone,
                'token': waiter.auth_token,
            },
            'message': f"Xush kelibsiz, {waiter.name}!"
        })
    else:
        return JsonResponse({'status': 'error', 'message': "Noma'lum rol"}, status=400)


@csrf_exempt
def waiter_deliver_order_api(request, order_id):
    """Ofitsiant stolga taomni topshirishi"""
    order = get_object_or_404(Order, id=order_id)
    order.status = 'yetkazildi'
    order.delivered_at = timezone.now()
    order.save()
    OrderStatusHistory.objects.create(
        order=order,
        old_status='tayor',
        new_status='yetkazildi',
        notes="Ofitsiant taomni stolga topshirdi"
    )
    return JsonResponse({'status': 'success', 'success': True, 'message': "Taom stolga berildi"})


# ==============================================================================
# 2. OSHPAZLAR KDS OYNASI (FAQAT YETKAZIB BERISH VA OLIB KETISH)
# ==============================================================================

def kitchen_kds_view(request):
    """Oshpazlar Oynasi (KDS):
    Faqat Yetkazib berish (delivery) va Olib ketish (pickup) buyurtmalarini ko'rsatadi!
    Ofitsiant bergan stollar esa chek printerdan chiqadi.
    """
    orders = Order.objects.filter(
        service_type__in=['delivery', 'pickup'],
        status__in=['yangi', 'tasdiqlangan']
    ).prefetch_related('items__product').order_by('created_at')

    ready_orders = Order.objects.filter(
        service_type__in=['delivery', 'pickup'],
        status='tayor'
    ).prefetch_related('items__product').order_by('-ready_at')[:8]

    context = {
        'orders': orders,
        'ready_orders': ready_orders,
        'orders_count': orders.count(),
        'title': "Oshxona (KDS) - Faqat Dastavka va Olib ketish"
    }
    return render(request, 'chef_panel/kitchen_kds.html', context)


# ==============================================================================
# 3. STOL QR-KODI VEB SAHIFASI (MIJOZ UCHUN HISOB VA TAFSILOT)
# ==============================================================================

def table_guest_bill_view(request, table_number):
    """Stol QR Kodini skaner qilganda ochiladigan faqat o'sha stolning elektron cheki:
    - Barcha buyurtma qilingan taomlar, miqdori va narxlari
    - Stol ofitsianti ma'lumoti
    - Oshxona tayyorlik holati
    - Jami to'lov summasi
    - Ofitsiant chaqirish tugmasi
    """
    active_orders = Order.objects.filter(
        service_type='dine_in',
        table_number=str(table_number),
        status__in=['yangi', 'tasdiqlangan', 'tayor']
    ).prefetch_related('items__product').order_by('created_at')

    table_obj = RestaurantTable.objects.filter(number=int(table_number) if str(table_number).isdigit() else 1).first()

    waiter_name = None
    all_items = []
    total_amount = 0
    order_nums = []

    for order in active_orders:
        order_nums.append(f"#{order.order_number}")
        if not waiter_name:
            waiter_name = order.waiter_name or (order.waiter.name if order.waiter else None)
        for it in order.items.all():
            all_items.append(it)
            total_amount += float(it.total)

    if not waiter_name and table_obj and table_obj.assigned_waiter:
        waiter_name = table_obj.assigned_waiter.name

    primary_order = active_orders.first() if active_orders.exists() else None
    active_call = WaiterCall.objects.filter(table_number=str(table_number), is_resolved=False).first()

    context = {
        'table_number': table_number,
        'table_obj': table_obj,
        'has_order': len(all_items) > 0,
        'order_number_str': ", ".join(order_nums) if order_nums else "",
        'primary_order': primary_order,
        'waiter_name': waiter_name or "Biriktirilgan ofitsiant",
        'active_call': active_call,
        'items': all_items,
        'total_amount': total_amount,
        'now': timezone.now(),
    }
    return render(request, 'chef_panel/table_guest_bill.html', context)


# ==============================================================================
# 4. FLUTTER MOBIL ILOVALARI UCHUN REST APILAR (CUSTOMER & COURIER)
# ==============================================================================

def mobile_customer_menu_api(request):
    """Flutter Mijoz Ilovasi: Barcha faol kategoriyalar va taomlar menyusi"""
    categories = Category.objects.filter(is_active=True).prefetch_related('product_set')
    
    result = []
    dishes_list = []
    for cat in categories:
        products_list = []
        for prod in cat.product_set.all():
            img_url = request.build_absolute_uri(prod.image.url) if prod.image else ""
            item_data = {
                'id': prod.id,
                'name': prod.name,
                'description': prod.description or "",
                'price': float(prod.price),
                'category': cat.name,
                'image': img_url,
                'image_url': img_url,
                'is_available': prod.is_available,
                'prep_time': 15,
            }
            products_list.append(item_data)
            dishes_list.append(item_data)

        result.append({
            'id': cat.id,
            'name': cat.name,
            'description': cat.description or "",
            'products': products_list
        })

    return JsonResponse({
        'status': 'success',
        'success': True,
        'categories': result,
        'dishes': dishes_list
    })


@csrf_exempt
def mobile_customer_order_create_api(request):
    """Flutter Mijoz Ilovasi: Dastavka yoki Olib ketish buyurtmasini yaratish"""
    if request.method != 'POST':
        return JsonResponse({'status': 'error', 'success': False, 'message': 'Faqat POST'}, status=405)

    try:
        data = json.loads(request.body.decode('utf-8')) if request.body else {}
    except Exception:
        data = request.POST

    full_name = data.get('full_name') or data.get('customer_name', 'Mijoz')
    phone = data.get('phone') or data.get('customer_phone', '+998900000000')
    service_type = data.get('service_type', 'delivery')  # 'delivery', 'pickup' or 'dine_in'
    payment_method = data.get('payment_method', 'naqd')
    table_number = data.get('table_number')
    address = data.get('address') or data.get('delivery_address', '')
    lat = data.get('latitude')
    lng = data.get('longitude')
    notes = data.get('notes', '')
    products_raw = data.get('items', [])

    if not products_raw:
        return JsonResponse({'status': 'error', 'success': False, 'message': "Savatcha bo'sh"}, status=400)

    # Stolga ofitsiant biriktirilganligini qat'iy tekshirish
    table_obj = None
    has_table = (service_type == 'dine_in') or bool(table_number and str(table_number).strip() and str(table_number).strip().lower() not in ['none', 'null', '0', ''])
    if has_table:
        t_int = int(table_number) if (table_number and str(table_number).isdigit()) else 1
        table_obj = RestaurantTable.objects.filter(number=t_int).first()
        if not table_obj or not table_obj.assigned_waiter:
            return JsonResponse({
                'status': 'error',
                'success': False,
                'message': f"Stol #{table_number or t_int} ga ofitsiant biriktirilmagan! Buyurtma berish uchun avval ofitsiant biriktirilishi shart."
            }, status=400)

    # Mijozni xavfsiz olish yoki yaratish (MultipleObjectsReturned xatosini oldini olish)
    clean_digits = ''.join(c for c in str(phone) if c.isdigit())
    last_9 = clean_digits[-9:] if len(clean_digits) >= 9 else clean_digits

    customer = None
    if last_9:
        customer = Customer.objects.filter(phone_number__icontains=last_9).order_by('-id').first()
    if not customer and phone:
        customer = Customer.objects.filter(phone_number=phone).order_by('-id').first()

    if not customer:
        tid = int(timezone.now().timestamp() * 1000)
        while Customer.objects.filter(telegram_id=tid).exists():
            tid += 1
        customer = Customer.objects.create(
            telegram_id=tid,
            phone_number=phone or "+998901234567",
            full_name=full_name or "Mijoz"
        )
    else:
        if full_name and (not customer.full_name or customer.full_name in ['Mehmon', 'Noma\'lum', 'Mijoz', '']):
            customer.full_name = full_name
            customer.save(update_fields=['full_name'])

    total_amount = Decimal('0')
    items_to_create = []

    for item in products_raw:
        prod_id = item.get('product_id') or item.get('dish_id')
        qty = int(item.get('quantity', 1))
        prod = Product.objects.filter(id=prod_id).first()
        if prod:
            subtotal = prod.price * qty
            total_amount += subtotal
            items_to_create.append((prod, qty, prod.price, subtotal))

    bot_settings = BotSettings.get_settings()
    delivery_cost = bot_settings.delivery_base_cost if service_type == 'delivery' else Decimal('0')
    final_total = total_amount + delivery_cost

    order = Order.objects.create(
        customer=customer,
        status='yangi',
        payment_method=payment_method,
        service_type=service_type,
        table_number=str(table_number) if table_number else None,
        waiter=table_obj.assigned_waiter if table_obj else None,
        waiter_name=table_obj.assigned_waiter.name if (table_obj and table_obj.assigned_waiter) else None,
        address=address if service_type == 'delivery' else None,
        latitude=lat if service_type == 'delivery' else None,
        longitude=lng if service_type == 'delivery' else None,
        notes=notes,
        products_total=total_amount,
        delivery_cost=delivery_cost,
        total_amount=final_total
    )

    for prod, qty, price, subtotal in items_to_create:
        OrderItem.objects.create(
            order=order,
            product=prod,
            quantity=qty,
            price=price,
            total=subtotal
        )

    OrderStatusHistory.objects.create(
        order=order,
        old_status='',
        new_status='yangi',
        notes='Flutter Mobile App orqali buyurtma berildi'
    )

    return JsonResponse({
        'status': 'success',
        'success': True,
        'order_id': order.id,
        'order_number': order.order_number,
        'total_amount': float(order.total_amount),
        'service_type': order.service_type,
        'message': "Buyurtmangiz qabul qilindi va oshxonaga uzatildi!"
    }, status=201)


def mobile_customer_orders_api(request, phone):
    """Flutter Mijoz Ilovasi: Telefon raqam bo'yicha barcha buyurtmalar ro'yxati"""
    clean_phone = phone.replace(' ', '').replace('+', '').replace('-', '')[-9:]
    orders = Order.objects.filter(
        customer__phone_number__icontains=clean_phone
    ).prefetch_related('items__product').order_by('-created_at')[:30]

    result = []
    for o in orders:
        items_data = []
        for it in o.items.all():
            items_data.append({
                'id': it.id,
                'dish_name': it.product.name,
                'name': it.product.name,
                'quantity': it.quantity,
                'price': float(it.price),
                'total': float(it.total)
            })
        result.append({
            'id': o.id,
            'order_id': o.id,
            'order_number': o.order_number,
            'status': o.status,
            'status_display': o.get_status_display(),
            'service_type': o.service_type,
            'service_type_display': o.get_service_type_display(),
            'delivery_address': o.address or "",
            'address': o.address or "",
            'total_amount': float(o.total_amount),
            'delivery_cost': float(o.delivery_cost),
            'payment_method': o.payment_method,
            'payment_method_display': o.get_payment_method_display(),
            'is_paid': o.is_paid,
            'created_at': o.created_at.strftime('%d.%m.%Y %H:%M'),
            'courier_name': o.courier_name or "",
            'notes': o.notes or "",
            'items': items_data
        })

    return JsonResponse({'status': 'success', 'success': True, 'orders': result})


def mobile_customer_order_status_api(request, order_id):
    """Flutter Mijoz Ilovasi: Bitta buyurtmaning jonli holatini kuzatish"""
    order = get_object_or_404(Order, id=order_id)
    items_data = []
    for it in order.items.all():
        items_data.append({
            'id': it.id,
            'dish_name': it.product.name,
            'name': it.product.name,
            'quantity': it.quantity,
            'price': float(it.price),
            'total': float(it.total)
        })

    return JsonResponse({
        'status': 'success',
        'success': True,
        'id': order.id,
        'order_id': order.id,
        'order_number': order.order_number,
        'status': order.status,
        'status_display': order.get_status_display(),
        'service_type': order.service_type,
        'service_type_display': order.get_service_type_display(),
        'delivery_address': order.address or "",
        'address': order.address or "",
        'courier_name': order.courier_name or "",
        'total_amount': float(order.total_amount),
        'delivery_cost': float(order.delivery_cost),
        'created_at': order.created_at.strftime('%H:%M'),
        'items': items_data
    })


@csrf_exempt
def mobile_customer_auth_api(request):
    """Flutter Mijoz Ilovasi: Telefon raqam orqali kirish / ro'yxatdan o'tish (OTP)"""
    if request.method != 'POST':
        return JsonResponse({'status': 'error', 'message': 'Faqat POST so\'rovi qabul qilinadi'}, status=405)

    try:
        data = json.loads(request.body.decode('utf-8')) if request.body else {}
    except Exception:
        data = request.POST

    phone = data.get('phone', '').strip()
    full_name = data.get('full_name', '').strip()

    if not phone:
        return JsonResponse({'status': 'error', 'message': 'Telefon raqam kiritilishi shart'}, status=400)

    clean_digits = ''.join(c for c in phone if c.isdigit())
    last_9 = clean_digits[-9:] if len(clean_digits) >= 9 else clean_digits

    customer = Customer.objects.filter(phone_number__icontains=last_9).first()
    is_new = False

    if not customer:
        is_new = True
        name_to_use = full_name if full_name else f"Mehmon (+998{last_9})"
        customer = Customer.objects.create(
            telegram_id=int(timezone.now().timestamp()),
            full_name=name_to_use,
            phone_number=f"+998{last_9}" if len(last_9) == 9 else phone
        )
    else:
        if full_name and customer.full_name.startswith("Mehmon"):
            customer.full_name = full_name
            customer.save()

    orders_count = Order.objects.filter(customer=customer).count()
    import hashlib
    token = hashlib.sha256(f"cust_{customer.id}_{customer.phone_number}".encode()).hexdigest()[:24]

    return JsonResponse({
        'status': 'success',
        'success': True,
        'is_new_user': is_new,
        'token': token,
        'customer': {
            'id': customer.id,
            'full_name': customer.full_name,
            'phone': customer.phone_number,
            'orders_count': orders_count,
            'cashback_points': orders_count * 2500,
            'default_address': "Toshkent sh., Yunusobod 4-mavze",
        },
        'message': 'Xush kelibsiz!'
    })


@csrf_exempt
def mobile_customer_profile_update_api(request):
    """Flutter Mijoz Ilovasi: Profil ma'lumotlarini yangilash"""
    if request.method != 'POST':
        return JsonResponse({'status': 'error', 'message': 'Faqat POST'}, status=405)

    try:
        data = json.loads(request.body.decode('utf-8')) if request.body else {}
    except Exception:
        data = request.POST

    phone = data.get('phone', '').strip()
    full_name = data.get('full_name', '').strip()

    clean_digits = ''.join(c for c in phone if c.isdigit())
    last_9 = clean_digits[-9:] if len(clean_digits) >= 9 else clean_digits

    customer = Customer.objects.filter(phone_number__icontains=last_9).first()
    if customer:
        if full_name:
            customer.full_name = full_name
            customer.save()
        return JsonResponse({
            'status': 'success',
            'customer': {
                'id': customer.id,
                'full_name': customer.full_name,
                'phone': customer.phone_number
            }
        })

    return JsonResponse({'status': 'error', 'message': 'Mijoz topilmadi'}, status=404)


@csrf_exempt
def mobile_customer_tip_api(request):
    """Flutter Mijoz Ilovasi: Kuryer va Restoranga choychaqa (Tip) hamda sharh yuborish"""
    if request.method != 'POST':
        return JsonResponse({'status': 'error', 'message': 'Faqat POST'}, status=405)

    try:
        data = json.loads(request.body.decode('utf-8')) if request.body else {}
    except Exception:
        data = request.POST

    order_id = data.get('order_id')
    tip_amount = float(data.get('tip_amount', 0))
    rating = int(data.get('rating', 5))
    review = data.get('review', '')

    order = Order.objects.filter(id=order_id).first()
    if order:
        OrderStatusHistory.objects.create(
            order=order,
            old_status=order.status,
            new_status=order.status,
            notes=f"⭐ Baho: {rating}/5 | Choychaqa: {tip_amount:,.0f} so'm | Sharh: {review}"
        )
        return JsonResponse({
            'status': 'success',
            'message': 'Rahmat! Sizning bahoyingiz va choychaqangiz kuryerga yetkazildi!'
        })

    return JsonResponse({'status': 'error', 'message': 'Buyurtma topilmadi'}, status=404)


# --- Kuryer Flutter Mobil Ilovasi API lari ---

@csrf_exempt
def mobile_courier_login_api(request):
    """Flutter Kuryer Ilovasi: Telefon va PIN orqali autentifikatsiya"""
    if request.method != 'POST':
        return JsonResponse({'success': False, 'message': 'Faqat POST'}, status=405)

    try:
        data = json.loads(request.body.decode('utf-8')) if request.body else {}
    except Exception:
        data = request.POST

    phone = data.get('phone', '').strip()
    pin = data.get('pin', '').strip()

    courier = CourierProfile.objects.filter(phone__icontains=phone[-9:] if len(phone) >= 9 else phone).first()
    if not courier or courier.pin_code != pin:
        return JsonResponse({'success': False, 'message': "Telefon raqam yoki PIN-kod noto'g'ri"}, status=401)

    if not courier.auth_token:
        import uuid
        courier.auth_token = f"courier_{uuid.uuid4().hex[:16]}"
        courier.save()

    return JsonResponse({
        'status': 'success',
        'success': True,
        'courier': {
            'id': courier.id,
            'name': courier.name,
            'phone': courier.phone,
            'vehicle_info': courier.vehicle_info,
            'token': courier.auth_token,
        },
        'courier_id': courier.id,
        'name': courier.name,
        'phone': courier.phone,
        'vehicle_info': courier.vehicle_info,
        'auth_token': courier.auth_token,
        'message': f"Xush kelibsiz, {courier.name}!"
    })


def mobile_courier_orders_api(request):
    """Flutter Kuryer Ilovasi: Biriktirilgan buyurtmalar va oshxonada tayyor bo'lgan dastavkalar"""
    token = request.headers.get('Authorization', '').replace('Bearer ', '').strip() or request.GET.get('token')
    courier = CourierProfile.objects.filter(auth_token=token).first() if token else None

    # Biriktirilgan barcha buyurtmalar
    my_orders = Order.objects.filter(
        courier=courier
    ).prefetch_related('items__product').order_by('-created_at') if courier else Order.objects.none()

    # Barcha ochiq dastavkalar (kuryer o'zi tanlab olishi mumkin bo'lgan)
    ready_deliveries = Order.objects.filter(
        service_type='delivery',
        status__in=['yangi', 'tasdiqlangan', 'tayor'],
        courier__isnull=True
    ).prefetch_related('items__product').order_by('-created_at')

    def format_orders(qset):
        res = []
        for o in qset:
            items_list = []
            for it in o.items.all():
                items_list.append({
                    'dish_name': it.product.name,
                    'quantity': it.quantity,
                    'price': float(it.price)
                })
            res.append({
                'id': o.id,
                'order_number': o.order_number,
                'customer_name': o.customer.full_name if o.customer else "Mijoz",
                'customer_phone': o.customer.phone_number if o.customer else "",
                'delivery_address': o.address or "Manzil ko'rsatilmagan",
                'address': o.address or "Manzil ko'rsatilmagan",
                'latitude': o.latitude,
                'longitude': o.longitude,
                'total_amount': float(o.total_amount),
                'payment_method': o.get_payment_method_display(),
                'status': o.status,
                'status_display': o.get_status_display(),
                'items_count': o.items.count(),
                'items': items_list,
                'created_at': o.created_at.strftime('%H:%M'),
                'notes': o.notes or ""
            })
        return res

    formatted_my_orders = format_orders(my_orders)
    formatted_available = format_orders(ready_deliveries)
    return JsonResponse({
        'status': 'success',
        'success': True,
        'courier_name': courier.name if courier else "Kuryer",
        'restaurant': {
            'name': 'Dilkash Restorani',
            'latitude': 41.311081,
            'longitude': 69.240562,
            'address': "Toshkent sh., Navoiy ko'chasi 14-uy",
            'phone': "+998 71 200 00 00"
        },
        'orders': formatted_my_orders,
        'my_active_orders': formatted_my_orders,
        'available_orders': formatted_available,
        'available_ready_orders': formatted_available
    })


@csrf_exempt
def mobile_courier_update_status_api(request, order_id):
    """Flutter Kuryer Ilovasi: Buyurtmani 'yolda' yoki 'yetkazildi' deb yangilash"""
    if request.method != 'POST':
        return JsonResponse({'status': 'error', 'success': False, 'message': 'Faqat POST'}, status=405)

    try:
        data = json.loads(request.body.decode('utf-8')) if request.body else {}
    except Exception:
        data = request.POST

    new_status = data.get('status') or data.get('new_status')  # 'yolda' or 'yetkazildi'
    token = request.headers.get('Authorization', '').replace('Bearer ', '').strip() or data.get('token')
    courier = CourierProfile.objects.filter(auth_token=token).first() if token else None

    order = get_object_or_404(Order, id=order_id)

    if new_status == 'yolda':
        if courier:
            order.courier = courier
            order.courier_name = courier.name
        order.status = 'yolda'
        order.save()
        OrderStatusHistory.objects.create(
            order=order,
            old_status='tayor',
            new_status='yolda',
            notes=f"Kuryer buyurtmani qabul qilib yo'lga chiqdi ({courier.name if courier else ''})"
        )
        return JsonResponse({'status': 'success', 'success': True, 'message': "Buyurtma qabul qilindi. Yo'lingiz bexatar bo'lsin!"})

    elif new_status == 'yetkazildi':
        order.status = 'yetkazildi'
        order.is_paid = True
        order.delivered_at = timezone.now()
        order.save()
        OrderStatusHistory.objects.create(
            order=order,
            old_status='yolda',
            new_status='yetkazildi',
            notes=f"Kuryer mijozga topshirdi va to'lovni tasdiqladi ({courier.name if courier else ''})"
        )
        return JsonResponse({'status': 'success', 'success': True, 'message': "Buyurtma mijozga yetkazildi deb belgilandi!"})

    return JsonResponse({'status': 'error', 'success': False, 'message': "Noto'g'ri status"}, status=400)


@csrf_exempt
def mobile_courier_location_api(request):
    """Flutter Kuryer Ilovasi: Kuryerning GPS koordinatalarini jonli uzatish"""
    if request.method != 'POST':
        return JsonResponse({'success': False, 'message': 'Faqat POST'}, status=405)

    try:
        data = json.loads(request.body.decode('utf-8')) if request.body else {}
    except Exception:
        data = request.POST

    token = request.headers.get('Authorization', '').replace('Bearer ', '').strip() or data.get('token')
    courier = CourierProfile.objects.filter(auth_token=token).first() if token else None
    if not courier:
        return JsonResponse({'success': False, 'message': 'Kuryer topilmadi'}, status=401)

    lat = data.get('latitude')
    lng = data.get('longitude')
    if lat and lng:
        courier.current_lat = float(lat)
        courier.current_lng = float(lng)
        courier.save()

    return JsonResponse({'success': True, 'message': 'Koordinata yangilandi'})


@csrf_exempt
def mobile_courier_claim_order_api(request):
    """
    Flutter Kuryer Ilovasi:
    Kuryer zakaz raqamini yozish orqali buyurtmani o'ziga biriktirib oladi.
    Shuningdek ochiq buyurtmalar ro'yxatidan tanlab olishni ham ta'minlaydi.
    """
    if request.method != 'POST':
        return JsonResponse({'status': 'error', 'success': False, 'message': 'Faqat POST'}, status=405)

    try:
        data = json.loads(request.body.decode('utf-8')) if request.body else {}
    except Exception:
        data = request.POST

    order_num_raw = str(data.get('order_number') or data.get('order_id') or '').strip()
    token = request.headers.get('Authorization', '').replace('Bearer ', '').strip() or data.get('token')
    courier_id = data.get('courier_id')

    courier = None
    if token:
        courier = CourierProfile.objects.filter(auth_token=token).first()
    if not courier and courier_id:
        courier = CourierProfile.objects.filter(id=courier_id).first()

    if not courier:
        return JsonResponse({
            'status': 'error',
            'success': False,
            'message': 'Kuryer profili topilmadi! Tizimga qaytadan kiring.'
        }, status=401)

    if not order_num_raw:
        return JsonResponse({
            'status': 'error',
            'success': False,
            'message': 'Buyurtma raqamini kiriting!'
        }, status=400)

    clean_num = order_num_raw.lstrip('#').strip()

    # Avval order_number bo'yicha qidiramiz
    order = Order.objects.filter(order_number=clean_num).first()
    if not order and clean_num.isdigit():
        order = Order.objects.filter(id=int(clean_num)).first()

    if not order:
        return JsonResponse({
            'status': 'error',
            'success': False,
            'message': f"#{clean_num} raqamli buyurtma tizimda topilmadi!"
        }, status=404)

    # Yetkazib berish buyurtmasi ekanligini tekshirish
    if order.service_type != 'delivery':
        return JsonResponse({
            'status': 'error',
            'success': False,
            'message': f"#{order.order_number} raqamli buyurtma dastavka emas ({order.get_service_type_display()})!"
        }, status=400)

    # Yakunlangan yoki bekor qilinganligini tekshirish
    if order.status in ['yetkazildi', 'yakunlandi', 'bekor_qilindi']:
        return JsonResponse({
            'status': 'error',
            'success': False,
            'message': f"#{order.order_number} raqamli buyurtma allaqachon {order.get_status_display()}!"
        }, status=400)

    # Boshqa kuryerga biriktirilganligini tekshirish
    if order.courier and order.courier.id != courier.id:
        return JsonResponse({
            'status': 'error',
            'success': False,
            'message': f"#{order.order_number} buyurtma allaqachon boshqa kuryer ({order.courier.name})ga biriktirilgan!"
        }, status=400)

    # Biriktirish
    old_status = order.status
    order.courier = courier
    order.courier_name = courier.name
    order.save()

    OrderStatusHistory.objects.create(
        order=order,
        old_status=old_status,
        new_status=order.status,
        notes=f"Kuryer {courier.name} buyurtmani #{order.order_number} raqami orqali o'ziga biriktirib oldi."
    )

    items_list = []
    for it in order.items.all():
        items_list.append({
            'dish_name': it.product.name,
            'quantity': it.quantity,
            'price': float(it.price)
        })

    return JsonResponse({
        'status': 'success',
        'success': True,
        'message': f"#{order.order_number} raqamli buyurtma sizga muvaffaqiyatli biriktirildi!",
        'order': {
            'id': order.id,
            'order_number': order.order_number,
            'customer_name': order.customer.full_name if order.customer else "Mijoz",
            'customer_phone': order.customer.phone_number if order.customer else "",
            'delivery_address': order.address or "Manzil ko'rsatilmagan",
            'address': order.address or "Manzil ko'rsatilmagan",
            'latitude': order.latitude,
            'longitude': order.longitude,
            'total_amount': float(order.total_amount),
            'status': order.status,
            'status_display': order.get_status_display(),
            'created_at': order.created_at.strftime('%H:%M'),
            'notes': order.notes or "",
            'items': items_list
        }
    })


@csrf_exempt
def mobile_courier_available_orders_api(request):
    """Flutter Kuryer Ilovasi: Kuryer o'ziga tanlab olishi mumkin bo'lgan barcha bo'sh dastavkalar"""
    open_orders = Order.objects.filter(
        service_type='delivery',
        status__in=['yangi', 'tasdiqlangan', 'tayor'],
        courier__isnull=True
    ).prefetch_related('items__product').order_by('-created_at')

    res = []
    for o in open_orders:
        items_list = []
        for it in o.items.all():
            items_list.append({
                'dish_name': it.product.name,
                'quantity': it.quantity,
                'price': float(it.price)
            })
        res.append({
            'id': o.id,
            'order_number': o.order_number,
            'customer_name': o.customer.full_name if o.customer else "Mijoz",
            'customer_phone': o.customer.phone_number if o.customer else "",
            'delivery_address': o.address or "Manzil ko'rsatilmagan",
            'address': o.address or "Manzil ko'rsatilmagan",
            'latitude': o.latitude,
            'longitude': o.longitude,
            'total_amount': float(o.total_amount),
            'payment_method': o.get_payment_method_display(),
            'status': o.status,
            'status_display': o.get_status_display(),
            'items_count': o.items.count(),
            'items': items_list,
            'created_at': o.created_at.strftime('%H:%M'),
            'notes': o.notes or ""
        })

    return JsonResponse({
        'status': 'success',
        'success': True,
        'orders': res,
        'count': len(res)
    })


@csrf_exempt
def waiter_assign_table_api(request, table_number):
    """Ofitsiant terminalidan stolni o'ziga biriktirish API"""
    if request.method != 'POST':
        return JsonResponse({'success': False, 'message': 'Faqat POST'}, status=405)

    try:
        data = json.loads(request.body.decode('utf-8')) if request.body else {}
    except Exception:
        data = request.POST

    waiter = None
    waiter_id = data.get('waiter_id')
    waiter_token = request.headers.get('Authorization', '').replace('Bearer ', '').strip() or data.get('token')
    waiter_name = data.get('waiter_name')

    if waiter_id:
        waiter = WaiterProfile.objects.filter(id=waiter_id).first()
    elif waiter_token:
        waiter = WaiterProfile.objects.filter(auth_token=waiter_token).first()
    elif waiter_name:
        waiter = WaiterProfile.objects.filter(name=waiter_name).first()

    if not waiter:
        return JsonResponse({'success': False, 'message': 'Ofitsiant profili topilmadi!'}, status=404)

    table_num_int = int(table_number) if str(table_number).isdigit() else 1
    table_obj = RestaurantTable.objects.filter(number=table_num_int).first()
    if not table_obj:
        return JsonResponse({'success': False, 'message': f"Stol #{table_number} topilmadi!"}, status=404)

    table_obj.assigned_waiter = waiter
    table_obj.save()

    # Faol buyurtma bo'lsa unga ham biriktiramiz
    active_order = Order.objects.filter(
        service_type='dine_in',
        table_number=str(table_number),
        status__in=['yangi', 'tasdiqlangan', 'tayor']
    ).first()
    if active_order:
        active_order.waiter = waiter
        active_order.waiter_name = waiter.name
        active_order.save()

    return JsonResponse({
        'success': True,
        'message': f"Stol #{table_number} {waiter.name}ga muvaffaqiyatli biriktirildi.",
        'assigned_waiter_id': waiter.id,
        'assigned_waiter_name': waiter.name
    })


@csrf_exempt
def waiter_release_table_api(request, table_number):
    """Stolni ofitsiantdan bo'shatish API"""
    if request.method != 'POST':
        return JsonResponse({'success': False, 'message': 'Faqat POST'}, status=405)

    table_num_int = int(table_number) if str(table_number).isdigit() else 1
    table_obj = RestaurantTable.objects.filter(number=table_num_int).first()
    if not table_obj:
        return JsonResponse({'success': False, 'message': f"Stol #{table_number} topilmadi!"}, status=404)

    table_obj.assigned_waiter = None
    table_obj.save()

    return JsonResponse({
        'success': True,
        'message': f"Stol #{table_number} ofitsiantdan bo'shatildi."
    })

