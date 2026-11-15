import base64
import json
from decimal import Decimal
from django.test import TestCase, Client
from django.urls import reverse
from django.utils import timezone
from .models import (
    Category, Product, Order, OrderItem, Customer,
    RestaurantTable, BotSettings, WaiterProfile, CourierProfile, WaiterCall,
    Hall, PrinterDevice, CashierProfile, WaiterFeedback, DishFeedback
)

class PosApiTests(TestCase):
    def setUp(self):
        self.client = Client()
        self.settings = BotSettings.get_settings()
        self.settings.service_fee_type = 'percent'
        self.settings.service_fee_percent = Decimal('10.0')
        self.settings.save()

        # Bo'limlar va toifalar
        self.cat_shashlik = Category.objects.create(name="Kaboblar", department="shashlik")
        self.cat_somsa = Category.objects.create(name="Tandir Somsalar", department="somsa")
        self.cat_kitchen = Category.objects.create(name="Milliy Taomlar", department="kitchen")
        self.cat_fastfood = Category.objects.create(name="Burger & Fast-food", department="fastfood")

        # Taomlar
        self.p_shashlik = Product.objects.create(category=self.cat_shashlik, name="Qo'y go'shti kabob", price=25000, is_available=True)
        self.p_somsa = Product.objects.create(category=self.cat_somsa, name="Tandir Somsa", price=12000, is_available=True)
        self.p_osh = Product.objects.create(category=self.cat_kitchen, name="To'y Oshi", price=45000, is_available=True)
        self.p_burger = Product.objects.create(category=self.cat_fastfood, name="Dilkash Burger", price=35000, is_available=True)

        # Stollar
        self.table1 = RestaurantTable.objects.create(number=1, name="Asosiy Zal 1", capacity=4)
        self.table2 = RestaurantTable.objects.create(number=2, name="VIP 1", capacity=8)

    def test_01_pos_bootstrap_api(self):
        """Bootstrap barcha bo'limlar, sozlamalar, mahsulotlar va stollarni qaytarishi kerak"""
        response = self.client.get('/api/pos/bootstrap/')
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data['status'], 'ok')
        self.assertIn('settings', data)
        self.assertIn('departments', data)
        self.assertIn('products', data)
        self.assertIn('tables', data)
        self.assertEqual(data['settings']['service_fee_percent'], 10.0)
        
        # 6 ta bo'lim mavjudligi tekshiruvi
        dept_codes = [d['code'] for d in data['departments']]
        for code in ['shashlik', 'somsa', 'kitchen', 'fastfood', 'bar', 'kassa']:
            self.assertIn(code, dept_codes)

    def test_02_stop_list_toggle(self):
        """Taomni Stop-listga kiritish va chiqarish bitta so'rovda ishlashi kerak"""
        # Stop listga kiritish
        response = self.client.post(f'/api/pos/products/{self.p_somsa.id}/toggle-stop/', 
                                    data=json.dumps({'is_available': False}), 
                                    content_type='application/json')
        self.assertEqual(response.status_code, 200)
        self.p_somsa.refresh_from_db()
        self.assertFalse(self.p_somsa.is_available)

        # Stop list ro'yxatini olish
        resp_list = self.client.get('/api/pos/stop-list/')
        self.assertEqual(resp_list.status_code, 200)
        data = resp_list.json()
        self.assertEqual(data['count'], 1)
        self.assertEqual(data['stop_list'][0]['id'], self.p_somsa.id)

        # Qayta yoqish
        self.client.post(f'/api/pos/products/{self.p_somsa.id}/toggle-stop/')
        self.p_somsa.refresh_from_db()
        self.assertTrue(self.p_somsa.is_available)

    def test_03_create_quick_saboy_order(self):
        """Tezkor Saboy (olib ketish) buyurtmasi to'lov bilan darhol yopilishi kerak"""
        payload = {
            'service_type': 'pickup',
            'is_paid': True,
            'payment_method': 'naqd',
            'items': [
                {'product_id': self.p_osh.id, 'quantity': 2, 'price': 45000}, # 90 000
                {'product_id': self.p_burger.id, 'quantity': 1, 'price': 35000}, # 35 000
            ],
            'notes': 'Tezkor Saboy'
        }
        response = self.client.post('/api/pos/orders/', data=json.dumps(payload), content_type='application/json')
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data['status'], 'ok')
        order = data['order']
        self.assertEqual(order['service_type'], 'pickup')
        self.assertTrue(order['is_paid'])
        self.assertEqual(order['status'], 'olib_ketildi')
        self.assertEqual(order['products_total'], 125000.0)
        self.assertEqual(order['total_amount'], 125000.0)

    def test_04_table_dine_in_with_service_fee(self):
        """Stolda buyurtma ochilganda xizmat haqi (10%) to'g'ri hisoblanishi kerak"""
        # Stolni ochish
        open_res = self.client.post('/api/pos/tables/', data=json.dumps({
            'action': 'open',
            'table_number': '1',
            'guests_count': 4,
            'waiter_name': 'Jasur'
        }), content_type='application/json')
        self.assertEqual(open_res.status_code, 200)

        # Taomlar qo'shish
        order_res = self.client.post('/api/pos/orders/', data=json.dumps({
            'service_type': 'dine_in',
            'table_number': '1',
            'guests_count': 4,
            'items': [
                {'product_id': self.p_shashlik.id, 'quantity': 4, 'price': 25000}, # 100 000
            ]
        }), content_type='application/json')
        self.assertEqual(order_res.status_code, 200)
        order = order_res.json()['order']
        self.assertEqual(order['products_total'], 100000.0)
        self.assertEqual(order['service_fee_amount'], 10000.0) # 10%
        self.assertEqual(order['total_amount'], 110000.0) # 100 000 + 10 000

        # To'lash va stolni yopish
        pay_res = self.client.post(f"/api/pos/orders/{order['id']}/pay/", data=json.dumps({
            'payment_method': 'aralash',
            'paid_cash': 50000,
            'paid_card': 60000
        }), content_type='application/json')
        self.assertEqual(pay_res.status_code, 200)
        pay_order = pay_res.json()['order']
        self.assertTrue(pay_order['is_paid'])
        self.assertEqual(pay_order['status'], 'yetkazildi')

    def test_05_offline_sync_push(self):
        """Offline rejimda saqlangan buyurtmalar serverga muvaffaqiyatli yuklanishi kerak"""
        offline_uuid = "pos-local-uuid-12345"
        payload = {
            'orders': [
                {
                    'offline_id': offline_uuid,
                    'service_type': 'pickup',
                    'status': 'olib_ketildi',
                    'payment_method': 'karta',
                    'is_paid': True,
                    'products_total': 35000,
                    'service_fee_amount': 0,
                    'total_amount': 35000,
                    'items': [
                        {'product_id': self.p_burger.id, 'quantity': 1, 'price': 35000}
                    ]
                }
            ]
        }
        res = self.client.post('/api/pos/sync/push/', data=json.dumps(payload), content_type='application/json')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data['status'], 'ok')
        self.assertEqual(data['synced_count'], 1)
        self.assertIn(offline_uuid, data['synced_ids'])

        # Bazada yaratilganini tekshirish
        synced_order = Order.objects.filter(offline_id=offline_uuid).first()
        self.assertIsNotNone(synced_order)
        self.assertEqual(synced_order.total_amount, Decimal('35000'))

    def test_06_health_and_table_zone_and_discount(self):
        """Healthcheck, stol zonalari va chegirma bilan buyurtma to'g'ri ishlashi kerak"""
        health = self.client.get('/health/')
        self.assertEqual(health.status_code, 200)
        self.assertEqual(health.json()['status'], 'ok')

        boot = self.client.get('/api/pos/bootstrap/').json()
        self.assertEqual(boot['tables'][0]['zone'], 'Zal')

        order_res = self.client.post('/api/pos/orders/', data=json.dumps({
            'service_type': 'pickup',
            'waiter_name': 'Jasur Rahimov',
            'discount_percent': 10,
            'is_paid': True,
            'payment_method': 'karta',
            'items': [
                {'product_id': self.p_osh.id, 'quantity': 2, 'price': 45000},
            ],
        }), content_type='application/json')
        self.assertEqual(order_res.status_code, 200)
        order = order_res.json()['order']
        self.assertEqual(order['waiter_name'], 'Jasur Rahimov')
        self.assertEqual(order['discount_percent'], 10.0)
        self.assertEqual(order['discount_amount'], 9000.0)
        self.assertEqual(order['total_amount'], 81000.0)

    def test_07_online_order_queue_and_accept_action(self):
        """Online buyurtma qabul qilingandan so'ng yangi navbatdan chiqishi kerak"""
        c = Customer.objects.create(telegram_id=-123456, full_name="Ali", phone_number="+998901234567")
        ord_obj = Order.objects.create(
            customer=c,
            service_type='delivery',
            status='yangi',
            products_total=Decimal('45000'),
            delivery_cost=Decimal('5000'),
            total_amount=Decimal('50000'),
        )
        OrderItem.objects.create(order=ord_obj, product=self.p_osh, quantity=1, price=45000, total=45000)

        q1 = self.client.get('/api/pos/online-orders/').json()
        self.assertEqual(q1['count'], 1)

        act = self.client.post(f'/api/pos/online-orders/{ord_obj.id}/action/', data=json.dumps({'action': 'accept'}), content_type='application/json')
        self.assertEqual(act.status_code, 200)
        self.assertEqual(act.json()['order']['status'], 'tasdiqlangan')

        q2 = self.client.get('/api/pos/online-orders/').json()
        self.assertEqual(q2['count'], 0)

    def test_08_mobile_staff_login_and_waiter_flow(self):
        """Mobil Ofitsiant ilovasi: auto-login, stol ochish, qo'shish, bekor qilish, hisob yopish"""
        waiter = WaiterProfile.objects.create(name="Sardor Alimov", phone="+998902223344", pin_code="2345")
        CourierProfile.objects.create(name="Jasur Rahimov", phone="+998901112233", pin_code="1234")
        WaiterProfile.objects.create(name="Jasur Rahimov", phone="+998901112233", pin_code="1234")

        # 1. Auto role login (ikkala rol ham bor Jasur)
        login_dual = self.client.post('/api/mobile/staff/login/', data=json.dumps({
            'phone': '+998 90 111 22 33',
            'pin': '1234',
        }), content_type='application/json')
        self.assertEqual(login_dual.status_code, 200)
        self.assertEqual(set(login_dual.json()['assigned_roles']), {'waiter', 'courier'})

        # 2. Yagona rol login (Sardor)
        login_w = self.client.post('/api/mobile/staff/login/', data=json.dumps({
            'role': 'auto',
            'phone': '902223344',
            'pin': '2345',
        }), content_type='application/json')
        self.assertEqual(login_w.status_code, 200)
        self.assertEqual(login_w.json()['assigned_roles'], ['waiter'])

        # 3. Stolni ochish / biriktirish va buyurtma yuborish
        assign_res = self.client.post('/api/waiter/table/T-01/assign/', data=json.dumps({
            'waiter_id': waiter.id,
        }), content_type='application/json')
        self.assertEqual(assign_res.status_code, 200)

        create_1 = self.client.post('/api/waiter/order/create/', data=json.dumps({
            'table_number': 'T-01',
            'waiter_id': waiter.id,
            'products': [[self.p_osh.id, 2]],
            'notes': 'Piyozsiz',
        }), content_type='application/json')
        self.assertEqual(create_1.status_code, 200)
        order_id = create_1.json()['order_id']

        # 4. Ochiq stolga yana taom qo'shish (dublikat order yaratmasdan)
        create_2 = self.client.post('/api/waiter/order/create/', data=json.dumps({
            'table_number': '1',
            'waiter_id': waiter.id,
            'products': [[self.p_somsa.id, 2]],
        }), content_type='application/json')
        self.assertEqual(create_2.status_code, 200)
        self.assertEqual(create_2.json()['order_id'], order_id)

        # 5. Floor statusda element ID lar, jami summa va 10% xizmat haqi tekshiruvi
        floor = self.client.get('/api/waiter/floor-status/').json()
        t1 = next(t for t in floor['tables'] if t['table_number'] == '1')
        self.assertEqual(t1['stage'], 'occupied')
        self.assertEqual(len(t1['order']['items']), 2)
        self.assertEqual(t1['order']['products_total'], 114000.0)
        self.assertEqual(t1['order']['service_fee_amount'], 11400.0)
        self.assertEqual(t1['order']['total_amount'], 125400.0)

        # 6. Bitta taomni bekor qilish (somsa)
        somsa_item_id = next(i['id'] for i in t1['order']['items'] if 'Somsa' in i['dish_name'])
        cancel_res = self.client.post(f'/api/table/order/item/{somsa_item_id}/update/', data=json.dumps({'action': 'remove'}), content_type='application/json')
        self.assertEqual(cancel_res.status_code, 200)
        self.assertEqual(cancel_res.json()['new_total'], 99000.0)

        # 7. Hisob so'rash va stolni karta bilan yopish
        req_bill = self.client.post('/api/waiter/bill-request/1/')
        self.assertEqual(req_bill.status_code, 200)
        floor2 = self.client.get('/api/waiter/floor-status/').json()
        t1_bill = next(t for t in floor2['tables'] if t['table_number'] == '1')
        self.assertEqual(t1_bill['stage'], 'billRequested')

        close_res = self.client.post(f'/api/waiter/order/{order_id}/close/', data=json.dumps({'payment_method': 'karta'}), content_type='application/json')
        self.assertEqual(close_res.status_code, 200)
        self.assertEqual(close_res.json()['payment_method'], 'karta')
        floor3 = self.client.get('/api/waiter/floor-status/').json()
        t1_free = next(t for t in floor3['tables'] if t['table_number'] == '1')
        self.assertEqual(t1_free['stage'], 'free')

    def test_09_bootstrap_staff_calls_and_bidirectional_sync_push(self):
        """Bootstrap staff/waiter_calls hamda POS Hub ikki tomonlama sync/push sinovi"""
        waiter = WaiterProfile.objects.create(
            name='Sardor Alimov',
            phone='+998902223344',
            pin_code='2345',
            is_active=True,
        )
        qr_call = WaiterCall.objects.create(
            table_number='2',
            reason="QR orqali ofitsiant chaqirildi",
            is_resolved=False,
        )

        # 1. Bootstrap xodimlar (faqat pin_hash) va QR chaqiruvlarni qaytarishi kerak
        boot = self.client.get('/api/pos/bootstrap/')
        self.assertEqual(boot.status_code, 200)
        b_data = boot.json()
        self.assertIn('staff', b_data)
        self.assertIn('waiter_calls', b_data)
        self.assertTrue(any(s['name'] == 'Sardor Alimov' and 'pin_hash' in s and 'pin_code' not in s for s in b_data['staff']))
        self.assertTrue(any(c['id'] == qr_call.id and c['table_number'] == '2' for c in b_data['waiter_calls']))
        t2_boot = next(t for t in b_data['tables'] if t['number'] == 2)
        self.assertIsNotNone(t2_boot['active_call'])
        self.assertEqual(t2_boot['active_call']['id'], qr_call.id)

        # 2. POS / Ofitsiant offline rejimda 1-stolda to'lanmagan buyurtma ochadi va sync/push qiladi
        push1 = self.client.post('/api/pos/sync/push/', data=json.dumps({
            'orders': [{
                'offline_id': 'off-t1-001',
                'service_type': 'dine_in',
                'table_number': '1',
                'guests_count': 3,
                'waiter_name': waiter.name,
                'is_paid': False,
                'status': 'yangi',
                'products_total': 45000,
                'service_fee_amount': 4500,
                'total_amount': 49500,
                'items': [{'product_id': self.p_osh.id, 'quantity': 1, 'price': 45000}],
            }]
        }), content_type='application/json')
        self.assertEqual(push1.status_code, 200)
        p1_data = push1.json()
        self.assertIn('off-t1-001', p1_data['synced_ids'])
        server_order_id = p1_data['server_id_map']['off-t1-001']

        order = Order.objects.get(id=server_order_id)
        self.assertFalse(order.is_paid)
        self.assertEqual(order.table_number, '1')
        self.table1.refresh_from_db()
        self.assertEqual(self.table1.guests_count, 3)

        # 3. Yangi taom qo'shilib karta bilan yopilganda + QR chaqiruv hal qilinganda sync/push yangilashi kerak
        push2 = self.client.post('/api/pos/sync/push/', data=json.dumps({
            'dismissed_call_ids': [qr_call.id],
            'orders': [{
                'offline_id': 'off-t1-001',
                'service_type': 'dine_in',
                'table_number': '1',
                'guests_count': 3,
                'waiter_name': waiter.name,
                'is_paid': True,
                'payment_method': 'karta',
                'products_total': 57000,
                'service_fee_amount': 5700,
                'total_amount': 62700,
                'items': [
                    {'product_id': self.p_osh.id, 'quantity': 1, 'price': 45000},
                    {'product_id': self.p_somsa.id, 'quantity': 1, 'price': 12000},
                ],
            }]
        }), content_type='application/json')
        self.assertEqual(push2.status_code, 200)
        order.refresh_from_db()
        qr_call.refresh_from_db()
        self.table1.refresh_from_db()
        self.assertTrue(order.is_paid)
        self.assertEqual(order.payment_method, 'karta')
        self.assertEqual(float(order.total_amount), 62700.0)
        self.assertEqual(order.items.count(), 2)
        self.assertTrue(qr_call.is_resolved)
        self.assertEqual(self.table1.guests_count, 0)

        # 4. Alohida POS call dismiss endpointi ham ishlashi kerak
        qr_call2 = WaiterCall.objects.create(table_number='2', reason='Chaqiruv 2', is_resolved=False)
        dismiss_res = self.client.post(f'/api/pos/waiter-calls/{qr_call2.id}/dismiss/')
        self.assertEqual(dismiss_res.status_code, 200)
        qr_call2.refresh_from_db()
        self.assertTrue(qr_call2.is_resolved)

    def test_10_pos_full_admin_management_apis(self):
        """POS Desktop boshqaruv API lari: kategoriya, taom, xodim, stol va tizim sozlamalari CRUD"""
        # 1. Kategoriya yaratish va tahrirlash
        cat_res = self.client.post('/api/pos/categories/save/', data=json.dumps({
            'name': 'Issiq ichimliklar',
            'department': 'bar',
            'description': 'Choy va kofe',
        }), content_type='application/json')
        self.assertEqual(cat_res.status_code, 200)
        cat_id = cat_res.json()['category']['id']
        self.assertEqual(cat_res.json()['category']['department'], 'bar')

        # 2. Taom yaratish, tahrirlash va o'chirish
        prod_res = self.client.post('/api/pos/products/save/', data=json.dumps({
            'category_id': cat_id,
            'name': 'Limonli Choy',
            'price': 15000,
            'description': 'Yangi damlangan',
            'is_available': True,
        }), content_type='application/json')
        self.assertEqual(prod_res.status_code, 200)
        prod_id = prod_res.json()['product']['id']
        self.assertEqual(prod_res.json()['product']['price'], 15000.0)

        # Taom bor kategoriyani o'chirish rad etilishi kerak
        bad_cat_del = self.client.post(f'/api/pos/categories/{cat_id}/delete/')
        self.assertEqual(bad_cat_del.status_code, 400)

        # Taomni o'chirish -> keyin bo'sh kategoriyani o'chirish
        self.assertEqual(self.client.post(f'/api/pos/products/{prod_id}/delete/').status_code, 200)
        self.assertEqual(self.client.post(f'/api/pos/categories/{cat_id}/delete/').status_code, 200)

        # 3. Xodim qo'shish (Ofitsiant + Kuryer), holatini almashtirish va o'chirish
        w_res = self.client.post('/api/pos/staff/save/', data=json.dumps({
            'role': 'waiter',
            'name': 'Azizbek Tursunov',
            'phone': '904445566',
            'pin_code': '7890',
        }), content_type='application/json')
        self.assertEqual(w_res.status_code, 200)
        w_id = w_res.json()['staff']['id']
        self.assertEqual(w_res.json()['staff']['phone'], '+998904445566')

        tog_res = self.client.post(f'/api/pos/staff/waiter/{w_id}/toggle/')
        self.assertEqual(tog_res.status_code, 200)
        self.assertFalse(tog_res.json()['is_active'])

        del_w = self.client.post(f'/api/pos/staff/waiter/{w_id}/delete/')
        self.assertEqual(del_w.status_code, 200)

        # 4. Stol qo'shish, tahrirlash va o'chirish
        t_res = self.client.post('/api/pos/tables/save/', data=json.dumps({
            'number': 15,
            'name': 'VIP Xona 15',
            'capacity': 12,
        }), content_type='application/json')
        self.assertEqual(t_res.status_code, 200)
        t_id = t_res.json()['table']['id']
        self.assertEqual(t_res.json()['table']['capacity'], 12)
        self.assertEqual(self.client.post(f'/api/pos/tables/{t_id}/delete/').status_code, 200)

        # 5. Barcha Bot/Printer/Yetkazish/To'lov sozlamalarini saqlash
        s_res = self.client.post('/api/pos/settings/save/', data=json.dumps({
            'service_start_time': '09:30',
            'service_end_time': '23:30',
            'delivery_base_cost': 8000,
            'delivery_cost_per_extra_km_block': 5000,
            'delivery_max_radius_km': 15,
            'service_fee_type': 'percent',
            'service_fee_percent': 12,
            'auto_print_network': True,
            'printers': {'kassa': '192.168.1.200:9100'},
            'click_merchant_id': 'M123',
            'broadcast_message_text': 'Yangi aksiyalar!',
        }), content_type='application/json')
        self.assertEqual(s_res.status_code, 200)
        s_data = s_res.json()['settings']
        self.assertEqual(s_data['service_start_time'], '09:30')
        self.assertEqual(s_data['service_end_time'], '23:30')
        self.assertEqual(s_data['delivery_base_cost'], 8000.0)
        self.assertEqual(s_data['delivery_max_radius_km'], 15.0)
        self.assertEqual(s_data['click_merchant_id'], 'M123')
        self.assertEqual(s_data['printers']['kassa'], '192.168.1.200:9100')

    def test_11_halls_printers_nested_categories_images_and_cashier_profile(self):
        """Zallar CRUD, Printerlar CRUD, ichma-ich kategoriyalar, taom rasmi baza bilan sinxron va kassir profili"""
        # 1. Zallar CRUD
        h_res = self.client.post('/api/pos/halls/save/', data=json.dumps({
            'name': 'Yozgi Bog',
            'description': 'Ochiq havo',
            'sort_order': 4,
            'is_active': True,
        }), content_type='application/json')
        self.assertEqual(h_res.status_code, 200)
        hall_id = h_res.json()['hall']['id']
        self.assertEqual(h_res.json()['hall']['name'], 'Yozgi Bog')

        # Yangi stolni yangi zalga biriktirish
        t_res = self.client.post('/api/pos/tables/save/', data=json.dumps({
            'number': 20,
            'name': 'Bog 1',
            'capacity': 6,
            'hall_id': hall_id,
        }), content_type='application/json')
        self.assertEqual(t_res.status_code, 200)
        self.assertEqual(t_res.json()['table']['zone'], 'Yozgi Bog')
        self.assertEqual(t_res.json()['table']['hall_id'], hall_id)
        t_id = t_res.json()['table']['id']

        # Stol bor zalni o'chirish rad etilishi kerak
        bad_h_del = self.client.post(f'/api/pos/halls/{hall_id}/delete/')
        self.assertEqual(bad_h_del.status_code, 400)

        # Stolni o'chirish -> keyin zalni o'chirish
        self.assertEqual(self.client.post(f'/api/pos/tables/{t_id}/delete/').status_code, 200)
        self.assertEqual(self.client.post(f'/api/pos/halls/{hall_id}/delete/').status_code, 200)

        # 2. Printerlar CRUD
        p_res = self.client.post('/api/pos/printers/save/', data=json.dumps({
            'name': 'Bar 2-qavat',
            'department': 'bar',
            'ip_address': '192.168.1.188',
            'port': 9100,
            'paper_width': 58,
            'subtitle': 'Kokteyl va qahva',
        }), content_type='application/json')
        self.assertEqual(p_res.status_code, 200)
        printer_id = p_res.json()['printer']['id']
        self.assertEqual(p_res.json()['printer']['effective_address'], '192.168.1.188:9100')
        self.assertEqual(p_res.json()['printer']['paper_width'], 58)

        # Printer tahrirlash
        p_upd = self.client.post('/api/pos/printers/save/', data=json.dumps({
            'id': printer_id,
            'name': 'Bar Asosiy',
            'department': 'bar',
            'ip_address': '192.168.1.199',
            'port': 9100,
            'paper_width': 80,
        }), content_type='application/json')
        self.assertEqual(p_upd.status_code, 200)
        self.assertEqual(p_upd.json()['printer']['name'], 'Bar Asosiy')

        # Printer o'chirish
        self.assertEqual(self.client.post(f'/api/pos/printers/{printer_id}/delete/').status_code, 200)

        # 3. Ichma-ich kategoriya + Taom rasmi DB bilan sinxron
        parent_c = self.client.post('/api/pos/categories/save/', data=json.dumps({
            'name': 'Ichimliklar Bosh',
            'department': 'bar',
        }), content_type='application/json').json()['category']
        child_c = self.client.post('/api/pos/categories/save/', data=json.dumps({
            'name': 'Salqin Ichimliklar',
            'department': 'bar',
            'parent_id': parent_c['id'],
        }), content_type='application/json')
        self.assertEqual(child_c.status_code, 200)
        child_id = child_c.json()['category']['id']
        self.assertEqual(child_c.json()['category']['parent_id'], parent_c['id'])

        # 1x1 PNG rasm yuklash va bazadan (/api/pos/products/<id>/image/) olish
        tiny_png = base64.b64decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX7cAAAAASUVORK5CYII='
        )
        prod_img = self.client.post('/api/pos/products/save/', data=json.dumps({
            'category_id': child_id,
            'name': 'Moxito',
            'price': 22000,
            'image_base64': base64.b64encode(tiny_png).decode('ascii'),
            'image_filename': 'mojito.png',
        }), content_type='application/json')
        self.assertEqual(prod_img.status_code, 200)
        prod_data = prod_img.json()['product']
        self.assertTrue(prod_data['image_url'])
        self.assertTrue(prod_data['image_hash'])

        img_resp = self.client.get(f"/api/pos/products/{prod_data['id']}/image/")
        self.assertEqual(img_resp.status_code, 200)
        self.assertEqual(img_resp.content, tiny_png)

        # Rasmni o'chirish
        rem_res = self.client.post('/api/pos/products/save/', data=json.dumps({
            'id': prod_data['id'],
            'category_id': child_id,
            'name': 'Moxito',
            'price': 22000,
            'remove_image': True,
        }), content_type='application/json')
        self.assertEqual(rem_res.status_code, 200)
        self.assertIsNone(rem_res.json()['product']['image_url'])
        self.assertEqual(self.client.get(f"/api/pos/products/{prod_data['id']}/image/").status_code, 404)

        # 4. Kassir profili
        cp_res = self.client.post('/api/pos/cashier-profile/save/', data=json.dumps({
            'name': 'Dilshod Alimov',
            'phone': '909998877',
            'role_title': 'Katta kassir',
            'pin_code': '5678',
            'require_pin_on_unlock': True,
            'notification_sound': False,
        }), content_type='application/json')
        self.assertEqual(cp_res.status_code, 200)
        cp = cp_res.json()['cashier_profile']
        self.assertEqual(cp['name'], 'Dilshod Alimov')
        self.assertEqual(cp['phone'], '+998909998877')
        self.assertTrue(cp['require_pin_on_unlock'])
        self.assertFalse(cp['notification_sound'])

        # 5. Bootstrap yangi bo'limlarni qaytarishi kerak
        boot = self.client.get('/api/pos/bootstrap/').json()
        self.assertIn('halls', boot)
        self.assertIn('printers', boot)
        self.assertIn('cashier_profile', boot)
        self.assertEqual(boot['cashier_profile']['name'], 'Dilshod Alimov')

    def test_12_inventory_warehouse_supplies_recipes_and_deduction(self):
        """Omborxona tizimi: xomashyo, ta'minotchi, kirim, chiqim, tex-karta va sotuvda avtomatik hisobdan chiqarish."""
        # 1. Boshlang'ich ombor bootstrap
        boot = self.client.get('/api/pos/inventory/bootstrap/').json()
        self.assertEqual(boot['status'], 'ok')
        self.assertIn('ingredients', boot)
        self.assertIn('suppliers', boot)
        self.assertIn('recipes', boot)
        self.assertIn('kpi', boot)

        # 2. Yangi xomashyo yaratish
        ing_res = self.client.post('/api/pos/inventory/ingredients/save/', data=json.dumps({
            'name': 'Marmar mol goʻshti (premium)',
            'category': 'meat',
            'unit': 'kg',
            'current_stock': 20.0,
            'min_stock_alert': 5.0,
            'cost_price': 120000.0,
            'description': 'Ribeye va T-bone uchun',
        }), content_type='application/json')
        self.assertEqual(ing_res.status_code, 200)
        ing_id = ing_res.json()['ingredient']['id']
        self.assertEqual(ing_res.json()['ingredient']['current_stock'], 20.0)

        # 3. Yangi ta'minotchi kiritish
        sup_res = self.client.post('/api/pos/inventory/suppliers/save/', data=json.dumps({
            'name': 'Premium Agro Goʻsht MCHJ',
            'phone': '+998901239988',
            'contact_person': 'Sherzod',
            'balance': 0.0,
        }), content_type='application/json')
        self.assertEqual(sup_res.status_code, 200)
        sup_id = sup_res.json()['supplier']['id']

        # 4. Kirim hujjati yaratish (+10 kg)
        sup_doc = self.client.post('/api/pos/inventory/supplies/create/', data=json.dumps({
            'supplier_id': sup_id,
            'payment_status': 'paid',
            'paid_amount': 1250000.0,
            'notes': 'Yangilangan partiya',
            'created_by': 'Bosh kassir',
            'items': [
                {'ingredient_id': ing_id, 'quantity': 10.0, 'unit_price': 125000.0}
            ],
        }), content_type='application/json')
        self.assertEqual(sup_doc.status_code, 200)
        self.assertEqual(sup_doc.json()['supply']['total_cost'], 1250000.0)

        # Xomashyo qoldig'i 20 + 10 = 30 kg bo'lishi kerak
        ings = self.client.get(f'/api/pos/inventory/ingredients/?q=Marmar').json()
        target_ing = next(i for i in ings['ingredients'] if i['id'] == ing_id)
        self.assertEqual(target_ing['current_stock'], 30.0)
        self.assertEqual(target_ing['cost_price'], 125000.0)

        # 5. Taomga tex-karta (retsept) biriktirish: 1 porsiya p_osh uchun 0.250 kg
        rec_res = self.client.post(f'/api/pos/inventory/recipes/{self.p_osh.id}/save/', data=json.dumps({
            'items': [
                {'ingredient_id': ing_id, 'quantity': 0.250, 'unit': 'kg', 'notes': 'Premium goʻsht qismi'}
            ]
        }), content_type='application/json')
        self.assertEqual(rec_res.status_code, 200)
        self.assertEqual(len(rec_res.json()['recipes']), 1)
        self.assertEqual(rec_res.json()['calculated_cost'], 31250.0) # 0.250 * 125000

        # 6. Chiqim hujjati (spisaniye) qilish (-2 kg aynigan)
        wo_res = self.client.post('/api/pos/inventory/write-offs/create/', data=json.dumps({
            'reason': 'spoilage',
            'notes': 'Texnik sababli yaroqsiz',
            'created_by': 'Bosh oshpaz',
            'items': [
                {'ingredient_id': ing_id, 'quantity': 2.0}
            ]
        }), content_type='application/json')
        self.assertEqual(wo_res.status_code, 200)

        # Qoldiq 30 - 2 = 28 kg bo'lishi kerak
        ings_after_wo = self.client.get(f'/api/pos/inventory/ingredients/?q=Marmar').json()
        target_ing2 = next(i for i in ings_after_wo['ingredients'] if i['id'] == ing_id)
        self.assertEqual(target_ing2['current_stock'], 28.0)

        # 7. POS orqali buyurtma berish va to'lash: 2 dona p_osh
        # Kutilgan sarf: 2 x 0.250 = 0.500 kg
        order_res = self.client.post('/api/pos/orders/', data=json.dumps({
            'service_type': 'pickup',
            'customer_name': 'Omborxonachi',
            'customer_phone': '+998901112233',
            'is_paid': True,
            'payment_method': 'naqd',
            'items': [
                {'product_id': self.p_osh.id, 'quantity': 2, 'price': float(self.p_osh.price)}
            ]
        }), content_type='application/json')
        self.assertEqual(order_res.status_code, 200)

        # Qoldiq endi 28 - 0.500 = 27.500 kg bo'lishi shart!
        ings_after_sale = self.client.get(f'/api/pos/inventory/ingredients/?q=Marmar').json()
        target_ing3 = next(i for i in ings_after_sale['ingredients'] if i['id'] == ing_id)
        self.assertEqual(target_ing3['current_stock'], 27.5)

        # 8. Harakatlar jurnali barcha operatsiyalarni ko'rsatishi kerak
        mov_res = self.client.get(f'/api/pos/inventory/movements/?ingredient_id={ing_id}').json()
        self.assertEqual(mov_res['status'], 'ok')
        types = [m['movement_type'] for m in mov_res['movements']]
        self.assertIn('supply', types)
        self.assertIn('write_off', types)
        self.assertIn('sale_deduction', types)

    def test_customer_live_tracking_and_courier_simulation(self):
        """Mijoz ilovasi: Kuryer jonli GPS kuzatuvi, ETA, masofa va simulyatsiya tekshiruvi"""
        from chef_panel.models import CourierProfile, Order, Customer
        courier = CourierProfile.objects.create(
            name="Sardor Kuryer",
            phone="+998909876543",
            vehicle_info="Honda Dio (Oq) - 01 B 555 AA",
            is_active=True,
            current_lat=41.3050,
            current_lng=69.2350
        )

        customer = Customer.objects.create(
            telegram_id=987654321,
            phone_number="+998901239988",
            full_name="Akmaljon"
        )

        order = Order.objects.create(
            customer=customer,
            service_type='delivery',
            status='yolda',
            address="Toshkent sh., Chilonzor 7-mavze",
            latitude=41.2825,
            longitude=69.2155,
            courier=courier,
            courier_name=courier.name,
            products_total=Decimal('75000.0'),
            delivery_cost=Decimal('10000.0'),
            total_amount=Decimal('85000.0')
        )

        # 1. Mijoz status API orqali live tracking telemetriyasini tekshirish
        res = self.client.get(f'/api/mobile/customer/order/{order.id}/status/')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data['success'])
        self.assertEqual(data['status'], 'yolda')
        self.assertEqual(data['latitude'], 41.2825)
        self.assertEqual(data['longitude'], 69.2155)
        self.assertIsNotNone(data['restaurant_lat'])
        self.assertIsNotNone(data['restaurant_lng'])

        # Kuryer ma'lumotlari
        courier_info = data['courier']
        self.assertIsNotNone(courier_info)
        self.assertEqual(courier_info['name'], "Sardor Kuryer")
        self.assertEqual(courier_info['current_lat'], 41.3050)
        self.assertEqual(courier_info['current_lng'], 69.2350)
        self.assertTrue(courier_info['is_live'])
        self.assertGreater(courier_info['distance_km'], 0)
        self.assertGreater(courier_info['eta_minutes'], 0)

        # 2. Simulyatsiya orqali kuryerni mijoz tomon siljitish
        sim_res = self.client.post(f'/api/mobile/customer/order/{order.id}/simulate-courier/')
        self.assertEqual(sim_res.status_code, 200)
        sim_data = sim_res.json()
        self.assertTrue(sim_data['success'])
        courier.refresh_from_db()
        self.assertNotEqual(courier.current_lat, 41.3050)

        # 3. Kuryer GPS yangilash API (mobile_courier_location_api)
        loc_res = self.client.post('/api/mobile/courier/location/update/', data=json.dumps({
            'courier_id': courier.id,
            'latitude': 41.2900,
            'longitude': 69.2200
        }), content_type='application/json')
        self.assertEqual(loc_res.status_code, 200)
        courier.refresh_from_db()
        self.assertEqual(courier.current_lat, 41.2900)
        self.assertEqual(courier.current_lng, 69.2200)

    def test_14_table_feedback_submission_and_confidentiality(self):
        """QR kod orqali ofitsiant va taomlarni baholash, maxfiylik va POS monitoring testi"""
        # 1. Ofitsiant va stol buyurtmasini yaratamiz
        waiter = WaiterProfile.objects.create(
            name="Bobur Mirzo",
            phone="+998901234567"
        )
        customer = Customer.objects.create(
            telegram_id=888999,
            full_name="Mehmon",
            phone_number="+998901112233"
        )
        order = Order.objects.create(
            customer=customer,
            table_number="1",
            waiter=waiter,
            waiter_name=waiter.name,
            service_type='dine_in',
            status='ochiq',
            products_total=Decimal('62000.0'),
            total_amount=Decimal('68200.0')
        )
        OrderItem.objects.create(order=order, product=self.p_shashlik, quantity=2, price=25000, total=50000)
        OrderItem.objects.create(order=order, product=self.p_somsa, quantity=1, price=12000, total=12000)

        # 2. QR orqali mijoz baholash so'rovini yuboradi
        feedback_payload = {
            'order_id': order.id,
            'table_number': '1',
            'waiter_id': waiter.id,
            'waiter_rating': 5,
            'waiter_comment': "Xizmat a'lo darajada, ofitsiant juda muloyim!",
            'dish_ratings': [
                {
                    'product_id': self.p_shashlik.id,
                    'rating': 5,
                    'comment': "Kabob shirali va juda mazali pishgan!"
                },
                {
                    'product_id': self.p_somsa.id,
                    'rating': 4,
                    'comment': "Somsa issiq, xamiri qarsildoq"
                }
            ]
        }
        res = self.client.post('/api/table/feedback/submit/', data=json.dumps(feedback_payload), content_type='application/json')
        self.assertEqual(res.status_code, 200)
        res_data = res.json()
        self.assertTrue(res_data['success'])

        # 3. Bazada saqlanganligini tekshiramiz
        w_fb = WaiterFeedback.objects.filter(waiter=waiter, order=order).first()
        self.assertIsNotNone(w_fb)
        self.assertEqual(w_fb.rating, 5)
        self.assertEqual(w_fb.waiter_name, "Bobur Mirzo")
        self.assertEqual(w_fb.comment, "Xizmat a'lo darajada, ofitsiant juda muloyim!")

        d_fbs = DishFeedback.objects.filter(order=order).order_by('id')
        self.assertEqual(d_fbs.count(), 2)
        self.assertEqual(d_fbs[0].product_name, "Qo'y go'shti kabob")
        self.assertEqual(d_fbs[0].rating, 5)
        self.assertEqual(d_fbs[1].product_name, "Tandir Somsa")
        self.assertEqual(d_fbs[1].rating, 4)

        # 4. Maxfiylik kafolati: Ofitsiant API'larida ushbu baholar UMUMAN ko'rsatilmasligi kerak
        # Ofitsiant o'z faol buyurtmalarini ko'rganda reytinglar berilmaydi
        w_orders_res = self.client.get(f'/api/waiter/orders/?waiter_id={waiter.id}')
        if w_orders_res.status_code == 200:
            content_str = w_orders_res.content.decode('utf-8')
            self.assertNotIn("waiter_comment", content_str)
            self.assertNotIn("Xizmat a'lo darajada", content_str)

        # 5. POS API orqali kassa/rahbariyat barchasini ko'ra oladi
        pos_res = self.client.get('/api/pos/feedback/')
        self.assertEqual(pos_res.status_code, 200)
        pos_data = pos_res.json()
        self.assertEqual(pos_data['status'], 'ok')
        self.assertEqual(pos_data['stats']['total_waiter_reviews'], 1)
        self.assertEqual(pos_data['stats']['avg_waiter_rating'], 5.0)
        self.assertEqual(pos_data['stats']['total_dish_reviews'], 2)
        self.assertEqual(pos_data['stats']['avg_dish_rating'], 4.5)

        # Ofitsiantlar reyting jadvali
        self.assertGreaterEqual(len(pos_data['waiters_summary']), 1)
        w_sum = [w for w in pos_data['waiters_summary'] if w['waiter_id'] == waiter.id][0]
        self.assertEqual(w_sum['name'], "Bobur Mirzo")
        self.assertEqual(w_sum['avg_rating'], 5.0)
        self.assertEqual(w_sum['reviews_count'], 1)

        # Qidiruv filteri tekshiruvi: Kabob bo'yicha filter
        pos_search = self.client.get('/api/pos/feedback/?q=kabob')
        self.assertEqual(pos_search.status_code, 200)
        search_data = pos_search.json()
        self.assertEqual(len(search_data['dish_feedbacks']), 1)
        self.assertEqual(search_data['dish_feedbacks'][0]['product_name'], "Qo'y go'shti kabob")









