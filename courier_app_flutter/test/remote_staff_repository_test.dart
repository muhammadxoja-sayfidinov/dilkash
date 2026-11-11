import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:courier_app_flutter/core/config/app_config.dart';
import 'package:courier_app_flutter/core/network/remote_staff_repository.dart';

void main() {
  group('RemoteStaffRepository Waiter & Auth Tests', () {
    test('authenticate parses dual roles and waiter session fields', () async {
      final client = MockClient((req) async {
        expect(req.url.path, '/api/mobile/staff/login/');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['role'], 'auto');
        expect(body['phone'], '+998901112233');
        expect(body['pin'], '1234');

        return http.Response(
          jsonEncode({
            'status': 'success',
            'success': true,
            'role': 'waiter',
            'assigned_roles': ['waiter', 'courier'],
            'user': {
              'id': 1,
              'waiter_id': 1,
              'courier_id': 1,
              'name': 'Jasur Rahimov',
              'phone': '+998901112233',
              'staff_code': 'DIL-1',
              'token': 'wait_tok_1',
              'waiter_token': 'wait_tok_1',
              'courier_token': 'cour_tok_1',
              'assigned_roles': ['waiter', 'courier'],
              'active_role': 'waiter',
              'vehicle_info': 'Honda Dio Scooter',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final repo = RemoteStaffRepository(client: client, baseUrl: 'https://example.test');
      final session = await repo.authenticate(phone: '+998901112233', pin: '1234');

      expect(session.name, 'Jasur Rahimov');
      expect(session.assignedRoles, ['waiter', 'courier']);
      expect(session.canActAsWaiter, isTrue);
      expect(session.canActAsCourier, isTrue);
      expect(session.effectiveWaiterToken, 'wait_tok_1');
      expect(session.effectiveCourierToken, 'cour_tok_1');
    });

    test('fetchTables normalizes free, occupied, ready and billRequested stages', () async {
      final client = MockClient((req) async {
        expect(req.url.path, '/api/waiter/floor-status/');
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'success': true,
            'tables': [
              {
                'number': 1,
                'table_number': '1',
                'name': 'Stol #1',
                'capacity': 4,
                'is_occupied': false,
                'stage': 'free',
                'order': null,
                'call': null,
              },
              {
                'number': 2,
                'table_number': '2',
                'name': 'Stol #2',
                'capacity': 4,
                'is_occupied': true,
                'stage': 'ready',
                'order': {
                  'id': 55,
                  'order_number': '55',
                  'status': 'tayor',
                  'guests_count': 3,
                  'products_total': 45000.0,
                  'service_fee_amount': 4500.0,
                  'total_amount': 49500.0,
                  'items': [
                    {
                      'id': 701,
                      'dish_name': "To'y Oshi",
                      'quantity': 1,
                      'price': 45000.0,
                      'total': 45000.0,
                      'status': 'ready',
                    },
                  ],
                },
                'call': null,
              },
            ],
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final repo = RemoteStaffRepository(client: client, baseUrl: 'https://example.test');
      final tables = await repo.fetchTables();

      expect(tables.length, 2);
      expect(tables[0]['status'], 'free');
      expect(tables[0]['name'], 'Stol #1');
      expect(tables[1]['status'], 'ready');
      expect(tables[1]['products_total'], 45000.0);
      expect(tables[1]['service_fee_amount'], 4500.0);
      expect(tables[1]['total_amount'], 49500.0);
      expect((tables[1]['items'] as List).first['id'], 701);
    });

    test('sendOrderToKitchen, cancelOrderItem, requestTableBill and settleTableBill hit Django endpoints', () async {
      final calls = <String>[];
      final client = MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        if (req.url.path == '/api/waiter/order/create/') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['table_number'], '3');
          expect(body['products'], [
            [10, 2]
          ]);
          return http.Response(jsonEncode({'success': true, 'order_id': 99}), 200);
        }
        if (req.url.path == '/api/waiter/floor-status/') {
          return http.Response(
            jsonEncode({
              'success': true,
              'tables': [
                {
                  'number': 3,
                  'table_number': '3',
                  'name': 'Stol #3',
                  'is_occupied': true,
                  'stage': 'occupied',
                  'order': {
                    'id': 99,
                    'order_number': '99',
                    'status': 'yangi',
                    'products_total': 90000.0,
                    'service_fee_amount': 9000.0,
                    'total_amount': 99000.0,
                    'items': [
                      {'id': 501, 'dish_name': "To'y Oshi", 'quantity': 2, 'price': 45000.0, 'total': 90000.0}
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }
        if (req.url.path == '/api/table/order/item/501/update/') {
          return http.Response(jsonEncode({'success': true, 'new_total': 0.0}), 200);
        }
        if (req.url.path == '/api/waiter/bill-request/3/') {
          return http.Response(jsonEncode({'success': true}), 200);
        }
        if (req.url.path == '/api/waiter/order/99/close/') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['payment_method'], 'karta');
          return http.Response(jsonEncode({'success': true, 'payment_method': 'karta'}), 200);
        }
        return http.Response('Not found', 404);
      });

      final repo = RemoteStaffRepository(client: client, baseUrl: 'https://example.test');
      final updated = await repo.sendOrderToKitchen(
        tableNumber: 'T-03',
        items: [
          {'id': 10, 'name': "To'y Oshi", 'quantity': 2, 'price': 45000.0}
        ],
        notes: 'Tezroq',
      );
      expect(updated['order_id'], 99);
      expect(await repo.cancelOrderItem(tableNumber: '3', itemId: 501), isTrue);
      expect(await repo.requestTableBill('T-03'), isTrue);
      final settled = await repo.settleTableBill(tableNumber: '3', paymentMethod: 'karta');
      expect(settled['success'], isTrue);
      expect(settled['payment_method'], 'karta');
      expect(calls, [
        'POST /api/waiter/order/create/',
        'GET /api/waiter/floor-status/',
        'POST /api/table/order/item/501/update/',
        'POST /api/waiter/bill-request/3/',
        'GET /api/waiter/floor-status/',
        'POST /api/waiter/order/99/close/',
      ]);
    });

    test('local_pos mode strictly routes Waiter to POS Wi-Fi Hub and blocks direct cloud calls', () async {
      SharedPreferences.setMockInitialValues({});
      await AppConfig.resetBaseUrl();
      await AppConfig.setCloudBaseUrl('https://cloud.example.test');
      await AppConfig.setConnectionMode(AppConfig.modeLocalPos);

      final hitHosts = <String>[];
      final client = MockClient((req) async {
        hitHosts.add('${req.url.scheme}://${req.url.authority}${req.url.path}');
        if (req.url.path == '/api/waiter/floor-status/') {
          return http.Response(
            jsonEncode({
              'success': true,
              'source': 'pos_local_hub',
              'tables': [
                {'number': 1, 'table_number': '1', 'name': 'Stol #1', 'is_occupied': false, 'stage': 'free'}
              ],
            }),
            200,
          );
        }
        if (req.url.path == '/api/waiter/call/42/dismiss/') {
          return http.Response(jsonEncode({'success': true, 'call_id': 42}), 200);
        }
        if (req.url.path == '/api/mobile/courier/orders/') {
          return http.Response(jsonEncode({'my_active_orders': [], 'available_orders': []}), 200);
        }
        return http.Response('Unexpected', 404);
      });

      final repo = RemoteStaffRepository(client: client);

      // 1. When no POS Hub IP is set in local_pos mode, Waiter MUST NOT bypass to cloud
      await expectLater(() => repo.fetchTables(), throwsException);
      expect(hitHosts, isEmpty);

      // 2. When POS Hub LAN URL is set, Waiter hits ONLY Local POS Hub while Courier hits Cloud
      await AppConfig.setLocalPosBaseUrl('http://192.168.1.50:8088');
      final tables = await repo.fetchTables();
      expect(tables.length, 1);
      expect(repo.isLocalPosConnected, isTrue);

      final dismissed = await repo.dismissWaiterCall(42);
      expect(dismissed, isTrue);

      await repo.fetchCourierOrders();

      expect(hitHosts, [
        'http://192.168.1.50:8088/api/waiter/floor-status/',
        'http://192.168.1.50:8088/api/waiter/call/42/dismiss/',
        'https://cloud.example.test/api/mobile/courier/orders/',
      ]);

      await AppConfig.resetBaseUrl();
    });
  });
}
