import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:courier_app_flutter/models/courier_order.dart';
import 'package:courier_app_flutter/core/auth/staff_session.dart';
import 'package:courier_app_flutter/core/auth/auth_notifier.dart';
import 'package:courier_app_flutter/features/common/screens/staff_profile_screen.dart';

void main() {
  group('CourierOrder Model & Simplified Profile Tests', () {
    test('CourierOrder correctly parses JSON with items', () {
      final json = {
        'id': 101,
        'order_number': 'ORD-9821',
        'status': 'preparing',
        'status_display': 'Tayyorlanmoqda',
        'customer_name': 'Alisher Navoiy',
        'customer_phone': '+998901234567',
        'delivery_address': 'Amir Temur shoh ko’chasi 15-uy',
        'notes': 'Eshik qo’ng’irog’i ishlamaydi',
        'total_amount': 95000.0,
        'created_at': '14:30',
        'items': [
          {
            'dish_name': 'Osh (To’y oshi)',
            'quantity': 2,
            'price': 40000.0,
          },
          {
            'dish_name': 'Moxito (Klassik)',
            'quantity': 1,
            'price': 15000.0,
          }
        ],
      };

      final order = CourierOrder.fromJson(json);

      expect(order.id, 101);
      expect(order.orderNumber, 'ORD-9821');
      expect(order.customerName, 'Alisher Navoiy');
      expect(order.totalAmount, 95000.0);
      expect(order.items.length, 2);
      expect(order.items.first.dishName, 'Osh (To’y oshi)');
      expect(order.items.first.quantity, 2);
      expect(order.items.first.price, 40000.0);
    });

    testWidgets('StaffProfileScreen renders staff details and simple shift toggle', (tester) async {
      const session = StaffSession(
        id: 7,
        name: 'Bobur Kuryer',
        phone: '+998909998877',
        staffCode: 'DIL-202',
        token: 'test_token',
        assignedRoles: ['courier'],
        activeRole: 'courier',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(session)),
          ],
          child: const MaterialApp(
            home: StaffProfileScreen(),
          ),
        ),
      );

      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('Bobur Kuryer'), findsOneWidget);
      expect(find.text('+998909998877'), findsOneWidget);
      expect(find.text('Smena holati'), findsOneWidget);
      expect(find.text('Tizimdan chiqish'), findsOneWidget);
    });
  });
}

class _MockAuthNotifier extends AuthNotifier {
  final StaffSession _session;
  _MockAuthNotifier(this._session);

  @override
  AsyncValue<StaffSession?> build() => AsyncValue.data(_session);
}
