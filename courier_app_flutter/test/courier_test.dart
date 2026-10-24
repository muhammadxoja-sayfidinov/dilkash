import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:courier_app_flutter/models/courier_order.dart';
import 'package:courier_app_flutter/screens/courier_account_screen.dart';

void main() {
  group('CourierOrder Model & Business Logic Tests', () {
    test('CourierOrder correctly parses JSON with items and coordinates', () {
      final json = {
        'id': 101,
        'order_number': 'ORD-9821',
        'status': 'preparing',
        'status_display': 'Tayyorlanmoqda',
        'customer_name': 'Alisher Navoiy',
        'customer_phone': '+998901234567',
        'delivery_address': 'Amir Temur shox koʻchasi 15-uy',
        'latitude': 41.3111,
        'longitude': 69.2797,
        'notes': 'Iltimos, eshik qoʻngʻirogʻi ishlamaydi',
        'total_amount': 95000.0,
        'created_at': '14:30',
        'items': [
          {
            'dish_name': 'Osh (Toʻy oshi)',
            'quantity': 2,
            'price': 40000.0,
            'portion': 'standard',
            'extras': ['Achichuk', 'Tuxum'],
          },
          {
            'dish_name': 'Moxito (Klassik)',
            'quantity': 1,
            'price': 15000.0,
            'portion': 'standard',
            'extras': [],
          }
        ],
      };

      final order = CourierOrder.fromJson(json);

      expect(order.id, 101);
      expect(order.orderNumber, 'ORD-9821');
      expect(order.status, 'preparing');
      expect(order.customerName, 'Alisher Navoiy');
      expect(order.latitude, 41.3111);
      expect(order.longitude, 69.2797);
      expect(order.totalAmount, 95000.0);
      expect(order.items.length, 2);
      expect(order.items.first.dishName, 'Osh (Toʻy oshi)');
      expect(order.items.first.quantity, 2);
      expect(order.items.first.price, 40000.0);
    });

    test('CourierOrder handles null coordinates and empty extras gracefully',
        () {
      final json = {
        'id': 102,
        'order_number': 'ORD-9822',
        'status': 'accepted',
        'status_display': 'Qabul qilindi',
        'customer_name': 'Jasur Bek',
        'customer_phone': '+998935551122',
        'delivery_address': 'Chilonzor 9-mavze',
        'latitude': null,
        'longitude': null,
        'notes': '',
        'total_amount': 35000,
        'created_at': '15:10',
        'items': [],
      };

      final order = CourierOrder.fromJson(json);

      expect(order.latitude, isNull);
      expect(order.longitude, isNull);
      expect(order.items, isEmpty);
      expect(order.totalAmount, 35000.0);
    });

    test('CourierUser deserializes authentication payload correctly', () {
      final json = {
        'id': 7,
        'name': 'Bobur Kuryer',
        'phone': '+998909998877',
        'token': 'jwt_courier_token_xyz',
        'vehicle_info': 'Honda Dio Scooter (oq)',
      };

      final courier = CourierUser.fromJson(json);

      expect(courier.id, 7);
      expect(courier.name, 'Bobur Kuryer');
      expect(courier.token, 'jwt_courier_token_xyz');
      expect(courier.vehicleInfo, 'Honda Dio Scooter (oq)');
    });

    testWidgets('CourierAccountScreen renders courier profile and settings',
        (tester) async {
      final courier = CourierUser(
        id: 7,
        name: 'Bobur Kuryer',
        phone: '+998909998877',
        token: 'test_token',
        vehicleInfo: 'Honda Dio',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CourierAccountScreen(courier: courier),
        ),
      );

      expect(find.text('Kuryer Profili & Sozlamalar'), findsOneWidget);
      expect(find.text('Bobur Kuryer'), findsOneWidget);
      expect(find.text('+998909998877'), findsOneWidget);
      expect(find.text('TRANSPORT VA YETKAZIB BERISH'), findsOneWidget);
      expect(find.text('ISH TARTIBI VA SOZLAMALAR'), findsOneWidget);
    });
  });
}
