import socket
import logging
from datetime import datetime
from django.utils import timezone
from .models import BotSettings

logger = logging.getLogger(__name__)

DEPARTMENT_CONFIG = {
    'shashlik': {
        'code': 'shashlik',
        'name': 'Shashlikxona / Mangal',
        'title': '🥩 SHASHLIKCHI CHEKI',
        'subtitle': 'Shashlik va Kaboblar bo\'limi',
        'icon': '🥩',
        'badge_color': '#ef4444',
        'badge_bg': '#fee2e2',
        'printer_attr': 'printer_shashlik_ip',
    },
    'somsa': {
        'code': 'somsa',
        'name': 'Somsaxona / Tandir',
        'title': '🥟 SOMSAXONA CHEKI',
        'subtitle': 'Tandir somsa va nonlar bo\'limi',
        'icon': '🥟',
        'badge_color': '#d97706',
        'badge_bg': '#fef3c7',
        'printer_attr': 'printer_somsa_ip',
    },
    'kitchen': {
        'code': 'kitchen',
        'name': 'Issiq oshxona (Milliy taomlar)',
        'title': '🍲 OSHXONA CHEKI',
        'subtitle': 'Milliy, birinchi, ikkinchi taomlar va salatlar',
        'icon': '🍲',
        'badge_color': '#059669',
        'badge_bg': '#d1fae5',
        'printer_attr': 'printer_kitchen_ip',
    },
    'fastfood': {
        'code': 'fastfood',
        'name': 'Fast-Food & Burgerlar',
        'title': '🍔 FAST-FOOD CHEKI',
        'subtitle': 'Burgerlar, lavashlar, sendvichlar va fri',
        'icon': '🍔',
        'badge_color': '#e11d48',
        'badge_bg': '#ffe4e6',
        'printer_attr': 'printer_fastfood_ip',
    },
    'bar': {
        'code': 'bar',
        'name': 'Desert & Bar (Ichimliklar xonasi)',
        'title': '☕ DESERT & BAR CHEKI',
        'subtitle': 'Shirinliklar, desertlar va ichimliklar xonasi',
        'icon': '☕',
        'badge_color': '#8b5cf6',
        'badge_bg': '#ede9fe',
        'printer_attr': 'printer_bar_ip',
    },
    'kassa': {
        'code': 'kassa',
        'name': 'Kassa (Umumiy hisob-kitob)',
        'title': '🧾 KASSA HISOB CHEKI',
        'subtitle': 'Mijoz uchun to\'liq hisob-kitob cheki',
        'icon': '🧾',
        'badge_color': '#10b981',
        'badge_bg': '#d1fae5',
        'printer_attr': 'printer_kassa_ip',
    },
}


def categorize_order_items(order):
    """
    Buyurtmadagi barcha taomlarni bo'limlar bo'yicha ajratib beradi:
    - shashlik: Shashlikchi chekiga
    - somsa: Somsaxona chekiga
    - kitchen: Issiq oshxona chekiga
    - fastfood: Fast-food va Burgerlar chekiga
    - bar: Desert va Ichimliklar xonasi chekiga
    - kassa: Barcha taomlar jamlangan to'liq hisob cheki
    """
    items = list(order.items.select_related('product', 'product__category').all())
    
    departments = {
        'shashlik': {'config': DEPARTMENT_CONFIG['shashlik'], 'items': [], 'total_qty': 0, 'total_sum': 0},
        'somsa':    {'config': DEPARTMENT_CONFIG['somsa'],    'items': [], 'total_qty': 0, 'total_sum': 0},
        'kitchen':  {'config': DEPARTMENT_CONFIG['kitchen'],  'items': [], 'total_qty': 0, 'total_sum': 0},
        'fastfood': {'config': DEPARTMENT_CONFIG['fastfood'], 'items': [], 'total_qty': 0, 'total_sum': 0},
        'bar':      {'config': DEPARTMENT_CONFIG['bar'],      'items': [], 'total_qty': 0, 'total_sum': 0},
        'kassa':    {'config': DEPARTMENT_CONFIG['kassa'],    'items': [], 'total_qty': 0, 'total_sum': 0},
    }

    for item in items:
        # Determine department using product method
        dept = 'kitchen'
        if hasattr(item.product, 'get_department'):
            dept = item.product.get_department()
        elif item.product and item.product.category:
            dept = item.product.category.get_department()
            
        if dept not in departments:
            dept = 'kitchen'

        item_data = {
            'id': item.id,
            'product_name': item.product.name,
            'quantity': item.quantity,
            'price': float(item.price),
            'total': float(item.total),
            'department': dept,
            'category_name': item.product.category.name if (item.product and item.product.category) else '',
        }

        # Add to station
        departments[dept]['items'].append(item_data)
        departments[dept]['total_qty'] += item.quantity
        departments[dept]['total_sum'] += float(item.total)

        # Kassa includes all items
        departments['kassa']['items'].append(item_data)
        departments['kassa']['total_qty'] += item.quantity
        departments['kassa']['total_sum'] += float(item.total)

    # Active kitchen/station departments that have at least 1 item
    active_stations = [d for d in ['shashlik', 'kitchen', 'bar'] if departments[d]['total_qty'] > 0]

    return {
        'departments': departments,
        'active_stations': active_stations,
        'has_shashlik': departments['shashlik']['total_qty'] > 0,
        'has_kitchen': departments['kitchen']['total_qty'] > 0,
        'has_bar': departments['bar']['total_qty'] > 0,
        'total_items_count': departments['kassa']['total_qty'],
    }


def send_escpos_socket(printer_address, raw_bytes, timeout=0.8):
    """
    Termal printerga TCP socket (port 9100) orqali to'g'ridan-to'g'ri ESC/POS komandalarini yuborish.
    printer_address: '192.168.1.100' yoki '192.168.1.100:9100'
    """
    if not printer_address or not str(printer_address).strip():
        return False, "Printer IP manzili kiritilmagan"

    address_str = str(printer_address).strip()
    if ':' in address_str:
        ip, port_str = address_str.split(':', 1)
        port = int(port_str) if port_str.isdigit() else 9100
    else:
        ip = address_str
        port = 9100

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        sock.connect((ip, port))
        sock.sendall(raw_bytes)
        sock.close()
        logger.info(f"Termal chek muvaffaqiyatli yuborildi: {ip}:{port}")
        return True, f"Chek muvaffaqiyatli yuborildi ({ip}:{port})"
    except Exception as e:
        logger.warning(f"Printerga ulanishda xatolik ({ip}:{port}): {e}")
        return False, f"Printerga ulanib bo'lmadi ({ip}:{port}). Printer o'chiq yoki tarmoqqa ulanmagan."


def format_escpos_slip(order, department, dept_data):
    """
    ESC/POS binary formatida chek shablonini generatsiya qilish
    """
    cfg = DEPARTMENT_CONFIG.get(department, DEPARTMENT_CONFIG['kitchen'])
    items = dept_data.get('items', [])
    if not items:
        return b''

    ESC = b'\x1b'
    GS = b'\x1d'
    
    # Initialize printer
    out = bytearray(ESC + b'@')
    
    # Text encoding: CP866 / UTF-8 fallback
    # Center align header
    out += ESC + b'a\x01'
    
    # Double size for department header
    out += GS + b'!\x11'
    out += f"\n*** {cfg['title']} ***\n".encode('ascii', errors='replace')
    
    # Normal size
    out += GS + b'!\x00'
    out += f"{cfg['subtitle']}\n".encode('ascii', errors='replace')
    out += b"================================\n"
    
    # Order Meta
    out += ESC + b'a\x00' # Left align
    table_str = f"STOL #{order.table_number}" if order.table_number else "STOLSIZ"
    out += f"{table_str.ljust(16)} Zakaz #{order.order_number}\n".encode('ascii', errors='replace')
    
    waiter_name = order.waiter_name or (order.waiter.name if order.waiter else "Ofitsiant")
    out += f"Ofitsiant: {waiter_name}\n".encode('ascii', errors='replace')
    
    now_str = timezone.localtime(order.created_at).strftime('%d.%m.%Y %H:%M')
    out += f"Vaqt: {now_str}\n".encode('ascii', errors='replace')
    out += b"--------------------------------\n"
    
    # Items list
    for item in items:
        # e.g.: [ 3x ] Shashlik qiyma
        qty_str = f"[ {item['quantity']}x ]"
        name_str = item['product_name']
        
        if department == 'kassa':
            # Kassa includes price
            price_str = f"{item['total']:,.0f}".replace(',', ' ')
            line = f"{qty_str} {name_str}\n"
            subline = f"{' ' * 7}{price_str} som\n"
            out += line.encode('ascii', errors='replace')
            out += subline.encode('ascii', errors='replace')
        else:
            # Kitchen / Shashlik / Bar kitchen ticket: Large readable font for cook
            out += GS + b'!\x01' # Double height
            line = f"{qty_str} {name_str}\n"
            out += line.encode('ascii', errors='replace')
            out += GS + b'!\x00' # Reset font
            
    out += b"--------------------------------\n"
    
    # Kassa totals
    if department == 'kassa':
        out += ESC + b'a\x02' # Right align
        out += f"Taomlar: {order.products_total:,.0f} som\n".replace(',', ' ').encode('ascii', errors='replace')
        if order.service_type == 'delivery' and order.delivery_cost:
            out += f"Yetkazib berish: {order.delivery_cost:,.0f} som\n".replace(',', ' ').encode('ascii', errors='replace')
        out += GS + b'!\x11' # Double size
        out += f"JAMI: {order.total_amount:,.0f} som\n".replace(',', ' ').encode('ascii', errors='replace')
        out += GS + b'!\x00'
        out += ESC + b'a\x01' # Center
        status_str = "TO'LANGAN" if order.is_paid else "TO'LANMAGAN"
        out += f"\n[{status_str}]\n".encode('ascii', errors='replace')
    else:
        out += ESC + b'a\x01' # Center
        out += f"Jami taomlar soni: {dept_data['total_qty']} ta\n".encode('ascii', errors='replace')
        out += b"ILTIMOS, TEZ VA SIFATLI TAYYORLANG!\n"

    out += b"================================\n\n\n\n"
    
    # Partial or full cut paper: GS V 66 0
    out += GS + b'V\x42\x00'
    
    return bytes(out)


import threading


def _background_network_print(order_id):
    """Orqa fonda (alohida oqimda) termal printerlarga chek yuborish vazifasi"""
    try:
        from .models import Order
        order = Order.objects.filter(id=order_id).first()
        if not order:
            return

        settings = BotSettings.get_settings()
        if not settings.auto_print_network:
            return

        categorized = categorize_order_items(order)
        depts = categorized['departments']

        # Bo'lim printerlariga (Shashlik, Somsa, Oshxona, Fast-food, Bar)
        for dept_key in ['shashlik', 'somsa', 'kitchen', 'fastfood', 'bar']:
            dept_data = depts[dept_key]
            if dept_data['total_qty'] > 0:
                printer_ip = getattr(settings, f"printer_{dept_key}_ip", None)
                if printer_ip and str(printer_ip).strip():
                    slip_bytes = format_escpos_slip(order, dept_key, dept_data)
                    send_escpos_socket(printer_ip, slip_bytes, timeout=0.6)

        # Kassa printeriga
        if settings.printer_kassa_ip and str(settings.printer_kassa_ip).strip():
            slip_bytes = format_escpos_slip(order, 'kassa', depts['kassa'])
            send_escpos_socket(settings.printer_kassa_ip, slip_bytes, timeout=0.6)
    except Exception as e:
        logger.warning(f"Orqa fonda termal chek yuborishda xatolik: {e}")


def auto_print_order_to_network(order):
    """
    BotSettings dagi avtomatik tarmoq printer sozlamalari asosida
    tegishli printerlarga chek yuborish.
    Buyurtma qabul qilinishini sekinlashtirmaslik uchun alohida daemon thread'da ishlaydi.
    """
    settings = BotSettings.get_settings()
    if not settings.auto_print_network:
        return {'printed': False, 'message': "Avtomatik printerga chiqarish o'chirilgan"}

    # Alohida oqimda yuborish (printer o'chiq yoki tarmoqda bo'lmasa ham buyurtma darhol qabul bo'ladi)
    thread = threading.Thread(target=_background_network_print, args=(order.id,), daemon=True)
    thread.start()

    return {'printed': True, 'async': True}


def format_escpos_test_slip(department, printer_ip):
    """Printer aloqasini tekshirish uchun test cheki generatsiyasi"""
    cfg = DEPARTMENT_CONFIG.get(department, DEPARTMENT_CONFIG['kassa'])
    ESC = b'\x1b'
    GS = b'\x1d'
    out = bytearray(ESC + b'@')
    out += ESC + b'a\x01' # Center
    out += GS + b'!\x11' # Double size
    out += f"\n*** SINOV CHEKI ***\n".encode('ascii', errors='replace')
    out += GS + b'!\x00'
    out += f"{cfg['title']}\n".encode('ascii', errors='replace')
    out += b"================================\n"
    out += ESC + b'a\x00'
    out += f"Bo'lim: {cfg['name']}\n".encode('ascii', errors='replace')
    out += f"Printer IP: {printer_ip}\n".encode('ascii', errors='replace')
    now_str = timezone.localtime().strftime('%d.%m.%Y %H:%M:%S')
    out += f"Vaqt: {now_str}\n".encode('ascii', errors='replace')
    out += b"--------------------------------\n"
    out += b"Printer aloqasi muvaffaqiyatli!\n"
    out += b"Ofitsiant zakazlari ushbu printerga\n"
    out += b"avtomatik tarzda chiqariladi.\n"
    out += b"================================\n\n\n\n"
    out += GS + b'V\x42\x00' # Cut paper
    return bytes(out)

