"""
Click va Payme to'lov tizimlari integratsiyasi (2026/2027)
"""

import base64
import json
import logging
from decimal import Decimal
from django.utils import timezone
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from .models import Order, PaymentTransaction, BotSettings
from .utils import send_telegram_message
from django.conf import settings

logger = logging.getLogger(__name__)

def generate_click_url(order: Order, return_url: str = None) -> str:
    """Click to'lov havolasini yaratish"""
    bot_settings = BotSettings.get_settings()
    service_id = bot_settings.click_service_id or "54321" # Demo / Sozlamalardan
    merchant_id = bot_settings.click_merchant_id or "12345"
    amount = f"{order.total_amount:.2f}"
    
    url = f"https://my.click.uz/services/pay?service_id={service_id}&merchant_id={merchant_id}&amount={amount}&transaction_param={order.order_number}"
    if return_url:
        url += f"&return_url={return_url}"
    return url

def generate_payme_url(order: Order) -> str:
    """Payme to'lov havolasini yaratish (Base64 params)"""
    bot_settings = BotSettings.get_settings()
    merchant_id = bot_settings.payme_merchant_id or "64b7f8e9a1b2c3d4e5f6a7b8"
    # Payme summani tiyinda qabul qiladi (1 so'm = 100 tiyin)
    amount_in_tiyin = int(order.total_amount * 100)
    
    params = f"m={merchant_id};ac.order_id={order.order_number};a={amount_in_tiyin}"
    encoded = base64.b64encode(params.encode()).decode()
    return f"https://checkout.paycom.uz/{encoded}"

def mark_order_as_paid(order: Order, provider: str, transaction_id: str, raw_data: dict = None):
    """Buyurtmani to'langan deb belgilash va Telegram xabar yuborish"""
    order.is_paid = True
    order.payment_id = transaction_id
    order.payment_method = provider
    order.save()

    PaymentTransaction.objects.update_or_create(
        transaction_id=transaction_id,
        defaults={
            'order': order,
            'provider': provider,
            'amount': order.total_amount,
            'status': 'completed',
            'completed_at': timezone.now(),
            'raw_response': json.dumps(raw_data or {})
        }
    )

    # Oshpazga to'lov haqida Telegram xabar yuborish
    provider_name = provider.upper()
    chef_text = (
        f"💳 **To'lov qabul qilindi!**\n\n"
        f"📋 Buyurtma #{order.order_number}\n"
        f"💰 Summa: {order.total_amount:,.0f} so'm\n"
        f"🏦 Tizim: **{provider_name}**\n"
        f"🆔 Tranzaksiya: `{transaction_id}`\n"
        f"Holat: ✅ TO'LANGAN"
    )
    send_telegram_message(chat_id=settings.CHEF_CHAT_ID, text=chef_text)

    # Mijozga to'lov tasdiqlanganligi haqida xabar
    if order.telegram_user_id:
        user_text = (
            f"🎉 **To'lovingiz muvaffaqiyatli qabul qilindi!**\n\n"
            f"📋 Buyurtma #{order.order_number}\n"
            f"💰 To'langan summa: {order.total_amount:,.0f} so'm ({provider_name})\n"
            f"Oshxonamiz taomingizni tayyorlamoqda! 👨‍🍳"
        )
        send_telegram_message(chat_id=order.telegram_user_id, text=user_text)

@csrf_exempt
def click_webhook(request):
    """
    Click Merchant API webhook
    Prepare (action=0) va Complete (action=1)
    """
    if request.method != 'POST':
        return JsonResponse({'error': -1, 'error_note': 'Only POST supported'})

    try:
        data = request.POST.dict() or json.loads(request.body.decode('utf-8'))
    except Exception:
        data = request.POST.dict()

    click_trans_id = data.get('click_trans_id')
    service_id = data.get('service_id')
    click_paydoc_id = data.get('click_paydoc_id')
    merchant_trans_id = data.get('merchant_trans_id') # order_number
    amount = data.get('amount')
    action = str(data.get('action', '0'))
    error = data.get('error')

    order = Order.objects.filter(order_number=merchant_trans_id).first()
    if not order:
        return JsonResponse({
            'error': -5,
            'error_note': 'Order not found',
            'click_trans_id': click_trans_id,
            'merchant_trans_id': merchant_trans_id
        })

    # Prepare (action=0)
    if action == '0':
        return JsonResponse({
            'click_trans_id': click_trans_id,
            'merchant_trans_id': merchant_trans_id,
            'merchant_prepare_id': order.id,
            'error': 0,
            'error_note': 'Success'
        })
    # Complete (action=1)
    elif action == '1':
        if str(error) == '0':
            mark_order_as_paid(order, 'click', str(click_trans_id), data)
            return JsonResponse({
                'click_trans_id': click_trans_id,
                'merchant_trans_id': merchant_trans_id,
                'merchant_confirm_id': order.id,
                'error': 0,
                'error_note': 'Success'
            })
        else:
            return JsonResponse({
                'click_trans_id': click_trans_id,
                'merchant_trans_id': merchant_trans_id,
                'error': -9,
                'error_note': 'Payment failed'
            })

    return JsonResponse({'error': -8, 'error_note': 'Unknown action'})

@csrf_exempt
def payme_webhook(request):
    """
    Payme Merchant API JSON-RPC webhook
    """
    if request.method != 'POST':
        return JsonResponse({'error': {'code': -32300, 'message': 'Only POST supported'}})

    try:
        body = json.loads(request.body.decode('utf-8'))
    except Exception:
        return JsonResponse({'error': {'code': -32700, 'message': 'Parse error'}})

    method = body.get('method')
    params = body.get('params', {})
    rpc_id = body.get('id')

    # CheckPerformTransaction
    if method == 'CheckPerformTransaction':
        order_num = params.get('account', {}).get('order_id')
        order = Order.objects.filter(order_number=order_num).first()
        if not order:
            return JsonResponse({'id': rpc_id, 'error': {'code': -31050, 'message': {'uz': 'Buyurtma topilmadi'}}})
        
        return JsonResponse({
            'id': rpc_id,
            'result': {
                'allow': True
            }
        })

    # PerformTransaction
    elif method == 'PerformTransaction':
        trans_id = params.get('id')
        trans = PaymentTransaction.objects.filter(transaction_id=trans_id).first()
        if trans and trans.order:
            mark_order_as_paid(trans.order, 'payme', trans_id, params)
            return JsonResponse({
                'id': rpc_id,
                'result': {
                    'transaction': str(trans.id),
                    'perform_time': int(timezone.now().timestamp() * 1000),
                    'state': 2
                }
            })

    # Standart muvaffaqiyatli javob
    return JsonResponse({
        'id': rpc_id,
        'result': {
            'state': 1
        }
    })

@csrf_exempt
def simulate_payment_api(request, order_id):
    """
    Test/Simulyatsiya uchun 1-bosish bilan to'lovni tasdiqlash
    (Test rejimida Click yoki Payme orqali to'langan deb belgilash)
    """
    if request.method == 'POST':
        order = Order.objects.filter(id=order_id).first()
        if not order:
            return JsonResponse({'success': False, 'message': 'Buyurtma topilmadi'}, status=404)
        
        provider = 'click'
        if request.POST.get('provider'):
            provider = request.POST.get('provider')
        else:
            try:
                if request.body:
                    b_data = json.loads(request.body.decode('utf-8'))
                    provider = b_data.get('provider', provider)
            except Exception:
                pass

        trans_id = f"TEST_{provider.upper()}_{int(timezone.now().timestamp())}"
        mark_order_as_paid(order, provider, trans_id, {'type': 'simulation'})

        return JsonResponse({
            'success': True,
            'message': f"Buyurtma #{order.order_number} {provider.upper()} orqali muvaffaqiyatli to'landi!",
            'is_paid': True,
            'payment_id': trans_id
        })
    return JsonResponse({'success': False, 'message': 'POST talab qilinadi'}, status=405)
