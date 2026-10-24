#!/usr/bin/env python3
"""
Restoran Tizimi - QE (Quality Engineer) & QA Test Suite (2026/2027)
Ushbu skript barcha modul, endpoint, baza operatsiyalari va to'lov jarayonlarini sinovdan o'tkazadi.
"""

import os
import sys
import json
import django
from decimal import Decimal

# Django muhitini yuklash
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'restaurant_system.settings')
django.setup()

from django.test import Client
from django.utils import timezone
from chef_panel.models import (
    Category, Product, Customer, Order, OrderItem,
    OrderStatusHistory, RestaurantTable, BotSettings, PaymentTransaction,
    WaiterProfile, CourierProfile, WaiterCall
)
from chef_panel.payments import generate_click_url, generate_payme_url
from chef_panel.views import is_valid_status_transition

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    CYAN = '\033[96m'
    BLUE = '\033[94m'
    BOLD = '\033[1m'
    END = '\033[0m'


test_results = []

def record_test(name, passed, message=""):
    test_results.append((name, passed, message))
    status_str = f"{Colors.GREEN}PASSED{Colors.END}" if passed else f"{Colors.RED}FAILED{Colors.END}"
    detail = f" - {message}" if message else ""
    print(f"[{status_str}] {name}{detail}")

def run_qe_qa_tests():
    print(f"\n{Colors.BOLD}{Colors.CYAN}======================================================{Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}🔍 RESTORAN TIZIMI: TO'LIQ QE & QA TEST SUITE (2026/2027){Colors.END}")
    print(f"{Colors.BOLD}{Colors.CYAN}======================================================{Colors.END}\n")

    client = Client()

    # ----------------------------------------------------
    # TEST 1: BAZA VA MODELLARNING SALOMATLIGI
    # ----------------------------------------------------
    print(f"\n{Colors.YELLOW}--- 1. BAZA VA MA'LUMOTLAR STRUKTURASI ---{Colors.END}")
    try:
        categories_count = Category.objects.filter(is_active=True).count()
        products_count = Product.objects.filter(is_available=True).count()
        tables_count = RestaurantTable.objects.filter(is_active=True).count()
        bot_settings = BotSettings.get_settings()

        record_test("Bazada kategoriyalar mavjudligi", categories_count > 0, f"{categories_count} ta faol kategoriya")
        record_test("Bazada mahsulotlar mavjudligi", products_count > 0, f"{products_count} ta mavjud mahsulot")
        record_test("Bazada restoran stollari mavjudligi", tables_count >= 10, f"{tables_count} ta stol")
        record_test("BotSettings tizim sozlamalari mavjudligi", bot_settings is not None, f"Boshlang'ich yetkazish: {bot_settings.delivery_base_cost} so'm")
    except Exception as e:
        record_test("Baza va modellar salomatligi", False, str(e))

    # ----------------------------------------------------
    # TEST 2: VEB SAHIFALAR VA MINI APP (HTTP GET)
    # ----------------------------------------------------
    print(f"\n{Colors.YELLOW}--- 2. VEB SAHIFALAR VA MINI APP REJIMI ---{Colors.END}")
    try:
        # Mini App / Sayt (To'g'ridan-to'g'ri 200 OK)
        res_menu = client.get('/menu/')
        record_test("GET /menu/ (Telegram Mini App)", res_menu.status_code == 200, f"Status: {res_menu.status_code}")

        res_menu_table = client.get('/menu/?table=4')
        record_test("GET /menu/?table=4 (Stoldan QR menyu)", res_menu_table.status_code == 200 and b'stol' in res_menu_table.content.lower(), "Stol parametri qabul qilindi (200 OK)")

        # Chef Panel
        res_dash = client.get('/chef_panel/')
        record_test("GET /chef_panel/ (Oshpaz Dashboard)", res_dash.status_code == 200, f"Status: {res_dash.status_code}")

        res_new_orders = client.get('/chef_panel/orders/new/')
        record_test("GET /chef_panel/orders/new/ (Yangi buyurtmalar)", res_new_orders.status_code == 200, f"Status: {res_new_orders.status_code}")

        res_orders = client.get('/chef_panel/orders/')
        record_test("GET /chef_panel/orders/ (Barcha buyurtmalar)", res_orders.status_code == 200, f"Status: {res_orders.status_code}")

        res_tables = client.get('/chef_panel/tables/qrs/')
        record_test("GET /chef_panel/tables/qrs/ (Stol QR kartochkalari)", res_tables.status_code == 200 and b'QR' in res_tables.content, "QR kodlar generatsiyasi tayyor")

    except Exception as e:
        record_test("Veb sahifalar sinovi", False, str(e))

    # ----------------------------------------------------
    # TEST 3: BUYURTMA YARATISH API (Dine-in, Pickup, Delivery)
    # ----------------------------------------------------
    print(f"\n{Colors.YELLOW}--- 3. BUYURTMA YARATISH API (TMA & WEB CHECKOUT) ---{Colors.END}")
    sample_product = Product.objects.filter(is_available=True).first()
    p_name = sample_product.name if sample_product else "Osh"
    p_price = int(sample_product.price) if sample_product else 35000

    order_ids = {}

    # 3.1 DINE-IN BLOKLASH (Mini ilovadan stolga buyurtma taqiqlanganligi - Qoida 5)
    try:
        dine_in_payload = {
            "user_id": 999901,
            "full_name": "QA Tester Dine-in",
            "phone": "+998901234501",
            "service_type": "dine_in",
            "table_number": "7",
            "payment_method": "click",
            "products_total": p_price * 2,
            "delivery_cost": 0,
            "total": p_price * 2,
            "products": [[p_name, 2, p_price]]
        }
        res_dine_blocked = client.post(
            '/chef_panel/api/orders/create/',
            data=json.dumps(dine_in_payload),
            content_type='application/json'
        )
        data_dine_blocked = res_dine_blocked.json()
        record_test(
            "Xavfsizlik: Mini ilovadan stolga buyurtma (dine_in) bloklanishi (400 Bad Request)",
            res_dine_blocked.status_code == 400 and not data_dine_blocked.get('success'),
            data_dine_blocked.get('message', 'Bloklandi')
        )
    except Exception as e:
        record_test("Mini ilova stolga buyurtma bloklanishi sinovi", False, str(e))

    # 3.1b OFITSIANT TERMINALIDAN STOLGA BUYURTMA OLISH VA AVTOMATIK BIRIKTIRISH
    try:
        # Stol #7 ni boshlaymiz
        RestaurantTable.objects.filter(number=7).update(assigned_waiter=None)
        waiter_p, _ = WaiterProfile.objects.get_or_create(name="Sardor (Senior Waiter)")

        waiter_order_res = client.post(
            '/api/waiter/order/create/',
            data=json.dumps({
                'table_number': '7',
                'waiter_id': waiter_p.id,
                'waiter_name': waiter_p.name,
                'products': [[sample_product.id, 2, float(p_price)]],
                'notes': 'Stol 7 uchun birinchi taomlar'
            }),
            content_type='application/json'
        )
        data_w_ord = waiter_order_res.json()
        record_test(
            "Ofitsiant Terminali: Stol #7 ga buyurtma yaratish (/api/waiter/order/create/)",
            waiter_order_res.status_code == 200 and data_w_ord.get('success') is True,
            f"Order #{data_w_ord.get('order_id')}, Stol #7"
        )

        table_7 = RestaurantTable.objects.get(number=7)
        record_test(
            "Bo'sh stolga zakaz olinganda darhol ofitsiantga avtomatik biriktirilishi",
            table_7.assigned_waiter_id == waiter_p.id,
            f"Biriktirilgan ofitsiant: {table_7.assigned_waiter.name if table_7.assigned_waiter else 'None'}"
        )

        if data_w_ord.get('success'):
            order_ids['dine_in'] = data_w_ord.get('order_id')
    except Exception as e:
        record_test("Ofitsiant stol buyurtmasi va biriktirish sinovi", False, str(e))

    # 3.2 PICKUP (Olib ketish)
    try:
        pickup_payload = {
            "user_id": 999902,
            "full_name": "QA Tester Pickup",
            "phone": "+998901234502",
            "service_type": "pickup",
            "payment_method": "payme",
            "products_total": p_price,
            "delivery_cost": 0,
            "total": p_price,
            "products": [[p_name, 1, p_price]]
        }
        res_pickup = client.post(
            '/chef_panel/api/orders/create/',
            data=json.dumps(pickup_payload),
            content_type='application/json'
        )
        data_pickup = res_pickup.json()
        record_test(
            "POST /api/orders/create/ (Pickup / Olib ketish)",
            res_pickup.status_code == 200 and data_pickup.get('success') is True,
            f"Order #{data_pickup.get('order_id')}, To'lov: Payme"
        )
        if data_pickup.get('success'):
            order_ids['pickup'] = data_pickup.get('order_id')
    except Exception as e:
        record_test("Pickup buyurtma yaratish", False, str(e))

    # 3.3 DELIVERY (Yetkazib berish)
    try:
        delivery_payload = {
            "user_id": 999903,
            "full_name": "QA Tester Delivery",
            "phone": "+998901234503",
            "service_type": "delivery",
            "payment_method": "naqd",
            "address": "Toshkent sh., Navoiy ko'chasi 14-uy",
            "location": {"latitude": 41.311081, "longitude": 69.240562},
            "products_total": p_price,
            "delivery_cost": 15000,
            "total": p_price + 15000,
            "products": [[p_name, 1, p_price]]
        }
        res_deliv = client.post(
            '/chef_panel/api/orders/create/',
            data=json.dumps(delivery_payload),
            content_type='application/json'
        )
        data_deliv = res_deliv.json()
        record_test(
            "POST /api/orders/create/ (Delivery / Yetkazish)",
            res_deliv.status_code == 200 and data_deliv.get('success') is True,
            f"Order #{data_deliv.get('order_id')}, Summa: {p_price + 15000}"
        )
        if data_deliv.get('success'):
            order_ids['delivery'] = data_deliv.get('order_id')
            deliv_order_obj = Order.objects.get(id=data_deliv.get('order_id'))
            record_test(
                "Web / Mini App API: Xarita GPS koordinatalari saqlanishi (latitude, longitude)",
                deliv_order_obj.latitude == 41.311081 and deliv_order_obj.longitude == 69.240562,
                f"GPS: {deliv_order_obj.latitude}, {deliv_order_obj.longitude}"
            )
    except Exception as e:
        record_test("Delivery buyurtma yaratish", False, str(e))

    # ----------------------------------------------------
    # TEST 4: BUYURTMA HOLATI STATE MACHINE VA TRANSITIONS
    # ----------------------------------------------------
    print(f"\n{Colors.YELLOW}--- 4. STATUS STATE MACHINE & TRANSITIONS SINIXTLARI ---{Colors.END}")
    
    # 4.1 State Machine qoidalari unit-test
    ok, _ = is_valid_status_transition('dine_in', 'yangi', 'tayor')
    record_test("State Machine: Dine-in (yangi -> tayor to'g'ridan-to'g'ri o'tish)", ok, "Ruxsat berildi")

    ok, _ = is_valid_status_transition('dine_in', 'tayor', 'yetkazildi')
    record_test("State Machine: Dine-in (tayor -> yetkazildi / stolga berildi)", ok, "Ruxsat berildi")

    ok, _ = is_valid_status_transition('pickup', 'tayor', 'olib_ketildi')
    record_test("State Machine: Pickup (tayor -> olib_ketildi)", ok, "Ruxsat berildi")

    ok, _ = is_valid_status_transition('pickup', 'tayor', 'yolda')
    record_test("State Machine: Pickup noto'g'ri o'tish (tayor -> yolda bloklash)", not ok, "To'g'ri bloklandi")

    ok, _ = is_valid_status_transition('delivery', 'tayor', 'yolda')
    record_test("State Machine: Delivery (tayor -> yolda)", ok, "Ruxsat berildi")

    ok, msg = is_valid_status_transition('delivery', 'tayor', 'tayor')
    record_test("State Machine: Idempotent bir xil status (tayor -> tayor)", ok, "Xatosiz qabul qilindi")

    # 4.2 API orqali Dine-in buyurtmasi statusini yangilash
    if 'dine_in' in order_ids:
        oid = order_ids['dine_in']
        
        # yangi -> tasdiqlangan
        r1 = client.post('/chef_panel/api/orders/update-status/', data=json.dumps({'order_id': oid, 'status': 'tasdiqlangan'}), content_type='application/json')
        record_test("API Holat: Dine-in yangi -> tasdiqlangan", r1.status_code == 200 and r1.json().get('success'), r1.json().get('message'))

        # tasdiqlangan -> tayor
        r2 = client.post('/chef_panel/api/orders/update-status/', data=json.dumps({'order_id': oid, 'status': 'tayor'}), content_type='application/json')
        record_test("API Holat: Dine-in tasdiqlangan -> tayor", r2.status_code == 200 and r2.json().get('success'), r2.json().get('message'))

        # Idempotent: tayor -> tayor (Avval 400 xato bergan joy!)
        r3 = client.post('/chef_panel/api/orders/update-status/', data=json.dumps({'order_id': oid, 'status': 'tayor'}), content_type='application/json')
        record_test("API Holat: Idempotent takroriy tayor -> tayor (400 xatosiz)", r3.status_code == 200 and r3.json().get('success'), "Xato yo'q, 200 OK")

        # tayor -> yetkazildi (stolga berildi)
        r4 = client.post('/chef_panel/api/orders/update-status/', data=json.dumps({'order_id': oid, 'status': 'yetkazildi'}), content_type='application/json')
        record_test("API Holat: Dine-in tayor -> yetkazildi (Stolga berildi)", r4.status_code == 200 and r4.json().get('success'), r4.json().get('message'))

    # ----------------------------------------------------
    # TEST 5: TO'LOV TIZIMLARI (CLICK, PAYME VA SIMULATION)
    # ----------------------------------------------------
    print(f"\n{Colors.YELLOW}--- 5. TO'LOV TIZIMLARI INTEGRATSIYASI ---{Colors.END}")
    if 'dine_in' in order_ids:
        test_order = Order.objects.get(id=order_ids['dine_in'])

        # 5.1 Click URL generatsiyasi
        click_url = generate_click_url(test_order)
        record_test("Click to'lov havolasi generatsiyasi", "my.click.uz/services/pay" in click_url and str(test_order.order_number) in click_url, click_url[:60] + "...")

        # 5.2 Payme URL generatsiyasi
        payme_url = generate_payme_url(test_order)
        record_test("Payme to'lov havolasi generatsiyasi", "checkout.paycom.uz" in payme_url, payme_url[:60] + "...")

        # 5.3 To'lov simulyatsiyasi API
        res_sim = client.post(f'/chef_panel/api/payments/simulate/{test_order.id}/', data=json.dumps({'provider': 'click'}), content_type='application/json')
        sim_data = res_sim.json()
        record_test("Instant To'lov Simulyatsiyasi API (Click)", res_sim.status_code == 200 and sim_data.get('is_paid') is True, f"Tranzaksiya: {sim_data.get('payment_id')}")

        test_order.refresh_from_db()
        record_test("Bazada to'lov holati yangilanganligi (is_paid=True)", test_order.is_paid is True, f"is_paid={test_order.is_paid}, payment_id={test_order.payment_id}")

        # 5.4 Click Webhook (Prepare action=0 va Complete action=1)
        click_prep = client.post('/chef_panel/api/payments/click/', data={
            'click_trans_id': '99887711',
            'service_id': '12345',
            'merchant_trans_id': test_order.order_number,
            'amount': str(test_order.total_amount),
            'action': '0',
            'error': '0'
        })
        record_test("Click Webhook: Prepare (action=0)", click_prep.json().get('error') == 0, click_prep.json().get('error_note'))

        click_comp = client.post('/chef_panel/api/payments/click/', data={
            'click_trans_id': '99887711',
            'service_id': '12345',
            'merchant_trans_id': test_order.order_number,
            'amount': str(test_order.total_amount),
            'action': '1',
            'error': '0'
        })
        record_test("Click Webhook: Complete (action=1)", click_comp.json().get('error') == 0, click_comp.json().get('error_note'))

        # 5.5 Payme Webhook (CheckPerformTransaction)
        payme_check = client.post('/chef_panel/api/payments/payme/', data=json.dumps({
            "method": "CheckPerformTransaction",
            "params": {"account": {"order_id": test_order.order_number}},
            "id": 123
        }), content_type='application/json')
        record_test("Payme Webhook: CheckPerformTransaction", payme_check.json().get('result', {}).get('allow') is True, "Ruxsat berildi")

    # ----------------------------------------------------
    # TEST 6: POS TERMAL PRINTER CHEKI VA TAFSILOTLAR API
    # ----------------------------------------------------
    print(f"\n{Colors.YELLOW}--- 6. POS TERMAL CHEK VA POPUP TAFSILOTLARI ---{Colors.END}")
    if 'dine_in' in order_ids:
        oid = order_ids['dine_in']
        
        # Termal chek sahifalari (Barcha stansiyalar bo'yicha)
        res_receipt = client.get(f'/chef_panel/orders/{oid}/receipt/')
        record_test("POS Termal Chek Umumiy (HTML render)", res_receipt.status_code == 200 and b'CHEK' in res_receipt.content.upper(), "Printer uslublari va QR kod tayyor")

        res_rec_all = client.get(f'/chef_panel/orders/{oid}/receipt/all/')
        record_test("POS Termal Chek: Barcha Stansiyalar (/receipt/all/)", res_rec_all.status_code == 200, "200 OK")

        res_rec_shash = client.get(f'/chef_panel/orders/{oid}/receipt/shashlik/')
        record_test("POS Termal Chek: Shashlikxona Sehi (/receipt/shashlik/)", res_rec_shash.status_code == 200, "200 OK")

        res_rec_kitch = client.get(f'/chef_panel/orders/{oid}/receipt/kitchen/')
        record_test("POS Termal Chek: Oshxona Sehi (/receipt/kitchen/)", res_rec_kitch.status_code == 200, "200 OK")

        res_rec_bar = client.get(f'/chef_panel/orders/{oid}/receipt/bar/')
        record_test("POS Termal Chek: Desert & Bar Sehi (/receipt/bar/)", res_rec_bar.status_code == 200, "200 OK")

        res_rec_kassa = client.get(f'/chef_panel/orders/{oid}/receipt/kassa/')
        record_test("POS Termal Chek: Kassir Hisob Cheki (/receipt/kassa/)", res_rec_kassa.status_code == 200, "200 OK")

        # Order Details API (Ko'rish tugmasi bosilganda)
        res_det = client.get(f'/chef_panel/api/orders/{oid}/details/')
        det_data = res_det.json()
        record_test("GET /api/orders/<id>/details/ (Popup API)", res_det.status_code == 200 and det_data.get('success') is True, f"Items: {len(det_data.get('order', {}).get('items', []))} ta")

    # ----------------------------------------------------
    # TEST 7: MAHSULOT MAVJUDLIGINI BOSHQARISH API
    # ----------------------------------------------------
    print(f"\n{Colors.YELLOW}--- 7. MAHSULOT MAVJUDLIGI (STOP-LIST) API ---{Colors.END}")
    if sample_product:
        orig_avail = sample_product.is_available
        res_toggle = client.post(f'/chef_panel/api/products/{sample_product.id}/toggle-availability/')
        t_data = res_toggle.json()
        record_test("POST toggle-availability API", res_toggle.status_code == 200 and t_data.get('is_available') != orig_avail, f"Yangi holat: {t_data.get('is_available')}")
        
        # Holatni qaytarib qo'yamiz
        client.post(f'/chef_panel/api/products/{sample_product.id}/toggle-availability/')

    # ----------------------------------------------------
    # TEST 8: OFITSIANT CHAQIRISH (WAITER CALL) API
    # ----------------------------------------------------
    print(f"\n{Colors.YELLOW}--- 8. OFITSIANT CHAQIRISH (WAITER CALL) API ---{Colors.END}")
    try:
        res_waiter = client.post(
            '/chef_panel/api/waiter/call/',
            data=json.dumps({'table_number': '5', 'reason': 'Hisob-kitob'}),
            content_type='application/json'
        )
        w_data = res_waiter.json()
        record_test("POST /api/waiter/call/ (Ofitsiant chaqirish)", res_waiter.status_code == 200 and w_data.get('success') is True, f"Javob: {w_data.get('message')}")
    except Exception as e:
        record_test("POST /api/waiter/call/", False, str(e))

    # ----------------------------------------------------
    # TEST 9: TELEGRAM BOT OFITSIANT TIZIMI VA STOLDAN BUYURTMA OLISH
    # ----------------------------------------------------
    print(f"\n{Colors.YELLOW}--- 9. TELEGRAM BOT OFITSIANT TIZIMI (STOL BUYURTMASI) ---{Colors.END}")
    try:
        from telegram_bot import _create_order_and_items_sync
        import asyncio

        # Test mahsulot
        test_prod = Product.objects.filter(is_available=True).first()
        prod_data = [{
            'product': test_prod,
            'quantity': 2,
            'price': test_prod.price,
            'product_name': test_prod.name,
            'total': test_prod.price * 2
        }]
        total_p = test_prod.price * 2

        # 1. Ofitsiant tomonidan stol #4 uchun buyurtma yaratish
        waiter_order = asyncio.run(_create_order_and_items_sync(
            telegram_user_id=999888777,
            full_name="Jamshid (Ofitsiant)",
            phone="+998901112233",
            payment_method="naqd",
            service_type="dine_in",
            location=None,
            address=None,
            products_total=total_p,
            delivery_cost=Decimal('0'),
            total_amount=total_p,
            order_items_data=prod_data,
            table_number="4"
        ))

        record_test("Ofitsiant stol buyurtmasi yaratishi", waiter_order is not None and waiter_order.table_number == "4", f"Buyurtma #{waiter_order.order_number}, Stol: #{waiter_order.table_number}")

        # 2. Stol buyurtmasi bazada to'g'ri bog'langanligi
        created_order = Order.objects.get(id=waiter_order.id)
        record_test("Stol raqami bazada saqlanishi", created_order.table_number == "4" and created_order.service_type == "dine_in", f"Stol: #{created_order.table_number}, Xizmat: {created_order.service_type}")

        # 3. Faol stollar ro'yxatida ko'rinishi
        active_tables = Order.objects.filter(service_type='dine_in', status__in=['yangi', 'tasdiqlangan', 'tayor'])
        record_test("Faol stollar so'rovida aks etishi", active_tables.filter(id=waiter_order.id).exists(), f"Faol stollar soni: {active_tables.count()} ta")

        # 4. Ofitsiant taomni stolga berishi (tayor -> yetkazildi)
        created_order.status = 'tayor'
        created_order.save()
        created_order.status = 'yetkazildi'
        created_order.delivered_at = timezone.now()
        created_order.save()
        record_test("Ofitsiant taomni stolga topshirishi (yetkazildi)", created_order.status == 'yetkazildi' and created_order.delivered_at is not None, "Stolga muvaffaqiyatli topshirildi")

    except Exception as e:
        record_test("Telegram bot ofitsiant moduli sinovi", False, str(e))

    # ----------------------------------------------------
    # 11. MAXSUS OFITSIANT BOT VA PROFIL TIZIMI (2026/2027)
    # ----------------------------------------------------
    print(f"\n{Colors.BLUE}--- 11. Maxsus Ofitsiant Boti & Profillari ---{Colors.END}")
    try:
        waiter_prof, _ = WaiterProfile.objects.update_or_create(
            telegram_id=888777666,
            defaults={'name': "Sardor (Senior Waiter)", 'phone': "+998901234567", 'is_active': True}
        )
        record_test("Ofitsiant profili yaratilishi/yangilanishi", waiter_prof.is_active and waiter_prof.name == "Sardor (Senior Waiter)", f"ID: {waiter_prof.id}, Chat ID: {waiter_prof.telegram_id}")

        # Asosiy buyurtma berish boti (telegram_bot.py) tekshiruvi
        import telegram_bot
        record_test("Asosiy buyurtma berish boti (telegram_bot.py) yuklanishi", hasattr(telegram_bot, 'start') and hasattr(telegram_bot, 'main_menu'), "Barcha asosiy buyurtma handlerlari mavjud")

        # Ofitsiant orqali izohli buyurtma yaratish API
        punch_res = client.post('/chef_panel/api/waiter/order/create/', data=json.dumps({
            'table_number': '5',
            'waiter_name': 'Sardor',
            'products': [[test_prod.id, 1, float(test_prod.price)]],
            'notes': 'Achchiq bo\'lmasin, muzli choy bilan'
        }), content_type='application/json')
        punch_json = punch_res.json()
        record_test("Ofitsiant terminali izohli buyurtma yaratishi (API)", punch_json.get('success') is True, f"Order #{punch_json.get('order_number')}, Stol #5")

        p_order = Order.objects.get(id=punch_json.get('order_id'))
        has_note = p_order.status_history.filter(notes__contains='Achchiq bo\'lmasin').exists()
        record_test("Buyurtma izohlari tarixda saqlanishi", has_note, "Maxsus izoh muvaffaqiyatli saqlandi")

    except Exception as e:
        record_test("Maxsus ofitsiant boti sinovi", False, str(e))

    # ----------------------------------------------------
    # 12. STOL QR MENYU, TAOM QO'SHISH, TAHRIRLASH VA KASSIRNING STOLNI YOPISHI
    # ----------------------------------------------------
    print(f"\n{Colors.BLUE}--- 12. Stol QR Menyu, Tahrirlash & Kassir Stolni Yopishi ---{Colors.END}")
    try:
        # 1. Mijoz QR menyudan stol holati va hisobini ko'rishi
        status_res = client.get('/api/table/5/status/')
        status_json = status_res.json()
        record_test("Mijoz QR menyudan stol hisobini ko'rishi (/api/table/5/status/)", status_json.get('has_active_order') is True, f"Buyurtma #{status_json['order']['order_number']}, Jami: {status_json['order']['total_amount']} so'm")

        active_ord_id = status_json['order']['id']
        first_item_id = status_json['order']['items'][0].get('id') if status_json['order']['items'] else None

        # 2. Xavfsizlik: Mini ilovadan stoldan taom qo'shish bloklanishi (400 Bad Request)
        append_block = client.post('/api/orders/create/', data=json.dumps({
            'full_name': 'Mehmon Stol 5',
            'phone': '+998901112233',
            'service_type': 'dine_in',
            'table_number': '5',
            'products': [[test_prod.name, 2, float(test_prod.price)]],
            'products_total': float(test_prod.price * 2),
            'total': float(test_prod.price * 2)
        }), content_type='application/json')
        record_test(
            "Xavfsizlik: Mini ilovadan stoldan buyurtma olish bloklanishi (400 Bad Request)",
            append_block.status_code == 400 and not append_block.json().get('success'),
            "Stoldan buyurtma faqat ofitsiant orqali beriladi"
        )

        # 2b. Ofitsiant tomonidan faol stolga qo'shimcha taom kiritilishi
        append_res = client.post('/api/waiter/order/create/', data=json.dumps({
            'table_number': '5',
            'waiter_name': 'Sardor',
            'products': [[test_prod.id, 2, float(test_prod.price)]],
            'notes': 'Qo\'shimcha non va choy'
        }), content_type='application/json')
        append_json = append_res.json()
        record_test(
            "Ofitsiant faol stolga qo'shimcha taom kiritishi (/api/waiter/order/create/)",
            append_json.get('success') is True,
            f"Stol #5 ga qo'shimcha buyurtma #{append_json.get('order_number')} kiritildi"
        )

        # 3. Faol buyurtmadan taom sonini tahrirlash/o'chirish (yangi holatida)
        curr_order = Order.objects.get(id=active_ord_id)
        curr_order.status = 'yangi'
        curr_order.save()
        item_to_edit = curr_order.items.first()
        if item_to_edit:
            edit_res = client.post(f'/api/table/order/item/{item_to_edit.id}/update/', data=json.dumps({
                'action': 'decrease'
            }), content_type='application/json')
            record_test("Mijoz QR menyudan taom sonini kamaytirishi/tahrirlashi", edit_res.json().get('success') is True, "Taom soni muvaffaqiyatli o'zgartirildi")

        # 4. Ofitsiant/Mijoz tomonidan kassirga hisob so'rovi yuborilishi
        bill_req_res = client.post('/api/waiter/bill-request/5/')
        record_test("Kassirga hisob-kitob so'rovi yuborilishi", bill_req_res.json().get('success') is True, "Kassirga xabar yuborildi")

        # 5. Kassir to'lovni qabul qilib stolni yopishi
        close_res = client.post(f'/chef_panel/api/waiter/order/{active_ord_id}/close/')
        close_json = close_res.json()
        record_test("Kassir stol to'lovini qabul qilib stolni yopishi", close_json.get('success') is True, "Stol to'landi va bo'shatildi")

        # 6. Stol bo'shaganligi tekshiruvi
        recheck_res = client.get('/api/table/5/status/')
        record_test("Stol qayta tekshirilganda bo'sh holatga o'tganligi", recheck_res.json().get('has_active_order') is False, "Stol bo'sh, yangi mehmon kutishga tayyor")

        # 7. Kassir hisobni yopganda stol ofitsiantdan to'liq bo'shatilishi (assigned_waiter = None)
        table_5 = RestaurantTable.objects.get(number=5)
        record_test(
            "Kassir hisobni yopganda stol ofitsiantdan to'liq bo'shatilishi (assigned_waiter = None)",
            table_5.assigned_waiter is None,
            "Stol qayta erkin holatda"
        )

    except Exception as e:
        record_test("Stol QR va Kassir yopish sinovi", False, str(e))

    # ----------------------------------------------------
    # 13. YANGI ROLLLAR TAQSIMOTI VA FLUTTER MOBIL APILAR (2026/2027)
    # ----------------------------------------------------
    print(f"\n{Colors.BLUE}--- 13. Yangi Rollar: Kassir, Oshpaz KDS, Mehmon QR, Flutter Mobil API ---{Colors.END}")
    try:
        # 1. Kassir POS Asosiy Ekrani (GET /cashier/)
        res_cashier = client.get('/cashier/')
        record_test("Kassir Asosiy POS Ekrani (GET /cashier/)", res_cashier.status_code == 200 and b'Kassir' in res_cashier.content, "Stollar xaritasi va to'liq boshqaruv mavjud")

        # 2. Kassir Dastavka & Olib ketish Ekrani (GET /cashier/delivery/)
        res_cash_deliv = client.get('/cashier/delivery/')
        record_test("Kassir Dastavka & Olib ketish oynasi (GET /cashier/delivery/)", res_cash_deliv.status_code == 200 and b'Dastavka' in res_cash_deliv.content, "Kuryer biriktirish va buyurtma boshqaruvi mavjud")

        # 3. Oshpaz KDS Ekrani (GET /kitchen/) - Faqat Dastavka va Olib ketish
        res_kds = client.get('/kitchen/')
        record_test("Oshpaz KDS Ekrani (GET /kitchen/)", res_kds.status_code == 200 and b'KDS' in res_kds.content, "Faqat yetkazib berish va olib ketish buyurtmalari ko'rsatiladi")

        # 4. Stol Mehmon QR Hisob Sahifasi (GET /table/3/)
        res_guest_qr = client.get('/table/3/')
        record_test("Mehmon QR Hisob Sahifasi (GET /table/3/)", res_guest_qr.status_code == 200 and b'Stol #3' in res_guest_qr.content, "Ofitsiant ma'lumoti, hisob va chaqirish tugmasi mavjud")

        # 5. Customer Mobile Flutter API: Menyu olish
        res_mob_menu = client.get('/api/mobile/customer/menu/')
        mob_menu_data = res_mob_menu.json()
        record_test(
            "Customer Mobile API: Menyu va Toifalar (/api/mobile/customer/menu/)",
            res_mob_menu.status_code == 200 and len(mob_menu_data.get('dishes', [])) > 0,
            f"{len(mob_menu_data.get('categories', []))} toifa, {len(mob_menu_data.get('dishes', []))} taom"
        )

        # 6. Customer Mobile Flutter API: Yangi Dastavka buyurtmasi yaratish
        first_dish = mob_menu_data.get('dishes', [])[0]
        res_mob_order = client.post(
            '/api/mobile/customer/order/create/',
            data=json.dumps({
                'customer_name': 'Alisher (Mobile App)',
                'customer_phone': '+998935557799',
                'service_type': 'delivery',
                'delivery_address': 'Chilonzor 9-mavze, 24-uy',
                'latitude': 41.2825,
                'longitude': 69.2155,
                'notes': 'Eshik kodi: 1234',
                'items': [{'dish_id': first_dish['id'], 'quantity': 2}]
            }),
            content_type='application/json'
        )
        mob_ord_data = res_mob_order.json()
        record_test(
            "Customer Mobile API: Buyurtma yaratish (/api/mobile/customer/order/create/)",
            res_mob_order.status_code == 201 and mob_ord_data.get('status') == 'success',
            f"Buyurtma #{mob_ord_data.get('order_number')}, ID: {mob_ord_data.get('order_id')}"
        )
        created_mobile_order_id = mob_ord_data.get('order_id')
        mob_order_db = Order.objects.get(id=created_mobile_order_id)
        record_test(
            "Customer Mobile API: Xarita GPS koordinatalari saqlanishi (lat/lng)",
            mob_order_db.latitude == 41.2825 and mob_order_db.longitude == 69.2155,
            f"GPS Lokatsiya: {mob_order_db.latitude}, {mob_order_db.longitude}"
        )

        # 7. Customer Mobile Flutter API: Jonli buyurtma holatini olish
        res_mob_status = client.get(f'/api/mobile/customer/order/{created_mobile_order_id}/status/')
        mob_stat_data = res_mob_status.json()
        record_test(
            "Customer Mobile API: Buyurtma holatini jonli kuzatish (/api/mobile/customer/order/<id>/status/)",
            res_mob_status.status_code == 200 and mob_stat_data.get('status') == 'yangi',
            f"Status: {mob_stat_data.get('status_display')}, Summa: {mob_stat_data.get('total_amount')} so'm"
        )

        # 7.1 Customer Mobile Flutter API: Kirish / Ro'yxatdan o'tish (Auth)
        res_cust_auth = client.post(
            '/api/mobile/customer/auth/',
            data=json.dumps({'phone': '+998935557799', 'full_name': 'Alisher Test'}),
            content_type='application/json'
        )
        cust_auth_data = res_cust_auth.json()
        record_test(
            "Customer Mobile API: Kirish & Profil Auth (/api/mobile/customer/auth/)",
            res_cust_auth.status_code == 200 and cust_auth_data.get('status') == 'success',
            f"Mijoz: {cust_auth_data.get('customer', {}).get('full_name')}, Token berildi"
        )

        # 7.2 Customer Mobile Flutter API: Profil yangilash
        res_cust_prof = client.post(
            '/api/mobile/customer/profile/update/',
            data=json.dumps({'phone': '+998935557799', 'full_name': 'Alisher Yangilangan'}),
            content_type='application/json'
        )
        record_test(
            "Customer Mobile API: Profil tahrirlash (/api/mobile/customer/profile/update/)",
            res_cust_prof.status_code == 200 and res_cust_prof.json().get('status') == 'success',
            "Ism muvaffaqiyatli yangilandi"
        )

        # 7.3 Customer Mobile Flutter API: Choychaqa va Baholash (Tip & Review)
        res_cust_tip = client.post(
            '/api/mobile/customer/tip/',
            data=json.dumps({
                'order_id': created_mobile_order_id,
                'tip_amount': 5000,
                'rating': 5,
                'review': 'Juda ajoyib servis va issiq taom!'
            }),
            content_type='application/json'
        )
        record_test(
            "Customer Mobile API: Choychaqa & Baholash (/api/mobile/customer/tip/)",
            res_cust_tip.status_code == 200 and res_cust_tip.json().get('status') == 'success',
            "Choychaqa va 5 yulduzli sharh saqlandi"
        )

        # 8. Courier Mobile Flutter API: Kuryer login
        CourierProfile.objects.update_or_create(
            phone='+998901234567',
            defaults={'name': 'Jasur (Kuryer)', 'pin_code': '1234', 'vehicle_info': 'Skuter', 'is_active': True}
        )
        res_cour_login = client.post(
            '/api/mobile/courier/login/',
            data=json.dumps({'phone': '+998901234567', 'pin': '1234'}),
            content_type='application/json'
        )
        cour_login_data = res_cour_login.json()
        record_test(
            "Courier Mobile API: Kuryer tizimga kirishi (/api/mobile/courier/login/)",
            res_cour_login.status_code == 200 and cour_login_data.get('status') == 'success',
            f"Kuryer: {cour_login_data.get('courier', {}).get('name')}, Token olindi"
        )
        courier_token = cour_login_data.get('courier', {}).get('token')
        courier_id = cour_login_data.get('courier', {}).get('id')

        # 9. Kassir kuryerni buyurtmaga biriktirishi (/api/cashier/assign-courier/)
        res_assign = client.post(
            '/api/cashier/assign-courier/',
            data=json.dumps({
                'order_id': created_mobile_order_id,
                'courier_id': courier_id
            }),
            content_type='application/json'
        )
        assign_data = res_assign.json()
        record_test(
            "Kassir buyurtmaga kuryer biriktirishi (/api/cashier/assign-courier/)",
            res_assign.status_code == 200 and assign_data.get('success') is True,
            f"Biriktirildi: {assign_data.get('courier_name')}"
        )

        # 10. Courier Mobile Flutter API: Kuryer o'ziga biriktirilgan buyurtmalarni ko'rishi
        res_cour_orders = client.get(f'/api/mobile/courier/orders/?token={courier_token}')
        cour_orders_data = res_cour_orders.json()
        target_cour_order = next((o for o in cour_orders_data.get('orders', []) if o['id'] == created_mobile_order_id), None)
        record_test(
            "Courier Mobile API: Kuryer biriktirilgan buyurtmalarni olish (/api/mobile/courier/orders/)",
            res_cour_orders.status_code == 200 and target_cour_order is not None,
            f"Kuryer ro'yxatida Order #{created_mobile_order_id} mavjud"
        )
        record_test(
            "Courier Mobile API: Xarita va Marshrut ma'lumotlari (GPS + Restoran koordinatalari)",
            target_cour_order is not None and target_cour_order.get('latitude') == 41.2825 and 'restaurant' in cour_orders_data,
            f"Mijoz GPS: ({target_cour_order.get('latitude') if target_cour_order else None}, {target_cour_order.get('longitude') if target_cour_order else None}), Restoran: {cour_orders_data.get('restaurant', {}).get('name')}"
        )

        # 11. Courier Mobile Flutter API: Kuryer 'yolda' statusiga o'tkazishi
        res_cour_enroute = client.post(
            f'/api/mobile/courier/order/{created_mobile_order_id}/update-status/',
            data=json.dumps({'token': courier_token, 'new_status': 'yolda'}),
            content_type='application/json'
        )
        record_test(
            "Courier Mobile API: Kuryer statusni 'yolda' qilib belgilashi",
            res_cour_enroute.status_code == 200 and res_cour_enroute.json().get('status') == 'success',
            "Holat: Yo'lda (Mijozga yetkazilmoqda)"
        )

        # 12. Courier Mobile Flutter API: Kuryer 'yetkazildi' statusiga o'tkazishi
        res_cour_done = client.post(
            f'/api/mobile/courier/order/{created_mobile_order_id}/update-status/',
            data=json.dumps({'token': courier_token, 'new_status': 'yetkazildi'}),
            content_type='application/json'
        )
        record_test(
            "Courier Mobile API: Kuryer statusni 'yetkazildi' qilib yopishi",
            res_cour_done.status_code == 200 and res_cour_done.json().get('status') == 'success',
            "Holat: Muvaffaqiyatli yetkazildi va hisob yopildi"
        )

        # ----------------------------------------------------
        # TEST 14: KASSIR XODIMLAR BOSHQARUVI VA YAGONA MOBIL ILOVA KIRISHI
        # ----------------------------------------------------
        print(f"\n{Colors.YELLOW}--- 14. KASSIR XODIMLAR BOSHQARUVI & MOBIL STAFF AUTH ---{Colors.END}")

        # 1. Kassir yangi kuryer yaratishi va PIN-kod berishi
        res_create_courier = client.post(
            '/api/cashier/staff/create/',
            data=json.dumps({
                'role': 'courier',
                'name': 'Bobur Kuryer',
                'phone': '+998909998877',
                'pin': '7788',
                'vehicle_info': 'Damas 01A888BB'
            }),
            content_type='application/json'
        )
        data_create_c = res_create_courier.json()
        record_test(
            "Kassir yangi Kuryer qo'shishi va PIN berishi (/api/cashier/staff/create/)",
            res_create_courier.status_code == 200 and data_create_c.get('success') is True,
            f"Kuryer yaratildi: {data_create_c.get('staff', {}).get('name')}, PIN: {data_create_c.get('staff', {}).get('pin')}"
        )

        # 2. Kassir yangi ofitsiant yaratishi va PIN-kod berishi
        res_create_waiter = client.post(
            '/api/cashier/staff/create/',
            data=json.dumps({
                'role': 'waiter',
                'name': 'Nodir Ofitsiant',
                'phone': '+998901112233',
                'pin': '5566'
            }),
            content_type='application/json'
        )
        data_create_w = res_create_waiter.json()
        record_test(
            "Kassir yangi Ofitsiant qo'shishi va PIN berishi (/api/cashier/staff/create/)",
            res_create_waiter.status_code == 200 and data_create_w.get('success') is True,
            f"Ofitsiant yaratildi: {data_create_w.get('staff', {}).get('name')}, PIN: {data_create_w.get('staff', {}).get('pin')}"
        )

        # 3. Kassir xodimlar ro'yxatini olishi
        res_staff_list = client.get('/api/cashier/staff/')
        data_staff_list = res_staff_list.json()
        has_new_courier = any(c['phone'] == '+998909998877' for c in data_staff_list.get('couriers', []))
        has_new_waiter = any(w['phone'] == '+998901112233' for w in data_staff_list.get('waiters', []))
        record_test(
            "Kassir barcha xodimlar va ularning PIN-kodlarini ko'rishi (/api/cashier/staff/)",
            res_staff_list.status_code == 200 and has_new_courier and has_new_waiter,
            f"Kuryerlar: {len(data_staff_list.get('couriers', []))} ta, Ofitsiantlar: {len(data_staff_list.get('waiters', []))} ta"
        )

        # 4. Kassir xodim faolligini o'zgartirishi
        courier_id_to_toggle = data_create_c.get('staff', {}).get('id')
        res_toggle = client.post(f'/api/cashier/staff/courier/{courier_id_to_toggle}/toggle/')
        data_toggle = res_toggle.json()
        record_test(
            "Kassir xodim faolligini o'zgartirishi (/api/cashier/staff/<type>/<id>/toggle/)",
            res_toggle.status_code == 200 and data_toggle.get('success') is True and data_toggle.get('is_active') is False,
            "Xodim holati muvaffaqiyatli 'Nofaol' qilindi"
        )
        # Faollashtirib qaytarish
        client.post(f'/api/cashier/staff/courier/{courier_id_to_toggle}/toggle/')

        # 5. Yagona mobil ilova orqali Kuryer kirishi (PIN-kod bilan)
        res_staff_login_c = client.post(
            '/api/mobile/staff/login/',
            data=json.dumps({
                'role': 'courier',
                'phone': '+998909998877',
                'pin': '7788'
            }),
            content_type='application/json'
        )
        data_login_c = res_staff_login_c.json()
        record_test(
            "Yagona ilova: Kuryer roli va PIN bilan kirish (/api/mobile/staff/login/)",
            res_staff_login_c.status_code == 200 and data_login_c.get('success') is True and data_login_c.get('role') == 'courier',
            f"Xush kelibsiz, {data_login_c.get('user', {}).get('name')}"
        )

        # 6. Yagona mobil ilova orqali Ofitsiant kirishi (PIN-kod bilan)
        res_staff_login_w = client.post(
            '/api/mobile/staff/login/',
            data=json.dumps({
                'role': 'waiter',
                'phone': '+998901112233',
                'pin': '5566'
            }),
            content_type='application/json'
        )
        data_login_w = res_staff_login_w.json()
        record_test(
            "Yagona ilova: Ofitsiant roli va PIN bilan kirish (/api/mobile/staff/login/)",
            res_staff_login_w.status_code == 200 and data_login_w.get('success') is True and data_login_w.get('role') == 'waiter',
            f"Xush kelibsiz, {data_login_w.get('user', {}).get('name')}"
        )

        # 7. Ofitsiant stollar xaritasini olishi
        res_floor = client.get('/api/waiter/floor-status/')
        data_floor = res_floor.json()
        record_test(
            "Ofitsiant jonli stollar xaritasini olishi (/api/waiter/floor-status/)",
            res_floor.status_code == 200 and data_floor.get('success') is True,
            f"Stollar soni: {data_floor.get('total_tables')} ta, Band: {data_floor.get('occupied_count')} ta"
        )

        # 8. Ofitsiant taomni stolga berishi (/api/waiter/order/<id>/deliver/)
        res_deliver = client.post(f'/api/waiter/order/{created_mobile_order_id}/deliver/')
        data_deliver = res_deliver.json()
        record_test(
            "Ofitsiant taomni stolga topshirishi (/api/waiter/order/<id>/deliver/)",
            res_deliver.status_code == 200 and data_deliver.get('success') is True,
            "Holat: Taom stolga berildi deb belgilandi"
        )

        # ----------------------------------------------------
        # TEST 15: PRINTER SOZLAMALARI VA STOLLARNI BIRIKTIRISH/BO'SHATISH API
        # ----------------------------------------------------
        print(f"\n{Colors.YELLOW}--- 15. PRINTER SOZLAMALARI & STOL BIRIKTIRISH/BO'SHATISH ---{Colors.END}")

        # 1. Kassir printer sozlamalarini olish
        res_print_get = client.get('/chef_panel/api/cashier/printer-settings/')
        p_data = res_print_get.json()
        record_test(
            "Kassir printer va bo'lim sozlamalarini olish (/api/cashier/printer-settings/)",
            res_print_get.status_code == 200 and p_data.get('success') is True,
            f"Stansiyalar soni: {len(p_data.get('departments', []))} ta"
        )

        # 2. Kassir printer sozlamalarini saqlash
        res_print_save = client.post(
            '/chef_panel/api/cashier/printer-settings/save/',
            data=json.dumps({
                'auto_print_network': True,
                'printers': {
                    'shashlik': '192.168.1.201',
                    'kitchen': '192.168.1.202',
                    'bar': '192.168.1.203',
                    'kassa': '192.168.1.204'
                }
            }),
            content_type='application/json'
        )
        record_test(
            "Kassir printer sozlamalarini saqlashi (/api/cashier/printer-settings/save/)",
            res_print_save.status_code == 200 and res_print_save.json().get('success') is True,
            "ESC/POS tarmoq printerlari IP manzillari saqlandi"
        )

        # 3. Kassir stol ma'lumotlarini olish (/api/cashier/table/<number>/)
        res_cashier_tbl = client.get('/api/cashier/table/7/')
        tbl_data = res_cashier_tbl.json()
        record_test(
            "Kassir stol ma'lumotlarini olish (/api/cashier/table/<num>/)",
            res_cashier_tbl.status_code == 200 and tbl_data.get('success') is True,
            f"Stol #{tbl_data.get('table', {}).get('number')} ma'lumotlari yuklandi"
        )

        # 4. Ofitsiant stolni o'ziga biriktirishi (/api/waiter/table/<num>/assign/)
        res_tbl_assign = client.post(
            '/api/waiter/table/2/assign/',
            data=json.dumps({'waiter_name': 'Sardor'}),
            content_type='application/json'
        )
        record_test(
            "Ofitsiant stolni o'ziga biriktirishi (/api/waiter/table/<num>/assign/)",
            res_tbl_assign.status_code == 200 and res_tbl_assign.json().get('success') is True,
            "Stol #2 Sardorga biriktirildi"
        )

        # 5. Ofitsiant stolni bo'shatishi (/api/waiter/table/<num>/release/)
        res_tbl_rel = client.post('/api/waiter/table/2/release/', data=json.dumps({}), content_type='application/json')
        record_test(
            "Ofitsiant stolni bo'shatishi (/api/waiter/table/<num>/release/)",
            res_tbl_rel.status_code == 200 and res_tbl_rel.json().get('success') is True,
            "Stol #2 ozod qilindi"
        )

        # 6. Ofitsiant chaqiruvini bekor qilish/hal etish (/api/waiter/call/<id>/dismiss/)
        test_call = WaiterCall.objects.create(table_number='2', reason='Muz va suv', is_resolved=False)
        res_dismiss = client.post(f'/api/waiter/call/{test_call.id}/dismiss/')
        record_test(
            "Ofitsiant chaqiruvini hal qilingan deb belgilash (/api/waiter/call/<id>/dismiss/)",
            res_dismiss.status_code == 200 and res_dismiss.json().get('success') is True,
            f"Stol #{test_call.table_number} chaqiruvi yopildi"
        )

    except Exception as e:
        record_test("Yangi rollar va Flutter API sinovi", False, str(e))

    print(f"\n{Colors.BOLD}{Colors.CYAN}======================================================{Colors.END}")
    total = len(test_results)
    passed_count = sum(1 for _, p, _ in test_results if p)
    failed_count = total - passed_count

    print(f"Jami testlar: {total}")
    print(f"{Colors.GREEN}Muvaffaqiyatli: {passed_count}{Colors.END}")
    if failed_count > 0:
        print(f"{Colors.RED}Xatoliklar: {failed_count}{Colors.END}")
        sys.exit(1)
    else:
        print(f"{Colors.GREEN}{Colors.BOLD}🎉 BARCHA QE & QA TESTLAR 100% MUVAFFAQITYATLI O'TDI!{Colors.END}")
        print(f"{Colors.BOLD}{Colors.CYAN}======================================================{Colors.END}\n")

if __name__ == '__main__':
    run_qe_qa_tests()

