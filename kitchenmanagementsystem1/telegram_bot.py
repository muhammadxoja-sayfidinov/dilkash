import os
import django
import logging
import json
from typing import Dict
from datetime import datetime
import math

from telegram import (
    Update, InlineKeyboardButton, InlineKeyboardMarkup, KeyboardButton,
    ReplyKeyboardMarkup, InputMediaPhoto, ReplyKeyboardRemove
)
from telegram.ext import (
    ApplicationBuilder, CommandHandler, CallbackQueryHandler, MessageHandler,
    ContextTypes, filters
)

# Import sync_to_async for Django ORM operations in async context
from asgiref.sync import sync_to_async

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'kitchen_system.settings')
django.setup()

from django.conf import settings
from django.db.models import Max
from kitchen.models import Category, Product, Order, OrderItem
from channels.layers import get_channel_layer
from django.utils import timezone

# ----------------------------------------------------
# Логгер созламалари
# ----------------------------------------------------
logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# ----------------------------------------------------
# Глобал ўзгарувчилар (Энди Django'дан олинади)
# ----------------------------------------------------
ADMIN_CHAT_ID = 1517715653
BOT_TOKEN = "1574987467:AAFvXaSfQBjagl4LmcY171Kw-gDiHco2v8Y"
# Дўкон (ёки омбор) координаталари
STORE_LAT = 41.284116
STORE_LON = 69.191645

# ----------------------------------------------------
# Django'дан маҳсулот ва категорияларни олиш
# ----------------------------------------------------
@sync_to_async
def get_all_products_data():
    products_data = {}
    for product in Product.objects.filter(is_available=True):
        products_data[product.name] = {
            "narx": float(product.price),
            "desc": product.description,
            "rasm": product.image.url if product.image else None,
            "id": product.id,
            "category_id": product.category.id
        }
    return products_data

@sync_to_async
def get_all_categories_data():
    categories_data = {}
    for category in Category.objects.filter(is_active=True):
        products_in_category = Product.objects.filter(category=category, is_available=True).values_list('name', flat=True)
        categories_data[category.name] = list(products_in_category)
    return categories_data

@sync_to_async
def get_user_orders_paginated(user_id, start_idx, end_idx):
    all_orders_queryset = Order.objects.filter(telegram_user_id=str(user_id)).order_by('-created_at')
    total_count = all_orders_queryset.count()
    subset = list(all_orders_queryset[start_idx:end_idx])
    return subset, total_count

@sync_to_async
def get_admin_orders_paginated(status_filter, start_idx, end_idx):
    if status_filter == 'yangi':
        orders_queryset = Order.objects.filter(status='yangi').order_by('-created_at')
    else: # 'all'
        orders_queryset = Order.objects.all().order_by('-created_at')
    
    total_count = orders_queryset.count()
    subset = list(orders_queryset[start_idx:end_idx])
    return subset, total_count

# ----------------------------------------------------
# 1) Масофа ва етказиб бериш нархи ҳисоблаш
# ----------------------------------------------------
def calculate_distance_km(lat1, lon1, lat2, lon2):
    """
    Haversine формуласи орқали (lat1, lon1) дан (lat2, lon2) га бўлган
    масофани (кмда) қайтаради.
    """
    R = 6371.0  # Ер шари радиуси (км)
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)

    a = (math.sin(d_lat / 2))**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * (math.sin(d_lon / 2))**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    distance = R * c
    return distance

def calculate_delivery_cost(distance_km):
    """
    0–2 км => 10 000 сўм
    2–4 км => 15 000 сўм
    4–6 км => 20 000 сўм
    ...
    Ҳар +2 км учун +5 000 сўм.
    Агар distance_km > 40 => None (хизмат йўқ).
    """
    if distance_km > 40:
        return None  # 40 км дан узоқ жойларга хизмат йўқ

    step_count = math.ceil(distance_km / 2.0)
    # step_count=1 => 10 000
    # step_count=2 => 15 000
    # step_count=n => 10 000 + (n-1)*5 000
    cost = 10000 + (step_count - 1) * 5000
    return cost

# ----------------------------------------------------
# 2) Асосий inline менюларни қуриш
# ----------------------------------------------------
def main_inline_menu(context: ContextTypes.DEFAULT_TYPE) -> InlineKeyboardMarkup:
    user_savat = context.user_data.get('savat', {})
    buttons = [
        [InlineKeyboardButton("Буюртма бериш", callback_data="menu")],
        [
            InlineKeyboardButton("👤 Профил", callback_data="profile"),
            InlineKeyboardButton("🛍 Буюртмаларим", callback_data="user_orders:1")
        ],
        [InlineKeyboardButton("✍️ Фикр билдириш", callback_data="feedback")]
    ]
    if user_savat:
        buttons[0].append(InlineKeyboardButton("🛒 Сават", callback_data="show_cart"))
    return InlineKeyboardMarkup(buttons)

async def build_cart_message(user_savat, context):
    mahsulotlar = await get_all_products_data()
    if not user_savat:
        return "🛒 Саватингиз бўш!"
    text = "Саватчада:\n"
    total = 0
    for product_name, qty in user_savat.items():
        product_data = mahsulotlar.get(product_name, {})
        narx = product_data.get("narx", 0)
        summa = narx * qty
        total += summa
        text += f"{qty} x {product_name} - {summa} сўм\n"

    text += f"\nМаҳсулотлар: {total} сўм\n"

    # Етказиб бериш нархини context дан оламиз:
    delivery_possible = context.user_data.get('delivery_possible', None)
    if delivery_possible is False:
        text += "Етказиб бериш: Мавжуд эмас (40 км дан узоқ)\n"
        text += f"Жами: {total} сўм\n"
    else:
        delivery_cost = context.user_data.get('delivery_cost')
        if delivery_cost is not None:
            text += f"Етказиб бериш: {delivery_cost} сўм\n"
            text += f"Жами: {total + delivery_cost} сўм\n"
        else:
            text += "Етказиб бериш: Локация киритилмаган\n"
            text += f"Жами (ҳозирча): {total} сўм\n"

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
            InlineKeyboardButton("-", callback_data=f"update_cart:{product}:dec"),
            InlineKeyboardButton(f"{product}", callback_data="noop"),
            InlineKeyboardButton("+", callback_data=f"update_cart:{product}:inc")
        ])
    return rows

async def remove_image_from_message(query, text, keyboard):
    try:
        await query.edit_message_media(
            media=InputMediaPhoto(
                media="https://i.postimg.cc/RFXYvrHz/2025-01-14-14-52-15.jpg", # Placeholder image
                caption=text,
                parse_mode='Markdown'
            ),
            reply_markup=InlineKeyboardMarkup(keyboard)
        )
    except Exception as e:
        logger.error(f"Failed to replace image with placeholder: {e}")
        await query.answer("Хатолик юз берди. Илтимос, қайта уриниб кўринг.", show_alert=True)

async def edit_message_based_on_type(query, text, keyboard, force_text=False):
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
    elif message.photo:
        try:
            await remove_image_from_message(query, text, keyboard)
        except Exception as e:
            logger.error(f"Failed to remove image: {e}")
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
            await query.answer("Хатолик юз берди. Илтимос, қайта уриниб кўринг.", show_alert=True)
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
# Саватни кўрсатиш
# ----------------------------------------------------
async def show_cart(update_or_query, context: ContextTypes.DEFAULT_TYPE, edit=False):
    user_savat = context.user_data.get('savat', {})
    text = await build_cart_message(user_savat, context)
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
    await update.message.reply_text(
        f"Ассалому алайкум, {user.first_name}! Илтимос, телефон рақамингизни улашинг:",
        reply_markup=ReplyKeyboardMarkup(
            [[KeyboardButton("📱 Контактни улашиш", request_contact=True)]],
            resize_keyboard=True,
            one_time_keyboard=True
        )
    )
    context.user_data["awaiting_contact_at_start"] = True

async def main_menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    text = "Нима буюртма қилмоқчисиз?"
    keyboard = main_inline_menu(context).inline_keyboard
    await edit_message_based_on_type(query, text, keyboard)

async def handle_contact(update: Update, context: ContextTypes.DEFAULT_TYPE):
    contact = update.message.contact
    context.user_data['phone_number'] = contact.phone_number
    context.user_data['full_name'] = contact.first_name + " " + (contact.last_name or "")

    await update.message.reply_text("Раҳмат!", reply_markup=ReplyKeyboardRemove())

    if context.user_data.get("awaiting_contact_at_start"):
        del context.user_data["awaiting_contact_at_start"]
        await update.message.reply_text(
            "Энди буюртма беришингиз мумкин:",
            reply_markup=main_inline_menu(context)
        )
        return

    # Агар /checkout жараёни бўлса
    await update.message.reply_text(
        "Контакт қабул қилинди! Энди локациянгизни юборинг:",
        reply_markup=ReplyKeyboardMarkup([
            [KeyboardButton("📍 Локацияни улашиш", request_location=True)]
        ], resize_keyboard=True)
    )
    context.user_data['awaiting_location'] = True

# ----------------------------------------------------
# Локация + масофа + етказиб бериш нархи
# ----------------------------------------------------
async def handle_location(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if 'awaiting_location' in context.user_data and context.user_data['awaiting_location']:
        location = update.message.location
        user_lat = location.latitude
        user_lon = location.longitude

        # Масофани ҳисоблаймиз
        distance_km = calculate_distance_km(STORE_LAT, STORE_LON, user_lat, user_lon)
        delivery_cost = calculate_delivery_cost(distance_km)

        if delivery_cost is None:
            # 40 км дан узоқ => етказиб бериш йўқ
            del context.user_data['awaiting_location']
            context.user_data['delivery_possible'] = False

            await update.message.reply_text(
                "Узр, сизнинг манзилингиз бизнинг 40 км радиусимиздан ташқарида.\n"
                "Шу сабаб етказиб бериш хизмати мавжуд эмас.\n"
                "Аммо менюдан маҳсулотларни кўришингиз мумкин."
            )
            await update.message.reply_text("Меню:", reply_markup=main_inline_menu(context))
        else:
            # 40 км ичида
            context.user_data['delivery_possible'] = True
            context.user_data['delivery_distance'] = distance_km
            context.user_data['delivery_cost'] = delivery_cost
            context.user_data['location'] = {
                'latitude': user_lat,
                'longitude': user_lon
            }
            del context.user_data['awaiting_location']

            await update.message.reply_text(
                f"Локация қабул қилинди (масофа тахминан {distance_km:.1f} км)."
                f"\nЕтказиб бериш нархи: {delivery_cost} сўм.\n"
                "Агар қўшимча манзил киритмоқчи бўлсангиз, ёзинг.\n"
                "Керак бўлмаса, \"Бекор қилиш\" деб ёзинг.",
                reply_markup=ReplyKeyboardMarkup([
                    [KeyboardButton("Бекор қилиш")]
                ], resize_keyboard=True)
            )
            context.user_data['awaiting_address'] = True

async def handle_address(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if 'awaiting_address' in context.user_data and context.user_data['awaiting_address']:
        address = update.message.text
        if address.lower() == "бекор қилиш":
            address = None
        context.user_data['address'] = address
        del context.user_data['awaiting_address']

        await update.message.reply_text(
            "Манзил қабул қилинди.",
            reply_markup=ReplyKeyboardRemove()
        )

        keyboard = [
            [InlineKeyboardButton("✅ Тасдиқлаш", callback_data="final_confirm_order")],
            [InlineKeyboardButton("❌ Бекор қилиш", callback_data="cancel_order")]
        ]
        context.user_data['payment_method'] = 'naqd'  # default to 'naqd' (cash)
        await update.message.reply_text(
            "Тўлов усули: Нақд\nБуюртмани тасдиқлаш учун \"✅ Тасдиқлаш\" босинг:",
            reply_markup=InlineKeyboardMarkup(keyboard)
        )

async def payment_method_chosen(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    if 'awaiting_payment' in context.user_data and context.user_data['awaiting_payment']:
        payment_method = query.data.split(":")[1]
        context.user_data['payment_method'] = payment_method
        del context.user_data['awaiting_payment']

        user_savat = context.user_data.get('savat', {})
        mahsulotlar = await get_all_products_data()
        total = 0
        order_details = []
        for product_name, qty in user_savat.items():
            narx = mahsulotlar.get(product_name, {}).get("narx", 0)
            summa = narx * qty
            total += summa
            order_details.append((product_name, qty, summa))
        text = "🚚 Буюртма маълумотлари:\n"
        for product_name, qty, summa in order_details:
            text += f"{product_name} - {qty} та - {summa} сўм\n"
        text += f"\nМаҳсулотлар: {total} сўм\n"
        text += f"\nТўлов усули: {payment_method}\n"
        text += "Буюртмани тасдиқлаш учун \"✅ Тасдиқлаш\" тугмасини босинг."

        keyboard = [
            [
                InlineKeyboardButton("✅ Тасдиқлаш", callback_data="final_confirm_order"),
                InlineKeyboardButton("❌ Бекор қилиш", callback_data="cancel_order")
            ]
        ]
        await query.edit_message_text(
            text, parse_mode="Markdown", reply_markup=InlineKeyboardMarkup(keyboard)
        )

# ----------------------------------------------------
# Профил
# ----------------------------------------------------
async def show_profile(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    user = update.effective_user
    profile_info = context.user_data
    user_id = user.id
    order_count = await sync_to_async(Order.objects.filter(telegram_user_id=str(user_id)).count)()

    text = f"👤 Профил маълумотлари:\n"
    text += f"Исм: {profile_info.get('full_name', 'Белгиланмаган')}\n"
    text += f"Телефон: {profile_info.get('phone_number', 'Белгиланмаган')}\n"
    text += f"Жами буюртмалар сони: {order_count}\n"

    keyboard = [[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]]
    await query.edit_message_text(text, reply_markup=InlineKeyboardMarkup(keyboard))

async def show_user_orders(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()

    data = query.data  # масалан "user_orders:1"
    _, page_str = data.split(":")
    page = int(page_str)

    user = update.effective_user

    start_idx = (page - 1) * 10
    end_idx = start_idx + 10
    
    # Use the new sync function
    subset, total_count = await get_user_orders_paginated(user.id, start_idx, end_idx)

    if not subset:
        await query.edit_message_text(
            "Бу ерда буюртма топилмади.",
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]])
        )
        return

    text = "🛍 Сизнинг буюртмалларингиз (сўнггилари аввал):\n\n"
    for order in subset:
        text += f"Буюртма ID: {order.order_id}\n"
        text += f"Вақт: {order.created_at.strftime('%Y-%m-%d %H:%M')}\n"
        text += f"Сумма: {order.total_amount} сўм\n"
        text += f"Статус: {order.get_status_display_with_icon()}\n\n"

    # Тугмалар
    buttons = []
    nav_buttons = []
    if page > 1:
        nav_buttons.append(InlineKeyboardButton("◀️ Олдинги", callback_data=f"user_orders:{page-1}"))
    if end_idx < total_count:
        nav_buttons.append(InlineKeyboardButton("Кейинги ▶️", callback_data=f"user_orders:{page+1}"))

    if nav_buttons:
        buttons.append(nav_buttons)
    buttons.append([InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")])

    await query.edit_message_text(text, reply_markup=InlineKeyboardMarkup(buttons))

# ----------------------------------------------------
# Категориялар ва маҳсулотлар
# ----------------------------------------------------
async def show_menu_inline(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()

    kategoriyalar = await get_all_categories_data()
    if not kategoriyalar:
        await edit_message_based_on_type(
            query,
            "Ҳозирча категориялар мавжуд эмас.",
            [[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]]
        )
        return

    keyboard = []
    row = []
    for kategoriya_name in kategoriyalar.keys():
        row.append(InlineKeyboardButton(kategoriya_name, callback_data=f"category:{kategoriya_name}"))
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
        text = await build_cart_message(user_savat, context) + "\n\nКатегория танланг:"
    else:
        text = "Категория танланг:"

    await edit_message_based_on_type(query, text, keyboard)

async def show_category(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    category_name = query.data.split(":")[1]

    kategoriyalar = await get_all_categories_data()
    mahsulotlar = await get_all_products_data()

    product_buttons = []
    row = []
    for product_name in kategoriyalar.get(category_name, []):
        if product_name in mahsulotlar:
            row.append(InlineKeyboardButton(product_name, callback_data=f"product:{product_name}"))
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

    new_text = f"{category_name} категориясидаги маҳсулотлар:"
    await edit_message_based_on_type(query, new_text, product_buttons)

async def show_product(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    product_name = query.data.split(":")[1]
    mahsulotlar = await get_all_products_data()
    product_data = mahsulotlar.get(product_name, {})
    if not product_data:
        await query.edit_message_text("Бу маҳсулот топилмади.")
        return

    narx = product_data.get("narx", 0)
    desc = product_data.get("desc", "")
    image = product_data.get("rasm", None)

    product_category_name = None
    if product_data.get("category_id"):
        try:
            product_category = await sync_to_async(Category.objects.get)(id=product_data["category_id"])
            product_category_name = product_category.name
        except Category.DoesNotExist:
            pass

    context.user_data[product_name] = context.user_data.get(product_name, 1)

    text = f"**{product_name}**\nНархи: {narx} сўм\n{desc}\n"
    keyboard = [
        [
            InlineKeyboardButton("-", callback_data=f"quantity:{product_name}:-1"),
            InlineKeyboardButton(f"{context.user_data[product_name]}", callback_data="noop"),
            InlineKeyboardButton("+", callback_data=f"quantity:{product_name}:1")
        ],
        [InlineKeyboardButton("🛒 Саватга қўшиш", callback_data=f"add_to_cart:{product_name}")]
    ]
    keyboard.append([
        InlineKeyboardButton("⬅️ Орқага", callback_data=f"product_go_back:{product_category_name}")
    ])

    if image:
        try:
            await query.edit_message_media(
                media=InputMediaPhoto(media=image, caption=text, parse_mode='Markdown'),
                reply_markup=InlineKeyboardMarkup(keyboard)
            )
        except Exception as e:
            logger.error(f"Failed to edit message media: {e}")
            await edit_message_based_on_type(query, text, keyboard)
    else:
        await query.edit_message_text(
            text,
            parse_mode="Markdown",
            reply_markup=InlineKeyboardMarkup(keyboard)
        )

async def product_go_back(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()

    _, category_name = query.data.split(":")
    try:
        await query.edit_message_reply_markup(reply_markup=None)
    except Exception as e:
        logger.error(f"Inline тугмаларни ўчиришда хатолик: {e}")

    kategoriyalar = await get_all_categories_data()
    if not kategoriyalar:
        await query.message.reply_text(
            "Ҳозирча категориялар мавжуд эмас.",
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("⬅️ Бош меню", callback_data="main_menu")]])
        )
        return

    keyboard = []
    row = []
    for kategoriya in kategoriyalar.keys():
        row.append(InlineKeyboardButton(kategoriya, callback_data=f"category:{kategoriya}"))
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
        "Категория танланг:",
        reply_markup=InlineKeyboardMarkup(keyboard)
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

    mahsulotlar = await get_all_products_data()
    product_data = mahsulotlar.get(product_name, {})
    narx = product_data.get("narx", 0)
    desc = product_data.get("desc", "")
    image = product_data.get("rasm", None)

    text = f"**{product_name}**\nНархи: {narx} сўм\n{desc}\n\nМиқдорини танланг:"
    keyboard = [
        [
            InlineKeyboardButton("-", callback_data=f"quantity:{product_name}:-1"),
            InlineKeyboardButton(f"{new_quantity}", callback_data="noop"),
            InlineKeyboardButton("+", callback_data=f"quantity:{product_name}:1")
        ],
        [InlineKeyboardButton("🛒 Саватга қўшиш", callback_data=f"add_to_cart:{product_name}")]
    ]

    product_category_name = None
    if product_data.get("category_id"):
        try:
            product_category = await sync_to_async(Category.objects.get)(id=product_data["category_id"])
            product_category_name = product_category.name
        except Category.DoesNotExist:
            pass
    if product_category_name:
        keyboard.append([InlineKeyboardButton("⬅️ Орқага", callback_data=f"category:{product_category_name}")])

    try:
        if image:
            await query.edit_message_media(
                media=InputMediaPhoto(media=image, caption=text, parse_mode='Markdown'),
                reply_markup=InlineKeyboardMarkup(keyboard)
            )
        else:
            await query.edit_message_text(
                text=text, parse_mode="Markdown",
                reply_markup=InlineKeyboardMarkup(keyboard)
            )
    except Exception as e:
        logger.error(f"Failed to update quantity selection: {e}")

async def add_to_cart(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    product_name = query.data.split(":")[1]
    selected_quantity = context.user_data.get(product_name, 1)

    savat = context.user_data.get('savat', {})
    savat[product_name] = savat.get(product_name, 0) + selected_quantity
    context.user_data['savat'] = savat

    mahsulotlar = await get_all_products_data()
    product_data = mahsulotlar.get(product_name, {})
    product_category_name = None
    if product_data.get("category_id"):
        try:
            product_category = await sync_to_async(Category.objects.get)(id=product_data["category_id"])
            product_category_name = product_category.name
        except Category.DoesNotExist:
            pass

    kategoriyalar = await get_all_categories_data()
    product_buttons = []
    row = []
    for nom in kategoriyalar.get(product_category_name, []):
        if nom in mahsulotlar:
            row.append(InlineKeyboardButton(nom, callback_data=f"product:{nom}"))
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

    new_text = f"✅ {product_name} саватга {selected_quantity} та қўшилди!\n\n{product_category_name} категориясидаги маҳсулотлар:"
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

    text = "🗑 Саватингиз бўшатилди."
    keyboard = [
        [
            InlineKeyboardButton("🚖 Буюртма бериш", callback_data="menu"),
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
            "🛒 Саватингиз бўш!",
            [[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]]
        )
        return

    if 'phone_number' not in context.user_data:
        await edit_message_based_on_type(
            query,
            "Буюртма бериш учун авваль контактингизни улашинг!",
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

    await edit_message_based_on_type(
        query,
        "Илтимос локациянгизни юборинг:",
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

# ----------------------------------------------------
# Динамик нарх билан финал тасдиқлаш
# ----------------------------------------------------
async def final_confirm_order(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()

    # Агар масофа >40 км бўлса, рад этамиз
    if context.user_data.get('delivery_possible') is False:
        await query.edit_message_text(
            "Узр, сизнинг ҳудудингизга етказиб бериш хизмати мавжуд эмас.\n"
            "Меню орқали танишиб кўришингиз мумкин."
        )
        return

    user = update.effective_user
    phone = context.user_data.get('phone_number', 'Номаълум')
    full_name = context.user_data.get('full_name', 'Номаълум')
    location = context.user_data.get('location', {})
    address = context.user_data.get('address', None)
    payment_method = context.user_data.get('payment_method', 'naqd') # Default to 'naqd'

    user_savat = context.user_data.get('savat', {})
    if not user_savat:
        await query.edit_message_text(
            "🛒 Саватингиз бўш!",
            reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("⬅️ Орқага", callback_data="main_menu")]])
        )
        return

    # Етказиб бериш нархи
    delivery_cost = context.user_data.get('delivery_cost', 0)

    mahsulotlar = await get_all_products_data()
    total_products_amount = 0
    order_items_data = [] # To store (product_obj, quantity, price_at_order)
    for product_name, qty in user_savat.items():
        product_data = mahsulotlar.get(product_name, {})
        product_obj = await sync_to_async(Product.objects.get)(name=product_name) # Get Django Product object
        narx = float(product_data.get("narx", 0))
        summa = narx * qty
        total_products_amount += summa
        order_items_data.append((product_obj, qty, narx)) # Store product object and its price at order time

    total_amount_with_delivery = total_products_amount + delivery_cost

    # Generate order_id
    last_order_id_obj = await sync_to_async(Order.objects.aggregate)(Max('order_id'))
    last_order = last_order_id_obj['order_id__max']
    if last_order and last_order.startswith('ORD'):
        try:
            last_num = int(last_order[3:])
            new_order_num = last_num + 1
        except ValueError:
            new_order_num = 1001 # Fallback if parsing fails
    else:
        new_order_num = 1001 # Start from 1001 if no orders or different format
    order_id = f"ORD{new_order_num}"

    # Create Order in Django
    try:
        new_order = await sync_to_async(Order.objects.create)(
            order_id=order_id,
            customer_name=full_name,
            customer_phone=phone,
            total_amount=total_amount_with_delivery,
            status='yangi', # 'yangi' for new order
            address=address,
            payment_method=payment_method,
            telegram_user_id=str(user.id),
            created_at=timezone.now(),
            updated_at=timezone.now(),
            # estimated_time will be set when status changes to 'tayyor'
        )

        for product_obj, qty, narx in order_items_data:
            await sync_to_async(OrderItem.objects.create)(
                order=new_order,
                product=product_obj,
                quantity=qty,
                price=narx # Price at the time of order
            )
        logger.info(f"Order {order_id} created in Django for user {user.id}")

        # Send WebSocket update to Django dashboard
        channel_layer = get_channel_layer()
        await channel_layer.group_send(
            'kitchen_orders',
            {
                'type': 'order_update',
                'order_id': new_order.order_id,
                'status': new_order.status,
                'message': f"Yangi buyurtma keldi: #{new_order.order_id}"
            }
        )

    except Exception as e:
        logger.error(f"Error creating order in Django: {e}")
        await query.edit_message_text("Буюртма беришда хатолик юз берди. Илтимос, қайта уриниб кўринг.")
        return

    # Admin notification
    admin_text = f"Янги буюртма #{order_id}\n"
    admin_text += f"Исм: {full_name}\n"
    admin_text += f"Телефон: {phone}\n"
    admin_text += f"Тўлов усули: {payment_method}\n"
    if address:
        admin_text += f"Манзил: {address}\n"
    else:
        admin_text += "Манзил: Фақат локация\n"
    admin_text += "\nМаҳсулотлар:\n"
    for product_obj, qty, narx in order_items_data:
        admin_text += f"{product_obj.name} - {qty} та - {narx * qty} сўм\n"
    admin_text += f"\nЖами: {total_amount_with_delivery} сўм\n"

    keyboard_admin = [
        [
            InlineKeyboardButton("✅ Тасдиқлаш", callback_data=f"admin_confirm_order:{order_id}"),
            InlineKeyboardButton("❌ Бекор қилиш", callback_data=f"admin_cancel_order:{order_id}")
        ]
    ]
    await context.bot.send_message(chat_id=ADMIN_CHAT_ID, text=admin_text, reply_markup=InlineKeyboardMarkup(keyboard_admin))
    if location:
        await context.bot.send_location(
            chat_id=ADMIN_CHAT_ID,
            latitude=location['latitude'],
            longitude=location['longitude']
        )

    user_text = f"✅ Буюртмангиз қабул қилинди!\nБуюртма ID: {order_id}\n"
    user_text += f"Исм: {full_name}\n"
    user_text += f"Телефон: {phone}\n"
    user_text += f"Тўлов усули: {payment_method}\n"
    if address:
        user_text += f"Манзил: {address}\n"
    else:
        user_text += "Манзил: Фақат локация\n"
    if location:
        user_text += f"Локация: https://www.google.com/maps?q={location['latitude']},{location['longitude']}\n"
    user_text += "\nМаҳсулотлар:\n"
    for product_obj, qty, narx in order_items_data:
        user_text += f"{product_obj.name} - {qty} та - {narx * qty} сўм\n"
    user_text += f"\nЖами: {total_amount_with_delivery} сўм\nСтатус: {new_order.get_status_display_with_icon()}"

    user_keyboard = [[InlineKeyboardButton("⬅️ Бош меню", callback_data="main_menu")]]
    user_message = await context.bot.send_message(
        chat_id=user.id,
        text=user_text,
        reply_markup=InlineKeyboardMarkup(user_keyboard),
        parse_mode="Markdown"
    )
    # Store user_message_id in context for potential future updates (though Django is source of truth)
    context.user_data['last_order_message_id'] = user_message.message_id
    context.user_data['last_order_id'] = order_id


    # Clear user data after successful order
    context.user_data.pop('savat', None)
    context.user_data.pop('address', None)
    context.user_data.pop('location', None)
    context.user_data.pop('payment_method', None)
    context.user_data.pop('delivery_cost', None)
    context.user_data.pop('delivery_distance', None)
    context.user_data.pop('delivery_possible', None)


    await query.edit_message_text("Буюртмангиз қабул қилинди! Тез орада боғланамиз.")
    await context.bot.send_message(chat_id=user.id, text="Бош меню:", reply_markup=main_inline_menu(context))

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
    if 'delivery_cost' in context.user_data:
        del context.user_data['delivery_cost']
    if 'delivery_distance' in context.user_data:
        del context.user_data['delivery_distance']
    if 'delivery_possible' in context.user_data:
        del context.user_data['delivery_possible']

    await query.edit_message_text("Буюртма бекор қилинди.", reply_markup=main_inline_menu(context))

async def feedback_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    context.user_data["awaiting_feedback"] = True
    await query.message.reply_text(
        "Фикрингизни ёзинг. Бекор қилиш учун /cancel ни ёзинг."
    )

async def handle_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    text = update.message.text
    if context.user_data.get('awaiting_address'):
        await handle_address(update, context)
        return

    if context.user_data.get("awaiting_feedback"):
        context.user_data["awaiting_feedback"] = False
        user = update.effective_user
        phone = context.user_data.get('phone_number', "Номаълум")
        full_name = context.user_data.get('full_name', user.full_name)

        admin_msg = (
            f"Янги фикр келиб тушди!\n\n"
            f"Муаллиф: {full_name}\n"
            f"Тел: {phone}\n"
            f"User ID: {user.id}\n\n"
            f"Фикр матни:\n{text}"
        )
        await context.bot.send_message(chat_id=ADMIN_CHAT_ID, text=admin_msg)
        await update.message.reply_text(
            "Фикрингиз учун раҳмат!",
            reply_markup=main_inline_menu(context)
        )
        return

    await update.message.reply_text("Хабарингиз қабул қилинди.")

async def error_handler(update: object, context: ContextTypes.DEFAULT_TYPE) -> None:
    logger.error(msg="Exception while handling an update:", exc_info=context.error)
    if isinstance(update, Update) and update.effective_user:
        try:
            await context.bot.send_message(
                chat_id=update.effective_user.id,
                text="Хатолик юз берди. Илтимос, кейинроқ қайта уриниб кўринг."
            )
        except Exception as e:
            logger.error(f"Failed to send error message to user: {e}")

# ----------------------------------------------------
# Админ панел ва буюртмалар бошқаруви
# ----------------------------------------------------
async def admin_panel(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_CHAT_ID:
        await update.message.reply_text("Сиз админ эмассиз.")
        return
    keyboard = [
        [InlineKeyboardButton("Янги буюртмалар", callback_data="admin_new_orders:1")],
        [InlineKeyboardButton("Барча буюртмалар", callback_data="admin_all_orders:1")]
    ]
    await update.message.reply_text("Админ панел:", reply_markup=InlineKeyboardMarkup(keyboard))

async def admin_handle_callbacks(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    if update.effective_user.id != ADMIN_CHAT_ID:
        await query.edit_message_text("Узр, сиз админ эмассиз.")
        return

    data = query.data
    if data.startswith("admin_new_orders"):
        _, page_str = data.split(":")
        page = int(page_str)
        
        start_idx = (page - 1) * 10
        end_idx = start_idx + 10
        subset, total_count = await get_admin_orders_paginated('yangi', start_idx, end_idx)

        if not subset:
            await query.edit_message_text(
                "Бу ерда буюртма топилмади.",
                reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("⬅️ Орқага", callback_data="admin_back")]])
            )
            return

        text = "Янги буюртмалар (охиргиси аввал):\n\n"
        for order in subset:
            text += f"Буюртма ID: {order.order_id}, Сумма: {order.total_amount} сўм, ФИО: {order.customer_name}\n"
            text += f"📄 Деталлар: /order_detail_{order.order_id}\n\n"

        buttons = []
        nav_buttons = []
        if page > 1:
            nav_buttons.append(InlineKeyboardButton("◀️ Олдинги", callback_data=f"admin_new_orders:{page-1}"))
        if end_idx < total_count:
            nav_buttons.append(InlineKeyboardButton("Кейинги ▶️", callback_data=f"admin_new_orders:{page+1}"))
        if nav_buttons:
            buttons.append(nav_buttons)

        buttons.append([InlineKeyboardButton("⬅️ Орқага", callback_data="admin_back")])
        await query.edit_message_text(text, reply_markup=InlineKeyboardMarkup(buttons))

    elif data.startswith("admin_all_orders"):
        _, page_str = data.split(":")
        page = int(page_str)

        start_idx = (page - 1) * 10
        end_idx = start_idx + 10
        subset, total_count = await get_admin_orders_paginated('all', start_idx, end_idx)

        if not subset:
            await query.edit_message_text(
                "Бу ерда буюртма топилмади.",
                reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton("⬅️ Орқага", callback_data="admin_back")]])
            )
            return

        text = "Барча буюртмалар (охиргиси аввал):\n\n"
        for order in subset:
            text += f"Буюртма ID: {order.order_id}, Статус: {order.get_status_display_with_icon()}, Сумма: {order.total_amount} сўм\n"
            text += f"📄 Деталлар: /order_detail_{order.order_id}\n\n"

        buttons = []
        nav_buttons = []
        if page > 1:
            nav_buttons.append(InlineKeyboardButton("◀️ Олдинги", callback_data=f"admin_all_orders:{page-1}"))
        if end_idx < total_count:
            nav_buttons.append(InlineKeyboardButton("Кейинги ▶️", callback_data=f"admin_all_orders:{page+1}"))
        if nav_buttons:
            buttons.append(nav_buttons)

        buttons.append([InlineKeyboardButton("⬅️ Орқага", callback_data="admin_back")])
        await query.edit_message_text(text, reply_markup=InlineKeyboardMarkup(buttons))

    elif data == "admin_back":
        keyboard = [
            [InlineKeyboardButton("Янги буюртмалар", callback_data="admin_new_orders:1")],
            [InlineKeyboardButton("Барча буюртмалар", callback_data="admin_all_orders:1")]
        ]
        await query.edit_message_text("Админ панел:", reply_markup=InlineKeyboardMarkup(keyboard))

async def order_detail_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_CHAT_ID:
        await update.message.reply_text("Узр, сиз админ эмассиз.")
        return

    text = update.message.text
    if not text.startswith("/order_detail_"):
        return

    oid = text.replace("/order_detail_", "")
    try:
        order = await sync_to_async(Order.objects.get)(order_id=oid)
    except Order.DoesNotExist:
        await update.message.reply_text("Бундай буюртма мавжуд эмас.")
        return

    text_resp = (
        f"Буюртма #{order.order_id}\n"
        f"Статус: {order.get_status_display_with_icon()}\n"
        f"Исм: {order.customer_name}\n"
        f"Тел: {order.customer_phone}\n"
        f"Сумma: {order.total_amount} сўм\n"
    )
    if order.address:
        text_resp += f"Манзил: {order.address}\n"
    else:
        text_resp += "Манзил: Фақат локация\n"
    text_resp += f"Тўлов: {order.payment_method}\n\nМаҳсулотлар:\n"

    order_items = await sync_to_async(list)(order.items.all())
    for item in order_items:
        text_resp += f"{item.product.name} - {item.quantity} та - {item.total_price} сўм\n"

    st = order.status
    if st in ['yetkazildi', 'bekor']: # Using Django model status values
        keyboard = [[InlineKeyboardButton("⬅️ Орқага", callback_data="admin_back")]]
    else:
        keyboard = [
            [
                InlineKeyboardButton("✅ Тасдиқланган", callback_data=f"set_status:{oid}:tasdiqlangan"),
                InlineKeyboardButton("👨‍🍳 Тайёрланмоқда", callback_data=f"set_status:{oid}:tayyorlanmoqda"),
                InlineKeyboardButton("🍽️ Тайёр", callback_data=f"set_status:{oid}:tayyor")
            ],
            [
                InlineKeyboardButton("🚚 Етказилди", callback_data=f"set_status:{oid}:yetkazildi"),
                InlineKeyboardButton("❌ Бекор қилинган", callback_data=f"set_status:{oid}:bekor")
            ],
            [InlineKeyboardButton("⬅️ Орқага", callback_data="admin_back")]
        ]
    await update.message.reply_text(text_resp, reply_markup=InlineKeyboardMarkup(keyboard))

async def set_order_status(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()

    try:
        _, oid, new_status = query.data.split(":")
        if update.effective_user.id != ADMIN_CHAT_ID:
            await query.edit_message_text("Узр, сиз админ эмассиз.")
            return

        try:
            order = await sync_to_async(Order.objects.get)(order_id=oid)
        except Order.DoesNotExist:
            await query.edit_message_text("Бундай буюртма мавжуд эмас.")
            return

        old_status = order.status
        order.status = new_status
        order.updated_at = timezone.now()
        if new_status == 'tayyor':
            order.estimated_time = timezone.now()
        await sync_to_async(order.save)()

        # Send WebSocket update to Django dashboard
        channel_layer = get_channel_layer()
        await channel_layer.group_send(
            'kitchen_orders',
            {
                'type': 'order_update',
                'order_id': order.order_id,
                'status': order.status,
                'old_status': old_status,
                'message': f"Buyurtma #{order.order_id} holati o'zgartirildi: {order.get_status_display_with_icon()}"
            }
        )

        # Notify user if telegram_user_id is available
        if order.telegram_user_id:
            user_id = int(order.telegram_user_id)
            status_emoji = {
                'yangi': '🆕',
                'tasdiqlangan': '✅',
                'tayyorlanmoqda': '👨‍🍳',
                'tayyor': '🍽️',
                'yetkazildi': '🚚',
                'bekor': '❌',
            }
            emoji = status_emoji.get(new_status, "")
            try:
                await context.bot.send_message(
                    chat_id=user_id,
                    text=f"{emoji} Буюртмангиз #{oid} ҳолати ўзгарди: {order.get_status_display_with_icon()}"
                )
            except Exception as e:
                logger.error(f"Failed to send status update to user {user_id} for order {oid}: {e}")
        else:
            logger.warning(f"Order {oid} has no telegram_user_id, cannot notify customer.")

        # Update admin message
        text_resp = (
            f"Буюртма #{order.order_id}\n"
            f"Статус: {order.get_status_display_with_icon()}\n"
            f"Исм: {order.customer_name}\n"
            f"Тел: {order.customer_phone}\n"
            f"Сумma: {order.total_amount} сўм\n"
        )
        if order.address:
            text_resp += f"Манзил: {order.address}\n"
        else:
            text_resp += "Манзил: Фақат локация\n"
        text_resp += f"Тўлов: {order.payment_method}\n\nМаҳсулотлар:\n"

        order_items = await sync_to_async(list)(order.items.all())
        for item in order_items:
            text_resp += f"{item.product.name} - {item.quantity} та - {item.total_price} сўм\n"

        text_resp += f"\nЖами: {order.total_amount} сўм\n"

        if new_status in ['yetkazildi', 'bekor']:
            keyboard = [[InlineKeyboardButton("⬅️ Орқага", callback_data="admin_back")]]
        else:
            keyboard = [
                [
                    InlineKeyboardButton("✅ Тасдиқланган", callback_data=f"set_status:{oid}:tasdiqlangan"),
                    InlineKeyboardButton("👨‍🍳 Тайёрланмоқда", callback_data=f"set_status:{oid}:tayyorlanmoqda"),
                    InlineKeyboardButton("🍽️ Тайёр", callback_data=f"set_status:{oid}:tayyor")
                ],
                [
                    InlineKeyboardButton("🚚 Етказилди", callback_data=f"set_status:{oid}:yetkazildi"),
                    InlineKeyboardButton("❌ Бекор қилинган", callback_data=f"set_status:{oid}:bekor")
                ],
                [InlineKeyboardButton("⬅️ Орқага", callback_data="admin_back")]
            ]

        await query.edit_message_text(
            text_resp,
            reply_markup=InlineKeyboardMarkup(keyboard)
        )

    except Exception as e:
        logger.error(f"Хатолик юз берди: {e}")
        await query.edit_message_text(f"Хатолик юз берди: {str(e)}")

async def admin_confirm_order(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    try:
        _, order_id = query.data.split(":")
        try:
            order = await sync_to_async(Order.objects.get)(order_id=order_id)
        except Order.DoesNotExist:
            await query.edit_message_text("Буюртма топилмади!")
            return

        old_status = order.status
        order.status = 'tasdiqlangan'
        order.updated_at = timezone.now()
        await sync_to_async(order.save)()

        # Send WebSocket update to Django dashboard
        channel_layer = get_channel_layer()
        await channel_layer.group_send(
            'kitchen_orders',
            {
                'type': 'order_update',
                'order_id': order.order_id,
                'status': order.status,
                'old_status': old_status,
                'message': f"Buyurtma #{order.order_id} holati o'zgartirildi: {order.get_status_display_with_icon()}"
            }
        )

        # Notify user if telegram_user_id is available
        if order.telegram_user_id:
            user_id = int(order.telegram_user_id)
            try:
                await context.bot.send_message(chat_id=user_id, text=f"✅ Буюртмangiz #{order_id} тасдиқланди!")
            except Exception as e:
                logger.error(f"Failed to send confirmation to user {user_id} for order {order_id}: {e}")
        else:
            logger.warning(f"Order {order_id} has no telegram_user_id, cannot notify customer.")

        # Update admin message
        text_resp = (
            f"Буюртма #{order.order_id} тасдиқланди!\n"
            f"Статус: {order.get_status_display_with_icon()}\n"
            f"Исм: {order.customer_name}\n"
            f"Тел: {order.customer_phone}\n"
            f"Сумma: {order.total_amount} сўм\n"
        )
        if order.address:
            text_resp += f"Манзил: {order.address}\n"
        else:
            text_resp += "Манзил: Фақат локация\n"
        text_resp += f"Тўлов: {order.payment_method}\n\nМаҳсулотлар:\n"

        order_items = await sync_to_async(list)(order.items.all())
        for item in order_items:
            text_resp += f"{item.product.name} - {item.quantity} та - {item.total_price} сўм\n"

        text_resp += f"\nЖами: {order.total_amount} сўм\n"

        keyboard = [
            [
                InlineKeyboardButton("👨‍🍳 Тайёрланмоқда", callback_data=f"set_status:{order_id}:tayyorlanmoqda"),
                InlineKeyboardButton("🍽️ Тайёр", callback_data=f"set_status:{order_id}:tayyor")
            ],
            [
                InlineKeyboardButton("🚚 Етказилди", callback_data=f"set_status:{order_id}:yetkazildi"),
                InlineKeyboardButton("❌ Бекор қилиш", callback_data=f"set_status:{order_id}:bekor")
            ]
        ]
        await query.edit_message_text(
            text_resp,
            reply_markup=InlineKeyboardMarkup(keyboard)
        )

    except Exception as e:
        logger.error(f"Хатолик юз берди: {e}")
        await query.edit_message_text(f"Хатолик юз берди: {str(e)}")

async def admin_cancel_order(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    try:
        _, order_id = query.data.split(":")
        try:
            order = await sync_to_async(Order.objects.get)(order_id=order_id)
        except Order.DoesNotExist:
            await query.edit_message_text("Буюртма топилмади!")
            return

        old_status = order.status
        order.status = 'bekor'
        order.updated_at = timezone.now()
        await sync_to_async(order.save)()

        # Send WebSocket update to Django dashboard
        channel_layer = get_channel_layer()
        await channel_layer.group_send(
            'kitchen_orders',
            {
                'type': 'order_update',
                'order_id': order.order_id,
                'status': order.status,
                'old_status': old_status,
                'message': f"Buyurtma #{order.order_id} holati o'zgartirildi: {order.get_status_display_with_icon()}"
            }
        )

        if order.telegram_user_id:
            user_id = int(order.telegram_user_id)
            try:
                await context.bot.send_message(
                    chat_id=user_id,
                    text=f"❌ Буюртмangiz #{order_id} бекор қилинди."
                )
            except Exception as e:
                logger.error(f"Failed to send cancellation to user {user_id} for order {order_id}: {e}")
        else:
            logger.warning(f"Order {order_id} has no telegram_user_id, cannot notify customer.")

        await query.edit_message_text(f"Буюртма #{order_id} бекор қилинди!")
    except Exception as e:
        logger.error(f"Хатолик юз берди: {e}")
        await query.edit_message_text(f"Хатолик юз берди: {str(e)}")

# ----------------------------------------------------
# Админ қўшимча командалар
# ----------------------------------------------------
async def add_product_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_CHAT_ID:
        await update.message.reply_text("Сизда рухсат йўқ.")
        return
    try:
        text = update.message.text.split("/add_product ", 1)[1]
        product_info = text.split(" - ")
        if len(product_info) < 3:
            await update.message.reply_text(
                "Формат: /add_product <категория> - <маҳсулот_номи> - <нархи> - <desc> - <расм_url>"
            )
            return
        category_name = product_info[0].strip()
        product_name = product_info[1].strip()
        price = product_info[2].strip()
        desc = product_info[3].strip() if len(product_info) > 3 else ""
        image_url = product_info[4].strip() if len(product_info) > 4 else ""

        category, created = await sync_to_async(Category.objects.get_or_create)(name=category_name)
        if created:
            await update.message.reply_text(f"Янги категория '{category_name}' яратилди.")

        product, created = await sync_to_async(Product.objects.update_or_create)(
            name=product_name,
            defaults={
                'category': category,
                'price': float(price),
                'description': desc,
                'image': image_url, # Store URL directly for simplicity, or handle file upload
                'is_available': True,
                'preparation_time': 15 # Default preparation time
            }
        )
        if created:
            await update.message.reply_text(
                f"{product.name} маҳсулоти {category.name} категориясига {product.price} сўм нархда қўшилди!"
            )
        else:
            await update.message.reply_text(
                f"{product.name} маҳсулоти янгиланди: {category.name} категорияси, {product.price} сўм."
            )

        # Send WebSocket update
        channel_layer = get_channel_layer()
        await channel_layer.group_send(
            'kitchen_orders',
            {
                'type': 'product_update',
                'product_id': product.id,
                'is_available': product.is_available,
                'message': f"Mahsulot {'qo\'shildi' if created else 'yangilandi'}: {product.name}"
            }
        )

    except Exception as e:
        await update.message.reply_text(f"Хатолик юз берди: {str(e)}")

async def add_category_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_CHAT_ID:
        await update.message.reply_text("Сизда рухсат йўқ.")
        return
    try:
        text = update.message.text.split("/add_category ", 1)[1]
        category_name = text.strip()
        category, created = await sync_to_async(Category.objects.get_or_create)(name=category_name)
        if created:
            await update.message.reply_text(f"{category_name} категорияси қўшилди!")
        else:
            await update.message.reply_text(f"{category_name} категорияси олдиндан мавжуд.")
    except Exception as e:
        await update.message.reply_text(f"Хатолик юз берди: {str(e)}")

async def update_order_status_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if update.effective_user.id != ADMIN_CHAT_ID:
        await update.message.reply_text("Сизда рухсат йўқ.")
        return
    args = context.args
    if len(args) < 2:
        await update.message.reply_text("Формат: /update_order_status <order_id> <new_status>")
        return
    try:
        order_id = args[0]
        new_status_uz = " ".join(args[1:]) # Status in Uzbek from command
        
        # Map Uzbek status to Django model status choices
        status_map = {
            'yangi': 'yangi', 'янги': 'yangi',
            'tasdiqlangan': 'tasdiqlangan', 'тасдиқланган': 'tasdiqlangan',
            'tayyorlanmoqda': 'tayyorlanmoqda', 'тайёрланмоқда': 'tayyorlanmoqda',
            'tayyor': 'tayyor', 'тайёр': 'tayyor',
            'yetkazildi': 'yetkazildi', 'етказилди': 'yetkazildi',
            'bekor': 'bekor', 'бекор': 'bekor', 'бекор қилинган': 'bekor'
        }
        new_status_model = status_map.get(new_status_uz.lower())

        if not new_status_model:
            await update.message.reply_text(f"Номаълум статус: {new_status_uz}. Мавжуд статуслар: {', '.join(status_map.keys())}")
            return

        try:
            order = await sync_to_async(Order.objects.get)(order_id=order_id)
        except Order.DoesNotExist:
            await update.message.reply_text("Бундай order_id мавжуд эмас.")
            return

        old_status = order.status
        order.status = new_status_model
        order.updated_at = timezone.now()
        if new_status_model == 'tayyor':
            order.estimated_time = timezone.now()
        await sync_to_async(order.save)()

        # Send WebSocket update to Django dashboard
        channel_layer = get_channel_layer()
        await channel_layer.group_send(
            'kitchen_orders',
            {
                'type': 'order_update',
                'order_id': order.order_id,
                'status': order.status,
                'old_status': old_status,
                'message': f"Buyurtma #{order.order_id} holati o'zgartirildi: {order.get_status_display_with_icon()}"
            }
        )

        if order.telegram_user_id:
            user_id = int(order.telegram_user_id)
            try:
                await context.bot.send_message(
                    chat_id=user_id,
                    text=f"Буюртмangiz ҳолати ўзгарди: {order.get_status_display_with_icon()}"
                )
            except Exception as e:
                logger.error(f"Failed to send status update to user {user_id} for order {order_id}: {e}")
        else:
            logger.warning(f"Order {order_id} has no telegram_user_id, cannot notify customer.")

        await update.message.reply_text("Буюртма ҳолати муваффақиятли ўзгартирилди.")

    except Exception as e:
        await update.message.reply_text(f"Хатолик юз берди: {str(e)}")

# ----------------------------------------------------
# Ботни ишга тушириш
# ----------------------------------------------------
def main():
    if not BOT_TOKEN:
        logger.error("BOT_TOKEN environment variable is not set.")
        return
    if not ADMIN_CHAT_ID:
        logger.error("ADMIN_CHAT_ID environment variable is not set or invalid.")
        return

    application = ApplicationBuilder().token(BOT_TOKEN).build()

    # Командалар
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("admin", admin_panel))
    application.add_handler(CommandHandler("add_product", add_product_handler))
    application.add_handler(CommandHandler("add_category", add_category_handler))
    application.add_handler(CommandHandler("update_order_status", update_order_status_cmd))

    # Админ буюртма деталь: /order_detail_<id>
    application.add_handler(MessageHandler(filters.Regex(r'^/order_detail_\w+$'), order_detail_command))

    # Хабарлар
    application.add_handler(MessageHandler(filters.CONTACT, handle_contact))
    application.add_handler(MessageHandler(filters.LOCATION, handle_location))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))

    # Callback
    application.add_handler(CallbackQueryHandler(admin_confirm_order, pattern="^admin_confirm_order:"))
    application.add_handler(CallbackQueryHandler(admin_cancel_order, pattern="^admin_cancel_order:"))
    application.add_handler(CallbackQueryHandler(set_order_status, pattern="^set_status:"))
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
    application.add_handler(CallbackQueryHandler(payment_method_chosen, pattern="^payment:"))
    application.add_handler(CallbackQueryHandler(final_confirm_order, pattern="^final_confirm_order$"))
    application.add_handler(CallbackQueryHandler(cancel_order, pattern="^cancel_order$"))
    application.add_handler(CallbackQueryHandler(feedback_callback, pattern="^feedback$"))
    application.add_handler(CallbackQueryHandler(show_profile, pattern="^profile$"))
    application.add_handler(CallbackQueryHandler(product_go_back, pattern="^product_go_back:"))

    # Саҳифалаш (Pagination)
    application.add_handler(CallbackQueryHandler(show_user_orders, pattern="^user_orders:"))
    application.add_handler(CallbackQueryHandler(admin_handle_callbacks, pattern="^admin_"))

    # Промо-код (ҳали жорий этилмаган)
    application.add_handler(CallbackQueryHandler(
        lambda u, c: u.answer("Промо-код функцияси ҳали жорий этилмаган", show_alert=True),
        pattern="^promo_not_implemented$")
    )

    application.add_error_handler(error_handler)
    application.run_polling()

if __name__ == '__main__':
    main()
