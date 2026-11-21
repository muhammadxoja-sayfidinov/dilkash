import math
import logging
from datetime import timedelta
from decimal import Decimal
from django.utils import timezone
from .models import Order, CourierProfile, WaiterProfile, StaffNotification

logger = logging.getLogger(__name__)

# Restoran koordinatalari (Markaziy filial)
RESTAURANT_LAT = 41.311081
RESTAURANT_LNG = 69.240562


def calculate_distance_km(lat1, lon1, lat2, lon2):
    """Haversine formulasi bo'yicha ikki nuqta orasidagi masofani (km) hisoblash"""
    if lat1 is None or lon1 is None or lat2 is None or lon2 is None:
        return 999.0
    try:
        r = 6371.0
        dlat = math.radians(float(lat2) - float(lat1))
        dlon = math.radians(float(lon2) - float(lon1))
        a = (math.sin(dlat / 2) ** 2 +
             math.cos(math.radians(float(lat1))) * math.cos(math.radians(float(lat2))) *
             math.sin(dlon / 2) ** 2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return round(r * c, 2)
    except Exception:
        return 999.0


def _clean_phone(phone):
    """Telefon raqamidan faqat oxirgi 9 ta raqamni ajratib olish"""
    digits = ''.join(c for c in str(phone or '') if c.isdigit())
    return digits[-9:] if len(digits) >= 9 else digits


def get_dual_role_staff_phones():
    """Tizimda bir vaqtning o'zida ham Ofitsiant, ham Kuryer roliga ega xodimlar telefonlari"""
    waiter_phones = {
        _clean_phone(w.phone)
        for w in WaiterProfile.objects.filter(is_active=True)
        if _clean_phone(w.phone)
    }
    courier_phones = {
        _clean_phone(c.phone)
        for c in CourierProfile.objects.filter(is_active=True)
        if _clean_phone(c.phone)
    }
    return waiter_phones & courier_phones


def find_best_courier_for_order(order, excluded_courier_ids=None):
    """
    Zakaz taqsimlash qoidasi:
    1. Avval eng yaqin kuryerlarga (Dedicated kuryerlar, masofa <= 5 km, bo'sh/kam yuklangan)
    2. So'ng uzoqroqdagi kuryerlarga (Dedicated kuryerlar, masofa > 5 km)
    3. Hammasi band yoki uzoqda bo'lsa: 2 rollik ofitsiantlarga (ham ofitsiant, ham kuryer bo'lganlar).
       Ularning orasidan kimning zakazi yo'q yoki eng kam bo'lsa, o'shanga yuboriladi.
    
    Qaytaradi: (courier_obj, is_dual_role, active_orders_count, distance_km)
    """
    excluded_ids = set(excluded_courier_ids or [])

    active_couriers = list(CourierProfile.objects.filter(is_active=True).exclude(id__in=excluded_ids))
    active_waiters = list(WaiterProfile.objects.filter(is_active=True))

    waiter_phone_map = {_clean_phone(w.phone): w for w in active_waiters if _clean_phone(w.phone)}
    courier_phone_map = {_clean_phone(c.phone): c for c in active_couriers if _clean_phone(c.phone)}

    dual_role_phones = set(waiter_phone_map.keys()) & set(courier_phone_map.keys())

    # 1 va 2-bosqich: Faqat sof kuryerlar (Dedicated couriers)
    dedicated_couriers = [
        c for c in active_couriers
        if _clean_phone(c.phone) not in dual_role_phones
    ]

    dedicated_candidates = []
    for c in dedicated_couriers:
        # Kuryerning joriy aktiv dastavka zakazlari soni
        active_cnt = Order.objects.filter(
            courier=c,
            status__in=['yolda', 'kuryerda', 'tayor', 'tasdiqlangan', 'yangi']
        ).count()

        dist = calculate_distance_km(
            c.current_lat,
            c.current_lng,
            RESTAURANT_LAT,
            RESTAURANT_LNG
        )
        is_busy = active_cnt >= 2  # 2 tadan ko'p zakazi bo'lsa band hisoblanadi

        dedicated_candidates.append({
            'courier': c,
            'is_dual_role': False,
            'active_orders': active_cnt,
            'distance_km': dist,
            'is_busy': is_busy,
        })

    # Faqat bo'sh/kam yuklangan kuryerlar
    free_dedicated = [c for c in dedicated_candidates if not c['is_busy']]

    # 1. Eng yaqin kuryerlar (masofa <= 5.0 km)
    nearest = [c for c in free_dedicated if c['distance_km'] <= 5.0]
    if nearest:
        nearest.sort(key=lambda x: (x['distance_km'], x['active_orders']))
        best = nearest[0]
        return best['courier'], False, best['active_orders'], best['distance_km']

    # 2. So'ng uzoqroqdagi kuryerlar (masofa 5.0 km - 15.0 km)
    farther = [c for c in free_dedicated if 5.0 < c['distance_km'] <= 15.0]
    if farther:
        farther.sort(key=lambda x: (x['distance_km'], x['active_orders']))
        best = farther[0]
        return best['courier'], False, best['active_orders'], best['distance_km']

    # 3. Hammasi band yoki uzoqda bo'lsa: 2 rollik ofitsiantlarga
    dual_candidates = []
    for ph in dual_role_phones:
        w_prof = waiter_phone_map.get(ph)
        c_prof = courier_phone_map.get(ph)
        if not c_prof or c_prof.id in excluded_ids:
            continue

        # Ofitsiantning aktiv stollari/zakazlari
        waiter_active_cnt = Order.objects.filter(
            waiter=w_prof,
            status__in=['yangi', 'tasdiqlangan', 'tayor']
        ).count() if w_prof else 0

        # Kuryer sifatida olgan dastavkalari
        courier_active_cnt = Order.objects.filter(
            courier=c_prof,
            status__in=['yolda', 'kuryerda', 'tayor']
        ).count()

        total_active = waiter_active_cnt + courier_active_cnt
        dual_candidates.append({
            'courier': c_prof,
            'waiter': w_prof,
            'is_dual_role': True,
            'active_orders': total_active,
            'waiter_orders': waiter_active_cnt,
            'courier_orders': courier_active_cnt,
            'distance_km': 0.0,
        })

    # "kimning zakazi yo'q yoki kam bo'lsa o'shanga kelsin"
    if dual_candidates:
        dual_candidates.sort(key=lambda x: (x['active_orders'], x['courier_orders']))
        best_dual = dual_candidates[0]
        return best_dual['courier'], True, best_dual['active_orders'], 0.0

    # Agar 2-rollik ofitsiant ham topilmasa, mavjud bo'lgan eng kam yuklangan sof kuryerga
    if dedicated_candidates:
        dedicated_candidates.sort(key=lambda x: (x['active_orders'], x['distance_km']))
        best = dedicated_candidates[0]
        return best['courier'], False, best['active_orders'], best['distance_km']

    return None, False, 0, 999.0


def dispatch_delivery_order(order, excluded_courier_ids=None):
    """
    Yetkazib berish buyurtmasini eng munosib kuryer yoki 2-rollik ofitsiantga taqsimlash
    va xabarnoma (DeepLink bilan) yaratish.
    """
    if not order or order.service_type != 'delivery':
        return None

    # Agar allaqachon kuryeri bo'lsa yoki yakunlangan bo'lsa, qayta taqsimlanmaydi
    if order.courier or order.status in ['yetkazildi', 'yakunlandi', 'bekor_qilindi']:
        return None

    courier, is_dual, active_count, dist = find_best_courier_for_order(order, excluded_courier_ids)
    if not courier:
        logger.warning(f"Buyurtma #{order.order_number} uchun bo'sh kuryer yoki 2-rollik ofitsiant topilmadi!")
        return None

    # DeepLink formati:
    # dilkash://courier/order/{order.id}?action=accept
    deeplink = f"dilkash://courier/order/{order.id}?action=accept"

    if is_dual:
        title = "🔔 Yangi dastavka buyurtmasi (Ofitsiant+Kuryer)!"
        message = (
            f"Zakaz #{order.order_number} bor ({order.total_amount:,.0f} so'm). "
            f"Qabul qilasanmi? (Hozirda sizda {active_count} ta aktiv zakaz bor)"
        )
    else:
        title = "🔔 Yangi dastavka buyurtmasi!"
        dist_info = f" ({dist:.1f} km masofada)" if dist < 100 else ""
        message = (
            f"Zakaz #{order.order_number} bor ({order.total_amount:,.0f} so'm){dist_info}. "
            f"Qabul qilasanmi?"
        )

    # Avvalgi faol takliflarni eskirgan deb belgilash
    StaffNotification.objects.filter(
        order=order,
        notification_type='delivery_offer',
        is_accepted__isnull=True
    ).update(is_accepted=False, is_read=True)

    # Yangi xabarnomani saqlash
    w_prof = WaiterProfile.objects.filter(phone__icontains=_clean_phone(courier.phone)).first()
    notif = StaffNotification.objects.create(
        phone=courier.phone,
        courier=courier,
        waiter=w_prof if is_dual else None,
        order=order,
        title=title,
        message=message,
        notification_type='delivery_offer',
        deeplink=deeplink,
        is_dual_role_prompt=is_dual,
        is_read=False,
        is_accepted=None,
        expires_at=timezone.now() + timedelta(minutes=5)
    )

    logger.info(
        f"Buyurtma #{order.order_number} '{courier.name}' ga taqsimlandi "
        f"(dual_role={is_dual}, active={active_count}, dist={dist}km, notif_id={notif.id})"
    )
    return notif


def respond_to_dispatch_offer(notif_id, action, staff_phone=None):
    """
    Kuryer yoki 2-rollik ofitsiantning taklifga javobini qayta ishlash:
    - 'accept': buyurtmani kuryerga biriktirish va 'yolda'/'tayor' qilish
    - 'decline': taklifni rad etish va avtomatik ravishda navbatdagi kuryerga taqsimlash
    """
    notif = StaffNotification.objects.filter(id=notif_id).select_related('order', 'courier').first()
    if not notif:
        return {'success': False, 'message': "Xabarnoma topilmadi!"}

    order = notif.order
    courier = notif.courier

    if not order:
        return {'success': False, 'message': "Buyurtma topilmadi!"}

    if action == 'accept':
        # Allaqachon boshqa kuryer olgan bo'lsa tekshirish
        if order.courier and order.courier.id != (courier.id if courier else 0):
            notif.is_accepted = False
            notif.is_read = True
            notif.save(update_fields=['is_accepted', 'is_read'])
            return {
                'success': False,
                'message': f"#{order.order_number} buyurtma boshqa kuryer ({order.courier_name}) tomonidan qabul qilingan!"
            }

        order.courier = courier
        order.courier_name = courier.name if courier else "Kuryer"
        if order.status in ['yangi', 'tasdiqlangan']:
            # Oshxona tayyorlagan bo'lsa yoki tayyor bo'lish jarayonida
            pass
        order.save(update_fields=['courier', 'courier_name'])

        notif.is_accepted = True
        notif.is_read = True
        notif.save(update_fields=['is_accepted', 'is_read'])

        return {
            'success': True,
            'message': f"#{order.order_number} raqamli buyurtma sizga muvaffaqiyatli biriktirildi!",
            'order_id': order.id,
            'order_number': order.order_number,
            'total_amount': float(order.total_amount),
            'deeplink': f"dilkash://courier/order/{order.id}",
            'is_dual_role': notif.is_dual_role_prompt,
        }

    elif action == 'decline':
        notif.is_accepted = False
        notif.is_read = True
        notif.save(update_fields=['is_accepted', 'is_read'])

        # Navbatdagi kuryerga avtomatik taqsimlash (rad etgan kuryerni chiqarib tashlagan holda)
        next_notif = dispatch_delivery_order(order, excluded_courier_ids=[courier.id] if courier else None)

        return {
            'success': True,
            'message': f"Buyurtma rad etildi va navbatdagi xodimga yo'naltirildi.",
            'next_dispatched': bool(next_notif),
        }

    return {'success': False, 'message': "Noto'g'ri amal (action)!"}
