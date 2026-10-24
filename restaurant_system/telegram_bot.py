import os
import django
import logging
import json
import math
import requests # Still needed for Telegram API calls
import datetime # Added for time comparison
from decimal import Decimal
from telegram import (
    Update, InlineKeyboardButton, InlineKeyboardMarkup, KeyboardButton,
    ReplyKeyboardMarkup, InputMediaPhoto, ReplyKeyboardRemove, WebAppInfo)
from telegram.ext import (
    ApplicationBuilder, CommandHandler, CallbackQueryHandler, MessageHandler,
    ContextTypes, filters)
# Import sync_to_async for bridging sync Django ORM with async bot
from asgiref.sync import sync_to_async
from django.db import transaction # For atomic operations

# Configure logging
logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO)
logger = logging.getLogger(__name__)

# Setup Django environment
# This assumes telegram_bot.py is in the same directory as manage.py
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'restaurant_system.settings')
django.setup()

# Now you can import Django models and settings
from django.conf import settings
from chef_panel.models import Category, Product, Customer, Order, OrderItem, OrderStatusHistory, BotSettings, RestaurantTable
from django.utils import timezone # For setting timestamps

# Global variables
STORE_LAT = getattr(settings, 'STORE_LAT', 40.665236)
STORE_LON = getattr(settings, 'STORE_LON', 72.563908)
mahsulotlar = {}
kategoriyalar = {}
bot_settings = None # Global variable to hold bot settings

# Placeholder image URL for cases where local image is not found or cannot be sent
PLACEHOLDER_IMAGE_URL = "https://i.postimg.cc/kgbRwBbN/photo-2025-07-24-23-50-48.jpg"

# --- Utility functions for Telegram API (adapted from chef_panel/utils.py) ---
def send_telegram_message(chat_id, text, reply_markup=None, message_id=None, parse_mode="Markdown"):
    """Telegram Bot API orqali xabar yuborish/tahrirlash"""
    url = f"{settings.TELEGRAM_API_BASE_URL}{settings.TELEGRAM_BOT_TOKEN}/"
    payload = {
        'chat_id': chat_id,
        'text': text,
        'parse_mode': parse_mode
    }
    if reply_markup:
        payload['reply_markup'] = json.dumps(reply_markup)
    try:
        if message_id:
            url += "editMessageText"
            payload['message_id'] = message_id
        else:
            url += "sendMessage"
        response = requests.post(url, json=payload)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        logger.error(f"Telegram xabar yuborishda xato: {e}")
        return None

def send_telegram_location(chat_id, latitude, longitude):
    """Telegram Bot API orqali lokatsiya yuborish"""
    url = f"{settings.TELEGRAM_API_BASE_URL}{settings.TELEGRAM_BOT_TOKEN}/sendLocation"
    payload = {
        'chat_id': chat_id,
        'latitude': latitude,
        'longitude': longitude
    }
    try:
        response = requests.post(url, json=payload)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        logger.error(f"Telegram lokatsiya yuborishda xato: {e}")
        return None

# --- Data loading from Django ORM ---
@sync_to_async
def load_data():
    global mahsulotlar, kategoriyalar, bot_settings
    mahsulotlar = {}
    kategoriyalar = {}
    
    for product in Product.objects.filter(is_available=True):
        # O'zgartirish: Rasmni lokal fayl yo'li sifatida saqlash
        local_image_path = product.image.path if product.image else None
        mahsulotlar[product.name] = {
            "narx": product.price,  # Keep as Decimal
            "desc": product.description,
            "rasm":  local_image_path # Lokal fayl yo'lini saqlash
        }
    
    for category in Category.objects.filter(is_active=True):
        kategoriyalar[category.name] = [p.name for p in category.product_set.filter(is_available=True)]

    # Load bot settings
    try:
        # Get the first (and ideally only) instance of BotSettings
        # If it doesn't exist, create a default one.
        bot_settings, created = BotSettings.objects.get_or_create(
            pk=1, # Use a fixed primary key to ensure only one instance
            defaults={
                'service_start_time': datetime.time(9, 0),  # 09:00
                'service_end_time': datetime.time(22, 0),    # 22:00
                'delivery_base_cost': 5000,
                'delivery_cost_per_extra_km_block': 5000,
                'delivery_max_radius_km': 10.0
            }
        )
        if created:
            logger.info("Default BotSettings yaratildi.")
    except Exception as e:
        logger.error(f"BotSettings yuklashda yoki yaratishda xato: {e}", exc_info=True)
        # Fallback to hardcoded defaults if DB access fails
        bot_settings = type('BotSettings', (object,), {
            'service_start_time': datetime.time(9, 0),
            'service_end_time': datetime.time(22, 0),
            'delivery_base_cost': Decimal('5000'),
            'delivery_cost_per_extra_km_block': Decimal('5000'),
            'delivery_max_radius_km': 10.0
        })() # Create a dummy object with default attributes

# --- Order status update logic (adapted from chef_panel/views.py) ---
@sync_to_async
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
    user_text = f"✅ **Буюртмангиз қабул қилинди!**\n\n"
    user_text += f"📋 Буюртма ID: **{order.order_number}**\n"
    user_text += f"👨‍💼 Исм: {order.customer.full_name}\n"
    user_text += f"📱 Телефон: {order.customer.phone_number}\n"
    user_text += f"💳 Тўлов усули: {order.get_payment_method_display()}\n"
    user_text += f"🚀 Хизмат тури: {order.get_service_type_display()}\n"
    
    if order.service_type == 'delivery':
        if order.address:
            user_text += f"🏠 Манзил: {order.address}\n"
        else:
            user_text += "📍 Манзил: Фақат локация\n"
        if order.latitude and order.longitude:
            user_text += f"📍 Локация: https://www.google.com/maps?q={order.latitude},{order.longitude}\n"
    else:
        user_text += "🏪 Олиб кетиш учун: Ресторандан\n"
    
    user_text += f"\n🍽 **Маҳсулотлар:**\n"
    for item in list(order.items.all()): # Convert queryset to list in sync context
        user_text += f"• {item.quantity} дона {item.product.name} - {item.total:,} сўм\n"
    user_text += f"\n💰 Жами: {order.total_amount:,} сўм\n"
    user_text += f"{emoji} Статус: **{order.get_status_display()}**"

    user_keyboard = [[{'text': "⬅️ Бош меню", 'callback_data': "main_menu"}]]
    
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

    # Oshpaz xabarini yangilash
    if order.chef_message_id:
        chef_text = f"{emoji} **Буюртма #{order.order_number} ҳолати ўзгарди: {order.get_status_display()}**\n\n"
        chef_text += f"👨‍💼 Исм: {order.customer.full_name}\n"
        chef_text += f"📱 Телефон: {order.customer.phone_number}\n"
        chef_text += f"💳 Тўлов усули: {order.get_payment_method_display()}\n"
        chef_text += f"🚀 Хизмат тури: {order.get_service_type_display()}\n"
        
        if order.service_type == 'delivery':
            if order.address:
                chef_text += f"🏠 Манзил: {order.address}\n"
            else:
                chef_text += "📍 Манзил: Фақат локация\n"
        else:
            chef_text += "🏪 Олиб кетиш учун: Ресторандан\n"
            
        chef_text += f"\n🍽 **Маҳсулотлар:**\n"
        for item in list(order.items.all()): # Convert queryset to list in sync context
            chef_text += f"• {item.quantity} дона {item.product.name} - {item.total:,} сўм\n"
        chef_text += f"\n💰 Жами: {order.total_amount:,} сўм"

        chef_keyboard = []
        if new_status == 'yangi':
            chef_keyboard = [
                [{'text': "✅ Тасдиқлаш", 'callback_data': f"chef_confirm:{order.id}"},
                 {'text': "❌ Бекор қилиш", 'callback_data': f"chef_cancel:{order.id}"}]
            ]
        elif new_status == 'tasdiqlangan':
            chef_keyboard = [
                [{'text': "🍽 Тайёр", 'callback_data': f"chef_ready:{order.id}"}],
                [{'text': "❌ Бекор қилиш", 'callback_data': f"chef_cancel:{order.id}"}]
            ]
        elif new_status == 'tayor' and order.service_type == 'pickup':
            chef_keyboard = [
                [{'text': "✅ Олиб кетилди", 'callback_data': f"chef_picked_up:{order.id}"}],
                [{'text': "❌ Бекор қилиш", 'callback_data': f"chef_cancel:{order.id}"}]
            ]
        # If status is 'tayor' (delivery), 'yolda', 'yetkazildi', 'olib_ketildi', 'bekor_qilingan', no more actions for chef
        
        send_telegram_message(
            chat_id=settings.CHEF_CHAT_ID,
            text=chef_text,
            reply_markup={'inline_keyboard': chef_keyboard},
            message_id=order.chef_message_id
        )

    # Kuryer xabarini yangilash (faqat delivery uchun)
    if order.service_type == 'delivery':
        if order.courier_message_id:
            courier_text = f"{emoji} **Буюртма #{order.order_number} ҳолати ўзгарди: {order.get_status_display()}**\n\n"
            courier_text += f"👨‍💼 Исм: {order.customer.full_name}\n"
            courier_text += f"📱 Телефон: {order.customer.phone_number}\n"
            courier_text += f"💳 Тўлов усули: {order.get_payment_method_display()}\n"
            if order.address:
                courier_text += f"🏠 Манзил: {order.address}\n"
            else:
                courier_text += "📍 Манзил: Фақат локация\n"
            courier_text += f"\n🍽 **Маҳсулотлар:**\n"
            for item in list(order.items.all()): # Convert queryset to list in sync context
                courier_text += f"• {item.quantity} дона {item.product.name} - {item.total:,} сўм\n"
            courier_text += f"\n💰 Жами: {order.total_amount:,} сўм"

            courier_keyboard = []
            if new_status == 'tayor':
                courier_keyboard = [
                    [{'text': "🚚 Йўлда", 'callback_data': f"courier_on_way:{order.id}"}],
                    [{'text': "❌ Бекор қилиш", 'callback_data': f"courier_cancel:{order.id}"}]
                ]
            elif new_status == 'yolda':
                courier_keyboard = [
                    [{'text': "✅ Етказилди", 'callback_data': f"courier_delivered:{order.id}"}],
                    [{'text': "❌ Бекор қилиш", 'callback_data': f"courier_cancel:{order.id}"}]
                ]
            
            send_telegram_message(
                chat_id=settings.ADMIN_CHAT_ID, # Assuming ADMIN_CHAT_ID is courier's chat ID
                text=courier_text,
                reply_markup={'inline_keyboard': courier_keyboard},
                message_id=order.courier_message_id
            )
        elif new_status == 'tayor': # If order is ready, send new message to courier if no existing message_id
            courier_text = f"🚚 **Етказиб бериш учун янги буюртма #{order.order_number}**\n\n"
            courier_text += f"👨‍💼 Исм: {order.customer.full_name}\n"
            courier_text += f"📱 Телефон: {order.customer.phone_number}\n"
            courier_text += f"💳 Тўлов усули: {order.get_payment_method_display()}\n"
            if order.address:
                courier_text += f"🏠 Манзил: {order.address}\n"
            else:
                courier_text += "📍 Манзил: Фақат локация\n"
            courier_text += f"\n🍽 **Маҳсулотлар:**\n"
            for item in list(order.items.all()): # Convert queryset to list in sync context
                courier_text += f"• {item.quantity} дона {item.product.name} - {item.total:,} сўм\n"
            courier_text += f"\n💰 Жами: {order.total_amount:,} сўм"

            courier_keyboard = [
                [{'text': "🚚 Йўлда", 'callback_data': f"courier_on_way:{order.id}"}],
                [{'text': "❌ Бекор қилиш", 'callback_data': f"courier_cancel:{order.id}"}]
            ]
            courier_msg_response = send_telegram_message(
                chat_id=settings.ADMIN_CHAT_ID,
                text=courier_text,
                reply_markup={'inline_keyboard': courier_keyboard}
            )
            if courier_msg_response and courier_msg_response.get('ok'):
                order.courier_message_id = courier_msg_response['result']['message_id']
                order.save()
                
            if order.latitude and order.longitude:
                send_telegram_location(
                    chat_id=settings.ADMIN_CHAT_ID,
                    latitude=order.latitude,
                    longitude=order.longitude
                )

# ----------------------------------------------------
# 1) Masofa va yetkazib berish narxi hisoblash
# ----------------------------------------------------
def calculate_distance_km(lat1, lon1, lat2, lon2):
    """
    Haversine formula orqali (lat1, lon1) dan (lat2, lon2) ga bo'lgan
    masofani (kmda) qaytaradi.
    """
    R = 6371.0  # Yer shari radiusi (km)
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (math.sin(d_lat / 2))**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * (math.sin(d_lon / 2))**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    distance = R * c
    return distance

def calculate_delivery_cost(distance_km, bot_settings_obj=None):
    """
    Yetkazib berish narxini yangi qoidalar asosida hisoblaydi:
    - Boshlang'ich narx: 5000 so'm (har qanday masofa uchun)
    - Qo'shimcha: har km uchun 5000 so'm (1 km dan keyin)
    - Maksimal radius: 10 km
    """
    if distance_km > 10.0:  # Fixed 10km max radius
        return None  # Maksimal radiusdan uzoq joylarga xizmat yo'q

    base_cost = Decimal('5000')  # Fixed base cost
    if distance_km <= 1.0:
        return base_cost
    else:
        additional_km = math.ceil(distance_km - 1.0)  # Round up additional km
        additional_cost = Decimal('5000') * additional_km
        return base_cost + additional_cost

def is_service_time_active(current_time, start_time, end_time):
    """
    Hozirgi vaqt xizmat ko'rsatish vaqti oralig'ida ekanligini tekshiradi.
    current_time: timezone-aware datetime object
    start_time, end_time: datetime.time objects (naive)
    """
    # Create dummy timezone-aware datetime objects for comparison on the same date
    today = current_time.date()
    start_dt = timezone.make_aware(datetime.datetime.combine(today, start_time), timezone.get_current_timezone())
    end_dt = timezone.make_aware(datetime.datetime.combine(today, end_time), timezone.get_current_timezone())

    if start_dt <= end_dt:
        # Normal case: e.g., 10:00 - 22:00
        return start_dt <= current_time <= end_dt
    else: 
        # Overnight service: e.g., 22:00 - 06:00 (next day)
        # Check if current_time is after start_dt (on current day) OR before end_dt (on next day)
        return current_time >= start_dt or current_time <= end_dt

# ----------------------------------------------------
# 2) Asosiy inline menyularni qurish
# ----------------------------------------------------
def main_inline_menu(context: ContextTypes.DEFAULT_TYPE) -> InlineKeyboardMarkup:
    user_savat = context.user_data.get('savat', {})
    web_app_url = getattr(settings, 'WEB_APP_URL', '')
    is_https = bool(web_app_url and web_app_url.startswith('https://'))

    first_row = []
    if is_https:
        first_row.append(InlineKeyboardButton("🚀 Menyu (Web App)", web_app=WebAppInfo(url=web_app_url)))
    first_row.append(InlineKeyboardButton("🍽 Buyurtma berish", callback_data="menu"))
    if user_savat:
        first_row.append(InlineKeyboardButton("🛒 Savat", callback_data="show_cart"))

    buttons = [
        first_row,
        [
            InlineKeyboardButton("🚚 Yetkazib berish", callback_data="service_type:delivery"),
            InlineKeyboardButton("🏪 Olib ketish", callback_data="service_type:pickup")
        ],
        [
            InlineKeyboardButton("🛍 Buyurtmalarim", callback_data="user_orders:1"),
            InlineKeyboardButton("👤 Profil", callback_data="profile")
        ],
        [
            InlineKeyboardButton("✍️ Fikr bildirish", callback_data="feedback")
        ]
    ]
    return InlineKeyboardMarkup(buttons)


def build_cart_message(user_savat, context):
    if not user_savat:
        return "🛒 Савтингиз бўш!"

    text = "🛒 Саватчада:\n"
    total = Decimal('0')
    for product, qty in user_savat.items():
        narx = mahsulotlar.get(product, {}).get("narx", Decimal('0'))
        summa = narx * qty
        total += summa
        text += f"• {qty} x {product} - {summa:,} сўм\n"

    text += f"\n💰 Маҳсулотлар: {total:,} сўм\n"

    # Service type va delivery cost
    service_type = context.user_data.get('service_type', 'delivery')
    if service_type == 'pickup':
        text += f"🏪 Олиб кетиш: Бепул\n"
        text += f"📊 Жами: {total:,} сўм\n"
    else:
        # Yetkazib berish narxini context dan olamiz:
        delivery_possible = context.user_data.get('delivery_possible', None)
        if delivery_possible is False:
            text += f"🚫 Етказиб бериш: Мавжуд эмас (10 км дан узоқ)\n"
            text += f"📊 Жами: {total:,} сўм\n"
        else:
            delivery_cost = context.user_data.get('delivery_cost')
            if delivery_cost:
                text += f"🚚 Етказиб бериш: {delivery_cost:,} сўм\n"
                text += f"📊 Жами: {total + delivery_cost:,} сўм\n"
            else:
                text += "📍 Етказиб бериш: Локация киритилмаган\n"
                text += f"📊 Жами (ҳозирча): {total:,} сўм\n"

    return text

def build_cart_keyboard(savat):
    rows = []
    rows.append([
        InlineKeyboardButton("⬅️ Орқага", callback_data="menu"),
        InlineKeyboardButton("🚖 Буюртма бериш", callback_data="checkout")
    ])
    rows.append([
        InlineKeyboardButton("🎟 Промо-код", callback_data="promo_not_implemented"),
        InlineKeyboardButton("🗑 Саватни бўшатиш", callback_data="clear_cart")
    ])
    for product, qty in savat.items():
        rows.append([
            InlineKeyboardButton("➖", callback_data=f"update_cart:{product}:dec"),
            InlineKeyboardButton(f"{product} ({qty})", callback_data="noop"),
            InlineKeyboardButton("➕", callback_data=f"update_cart:{product}:inc")
        ])
    return rows

async def edit_message_based_on_type(query, text, keyboard, force_text=False, image_url=None):
    message = query.message
    if force_text:
        try:
            await query.delete_message()
            await query.message.reply_text(
                text,
                reply_markup=InlineKeyboardMarkup(keyboard),
                parse_mode="Markdown"
            )
        except Exception as e:
            logger.error(f"Failed to delete and resend message: {e}")
            await query.answer("Хатолик юз берди. Илтимос, қайта уриниб кўринг.", show_alert=True)
    elif message.photo or image_url: # Check if message has photo or if a new image_url is provided
        try:
            # If image_url is provided, use it. Otherwise, keep existing photo.
            # If message.photo is empty, and no image_url, this will fail.
            # Telegram API requires a file_id or URL for InputMediaPhoto.
            media_to_send = InputMediaPhoto(
                media=image_url if image_url else message.photo[-1].file_id, # Use provided URL or existing file_id
                caption=text,
                parse_mode='Markdown'
            )
            await query.edit_message_media(
                media=media_to_send,
                reply_markup=InlineKeyboardMarkup(keyboard)
            )
        except Exception as e:
            logger.error(f"Failed to edit message media: {e}")
            await query.answer("Хатолик юз берди. Илтимос, қайта уриниб кўринг.", show_alert=True)
            # Fallback to editing text if media edit fails
            try:
                await query.edit_message_text(
                    text=text,
                    reply_markup=InlineKeyboardMarkup(keyboard),
                    parse_mode="Markdown"
                )
            except Exception as e_text:
                logger.error(f"Failed to fallback to edit message text: {e_text}")
                await query.answer("Хатолик юз берди. Илтимос, қайта уриниб кўринг.", show_alert=True)
    elif message.text:
        try:
            await query.edit_message_text(
                text=text,
                reply_markup=InlineKeyboardMarkup(keyboard),
                parse_mode="Markdown"
            )
        except Exception as e:
            logger.error(f"Failed to edit message text: {e}")
            await query.answer("Хатолик юз берди. Илtimos, qayta urinib ko'ring.", show_alert=True)
    else:
        try:
            await query.delete_message()
            await query.message.reply_text(
                text,
                reply_markup=InlineKeyboardMarkup(keyboard),
                parse_mode="Markdown"
            )
        except Exception as e:
            logger.error(f"Failed to handle unknown message type: {e}")
            await query.answer("Хатолик юз берди. Илтимос, қайта уриниб кўринг.", show_alert=True)

# ----------------------------------------------------
# Savatni ko'rsatish
# ----------------------------------------------------
async def show_cart(update_or_query, context: ContextTypes.DEFAULT_TYPE, edit=False):
    user_savat = context.user_data.get('savat', {})
    text = build_cart_message(user_savat, context)
    keyboard = build_cart_keyboard(user_savat)

    if isinstance(update_or_query, Update):
        update = update_or_query
        if update.callback_query:
            query = update.callback_query
            await query.answer()
            if edit:
                await edit_message_based_on_type(query, text, keyboard)
            else:
                await update.message.reply_text(
                    text, reply_markup=InlineKeyboardMarkup(keyboard),
                    parse_mode="Markdown"
                )
        else:
            await update.message.reply_text(
                text, reply_markup=InlineKeyboardMarkup(keyboard),
                parse_mode="Markdown"
            )
    else:
        query = update_or_query
        await query.answer()
        if edit:
            await edit_message_based_on_type(query, text, keyboard)
        else:
            await query.message.reply_text(
                text, reply_markup=InlineKeyboardMarkup(keyboard),
                parse_mode="Markdown"
            )

# ----------------------------------------------------
# /start
# ----------------------------------------------------
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user = update.effective_user
    web_app_url = getattr(settings, 'WEB_APP_URL', '')
    is_https = bool(web_app_url and web_app_url.startswith('https://'))

    kb_rows = []
    if is_https:
        kb_rows.append([KeyboardButton("🚀 Menyu ochish (Web App)", web_app=WebAppInfo(url=web_app_url))])
        kb_rows.append([KeyboardButton("🚚 Yetkazib berish"), KeyboardButton("🏪 Olib ketish")])
        kb_rows.append([KeyboardButton("🛒 Savat"), KeyboardButton("👤 Profil")])
        kb_rows.append([KeyboardButton("📱 Kontaktni ulashish", request_contact=True)])
    else:
        kb_rows.append([KeyboardButton("🚚 Yetkazib berish"), KeyboardButton("🏪 Olib ketish")])
        kb_rows.append([KeyboardButton("🍽 Bot Menyusi"), KeyboardButton("🛒 Savat")])
        kb_rows.append([KeyboardButton("👤 Profil"), KeyboardButton("📱 Kontaktni ulashish", request_contact=True)])

    reply_kb = ReplyKeyboardMarkup(kb_rows, resize_keyboard=True)
    await update.message.reply_text(
        f"🎉 Assalomu alaykum, {user.first_name}!\n\n"
        f"🍽 Restoranimizga xush kelibsiz!\n\n"
        f"Buyurtma berish usulini tanlang (🚚 Yetkazib berish yoki 🏪 Olib ketish) 👇",
        reply_markup=reply_kb
    )

    # Also show the main inline menu
    await update.message.reply_text(
        "🍽 Nimani buyurtma qilmoqchisiz?",
        reply_markup=main_inline_menu(context)
    )
    context.user_data["awaiting_contact_at_start"] = True

async def main_menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    text = "🍽 Нима буюртма қилмоқчисиз?"
    keyboard = main_inline_menu(context).inline_keyboard
    await edit_message_based_on_type(query, text, keyboard)

async def handle_contact(update: Update, context: ContextTypes.DEFAULT_TYPE):
    contact = update.message.contact
    context.user_data['phone_number'] = contact.phone_number
    context.user_data['full_name'] = contact.first_name + " " + (contact.last_name or "")
    context.user_data['telegram_user_id'] = update.effective_user.id

    await update.message.reply_text("✅ Раҳмат!", reply_markup=ReplyKeyboardRemove())

    if context.user_data.get("awaiting_contact_at_start"):
        del context.user_data["awaiting_contact_at_start"]
        # Service type tanlash
        keyboard = InlineKeyboardMarkup([
            [InlineKeyboardButton("🚚 Етказиб бериш", callback_data="service_type:delivery")],
            [InlineKeyboardButton("🏪 Олиб кетиш", callback_data="service_type:pickup")]
        ])
        await update.message.reply_text(
            "🚀 Қайси хизматдан фойдаланмоқчисиз?",
            reply_markup=keyboard
        )
        return

    # Agar /checkout jarayoni bo'lsa
    service_type = context.user_data.get('service_type', 'delivery')
    if service_type == 'delivery':
        await update.message.reply_text(
            "📞 Контакт қабул қилинди! Энди локациянгизни юборинг:",
            reply_markup=ReplyKeyboardMarkup([
                [KeyboardButton("📍 Локацияни улашиш", request_location=True)]
            ], resize_keyboard=True)
        )
        context.user_data['awaiting_location'] = True
    else:
        # Pickup uchun address/location kerak emas
        await update.message.reply_text(
            "📞 Контакт қабул қилинди!",
            reply_markup=ReplyKeyboardRemove()
        )
        keyboard = [
            [InlineKeyboardButton("✅ Тасдиқлаш", callback_data="final_confirm_order")],
            [InlineKeyboardButton("❌ Бекор қилиш", callback_data="cancel_order")]
        ]
        context.user_data['payment_method'] = 'naqd'  # default
        await update.message.reply_text(
            "💳 Тўлов усули: Нақд\n🔸 Буюртмани тасдиқлаш учун \"✅ Тасдиқлаш\" босинг:",
            reply_markup=InlineKeyboardMarkup(keyboard)
        )

async def handle_service_type(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    
    service_type = query.data.split(":")[1]
    context.user_data['service_type'] = service_type
    
    if service_type == 'delivery':
        text = "🚚 Етказиб бериш хизмати танланди!\n\n🍽 Энди буюртма беришингиз мумкин:"
    else:
        text = "🏪 Олиб кетиш хизмати танланди!\n\n🍽 Энди буюртма беришингиз мумкин:"
    
    await edit_message_based_on_type(query, text, main_inline_menu(context).inline_keyboard)

# ----------------------------------------------------
# Lokatsiya + masofa + yetkazib berish narxi (faqat delivery uchun)
# ----------------------------------------------------
async def handle_location(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if 'awaiting_location' in context.user_data and context.user_data['awaiting_location']:
        location = update.message.location
        user_lat = location.latitude
        user_lon = location.longitude

        # Masofani hisoblaymiz
        distance_km = calculate_distance_km(STORE_LAT, STORE_LON, user_lat, user_lon)
        delivery_cost = calculate_delivery_cost(distance_km)

        if delivery_cost is None:
            # Maksimal radiusdan uzoq => yetkazib berish yo'q
            del context.user_data['awaiting_location']
            context.user_data['delivery_possible'] = False
            await update.message.reply_text(
                f"😔 Узр, сизнинг манзилингиз бизнинг {bot_settings.delivery_max_radius_km} км радиусимиздан ташқарида.\n"
                "🚫 Шу сабаб етказиб бериш хизмати мавжуд эмас.\n"
                "💡 Лекин сиз олиб кетиш хизматидан фойдаланишингиз мумкин!\n\n"
                "🏪 Олиб кетиш хизматига ўтишни хоҳлайсизми?",
                reply_markup=InlineKeyboardMarkup([
                    [InlineKeyboardButton("🏪 Олиб кетишга ўтиш", callback_data="service_type:pickup")],
                    [InlineKeyboardButton("🍽 Фақат меню кўриш", callback_data="main_menu")]
                ])
            )
        else:
            # Radius ichida
            context.user_data['delivery_possible'] = True
            context.user_data['delivery_distance'] = distance_km
            context.user_data['delivery_cost'] = delivery_cost
            context.user_data['location'] = {
                'latitude': user_lat,
                'longitude': user_lon
            }
            del context.user_data['awaiting_location']
            await update.message.reply_text(
                f"📍 Локация қабул қилинди!\n"
                f"📏 Масофа: таҳминан {distance_km:.1f} км\n"
                f"💰 Етказиб бериш нархи: {delivery_cost:,} сўм\n\n"
                f"🏠 Агар қўшимча манзил киритмоқчи бўлсангиз, ёзинг.\n"
                f"❌ Керак бўлмаса, \"Қўшимча манзил керак эмас\" деб ёзинг.",
                reply_markup=ReplyKeyboardMarkup([
                    [KeyboardButton("❌ Қўшимча манзил керак эмас")]
                ], resize_keyboard=True)
            )
            context.user_data['awaiting_address'] = True

async def handle_address(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if 'awaiting_address' in context.user_data and context.user_data['awaiting_address']:
        address = update.message.text
        if address.lower() == "❌ қўшимча манзил керак эмас" or address.lower() == "қўшимча манзил керак эмас":
            address = None

        context.user_data['address'] = address
        del context.user_data['awaiting_address']

        await update.message.reply_text(
            "🏠 Манзил қабул қилинди.",
            reply_markup=ReplyKeyboardRemove()
        )

        keyboard = [
            [InlineKeyboardButton("✅ Тасдиқлаш", callback_data="final_confirm_order")],
            [InlineKeyboardButton("❌ Бекор қилиш", callback_data="cancel_order")]
        ]
        context.user_data['payment_method'] = 'naqd'  # default
        await update.message.reply_text(
            "💳 Тўлов усули: Нақд\n🔸 Буюртмани тасдиқлаш учун \"✅ Тасдиқлаш\" босинг:",
            reply_markup=InlineKeyboardMarkup(keyboard)
        )

# ----------------------------------------------------
# Profil
# ----------------------------------------------------
async def show_profile(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    user = update.effective_user
    profile_info = context.user_data
    user_id = user.id
    
    # Django ORM dan foydalanuvchi buyurtmalarini olish
    try:
        customer = await sync_to_async(Customer.objects.filter(telegram_id=user_id).first)()
        order_count = await sync_to_async(Order.objects.filter(customer=customer).count)() if customer else 0
    except Exception as e:
        logger.error(f"Django ORM dan buyurtmalarni olishda xato: {e}")
        order_count = "Юклаб бўлмади"

    text = f"👤 **Профил маълумотлари:**\n\n"
    text += f"👨‍💼 Исм: {profile_info.get('full_name', 'Белгиланмаган')}\n"
    text += f"📱 Телефон: {profile_info.get('phone_number', 'Белгиланмаган')}\n"
    text += f"📊 Жами буюртмалар сони: {order_count}\n"

    keyboard = [[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]]
    await edit_message_based_on_type(query, text, keyboard)

async def show_user_orders(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    data = query.data  # masalan "user_orders:1"
    _, page_str = data.split(":")
    page = int(page_str)
    user = update.effective_user
    
    # Django ORM dan foydalanuvchi buyurtmalarini olish
    orders_data = []
    try:
        customer = await sync_to_async(Customer.objects.filter(telegram_id=user.id).first)()
        if customer:
            # Ensure the queryset is evaluated in the sync context before passing to async
            all_orders_queryset = await sync_to_async(list)(Order.objects.filter(customer=customer).order_by('-created_at'))
            for order in all_orders_queryset:
                orders_data.append({
                    'order_id': order.order_number,
                    'date': order.created_at.strftime("%Y-%m-%d %H:%M"),
                    'total': float(order.total_amount),
                    'status': order.status,
                    'status_display': order.get_status_display(),
                    'service_type': order.service_type,
                    'service_type_display': order.get_service_type_display(),
                })
            logger.info(f"Foydalanuvchi {user.id} uchun {len(orders_data)} ta buyurtma topildi.")
        else:
            logger.info(f"Foydalanuvchi {user.id} uchun mijoz topilmadi, buyurtmalar yo'q.")
            await edit_message_based_on_type(
                query,
                "📋 Сизда ҳали буюртмалар мавжуд эмас.",
                [[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]]
            )
            return # Exit early if no customer
    except Exception as e:
        logger.error(f"Django ORM dan buyurtmalarni olishda xato: {e}", exc_info=True)
        await edit_message_based_on_type(query, "Буюртмаларни юклашда техник хато юз берди. Илтимос, кейинроқ уриниб кўринг.", [[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]])
        return # Exit early on error

    # Pagination logic
    items_per_page = 5 # Changed to 5 for more compact view, can be adjusted
    total_orders = len(orders_data)
    total_pages = math.ceil(total_orders / items_per_page)
    
    start_idx = (page - 1) * items_per_page
    end_idx = start_idx + items_per_page
    subset = orders_data[start_idx:end_idx]

    if not subset:
        # This case should ideally be caught by the 'if customer' block above,
        # but keeping it for robustness if pagination results in empty subset.
        await edit_message_based_on_type(
            query,
            "📋 Бу саҳифада буюртма топилмади.",
            [[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]]
        )
        return

    text = "🛍 **Сизнинг буюртмалар тарихи** (охиргилари аввал):\n\n"
    for order in subset:
        order_id = order['order_id']
        date = order['date']
        total = order['total']
        status = order['status_display']
        service_type = order['service_type_display']
        
        status_emoji = {
            "Янги": "🆕",
            "Тасдиқланган": "✅", 
            "Тайёр": "🍽",
            "Йўлда": "🚚",
            "Етказилди": "✅",
            "Олиб кетилди": "✅",
            "Бекор қилинган": "❌"
        }
        emoji = status_emoji.get(status, "📋")
        
        text += f"📋 Буюртма ID: **{order_id}**\n"
        text += f"📅 Вақт: {date}\n"
        text += f"🚀 Хизмат: {service_type}\n"
        text += f"💰 Сумма: {total:,} сўм\n"
        text += f"{emoji} Статус: **{status}**\n\n"

    # Tugmalar
    buttons = []
    nav_buttons = []
    if page > 1:
        nav_buttons.append(InlineKeyboardButton("◀️ Олдинги", callback_data=f"user_orders:{page-1}"))
    if page < total_pages:
        nav_buttons.append(InlineKeyboardButton("Кейинги ▶️", callback_data=f"user_orders:{page+1}"))
    if nav_buttons:
        buttons.append(nav_buttons)
    buttons.append([InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")])

    await edit_message_based_on_type(query, text, buttons)

# ----------------------------------------------------
# Kategoriyalar va mahsulotlar
# ----------------------------------------------------
async def show_menu_inline(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    await load_data() # Ensure latest products/categories and bot_settings are loaded

    # Get bot settings from context.bot_data
    current_bot_settings = context.bot_data.get('bot_settings')
    if not current_bot_settings:
        await edit_message_based_on_type(
            query,
            "❌ Бот созламалари юкланмади. Илтимос, кейинроқ уриниб кўринг.",
            [[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]]
        )
        return

    now = timezone.now()
    if not is_service_time_active(now, current_bot_settings.service_start_time, current_bot_settings.service_end_time):
        await edit_message_based_on_type(
            query,
            f"⏰ Узр, ҳозирда буюртмалар қабул қилмаймиз.\n"
            f"Бизнинг иш вақтимиз: {current_bot_settings.service_start_time.strftime('%H:%M')} дан {current_bot_settings.service_end_time.strftime('%H:%M')} гача.",
            [[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]]
        )
        return

    if not kategoriyalar:
        await edit_message_based_on_type(
            query,
            "📋 Ҳозирча категориялар мавжуд эмас.",
            [[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]]
        )
        return

    keyboard = []
    row = []
    for kategoriya in kategoriyalar.keys():
        row.append(InlineKeyboardButton(f"🔸 {kategoriya}", callback_data=f"category:{kategoriya}"))
        if len(row) == 2:
            keyboard.append(row)
            row = []
    if row:
        keyboard.append(row)

    navigation_buttons = [InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]
    user_savat = context.user_data.get('savat', {})
    if user_savat:
        navigation_buttons.append(InlineKeyboardButton(f"🛒 Саватга ўтиш", callback_data="show_cart"))
    keyboard.append(navigation_buttons)

    if user_savat:
        text = build_cart_message(user_savat, context) + "\n\n🍽 **Категория танланг:**"
    else:
        text = "🍽 **Категория танланг:**"

    await edit_message_based_on_type(query, text, keyboard)

async def show_category(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    category_name = query.data.split(":")[1]
    await load_data() # Ensure latest products/categories are loaded

    product_buttons = []
    row = []
    for nom in kategoriyalar.get(category_name, []):
        if nom in mahsulotlar:
            row.append(InlineKeyboardButton(f"🔸 {nom}", callback_data=f"product:{nom}"))
            if len(row) == 2:
                product_buttons.append(row)
                row = []
    if row:
        product_buttons.append(row)

    user_savat = context.user_data.get('savat', {})
    if user_savat:
        product_buttons.append([
            InlineKeyboardButton("⬅️ Орқага", callback_data="menu"),
            InlineKeyboardButton(f"🛒 Саватга ўтиш", callback_data="show_cart")
        ])
    else:
        product_buttons.append([InlineKeyboardButton("⬅️ Орқага", callback_data="menu")])

    new_text = f"🍽 **{category_name}** категориясидаги маҳсулотлар:"
    
    # Agar oldingi xabar rasmli bo'lsa, placeholder rasmni saqlash
    if query.message.photo:
        await edit_message_based_on_type(query, new_text, product_buttons, image_url=PLACEHOLDER_IMAGE_URL)
    else:
        await edit_message_based_on_type(query, new_text, product_buttons)

async def show_product(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    product_name = query.data.split(":")[1]
    product_data = mahsulotlar.get(product_name, {})

    if not product_data:
        await edit_message_based_on_type(query, "❌ Бу маҳсулот топилмади.", []) # Use edit_message_based_on_type
        return

    narx = product_data.get("narx", Decimal('0'))
    desc = product_data.get("desc", "")
    image_path = product_data.get("rasm", None) # Lokal fayl yo'li

    product_category = None
    for cat, prods in kategoriyalar.items():
        if product_name in prods:
            product_category = cat
            break

    context.user_data[product_name] = context.user_data.get(product_name, 1)

    text = f"🍽 **{product_name}**\n"
    text += f"💰 Нархи: {narx:,} сўм\n"
    if desc:
        text += f"📝 Тафсилот: {desc}\n"
    text += f"\n📊 Миқдор:"
    
    keyboard = [
        [
            InlineKeyboardButton("➖", callback_data=f"quantity:{product_name}:-1"),
            InlineKeyboardButton(f"{context.user_data[product_name]}", callback_data="noop"),
            InlineKeyboardButton("➕", callback_data=f"quantity:{product_name}:1")
        ],
        [InlineKeyboardButton("🛒 Саватга қўшиш", callback_data=f"add_to_cart:{product_name}")]
    ]

    # product_category ni topish
    product_category = None
    for cat, prods in kategoriyalar.items():
        if product_name in prods:
            product_category = cat
            break

    if product_category:
        keyboard.append([InlineKeyboardButton("⬅️ Орқага", callback_data=f"category:{product_category}")])

    if image_path: # Agar rasm yo'li mavjud bo'lsa
        try:
            with open(image_path, 'rb') as f: # Rasmni lokal tarzda ochish
                await query.edit_message_media(
                    media=InputMediaPhoto(media=f, caption=text, parse_mode='Markdown'), # Fayl obyektini yuborish
                    reply_markup=InlineKeyboardMarkup(keyboard)
                )
        except FileNotFoundError:
            logger.error(f"Image file not found at {image_path}")
            await query.answer("Расм топилмади.", show_alert=True)
            # Agar rasm topilmasa, faqat matnni yuborish
            await edit_message_based_on_type( # Corrected call
                query,
                text,
                keyboard,
                image_url=PLACEHOLDER_IMAGE_URL # Use placeholder image
            )
        except Exception as e:
            logger.error(f"Failed to edit message media with local file {image_path}: {e}")
            await query.answer("Расм юборишда хатолик юз берди. Илтимос, қайта уриниб кўринг.", show_alert=True)
            # Boshqa xatoliklarda ham faqat matnni yuborish
            await edit_message_based_on_type( # Corrected call
                query,
                text,
                keyboard,
                image_url=PLACEHOLDER_IMAGE_URL # Use placeholder image
            )
    else:
        # Agar rasm yo'li mavjud bo'lmasa, placeholder rasmni yuborish
        await edit_message_based_on_type( # Corrected call
            query,
            text,
            keyboard,
            image_url=PLACEHOLDER_IMAGE_URL # Use placeholder image
        )

async def product_go_back(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    _, category = query.data.split(":")

    try:
        await query.edit_message_reply_markup(reply_markup=None)
    except Exception as e:
        logger.error(f"Inline tugmalarni o'chirishda xatolik: {e}")

    await load_data() # Ensure latest products/categories are loaded

    if not kategoriyalar:
        await query.message.reply_text(
            "📋 Ҳозирча категориялар мавжуд эмас.",
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("⬅️ Бош меню", callback_data="main_menu")]])
        )
        return

    keyboard = []
    row = []
    for kategoriya in kategoriyalar.keys():
        row.append(InlineKeyboardButton(f"🔸 {kategoriya}", callback_data=f"category:{kategoriya}"))
        if len(row) == 2:
            keyboard.append(row)
            row = []
    if row:
        keyboard.append(row)

    navigation_buttons = [InlineKeyboardButton("⬅️ Бош меню", callback_data="main_menu")]
    user_savat = context.user_data.get('savat', {})
    if user_savat:
        navigation_buttons.append(InlineKeyboardButton(f"🛒 Саватга ўтиш", callback_data="show_cart"))
    keyboard.append(navigation_buttons)

    await query.message.reply_text(
        "🍽 **Категория танланг:**",
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode="Markdown"
    )

async def handle_quantity(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()

    try:
        _, product_name, change = query.data.split(":")
        change = int(change)
    except ValueError:
        logger.error(f"Invalid callback data format for quantity: {query.data}")
        return

    current_quantity = context.user_data.get(product_name, 1)
    new_quantity = max(1, current_quantity + change)
    context.user_data[product_name] = new_quantity

    product_data = mahsulotlar.get(product_name, {})
    narx = product_data.get("narx", Decimal('0'))
    desc = product_data.get("desc", "")
    image_path = product_data.get("rasm", None) # Lokal fayl yo'li

    text = f"🍽 **{product_name}**\n"
    text += f"💰 Нархи: {narx:,} сўм\n"
    if desc:
        text += f"📝 Тафсилот: {desc}\n"
    text += f"\n📊 Миқдор:"
    
    keyboard = [
        [
            InlineKeyboardButton("➖", callback_data=f"quantity:{product_name}:-1"),
            InlineKeyboardButton(f"{new_quantity}", callback_data="noop"),
            InlineKeyboardButton("➕", callback_data=f"quantity:{product_name}:1")
        ],
        [InlineKeyboardButton("🛒 Саватга қўшиш", callback_data=f"add_to_cart:{product_name}")]
    ]

    product_category = None
    for cat, prods in kategoriyalar.items():
        if product_name in prods:
            product_category = cat
            break

    if product_category:
        keyboard.append([InlineKeyboardButton("⬅️ Орқага", callback_data=f"category:{product_category}")])

    if image_path: # Agar rasm yo'li mavjud bo'lsa
        try:
            with open(image_path, 'rb') as f: # Rasmni lokal tarzda ochish
                await query.edit_message_media(
                    media=InputMediaPhoto(media=f, caption=text, parse_mode='Markdown'), # Fayl obyektini yuborish
                    reply_markup=InlineKeyboardMarkup(keyboard)
                )
        except FileNotFoundError:
            logger.error(f"Image file not found at {image_path}")
            await query.answer("Расм топилмади.", show_alert=True)
            # Agar rasm topilmasa, placeholder rasmni yuborish
            await edit_message_based_on_type( # Corrected call
                query,
                text,
                keyboard,
                image_url=PLACEHOLDER_IMAGE_URL # Use placeholder image
            )
        except Exception as e:
            logger.error(f"Failed to update quantity selection with local file {image_path}: {e}")
            await query.answer("Расм юборишда хатолик юз берди. Илтимос, қайта уриниб кўринг.", show_alert=True)
            # Boshqa xatoliklarda ham placeholder rasmni yuborish
            await edit_message_based_on_type( # Corrected call
                query,
                text,
                keyboard,
                image_url=PLACEHOLDER_IMAGE_URL # Use placeholder image
            )
    else:
        # Agar rasm yo'li mavjud bo'lmasa, placeholder rasmni yuborish
        await edit_message_based_on_type( # Corrected call
            query,
            text,
            keyboard,
            image_url=PLACEHOLDER_IMAGE_URL # Use placeholder image
        )

async def add_to_cart(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    product_name = query.data.split(":")[1]
    selected_quantity = context.user_data.get(product_name, 1)

    # Check service time before adding to cart
    current_bot_settings = context.bot_data.get('bot_settings')
    if current_bot_settings:
        now = timezone.now()
        if not is_service_time_active(now, current_bot_settings.service_start_time, current_bot_settings.service_end_time):
            await query.answer(
                f"❌ Ҳозирда буюртмалар қабул қилинмайди. Илтимос, иш вақтларида ҳаракат қилинг: соат {current_bot_settings.service_start_time.strftime('%H:%M')} дан {current_bot_settings.service_end_time.strftime('%H:%M')} гача.",
                show_alert=True
            )
            return

    savat = context.user_data.get('savat', {})
    savat[product_name] = savat.get(product_name, 0) + selected_quantity
    context.user_data['savat'] = savat

    product_category = None
    for cat, prods in kategoriyalar.items():
        if product_name in prods:
            product_category = cat
            break

    product_buttons = []
    row = []
    for nom in kategoriyalar.get(product_category, []):
        if nom in mahsulotlar:
            row.append(InlineKeyboardButton(f"🔸 {nom}", callback_data=f"product:{nom}"))
            if len(row) == 2:
                product_buttons.append(row)
                row = []
    if row:
        product_buttons.append(row)

    if savat:
        product_buttons.append([
            InlineKeyboardButton("⬅️ Орқага", callback_data="menu"),
            InlineKeyboardButton(f"🛒 Саватга ўтиш", callback_data="show_cart")
        ])
    else:
        product_buttons.append([InlineKeyboardButton("⬅️ Орқага", callback_data="menu")])

    new_text = f"✅ **{product_name}** саватга {selected_quantity} дона қўшилди!\n\n🍽 **{product_category}** категориясидаги маҳсулотлар:"
    
    # Agar oldingi xabar rasmli bo'lsa, placeholder rasmni saqlash
    if query.message.photo:
        await edit_message_based_on_type(query, new_text, product_buttons, image_url=PLACEHOLDER_IMAGE_URL)
    else:
        await edit_message_based_on_type(query, new_text, product_buttons)

async def view_cart_inline(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await show_cart(query, context, edit=True)

async def update_cart_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()

    try:
        _, product_name, action = query.data.split(":")
        savat = context.user_data.get('savat', {})
        if product_name in savat:
            if action == "inc":
                savat[product_name] += 1
            elif action == "dec":
                savat[product_name] -= 1
                if savat[product_name] <= 0:
                    del savat[product_name]
        context.user_data['savat'] = savat
        await show_cart(query, context, edit=True)
    except ValueError:
        logger.error(f"Invalid callback data format for update_cart: {query.data}")

async def clear_cart(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    context.user_data.pop('savat', None)

    text = "🗑 Савтингиз бўшатилди."
    keyboard = [
        [
            InlineKeyboardButton("🍽 Буюртма бериш", callback_data="menu"),
            InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")
        ]
    ]
    await edit_message_based_on_type(query, text, keyboard)

async def checkout(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    user_savat = context.user_data.get('savat', {})

    if not user_savat:
        await edit_message_based_on_type(
            query,
            "🛒 Савтингиз бўш!",
            [[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]]
        )
        return

    # Check minimum order value (15,000 som without delivery)
    total_products_price = Decimal('0')
    for product_name, qty in user_savat.items():
        narx = mahsulotlar.get(product_name, {}).get("narx", Decimal('0'))
        total_products_price += narx * qty

    if total_products_price < Decimal('15000'):
        await edit_message_based_on_type(
            query,
            f"❌ Минимал бу��ртма қиймати 15,000 сўм бўлиши керак.\n"
            f"Ҳозирги сумма: {total_products_price:,} сўм\n"
            f"Қўшимча: {Decimal('15000') - total_products_price:,} сўм керак.",
            [[InlineKeyboardButton("⬅️ Орқага", callback_data="show_cart")]]
        )
        return

    # Check service time
    current_bot_settings = context.bot_data.get('bot_settings')
    if not current_bot_settings:
        await edit_message_based_on_type(query, "❌ Бот созламалари юкланмади. Илтимос, кейинроx уриниб кўринг.", [[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]])
        return

    now = timezone.now()
    if not is_service_time_active(now, current_bot_settings.service_start_time, current_bot_settings.service_end_time):
        await edit_message_based_on_type(
            query,
            f"⏰ Узр, ҳозирда буюртмалар қабул қилмаймиз.\n"
            f"Бизнинг иш вақтимиз: {current_bot_settings.service_start_time.strftime('%H:%M')} дан {current_bot_settings.service_end_time.strftime('%H:%M')} гача.",
            [[InlineKeyboardButton("⬅️ Бош меню", callback_data="main_menu")]]
        )
        # Clear user data as order cannot be placed
        context.user_data.pop('savat', None)
        context.user_data.pop('address', None)
        context.user_data.pop('location', None)
        context.user_data.pop('payment_method', None)
        return

    if 'phone_number' not in context.user_data:
        await edit_message_based_on_type(
            query,
            "📱 Буюртма бериш учун аввал контактингизни улашинг!",
            [[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]]
        )
        await query.message.reply_text(
            "📱 Контактни улашинг:",
            reply_markup=ReplyKeyboardMarkup(
                [[KeyboardButton("📱 Контактни улашиш", request_contact=True)]],
                resize_keyboard=True
            )
        )
        return

    # Service type tanlash agar tanlanmagan bo'lsa
    if 'service_type' not in context.user_data:
        keyboard = InlineKeyboardMarkup([
            [InlineKeyboardButton("🚚 Етказиб бериш", callback_data="service_type:delivery")],
            [InlineKeyboardButton("🏪 Олиб кетиш", callback_data="service_type:pickup")]
        ])
        await edit_message_based_on_type(
            query,
            "🚀 Қайси хизматдан фойдаланмоқчисиз?",
            keyboard.inline_keyboard
        )
        return

    service_type = context.user_data.get('service_type')
    
    if service_type == 'delivery':
        await edit_message_based_on_type(
            query,
            "📍 Илтимос локациянгизни юборинг:",
            [[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]]
        )
        await query.message.reply_text(
            "📍 Локацияни юборинг:",
            reply_markup=ReplyKeyboardMarkup(
                [[KeyboardButton("📍 Локацияни улашиш", request_location=True)]],
                resize_keyboard=True
            )
        )
        context.user_data['awaiting_location'] = True
    else:
        # Pickup uchun location kerak emas, to'g'ridan-to'g'ri tasdiqlash
        keyboard = [
            [InlineKeyboardButton("✅ Тасдиқлаш", callback_data="final_confirm_order")],
            [InlineKeyboardButton("❌ Бекор қилиш", callback_data="cancel_order")]
        ]
        context.user_data['payment_method'] = 'naqd'  # default
        await edit_message_based_on_type(
            query,
            "🏪 Олиб кетиш хизмати танланди!\n💳 Тўлов усули: Нақд\n🔸 Буюртмани тасдиқлаш учун \"✅ Тасдиқлаш\" босинг:",
            keyboard
        )

# ----------------------------------------------------
# Buyurtmani tasdiqlash va Django ga yuborish (ORM orqali)
# ----------------------------------------------------
@sync_to_async
@transaction.atomic
def _create_order_and_items_sync(telegram_user_id, full_name, phone, payment_method, service_type, location, address, products_total, delivery_cost, total_amount, order_items_data, table_number=None):
    customer, created = Customer.objects.get_or_create(
        telegram_id=telegram_user_id,
        defaults={'full_name': full_name, 'phone_number': phone}
    )
    if not created:
        customer.full_name = full_name
        customer.phone_number = phone
        customer.save()

    order = Order.objects.create(
        customer=customer,
        telegram_user_id=telegram_user_id,
        status='yangi',
        payment_method=payment_method,
        service_type=service_type,
        table_number=table_number,
        latitude=location.get('latitude') if location else None,
        longitude=location.get('longitude') if location else None,
        address=address,
        products_total=products_total,
        delivery_cost=delivery_cost,
        total_amount=total_amount,
    )

    for item_data in order_items_data:
        OrderItem.objects.create(
            order=order,
            product=item_data['product'],
            quantity=item_data['quantity'],
            price=item_data['price'],
            total=item_data['quantity'] * item_data['price']
        )

    OrderStatusHistory.objects.create(
        order=order,
        old_status='',
        new_status='yangi',
        notes='Telegram bot orqali yaratildi' + (f' (Stol: #{table_number})' if table_number else '')
    )

    return order

async def final_confirm_order(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()

    # Get bot settings from context.bot_data
    current_bot_settings = context.bot_data.get('bot_settings')
    if not current_bot_settings:
        await edit_message_based_on_type(query, "❌ Бот созламалари юкланмади. Илтимос, кейинроқ уриниб кўринг.", [[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]])
        return

    # Check service time again before final confirmation
    now = timezone.now()
    if not is_service_time_active(now, current_bot_settings.service_start_time, current_bot_settings.service_end_time):
        await edit_message_based_on_type(
            query,
            f"⏰ Узр, ҳозирда буюртмалар қабул қилмаймиз.\n"
            f"Бизнинг иш вақтимиз: {current_bot_settings.service_start_time.strftime('%H:%M')} дан {current_bot_settings.service_end_time.strftime('%H:%M')} гача.",
            [[InlineKeyboardButton("⬅️ Бош меню", callback_data="main_menu")]]
        )
        # Clear user data as order cannot be placed
        context.user_data.pop('savat', None)
        context.user_data.pop('address', None)
        context.user_data.pop('location', None)
        context.user_data.pop('payment_method', None)
        return

    service_type = context.user_data.get('service_type', 'delivery')
    
    # Agar delivery bo'lsa va masofa > maksimal radius bo'lsa, rad etamiz
    if service_type == 'delivery' and context.user_data.get('delivery_possible') is False:
        await edit_message_based_on_type(
            query,
            f"😔 Узр, сизнинг ҳудудингизга етказиб бериш хизмати мавжуд эмас (максимал {bot_settings.delivery_max_radius_km} км)."
            "🍽 Меню орқали танишиб кўришингиз мумкин.",
            [[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]]
        )
        return

    user = update.effective_user
    phone = context.user_data.get('phone_number', 'Номаълум')
    full_name = context.user_data.get('full_name', 'Номаълум')
    telegram_user_id = context.user_data.get('telegram_user_id', user.id)
    location = context.user_data.get('location', {}) if service_type == 'delivery' else None
    address = context.user_data.get('address', None) if service_type == 'delivery' else None
    payment_method = context.user_data.get('payment_method', 'naqd')
    user_savat = context.user_data.get('savat', {})

    if not user_savat:
        await edit_message_based_on_type(
            query,
            "🛒 Савтингиз бўш!",
            [[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]]
        )
        return

    delivery_cost = context.user_data.get('delivery_cost', Decimal('0')) if service_type == 'delivery' else Decimal('0')
    total_products_price = Decimal('0')
    order_items_data = []

    for product_name, qty in user_savat.items():
        product_obj = await sync_to_async(Product.objects.filter(name=product_name).first)()
        if product_obj:
            item_price = product_obj.price  # Keep as Decimal
            total_products_price += item_price * qty
            order_items_data.append({
                'product': product_obj,
                'quantity': qty,
                'price': item_price,
                'product_name': product_name, # Add product_name for easier text generation
                'total': item_price * qty # Add total for easier text generation
            })
        else:
            logger.warning(f"Mahsulot topilmadi: {product_name}")
            await edit_message_based_on_type(query, f"❌ Буюртма юборишда хато: '{product_name}' маҳсулоти топилмади.", [[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]])
            return

    total_amount = total_products_price + delivery_cost

    try:
        order = await _create_order_and_items_sync(
            telegram_user_id, full_name, phone, payment_method, service_type, location, address,
            total_products_price, delivery_cost, total_amount, order_items_data
        )
        
        # Telegram xabarlarini yuborish va message_id'larni saqlash
        chef_text = f"🍽 **Янги буюртма #{order.order_number}**\n\n"
        chef_text += f"👨‍💼 Исм: {full_name}\n"
        chef_text += f"📱 Телефон: {phone}\n"
        chef_text += f"💳 Тўлов усули: {order.get_payment_method_display()}\n"
        chef_text += f"🚀 Хизмат тури: {order.get_service_type_display()}\n"
        
        if service_type == 'delivery':
            if order.address:
                chef_text += f"🏠 Манзил: {order.address}\n"
            else:
                chef_text += "📍 Манзил: Фақат локация\n"
        else:
            chef_text += "🏪 Олиб кетиш учун: Ресторандан\n"
            
        chef_text += f"\n🍽 **Маҳсулотлар:**\n"
        for item in order_items_data: # Iterate directly over the prepared list
            chef_text += f"• {item['quantity']} дона {item['product_name']} - {item['total']:,} сўм\n"
        chef_text += f"\n💰 Жами: {order.total_amount:,} сўм"

        keyboard_chef = [
            [
                {'text': "✅ Тасдиқлаш", 'callback_data': f"chef_confirm:{order.id}"},
                {'text': "❌ Бекор қилиш", 'callback_data': f"chef_cancel:{order.id}"}
            ]
        ]
        
        chef_msg_response = send_telegram_message(
            chat_id=settings.CHEF_CHAT_ID, 
            text=chef_text, 
            reply_markup={'inline_keyboard': keyboard_chef}
        )
        if chef_msg_response and chef_msg_response.get('ok'):
            order.chef_message_id = chef_msg_response['result']['message_id']
        
        # Lokatsiya yuborish faqat delivery uchun
        if service_type == 'delivery' and order.latitude and order.longitude:
            send_telegram_location(
                chat_id=settings.CHEF_CHAT_ID,
                latitude=order.latitude,
                longitude=order.longitude
            )

        # Foydalanuvchiga xabar
        user_text = f"✅ **Буюртмангиз қабул қилинди!**\n\n"
        user_text += f"📋 Буюртма ID: **{order.order_number}**\n"
        user_text += f"👨‍💼 Исм: {full_name}\n"
        user_text += f"📱 Телефон: {phone}\n"
        user_text += f"💳 Тўлов усули: {order.get_payment_method_display()}\n"
        user_text += f"🚀 Хизмат тури: {order.get_service_type_display()}\n"
        
        if service_type == 'delivery':
            if order.address:
                user_text += f"🏠 Манзил: {order.address}\n"
            else:
                user_text += "📍 Манзил: Фақат локация\n"
            if order.latitude and order.longitude:
                user_text += f"📍 Локация: https://www.google.com/maps?q={order.latitude},{order.longitude}\n"
        else:
            user_text += "🏪 Олиб кетиш учун: Ресторандан\n"
            
        user_text += f"\n🍽 **Маҳсулотлар:**\n"
        for item in order_items_data: # Iterate directly over the prepared list
            user_text += f"• {item['quantity']} дона {item['product_name']} - {item['total']:,} сўм\n"
        user_text += f"\n💰 Жами: {order.total_amount:,} сўм\n🆕 Статус: **Янги**"

        user_keyboard = [[{'text': "⬅️ Бош меню", 'callback_data': "main_menu"}]]
        user_msg_response = send_telegram_message(
            chat_id=telegram_user_id,
            text=user_text,
            reply_markup={'inline_keyboard': user_keyboard}
        )
        if user_msg_response and user_msg_response.get('ok'):
            order.user_message_id = user_msg_response['result']['message_id']
            
        await sync_to_async(order.save)() # Save message IDs

        await edit_message_based_on_type(query, f"✅ Буюртмангиз #{order.order_number} қабул қилинди!", main_inline_menu(context).inline_keyboard)

    except Exception as e:
        logger.error(f"Buyurtma yaratishda xato: {e}", exc_info=True)
        await edit_message_based_on_type(query, f"❌ Буюртма юборишda xato: {str(e)}", [[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]])

    # Clear user data after successful submission
    context.user_data.pop('savat', None)
    context.user_data.pop('address', None)
    context.user_data.pop('location', None)
    context.user_data.pop('payment_method', None)

async def cancel_order(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    context.user_data.pop('savat', None)
    if 'address' in context.user_data:
        del context.user_data['address']
    if 'location' in context.user_data:
        del context.user_data['location']
    if 'payment_method' in context.user_data:
        del context.user_data['payment_method']

    await edit_message_based_on_type(query, "❌ Буюртма бекор қилинди.", main_inline_menu(context).inline_keyboard)

# ----------------------------------------------------
# Oshpaz va Kuryer paneli callbacklari (ORM orqali)
# ----------------------------------------------------
@sync_to_async
@transaction.atomic
def _update_order_status_sync(order_id, new_status, old_status):
    logger.info(f"Attempting to update order {order_id} status from {old_status} to {new_status}")
    order = Order.objects.get(id=order_id)
    order.status = new_status
    
    if new_status == 'tasdiqlangan':
        order.confirmed_at = timezone.now()
    elif new_status == 'tayor':
        order.ready_at = timezone.now()
    elif new_status == 'yetkazildi':
        order.delivered_at = timezone.now()
    elif new_status == 'olib_ketildi':
        order.picked_up_at = timezone.now()
    
    order.save()
    logger.info(f"Order {order_id} status successfully updated to {order.status} in DB.")
    
    OrderStatusHistory.objects.create(
        order=order,
        old_status=old_status,
        new_status=new_status,
        changed_by=None, # Bot orqali o'zgargani uchun user None
        notes=f'Telegram bot orqali yangilandi'
    )
    logger.info(f"Order status history created for order {order_id}: {old_status} -> {new_status}")
    return order

async def handle_chef_courier_status_update(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    
    try:
        action, order_id = query.data.split(":")
        logger.info(f"Callback received: action={action}, order_id={order_id}")
        
        # Fetch order to get old_status before passing to sync function
        order_obj_for_status_check = await sync_to_async(Order.objects.get)(id=int(order_id))
        old_status = order_obj_for_status_check.status
        service_type = order_obj_for_status_check.service_type
        logger.info(f"Order {order_id} current status: {old_status}, service_type: {service_type}")

        status_map = {
            "chef_confirm": "tasdiqlangan",
            "chef_ready": "tayor",
            "chef_cancel": "bekor_qilingan",
            "chef_picked_up": "olib_ketildi",
            "chef_served": "yetkazildi",
            "courier_on_way": "yolda",
            "courier_delivered": "yetkazildi",
            "courier_cancel": "bekor_qilingan",
        }

        new_status = status_map.get(action)
        logger.info(f"Mapped new status: {new_status}")

        if not new_status:
            await edit_message_based_on_type(query, "❌ Номаълум ҳолат ўзгариши.", [])
            logger.warning(f"Unknown status change action: {action}")
            return

        if old_status == new_status:
            await edit_message_based_on_type(query, f"ℹ️ Буюртма ҳолати аллақачон '{new_status}'.", [])
            return

        # Valid transitions for different service types
        if service_type == 'pickup':
            valid_transitions = {
                'yangi': ['tasdiqlangan', 'tayor', 'bekor_qilingan'],
                'tasdiqlangan': ['tayor', 'bekor_qilingan'],
                'tayor': ['olib_ketildi', 'bekor_qilingan'],
            }
        elif service_type == 'dine_in':
            valid_transitions = {
                'yangi': ['tasdiqlangan', 'tayor', 'yetkazildi', 'bekor_qilingan'],
                'tasdiqlangan': ['tayor', 'yetkazildi', 'bekor_qilingan'],
                'tayor': ['yetkazildi', 'olib_ketildi', 'bekor_qilingan'],
                'yetkazildi': [],
            }
        else:  # delivery
            valid_transitions = {
                'yangi': ['tasdiqlangan', 'tayor', 'bekor_qilingan'],
                'tasdiqlangan': ['tayor', 'bekor_qilingan'],
                'tayor': ['yolda', 'yetkazildi', 'bekor_qilingan'],
                'yolda': ['yetkazildi', 'bekor_qilingan'],
            }

        if new_status not in valid_transitions.get(old_status, []):
            await edit_message_based_on_type(query, f"Ҳолат {old_status} дан {new_status} га ўзгартиришга рухсат берилмаган.", [])
            logger.warning(f"Invalid transition for order {order_id}: {old_status} -> {new_status} (service_type: {service_type})")
            return

        updated_order = await _update_order_status_sync(int(order_id), new_status, old_status)
        logger.info(f"Order {order_id} status updated to {updated_order.status}. Now updating Telegram messages.")
            
        await _update_telegram_messages(updated_order, old_status, new_status) # Pass the updated order object
        logger.info(f"Telegram messages updated for order {order_id}.")
        
    except Order.DoesNotExist:
        logger.error(f"Order with ID {order_id} not found.", exc_info=True)
        await edit_message_based_on_type(query, "❌ Буюртма топилмади.", [])
    except Exception as e:
        logger.error(f"Status update error for order {order_id}: {e}", exc_info=True)
        await edit_message_based_on_type(query, f"❌ Хато: {str(e)}", [])

# ----------------------------------------------------
# Fikr bildirish
# ----------------------------------------------------
async def feedback_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    context.user_data["awaiting_feedback"] = True
    await query.message.reply_text(
        "✍️ Фикрингизни ёзинг. Бекор қилиш учун /cancel ни ёзинг."
    )


# ====================================================
# OFITSIANT (WAITER) - ENDI FAQAT MOBIL ILOVADA ISHLAYDI
# ====================================================

async def waiter_panel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Ofitsiantlarga ilovaga o'tish haqida xabar"""
    text = (
        "📱 *DILKASH RESTORAN — XODIMLAR MOBIL ILOVASI*\n\n"
        "Hurmatli ofitsiant!\n"
        "Endi restoran stollari, yangi buyurtmalar va chaqiruvlar bilan ishlash "
        "Telegram orqali emas, balki to'liq *Dilkash Staff* mobil ilovasida amalga oshiriladi.\n\n"
        "🔑 *Qanday kiriladi?*\n"
        "1. Kassir sizga bergan login va parolni oling;\n"
        "2. Mobil ilovada *'Ofitsiant'* rolini tanlang;\n"
        "3. Login va parolni kiritib, barcha stollarni jonli boshqaring!"
    )
    keyboard = [[InlineKeyboardButton("🏠 Asosiy mijoz menyusi", callback_data="main_menu")]]
    if update.callback_query:
        query = update.callback_query
        await query.answer()
        await edit_message_based_on_type(query, text, keyboard, force_text=True)
    elif update.message:
        await update.message.reply_text(
            text,
            reply_markup=InlineKeyboardMarkup(keyboard),
            parse_mode="Markdown"
        )


async def handle_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if text in ["🚚 Yetkazib berish", "Yetkazib berish", "yetkazib berish"]:
        context.user_data['service_type'] = 'delivery'
        await update.message.reply_text(
            "🚚 **Yetkazib berish xizmati tanlandi.**\n\nIltimos, yetkazib berish manzilini aniqlash uchun lokatsiyangizni jo'nating:",
            reply_markup=ReplyKeyboardMarkup([
                [KeyboardButton("📍 Lokatsiyani yuborish", request_location=True)],
                [KeyboardButton("⬅️ Bosh menu")]
            ], resize_keyboard=True)
        )
        return

    if text in ["🏪 Olib ketish", "Olib ketish", "olib ketish"]:
        context.user_data['service_type'] = 'pickup'
        await update.message.reply_text(
            "🏪 **Olib ketish (Samovivoz) xizmati tanlandi.**\n\nBuyurtmani restoranimizdan olib ketishingiz mumkin. Taomlarni tanlang:",
            reply_markup=main_inline_menu(context)
        )
        return

    if text in ["🛒 Savat", "Savat", "savat"]:
        await show_cart(update, context)
        return

    if text in ["🤵 Ofitsiant Paneli", "Ofitsiant", "ofitsiant", "waiter", "/waiter", "/ofitsiant", "🤵 Ofitsiant"]:
        await waiter_panel(update, context)
        return


    if text in ["🍽 Bot Menyusi", "🍽 Bot menyusi", "Menyu", "menyu"]:
        await update.message.reply_text("🍽 Nimani buyurtma qilmoqchisiz?", reply_markup=main_inline_menu(context))
        return

    if text in ["👤 Profil", "👤 Профил", "Profil", "profil"]:
        await show_profile(update, context)
        return

    if context.user_data.get('awaiting_address'):
        await handle_address(update, context)
        return

    if context.user_data.get("awaiting_feedback"):
        context.user_data["awaiting_feedback"] = False
        user = update.effective_user
        phone = context.user_data.get('phone_number', "Номаълум")
        full_name = context.user_data.get('full_name', user.full_name)

        admin_msg = (
            f"💬 **Янги фикр келиб тушди!**\n\n"
            f"👨‍💼 Муаллиф: {full_name}\n"
            f"📱 Тел: {phone}\n"
            f"🆔 User ID: {user.id}\n\n"
            f"📝 **Фикр матни:**\n{text}"
        )
        
        try:
            # Use settings.ADMIN_CHAT_ID from Django settings
            await context.bot.send_message(chat_id=settings.ADMIN_CHAT_ID, text=admin_msg, parse_mode="Markdown")
        except Exception as e:
            logger.error(f"Failed to send feedback to admin: {e}")
            
        await update.message.reply_text(
            "✅ Фикрингиз учун раҳмат! Тез орада кўриб чиқамиз.",
            reply_markup=main_inline_menu(context)
        )
        return

    await update.message.reply_text("📨 Хабарингиз қабул қилинди.")

# ----------------------------------------------------
# Xatolarni boshqarish
# ----------------------------------------------------
async def error_handler(update: object, context: ContextTypes.DEFAULT_TYPE) -> None:
    logger.error(msg="Exception while handling an update:", exc_info=context.error)
    if isinstance(update, Update) and update.effective_user:
        try:
            await context.bot.send_message(
                chat_id=update.effective_user.id,
                text="❌ Хатолик юз берди. Илтимос, кейinroq qayta urinib ko'ring."
            )
        except Exception as e:
            logger.error(f"Failed to send error message to user: {e}")

async def post_init(application):
    await load_data()
    # Store bot_settings in application.bot_data for easy access in handlers
    application.bot_data['bot_settings'] = bot_settings # Use the global bot_settings loaded by load_data

# ----------------------------------------------------
# Botni ishga tushirish
# ----------------------------------------------------
def main():
    application = ApplicationBuilder().token(settings.TELEGRAM_BOT_TOKEN).post_init(post_init).build()

    # Asosiy komandalar
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("waiter", waiter_panel))
    application.add_handler(CommandHandler("ofitsiant", waiter_panel))

    # Xabarlar
    application.add_handler(MessageHandler(filters.CONTACT, handle_contact))
    application.add_handler(MessageHandler(filters.LOCATION, handle_location))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))

    # Service type selection
    application.add_handler(CallbackQueryHandler(handle_service_type, pattern="^service_type:"))

    # Oshpaz va Kuryer callbacklari (Django ORM orqali)
    application.add_handler(CallbackQueryHandler(handle_chef_courier_status_update, pattern="^chef_confirm:"))
    application.add_handler(CallbackQueryHandler(handle_chef_courier_status_update, pattern="^chef_ready:"))
    application.add_handler(CallbackQueryHandler(handle_chef_courier_status_update, pattern="^chef_cancel:"))
    application.add_handler(CallbackQueryHandler(handle_chef_courier_status_update, pattern="^chef_picked_up:"))
    application.add_handler(CallbackQueryHandler(handle_chef_courier_status_update, pattern="^chef_served:"))
    application.add_handler(CallbackQueryHandler(handle_chef_courier_status_update, pattern="^courier_on_way:"))
    application.add_handler(CallbackQueryHandler(handle_chef_courier_status_update, pattern="^courier_delivered:"))
    application.add_handler(CallbackQueryHandler(handle_chef_courier_status_update, pattern="^courier_cancel:"))

    # Asosiy callbacklar
    application.add_handler(CallbackQueryHandler(main_menu, pattern="^main_menu$"))
    application.add_handler(CallbackQueryHandler(show_menu_inline, pattern="^menu$"))
    application.add_handler(CallbackQueryHandler(show_category, pattern="^category:"))
    application.add_handler(CallbackQueryHandler(show_product, pattern="^product:"))
    application.add_handler(CallbackQueryHandler(handle_quantity, pattern="^quantity:"))
    application.add_handler(CallbackQueryHandler(add_to_cart, pattern="^add_to_cart:"))
    application.add_handler(CallbackQueryHandler(view_cart_inline, pattern="^show_cart$"))
    application.add_handler(CallbackQueryHandler(clear_cart, pattern="^clear_cart$"))
    application.add_handler(CallbackQueryHandler(update_cart_handler, pattern="^update_cart:"))
    application.add_handler(CallbackQueryHandler(checkout, pattern="^checkout$"))
    application.add_handler(CallbackQueryHandler(final_confirm_order, pattern="^final_confirm_order$"))
    application.add_handler(CallbackQueryHandler(cancel_order, pattern="^cancel_order$"))
    application.add_handler(CallbackQueryHandler(feedback_callback, pattern="^feedback$"))
    application.add_handler(CallbackQueryHandler(show_profile, pattern="^profile$"))
    application.add_handler(CallbackQueryHandler(product_go_back, pattern="^product_go_back:"))

    # Sahifalash
    application.add_handler(CallbackQueryHandler(show_user_orders, pattern="^user_orders:"))

    # Promo-kod
    application.add_handler(CallbackQueryHandler(
        lambda u, c: u.answer("🎟 Промо-код функцияси ҳали жорий этилмаган", show_alert=True),
        pattern="^promo_not_implemented$")
    )

    # Ofitsiant (Waiter) - endi to'liq Flutter mobil ilovasida
    application.add_handler(CallbackQueryHandler(waiter_panel, pattern="^waiter_"))

    application.add_error_handler(error_handler)
    
    print("🤖 Бот ишга тушмоқда...")
    print(f"Bot Token: {settings.TELEGRAM_BOT_TOKEN[:5]}...") # Print partial token for security
    print(f"Chef Chat ID: {settings.CHEF_CHAT_ID}")
    print(f"Admin Chat ID: {settings.ADMIN_CHAT_ID}")
    
    # Call load_data as an async function before starting polling
    application.run_polling()

if __name__ == '__main__':
    main()
