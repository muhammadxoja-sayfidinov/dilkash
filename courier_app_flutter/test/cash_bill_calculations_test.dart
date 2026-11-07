import 'package:flutter_test/flutter_test.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';

void main() {
  group('Simplified Cash and Bill Calculations Tests', () {
    test('Waiter Bill Calculation: items and total sum', () {
      final items = [
        {'name': 'Toshkent To’y Oshi', 'price': 45000.0, 'quantity': 2},
        {'name': 'Achichuk Salati', 'price': 15000.0, 'quantity': 2},
        {'name': 'Rayhon sharbati 1L', 'price': 25000.0, 'quantity': 1},
      ];

      // Total = (45000 * 2) + (15000 * 2) + (25000 * 1) = 90000 + 30000 + 25000 = 145000
      final total = items.fold<double>(
        0.0,
        (sum, item) =>
            sum + ((item['price'] as double) * (item['quantity'] as int)),
      );

      expect(total, 145000.0);
      expect(UzbekFormatters.formatCurrency(total), '145 000 so’m');
    });

    test('Courier Today Summary: calculates cash collected to hand over', () {
      final history = [
        {'id': 1, 'amount': 85000.0, 'payment_type': 'cash'},
        {'id': 2, 'amount': 120000.0, 'payment_type': 'paid'}, // Card/Click, not cash
        {'id': 3, 'amount': 45000.0, 'payment_type': 'cash'},
      ];

      double cashToHandOver = 0.0;
      for (final h in history) {
        if (h['payment_type'] == 'cash') {
          cashToHandOver += (h['amount'] as double);
        }
      }

      expect(cashToHandOver, 130000.0);
      expect(UzbekFormatters.formatCurrency(cashToHandOver), '130 000 so’m');
    });
  });
}
