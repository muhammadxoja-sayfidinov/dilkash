import json
from decimal import Decimal
from django.test import TestCase, Client
from django.urls import reverse
from django.utils import timezone
from .models import Category, Product, Order, OrderItem, Customer, RestaurantTable, BotSettings

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


