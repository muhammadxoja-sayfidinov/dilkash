import json
from decimal import Decimal
from django.test import TestCase, Client
from django.urls import reverse
from django.utils import timezone
from .models import (
    Category, Product, Order, OrderItem, Customer,
    RestaurantTable, BotSettings, WaiterProfile, CourierProfile, WaiterCall
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





