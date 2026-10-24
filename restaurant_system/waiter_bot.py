#!/usr/bin/env python3
"""
Dilkash Restaurant - Maxsus Ofitsiant Telegram Boti (2026/2027)
Ushbu bot faqat ofitsiantlar uchun mo'ljallangan bo'lib:
1. Stollar xaritasi va jonli holati (🟢 Bo'sh, 🟡 Band, 🔵 Oshxonada tayyor, 🔴 Mijoz chaqiruvi).
2. Stol buyurtmalarini tezkor kiritish va oshxonaga uzatish.
3. Mijozlar stoldan ofitsiant chaqirganda tezkor push-xabar va [✅ Boraman] tugmasi.
4. Oshpaz taomni tayyorlaganda [🍽️ Stolga yetkazdim] tezkor tugmasi.
5. Stol hisob-kitobini yopish (Naqd / Karta) va chek ko'rish.
6. 📱 Ofitsiant POS Web App (Handheld WebApp) integratsiyasi.
"""

import os
import sys
import logging
import asyncio
from decimal import Decimal
from datetime import datetime

# Django muhitini yuklash
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'restaurant_system.settings')

import django
django.setup()

from django.conf import settings
from django.utils import timezone
from asgiref.sync import sync_to_async

from chef_panel.models import (
    Order, OrderItem, Product, Category, Customer,
    RestaurantTable, WaiterCall, WaiterProfile, OrderStatusHistory
)
from chef_panel.utils import send_telegram_message

from telegram import (
    Update, InlineKeyboardButton, InlineKeyboardMarkup,
    ReplyKeyboardMarkup, KeyboardButton, WebAppInfo
)
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler,
    MessageHandler, ContextTypes, filters
)

logging.basicConfig(
    format='%(asctime)s - [WAITER_BOT] - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Tokenni aniqlash (Birinchi navbatda WAITER_BOT_TOKEN, bo'lmasa TELEGRAM_BOT_TOKEN)
WAITER_BOT_TOKEN = os.getenv('WAITER_BOT_TOKEN', '').strip()
if not WAITER_BOT_TOKEN:
    WAITER_BOT_TOKEN = getattr(settings, 'TELEGRAM_BOT_TOKEN', '').strip()


def get_waiter_webapp_url(table_num=None):
    """Ofitsiant WebApp havolasi"""
    base_url = os.getenv('WEB_APP_URL', getattr(settings, 'WEB_APP_URL', ''))
    if 'trycloudflare.com' in base_url or 'ngrok' in base_url or base_url.startswith('https://'):
        clean_base = base_url.replace('/menu/', '').rstrip('/')
        url = f"{clean_base}/waiter/"
    else:
        url = "http://127.0.0.1:8000/waiter/"
    
    if table_num:
        url += f"?table={table_num}"
    return url


def get_main_reply_keyboard():
    """Ofitsiant asosiy doimiy klaviaturasi"""
    webapp_url = get_waiter_webapp_url()
    is_https = webapp_url.startswith('https://')

    kb = []
    if is_https:
        kb.append([KeyboardButton("📱 Ofitsiant POS WebApp", web_app=WebAppInfo(url=webapp_url))])

    kb.append([KeyboardButton("🪑 Stollar Xaritasi"), KeyboardButton("🔔 Chaqiruvlar")])
    kb.append([KeyboardButton("🍽️ Tayyor Taomlar"), KeyboardButton("🧾 Hisob-kitob")])
    kb.append([KeyboardButton("📊 Bugungi Smena"), KeyboardButton("🔄 Yangilash")])

    return ReplyKeyboardMarkup(kb, resize_keyboard=True)


async def register_or_update_waiter(user):
    """Ofitsiantni ma'lumotlar bazasida ro'yxatdan o'tkazish/yangilash"""
    name = user.first_name + (f" {user.last_name}" if user.last_name else "")
    profile, created = await sync_to_async(WaiterProfile.objects.update_or_create)(
        telegram_id=user.id,
        defaults={
            'name': name,
            'is_active': True
        }
    )
    return profile


# ==========================================
# KOMANDALAR VA ASOSIY MENULAR
# ==========================================

async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Ofitsiant boti /start komandasi"""
    user = update.effective_user
    profile = await register_or_update_waiter(user)

    webapp_url = get_waiter_webapp_url()
    is_https = webapp_url.startswith('https://')

    welcome_text = (
        f"👋 **Assalomu alaykum, {profile.name}!**\n\n"
        f"🤵 **Dilkash Restaurant — Ofitsiant Xizmat Boti (2026/2027)**\n\n"
        f"Siz tizimda faol ofitsiant sifatida tizimga ulandingiz.\n"
        f"Mijoz chaqiruvlari, oshxona tayyorlagan taomlar va buyurtma hisob-kitoblari "
        f"to'g'ridan-to'g'ri ushbu botga keladi.\n\n"
        f"Quyidagi menyu orqali kerakli bo'limni tanlang 👇"
    )

    inline_kb = []
    if is_https:
        inline_kb.append([
            InlineKeyboardButton("🚀 Ofitsiant POS WebApp (Tezkor)", web_app=WebAppInfo(url=webapp_url))
        ])
    inline_kb.append([
        InlineKeyboardButton("🪑 Stollar xaritasini ko'rish", callback_data="waiter_tables_grid"),
        InlineKeyboardButton("🔔 Chaqiruvlar", callback_data="waiter_calls_list")
    ])

    await update.message.reply_text(
        welcome_text,
        reply_markup=get_main_reply_keyboard(),
        parse_mode="Markdown"
    )
    await update.message.reply_text(
        "⚡️ **Tezkor Harakatlar:**",
        reply_markup=InlineKeyboardMarkup(inline_kb),
        parse_mode="Markdown"
    )


async def show_tables_grid(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Stollar xaritasini jonli ko'rsatish"""
    tables = await sync_to_async(list)(RestaurantTable.objects.filter(is_active=True).order_by('number'))
    active_orders = await sync_to_async(list)(
        Order.objects.filter(
            service_type='dine_in',
            status__in=['yangi', 'tasdiqlangan', 'tayor']
        ).select_related('customer')
    )
    calling_tables = await sync_to_async(list)(
        WaiterCall.objects.filter(is_resolved=False).values_list('table_number', flat=True)
    )

    orders_by_table = {str(o.table_number): o for o in active_orders if o.table_number}
    calls_set = set(str(c) for c in calling_tables)

    total_count = len(tables) if tables else 12
    occupied_count = len(orders_by_table)
    free_count = max(0, total_count - occupied_count)
    calls_count = len(calls_set)

    text = (
        f"🪑 **RESTORAN STOLLARI XARITASI**\n\n"
        f"📊 **Statistika:**\n"
        f"🟢 Bo'sh: {free_count} ta  |  🟡 Band: {occupied_count} ta  |  🔴 Chaqiruv: {calls_count} ta\n\n"
        f"Kerakli stol ustiga bosing 👇"
    )

    keyboard = []
    row = []

    table_numbers = [str(t.number) for t in tables] if tables else [str(i) for i in range(1, 13)]

    for num in table_numbers:
        is_calling = num in calls_set
        order = orders_by_table.get(num)

        if is_calling:
            icon = "🔴"
            label = f"{icon} #{num} Chaqiruv!"
        elif order:
            if order.status == 'tayor':
                icon = "🔵"
                label = f"{icon} #{num} Tayyor!"
            else:
                icon = "🟡"
                amount_k = int(order.total_amount // 1000)
                label = f"{icon} #{num} ({amount_k}k)"
        else:
            icon = "🟢"
            label = f"{icon} Stol #{num}"

        row.append(InlineKeyboardButton(label, callback_data=f"waiter_table:{num}"))
        if len(row) == 2:
            keyboard.append(row)
            row = []

    if row:
        keyboard.append(row)

    keyboard.append([
        InlineKeyboardButton("🔄 Yangilash", callback_data="waiter_tables_grid"),
        InlineKeyboardButton("🔔 Chaqiruvlar ro'yxati", callback_data="waiter_calls_list")
    ])

    if update.callback_query:
        await update.callback_query.answer()
        try:
            await update.callback_query.edit_message_text(
                text,
                reply_markup=InlineKeyboardMarkup(keyboard),
                parse_mode="Markdown"
            )
        except Exception:
            await update.callback_query.message.reply_text(
                text,
                reply_markup=InlineKeyboardMarkup(keyboard),
                parse_mode="Markdown"
            )
    else:
        await update.message.reply_text(
            text,
            reply_markup=InlineKeyboardMarkup(keyboard),
            parse_mode="Markdown"
        )


async def table_detail_view(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Tanlangan stol tafsilotlari va harakatlar"""
    query = update.callback_query
    await query.answer()

    table_num = query.data.split(":", 1)[1]
    context.user_data['active_table'] = table_num

    # Stol holatini aniqlash
    active_order = await sync_to_async(
        Order.objects.filter(
            service_type='dine_in',
            table_number=str(table_num),
            status__in=['yangi', 'tasdiqlangan', 'tayor']
        ).prefetch_related('items__product').first
    )()

    active_call = await sync_to_async(
        WaiterCall.objects.filter(table_number=str(table_num), is_resolved=False).first
    )()

    webapp_url = get_waiter_webapp_url(table_num)
    is_https = webapp_url.startswith('https://')

    keyboard = []

    if active_call:
        status_header = f"🔴 **DIQQAT! STOL #{table_num} OFITSIANTNI CHAQIRMOQDA!**\nSabab: {active_call.reason}\nVaqt: {active_call.created_at.strftime('%H:%M')}\n"
        keyboard.append([
            InlineKeyboardButton("✅ Boraman / Chaqiruvni qabul qildim", callback_data=f"waiter_call_dismiss:{table_num}")
        ])
    elif active_order:
        status_display = {
            'yangi': '🆕 Yangi buyurtma',
            'tasdiqlangan': '👨‍🍳 Oshxonada tayyorlanmoqda',
            'tayor': '🔵 TAYYOR (Stolga yetkazing!)'
        }.get(active_order.status, active_order.status)

        status_header = (
            f"🟡 **STOL #{table_num} — BAND**\n\n"
            f"📋 Buyurtma raqami: **#{active_order.order_number}**\n"
            f"Holati: **{status_display}**\n"
            f"Vaqt: {active_order.created_at.strftime('%H:%M')}\n\n"
            f"🍽 **Taomlar:**\n"
        )
        items = await sync_to_async(list)(active_order.items.all())
        for it in items:
            status_header += f"• {it.quantity} x {it.product.name} — {it.total:,} so'm\n"
        status_header += f"\n💰 **Jami:** {active_order.total_amount:,} so'm\n"

        if active_order.status == 'tayor':
            keyboard.append([
                InlineKeyboardButton("🍽️ Stolga yetkazildi (Tayyor)", callback_data=f"waiter_served_order:{active_order.id}")
            ])

        keyboard.append([
            InlineKeyboardButton("➕ Taom qo'shish", callback_data=f"waiter_punch_start:{table_num}"),
            InlineKeyboardButton("🧾 Chekni ko'rish", callback_data=f"waiter_view_bill:{active_order.id}")
        ])
        keyboard.append([
            InlineKeyboardButton("🔔 Kassirga hisob so'rovi yuborish", callback_data=f"waiter_request_cashier:{table_num}")
        ])
    else:
        status_header = (
            f"🟢 **STOL #{table_num} — BO'SH**\n\n"
            f"Mehmonlar kelganda darhol yangi buyurtma kiritishingiz mumkin."
        )
        keyboard.append([
            InlineKeyboardButton("📝 Yangi buyurtma olish", callback_data=f"waiter_punch_start:{table_num}")
        ])


    if is_https:
        keyboard.append([
            InlineKeyboardButton(f"🚀 Stol #{table_num} POS WebApp", web_app=WebAppInfo(url=webapp_url))
        ])

    keyboard.append([
        InlineKeyboardButton("⬅️ Barcha stollar", callback_data="waiter_tables_grid")
    ])

    await query.edit_message_text(
        status_header,
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode="Markdown"
    )


# ==========================================
# CHAQIRUVLARNI BOSHQARISH
# ==========================================

async def show_calls_list(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Mijozlar chaqiruvlari ro'yxati"""
    calls = await sync_to_async(list)(
        WaiterCall.objects.filter(is_resolved=False).order_by('-created_at')[:10]
    )

    if not calls:
        text = "🔔 **Faol chaqiruvlar mavjud emas!**\n\nBarcha mijozlarga xizmat ko'rsatilgan. 🟢"
        keyboard = [
            [InlineKeyboardButton("🪑 Stollar xaritasi", callback_data="waiter_tables_grid")],
            [InlineKeyboardButton("🔄 Yangilash", callback_data="waiter_calls_list")]
        ]
    else:
        text = f"🔔 **FAOL CHAQIRUVLAR ({len(calls)} ta):**\n\n"
        keyboard = []
        for c in calls:
            text += f"🔴 **Stol #{c.table_number}**: {c.reason} ({c.created_at.strftime('%H:%M')})\n"
            keyboard.append([
                InlineKeyboardButton(f"✅ Boraman (Stol #{c.table_number})", callback_data=f"waiter_call_dismiss:{c.table_number}")
            ])
        keyboard.append([
            InlineKeyboardButton("🔄 Yangilash", callback_data="waiter_calls_list"),
            InlineKeyboardButton("🪑 Stollar xaritasi", callback_data="waiter_tables_grid")
        ])

    if update.callback_query:
        await update.callback_query.answer()
        await update.callback_query.edit_message_text(
            text,
            reply_markup=InlineKeyboardMarkup(keyboard),
            parse_mode="Markdown"
        )
    else:
        await update.message.reply_text(
            text,
            reply_markup=InlineKeyboardMarkup(keyboard),
            parse_mode="Markdown"
        )


async def dismiss_call_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Chaqiruvni qabul qilish va yopish"""
    query = update.callback_query
    table_num = query.data.split(":", 1)[1]

    calls = await sync_to_async(list)(WaiterCall.objects.filter(table_number=str(table_num), is_resolved=False))
    for c in calls:
        c.is_resolved = True
        c.resolved_at = timezone.now()
        await sync_to_async(c.save)()

    await query.answer(f"✅ Stol #{table_num} chaqiruvi qabul qilindi!", show_alert=True)
    await table_detail_view(update, context)


# ==========================================
# OSHXONA TAYYOR TAOMLARI
# ==========================================

async def show_ready_orders(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Oshxonada tayyor bo'lgan buyurtmalar"""
    orders = await sync_to_async(list)(
        Order.objects.filter(
            service_type='dine_in',
            status='tayor'
        ).prefetch_related('items__product').order_by('-ready_at')
    )

    if not orders:
        text = "🍽️ **Hozirda oshxonada tayyor bo'lgan taomlar yo'q.**\nBarcha taomlar stolga yetkazilgan. 🟢"
        keyboard = [
            [InlineKeyboardButton("🪑 Stollar xaritasi", callback_data="waiter_tables_grid")],
            [InlineKeyboardButton("🔄 Yangilash", callback_data="waiter_ready_orders")]
        ]
    else:
        text = f"🍽️ **OSHXONADA TAYYOR BO'LGAN TAOMLAR ({len(orders)} ta):**\n\n"
        keyboard = []
        for o in orders:
            text += f"🔵 **Stol #{o.table_number}** (Buyurtma #{o.order_number}):\n"
            for it in o.items.all():
                text += f"• {it.quantity} x {it.product.name}\n"
            text += f"💰 Jami: {o.total_amount:,} so'm\n\n"
            keyboard.append([
                InlineKeyboardButton(f"🍽️ Stol #{o.table_number} ga yetkazdim", callback_data=f"waiter_served_order:{o.id}")
            ])
        keyboard.append([
            InlineKeyboardButton("🔄 Yangilash", callback_data="waiter_ready_orders"),
            InlineKeyboardButton("🪑 Stollar", callback_data="waiter_tables_grid")
        ])

    if update.callback_query:
        await update.callback_query.answer()
        await update.callback_query.edit_message_text(
            text,
            reply_markup=InlineKeyboardMarkup(keyboard),
            parse_mode="Markdown"
        )
    else:
        await update.message.reply_text(
            text,
            reply_markup=InlineKeyboardMarkup(keyboard),
            parse_mode="Markdown"
        )


async def mark_order_served(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Taom stolga yetkazildi deb belgilash"""
    query = update.callback_query
    order_id = int(query.data.split(":", 1)[1])

    try:
        order = await sync_to_async(Order.objects.get)(id=order_id)
        order.status = 'yetkazildi'
        order.delivered_at = timezone.now()
        await sync_to_async(order.save)()

        await sync_to_async(OrderStatusHistory.objects.create)(
            order=order,
            old_status='tayor',
            new_status='yetkazildi',
            notes=f"Ofitsiant bot orqali stolga yetkazildi ({update.effective_user.first_name})"
        )

        await query.answer(f"✅ Stol #{order.table_number} taomlari topshirildi!", show_alert=True)
    except Exception as e:
        await query.answer(f"Xatolik: {e}", show_alert=True)

    await show_ready_orders(update, context)


# ==========================================
# HISOB-KITOB VA STOLNI YOPISH
# ==========================================

async def show_bills_overview(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Faol stollar hisob-kitoblari"""
    orders = await sync_to_async(list)(
        Order.objects.filter(
            service_type='dine_in',
            status__in=['yangi', 'tasdiqlangan', 'tayor']
        ).order_by('-created_at')
    )

    if not orders:
        text = "🧾 **Hozirda band stollar va to'lov hisoblari yo'q.**"
        keyboard = [[InlineKeyboardButton("🪑 Stollar xaritasi", callback_data="waiter_tables_grid")]]
    else:
        text = f"🧾 **FAOL STOLLAR HISOB-KITOBLARI ({len(orders)} ta):**\n\n"
        keyboard = []
        for o in orders:
            text += f"🪑 **Stol #{o.table_number}**: {o.total_amount:,} so'm (#{o.order_number})\n"
            keyboard.append([
                InlineKeyboardButton(f"🧾 Stol #{o.table_number} hisobi ({o.total_amount:,} so'm)", callback_data=f"waiter_view_bill:{o.id}")
            ])
        keyboard.append([InlineKeyboardButton("🪑 Stollar xaritasi", callback_data="waiter_tables_grid")])

    if update.callback_query:
        await update.callback_query.answer()
        await update.callback_query.edit_message_text(
            text,
            reply_markup=InlineKeyboardMarkup(keyboard),
            parse_mode="Markdown"
        )
    else:
        await update.message.reply_text(
            text,
            reply_markup=InlineKeyboardMarkup(keyboard),
            parse_mode="Markdown"
        )


async def render_order_bill(query, order_id):
    order = await sync_to_async(Order.objects.prefetch_related('items__product').get)(id=order_id)
    items = await sync_to_async(list)(order.items.all())

    text = (
        f"🧾 **STOL #{order.table_number} HISOBI**\n\n"
        f"Buyurtma raqami: **#{order.order_number}**\n"
        f"Vaqt: {order.created_at.strftime('%H:%M')}\n"
        f"━━━━━━━━━━━━━━━━━━\n"
    )
    for it in items:
        text += f"• {it.quantity} x {it.product.name} — {it.total:,} so'm\n"

    text += (
        f"━━━━━━━━━━━━━━━━━━\n"
        f"💰 **JAMI HISOB: {order.total_amount:,} so'm**\n\n"
        f"ℹ️ *Eslatma: Stolni yopish va to'lovni qabul qilish KASSIR vakolatida.*"
    )

    keyboard = [
        [
            InlineKeyboardButton("🔔 Kassirga hisob so'rovi yuborish", callback_data=f"waiter_request_cashier:{order.table_number}"),
            InlineKeyboardButton("➕ Taom qo'shish", callback_data=f"waiter_punch_start:{order.table_number}")
        ],
        [
            InlineKeyboardButton("⬅️ Stol sahifasi", callback_data=f"waiter_table:{order.table_number}")
        ]
    ]

    await query.edit_message_text(
        text,
        reply_markup=InlineKeyboardMarkup(keyboard),
        parse_mode="Markdown"
    )


async def waiter_view_bill(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Ofitsiant uchun stol cheki va hisob tafsiloti"""
    query = update.callback_query
    await query.answer()
    order_id = int(query.data.split(":", 1)[1])
    await render_order_bill(query, order_id)


async def waiter_punch_categories(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Ofitsiant uchun taom kategoriyalarini ko'rsatish"""
    query = update.callback_query
    await query.answer()

    table_num = query.data.split(":", 1)[1]
    webapp_url = get_waiter_webapp_url(table_num)
    is_https = webapp_url.startswith('https://')

    categories = await sync_to_async(list)(Category.objects.filter(is_active=True))

    text = (
        f"📝 **STOL #{table_num} GA TAOM TANLASH**\n\n"
        f"Kategoriyani tanlang yoki quyidagi POS WebApp orqali oching:"
    )

    keyboard = []
    if is_https:
        keyboard.append([
            InlineKeyboardButton(f"🚀 Stol #{table_num} POS WebApp", web_app=WebAppInfo(url=webapp_url))
        ])

    row = []
    for cat in categories:
        row.append(InlineKeyboardButton(f"📂 {cat.name}", callback_data=f"waiter_punch_cat:{table_num}:{cat.id}"))
        if len(row) == 2:
            keyboard.append(row)
            row = []
    if row:
        keyboard.append(row)

    keyboard.append([InlineKeyboardButton("⬅️ Stolga qaytish", callback_data=f"waiter_table:{table_num}")])

    await query.edit_message_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode="Markdown")


async def waiter_punch_products(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Kategoriyadagi mahsulotlarni tanlash"""
    query = update.callback_query
    await query.answer()

    _, table_num, cat_id = query.data.split(":")
    category = await sync_to_async(Category.objects.get)(id=int(cat_id))
    products = await sync_to_async(list)(Product.objects.filter(category=category, is_available=True))

    text = f"📂 **{category.name}** (Stol #{table_num})\n\nTaomni tanlab, stolga qo'shing 👇"

    keyboard = []
    for prod in products:
        keyboard.append([
            InlineKeyboardButton(f"➕ {prod.name} ({prod.price:,.0f} so'm)", callback_data=f"waiter_punch_add:{table_num}:{prod.id}")
        ])

    keyboard.append([InlineKeyboardButton("⬅️ Boshqa kategoriya", callback_data=f"waiter_punch_start:{table_num}")])

    await query.edit_message_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode="Markdown")


async def waiter_punch_add_item(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Tanlangan taomni stol buyurtmasiga qo'shish"""
    query = update.callback_query
    _, table_num, prod_id = query.data.split(":")

    product = await sync_to_async(Product.objects.get)(id=int(prod_id))
    user_name = update.effective_user.first_name

    order = await sync_to_async(
        Order.objects.filter(
            service_type='dine_in',
            table_number=str(table_num),
            status__in=['yangi', 'tasdiqlangan', 'tayor']
        ).first
    )()

    if not order:
        customer, _ = await sync_to_async(Customer.objects.get_or_create)(
            telegram_id=1000000000 + int(table_num if table_num.isdigit() else 1),
            defaults={'full_name': f"Stol #{table_num}", 'phone_number': "+998900000000"}
        )
        order = await sync_to_async(Order.objects.create)(
            customer=customer,
            status='tasdiqlangan',
            payment_method='naqd',
            service_type='dine_in',
            table_number=str(table_num),
            products_total=Decimal('0'),
            delivery_cost=Decimal('0'),
            total_amount=Decimal('0')
        )
        await sync_to_async(OrderStatusHistory.objects.create)(
            order=order,
            old_status='',
            new_status='tasdiqlangan',
            notes=f"Ofitsiant bot orqali ochildi ({user_name})"
        )

    item, created = await sync_to_async(OrderItem.objects.get_or_create)(
        order=order,
        product=product,
        defaults={
            'quantity': 1,
            'price': product.price,
            'total': product.price
        }
    )
    if not created:
        item.quantity += 1
        item.total = item.quantity * item.price
        await sync_to_async(item.save)()

    order.products_total = (order.products_total or Decimal('0')) + product.price
    order.total_amount = (order.total_amount or Decimal('0')) + product.price
    await sync_to_async(order.save)()

    chef_text = (
        f"➕ <b>OFITSIANT BUYURTMASI (Stol #{table_num})</b>\n\n"
        f"🍽 <b>Taom:</b> 1x {product.name}\n"
        f"🤵 <b>Ofitsiant:</b> {user_name}\n"
        f"⏰ <b>Vaqt:</b> {timezone.now().strftime('%H:%M')}\n"
        f"💰 <b>Jami hisob:</b> {order.total_amount:,.0f} so'm"
    )
    if hasattr(settings, 'CHEF_CHAT_ID') and settings.CHEF_CHAT_ID:
        send_telegram_message(settings.CHEF_CHAT_ID, chef_text, parse_mode="HTML")

    await query.answer(f"✅ {product.name} stol #{table_num} ga qo'shildi!", show_alert=True)
    await render_order_bill(query, order.id)


async def waiter_request_cashier(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Kassirga hisob-kitob qilish so'rovi yuborish"""
    query = update.callback_query
    table_num = query.data.split(":", 1)[1]

    order = await sync_to_async(
        Order.objects.filter(
            service_type='dine_in',
            table_number=str(table_num),
            status__in=['yangi', 'tasdiqlangan', 'tayor']
        ).first
    )()

    total_str = f"{order.total_amount:,.0f} so'm" if order else "Hisob ochiq"
    cashier_text = (
        f"🧾 <b>KASSIR DIQQATIGA! HISOB-KITOB SO'ROVI!</b>\n\n"
        f"🪑 <b>Stol:</b> #{table_num}\n"
        f"💰 <b>Jami summa:</b> {total_str}\n"
        f"🤵 <b>Ofitsiant:</b> {update.effective_user.first_name}\n"
        f"⏰ <b>Vaqt:</b> {timezone.now().strftime('%H:%M')}\n\n"
        f"Iltimos, kassa panelidan chek chiqarib, to'lovni qabul qiling va stolni yoping!"
    )

    if hasattr(settings, 'ADMIN_CHAT_ID') and settings.ADMIN_CHAT_ID:
        send_telegram_message(settings.ADMIN_CHAT_ID, cashier_text, parse_mode="HTML")
    if hasattr(settings, 'CHEF_CHAT_ID') and settings.CHEF_CHAT_ID:
        send_telegram_message(settings.CHEF_CHAT_ID, cashier_text, parse_mode="HTML")

    await query.answer(f"✅ Stol #{table_num} hisobi kassirga uzatildi! Stolni kassir yopadi.", show_alert=True)
    await table_detail_view(update, context)



# ==========================================
# SMENA STATISTIKASI
# ==========================================

async def show_shift_stats(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Bugungi smena statistikasi"""
    today = timezone.now().date()
    today_orders = await sync_to_async(list)(
        Order.objects.filter(
            service_type='dine_in',
            created_at__date=today
        )
    )

    total_orders = len(today_orders)
    total_rev = sum(o.total_amount for o in today_orders)
    avg_check = (total_rev // total_orders) if total_orders > 0 else 0

    text = (
        f"📊 **BUGUNGI SMENA STATISTIKASI**\n\n"
        f"📅 Sana: **{today.strftime('%d.%m.%Y')}**\n"
        f"🤵 Ofitsiant: **{update.effective_user.first_name}**\n\n"
        f"🍽️ Xizmat ko'rsatilgan stollar: **{total_orders} ta**\n"
        f"💰 Umumiy tushum: **{total_rev:,} so'm**\n"
        f"📈 O'rtacha chek: **{avg_check:,} so'm**\n"
    )

    keyboard = [
        [InlineKeyboardButton("🪑 Stollar xaritasi", callback_data="waiter_tables_grid")],
        [InlineKeyboardButton("🔄 Yangilash", callback_data="waiter_shift_stats")]
    ]

    if update.callback_query:
        await update.callback_query.answer()
        await update.callback_query.edit_message_text(
            text,
            reply_markup=InlineKeyboardMarkup(keyboard),
            parse_mode="Markdown"
        )
    else:
        await update.message.reply_text(
            text,
            reply_markup=InlineKeyboardMarkup(keyboard),
            parse_mode="Markdown"
        )


# ==========================================
# MATNLI XABARLAR HANDLERI
# ==========================================

async def handle_waiter_messages(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Ofitsiant klaviatura tugmalarini qabul qilish"""
    text = update.message.text

    if "Stollar Xaritasi" in text or "🪑" in text:
        await show_tables_grid(update, context)
    elif "Chaqiruvlar" in text or "🔔" in text:
        await show_calls_list(update, context)
    elif "Tayyor Taomlar" in text or "🍽️" in text:
        await show_ready_orders(update, context)
    elif "Hisob-kitob" in text or "🧾" in text:
        await show_bills_overview(update, context)
    elif "Bugungi Smena" in text or "📊" in text:
        await show_shift_stats(update, context)
    elif "Yangilash" in text or "🔄" in text:
        await show_tables_grid(update, context)
    else:
        await start_command(update, context)


# ==========================================
# ASINXRON JONLI KUZATUVCHI (WATCHDOG)
# ==========================================

async def waiter_background_watchdog(application: Application):
    """Yangi chaqiruvlar va tayyor taomlarni avtomatik aniqlab ofitsiantlarga yuborish"""
    last_checked_call_id = 0
    last_checked_ready_order_ids = set()

    # Dastlabki so'nggi ID larni olish
    try:
        latest_call = await sync_to_async(WaiterCall.objects.order_by('-id').first)()
        if latest_call:
            last_checked_call_id = latest_call.id
    except Exception:
        pass

    while True:
        try:
            # 1. Yangi chaqiruvlarni tekshirish
            new_calls = await sync_to_async(list)(
                WaiterCall.objects.filter(
                    id__gt=last_checked_call_id,
                    is_resolved=False
                ).order_by('id')
            )

            for call in new_calls:
                last_checked_call_id = max(last_checked_call_id, call.id)
                active_waiters = await sync_to_async(list)(
                    WaiterProfile.objects.filter(is_active=True, telegram_id__isnull=False)
                )

                call_text = (
                    f"🚨 **YANGI MIJOZ CHAQIRUVI!**\n\n"
                    f"🪑 **Stol:** #{call.table_number}\n"
                    f"💬 **Sabab:** {call.reason}\n"
                    f"⏰ **Vaqt:** {call.created_at.strftime('%H:%M')}\n\n"
                    f"Iltimos, zudlik bilan stolga yaqinlashing!"
                )
                call_kb = InlineKeyboardMarkup([
                    [InlineKeyboardButton(f"✅ Boraman (Stol #{call.table_number})", callback_data=f"waiter_call_dismiss:{call.table_number}")]
                ])

                for w in active_waiters:
                    try:
                        await application.bot.send_message(
                            chat_id=w.telegram_id,
                            text=call_text,
                            reply_markup=call_kb,
                            parse_mode="Markdown"
                        )
                    except Exception as err:
                        logger.debug(f"Ofitsiantga yuborishda: {err}")

            # 2. Yangi tayyor taomlarni tekshirish
            ready_orders = await sync_to_async(list)(
                Order.objects.filter(
                    service_type='dine_in',
                    status='tayor'
                ).prefetch_related('items__product')
            )

            current_ready_ids = {o.id for o in ready_orders}
            new_ready_orders = [o for o in ready_orders if o.id not in last_checked_ready_order_ids]

            for ord_obj in new_ready_orders:
                active_waiters = await sync_to_async(list)(
                    WaiterProfile.objects.filter(is_active=True, telegram_id__isnull=False)
                )

                order_text = (
                    f"🍽️ **STOL #{ord_obj.table_number} TAOMLARI TAYYOR!**\n\n"
                    f"📋 Buyurtma: #{ord_obj.order_number}\n"
                    f"🍽 **Taomlar:**\n"
                )
                for item in ord_obj.items.all():
                    order_text += f"• {item.quantity} x {item.product.name}\n"
                order_text += f"\nOshxonadan olib, stolga yetkazing!"

                ready_kb = InlineKeyboardMarkup([
                    [InlineKeyboardButton(f"🍽️ Stolga yetkazdim", callback_data=f"waiter_served_order:{ord_obj.id}")]
                ])

                for w in active_waiters:
                    try:
                        await application.bot.send_message(
                            chat_id=w.telegram_id,
                            text=order_text,
                            reply_markup=ready_kb,
                            parse_mode="Markdown"
                        )
                    except Exception as err:
                        logger.debug(f"Ofitsiantga taom tayyor xabari yuborishda: {err}")

            last_checked_ready_order_ids = current_ready_ids

        except Exception as e:
            logger.debug(f"Watchdog tsiklida xato: {e}")

        await asyncio.sleep(3)


# ==========================================
# ASOSIY ISHGA TUSHIRISH
# ==========================================

async def post_init(application: Application):
    """Bot ishga tushgach orqa fonda xabarnoma qidiruvchini ishga tushirish"""
    asyncio.create_task(waiter_background_watchdog(application))


def main():
    if not WAITER_BOT_TOKEN:
        print("❌ [XATOLIK] Telegram bot token topilmadi! .env faylida WAITER_BOT_TOKEN yoki TELEGRAM_BOT_TOKEN ni ko'rsating.")
        sys.exit(1)

    print("=" * 60)
    print("🤵 OFITSIANT TELEGRAM BOTI ISHGA TUSHMOQDA (2026/2027)")
    print(f"🔑 Token: {WAITER_BOT_TOKEN[:10]}...{WAITER_BOT_TOKEN[-5:]}")
    print("=" * 60)

    application = Application.builder().token(WAITER_BOT_TOKEN).post_init(post_init).build()

    # Buyruqlar
    application.add_handler(CommandHandler("start", start_command))
    application.add_handler(CommandHandler("tables", show_tables_grid))
    application.add_handler(CommandHandler("stollar", show_tables_grid))
    application.add_handler(CommandHandler("calls", show_calls_list))
    application.add_handler(CommandHandler("chaqiruvlar", show_calls_list))
    application.add_handler(CommandHandler("ready", show_ready_orders))
    application.add_handler(CommandHandler("tayyor", show_ready_orders))
    application.add_handler(CommandHandler("stats", show_shift_stats))
    application.add_handler(CommandHandler("smena", show_shift_stats))

    # Callbacklar
    application.add_handler(CallbackQueryHandler(show_tables_grid, pattern="^waiter_tables_grid$"))
    application.add_handler(CallbackQueryHandler(table_detail_view, pattern=r"^waiter_table:\d+$"))
    application.add_handler(CallbackQueryHandler(show_calls_list, pattern="^waiter_calls_list$"))
    application.add_handler(CallbackQueryHandler(dismiss_call_callback, pattern=r"^waiter_call_dismiss:\d+$"))
    application.add_handler(CallbackQueryHandler(show_ready_orders, pattern="^waiter_ready_orders$"))
    application.add_handler(CallbackQueryHandler(mark_order_served, pattern=r"^waiter_served_order:\d+$"))
    application.add_handler(CallbackQueryHandler(waiter_punch_categories, pattern=r"^waiter_punch_start:\d+$"))
    application.add_handler(CallbackQueryHandler(waiter_punch_products, pattern=r"^waiter_punch_cat:\d+:\d+$"))
    application.add_handler(CallbackQueryHandler(waiter_punch_add_item, pattern=r"^waiter_punch_add:\d+:\d+$"))
    application.add_handler(CallbackQueryHandler(show_bills_overview, pattern="^waiter_bills_list$"))
    application.add_handler(CallbackQueryHandler(waiter_view_bill, pattern=r"^waiter_view_bill:\d+$"))
    application.add_handler(CallbackQueryHandler(waiter_request_cashier, pattern=r"^waiter_request_cashier:\d+$"))
    application.add_handler(CallbackQueryHandler(show_shift_stats, pattern="^waiter_shift_stats$"))

    # Matnli xabarlar
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_waiter_messages))

    # Pollingni ishga tushirish
    application.run_polling(drop_pending_updates=True)


if __name__ == '__main__':
    main()
