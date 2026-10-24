import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cash and Bill Calculations Unit Tests', () {
    test('Waiter Bill Calculation: subtotal, service charge, and discount', () {
      final items = [
        {'name': 'Toshkent Toʻy Oshi', 'price': 48000.0, 'quantity': 3},
        {'name': 'Achichuk Salati', 'price': 18000.0, 'quantity': 2},
        {'name': 'Koʻk choy (choynak)', 'price': 12000.0, 'quantity': 2},
      ];

      // Subtotal = (48000 * 3) + (18000 * 2) + (12000 * 2) = 144000 + 36000 + 24000 = 204000
      final subtotal = items.fold<double>(
        0.0,
        (sum, item) => sum + ((item['price'] as double) * (item['quantity'] as int)),
      );
      expect(subtotal, 204000.0);

      // 10% Service Charge = 20400
      const servicePercent = 10.0;
      final serviceCharge = subtotal * (servicePercent / 100);
      expect(serviceCharge, 20400.0);

      // 5% VIP Discount = 10200
      const discountPercent = 5.0;
      final discount = subtotal * (discountPercent / 100);
      expect(discount, 10200.0);

      // Total = subtotal + serviceCharge - discount = 204000 + 20400 - 10200 = 214200
      final total = subtotal + serviceCharge - discount;
      expect(total, 214200.0);
    });

    test('Waiter Bill Splitting: Equal Split among guests with remainder handling', () {
      const totalAmount = 215000.0;
      const guestCount = 4;

      // Equal share = 215000 / 4 = 53750
      final perGuestShare = (totalAmount / guestCount).roundToDouble();
      expect(perGuestShare, 53750.0);
      expect(perGuestShare * guestCount, totalAmount);

      // Uneven split test: 100000 / 3 = 33333.33 -> round = 33333
      const unevenTotal = 100000.0;
      const guestCount3 = 3;
      final baseShare = (unevenTotal / guestCount3).floorToDouble();
      final remainder = unevenTotal - (baseShare * guestCount3);
      expect(baseShare, 33333.0);
      expect(remainder, 1.0);
    });

    test('Waiter Bill Splitting by Guest seat assignment', () {
      final guestOrders = {
        'Mehmon 1': [
          {'name': 'Toshkent Toʻy Oshi', 'price': 48000.0},
          {'name': 'Achichuk', 'price': 18000.0},
        ],
        'Mehmon 2': [
          {'name': 'Moxito', 'price': 22000.0},
          {'name': 'Qozon Kabob', 'price': 72000.0},
        ],
      };

      final guest1Total = (guestOrders['Mehmon 1'] as List).fold<double>(
        0.0,
        (sum, item) => sum + (item['price'] as double),
      );
      final guest2Total = (guestOrders['Mehmon 2'] as List).fold<double>(
        0.0,
        (sum, item) => sum + (item['price'] as double),
      );

      expect(guest1Total, 66000.0);
      expect(guest2Total, 94000.0);
      expect(guest1Total + guest2Total, 160000.0);
    });

    test('Courier Change Calculator: computes exact change and validates sufficiency', () {
      const orderAmount = 78000.0;
      const cashReceived = 100000.0;

      expect(cashReceived >= orderAmount, isTrue);
      const change = cashReceived - orderAmount;
      expect(change, 22000.0);

      // Insufficient cash
      const insufficientCash = 50000.0;
      expect(insufficientCash < orderAmount, isTrue);
      const deficit = orderAmount - insufficientCash;
      expect(deficit, 28000.0);
    });

    test('Courier Shift Cash Handover: running balance and discrepancy reconciliation', () {
      // 3 cash deliveries completed during shift
      final cashOrders = [
        {'id': 1, 'collected': 85000.0, 'fee': 15000.0},
        {'id': 2, 'collected': 120000.0, 'fee': 18000.0},
        {'id': 3, 'collected': 45000.0, 'fee': 12000.0},
      ];

      // Total cash on hand (restaurant money to hand in)
      final expectedCashOnHand = cashOrders.fold<double>(
        0.0,
        (sum, o) => sum + (o['collected'] as double),
      );
      expect(expectedCashOnHand, 250000.0);

      // Courier earnings (separate from restaurant cash)
      final totalCourierEarnings = cashOrders.fold<double>(
        0.0,
        (sum, o) => sum + (o['fee'] as double),
      );
      expect(totalCourierEarnings, 45000.0);

      // Case 1: Exact handover
      const actualHandoverExact = 250000.0;
      final discrepancyExact = actualHandoverExact - expectedCashOnHand;
      expect(discrepancyExact, 0.0);

      // Case 2: Shortage (kamomad)
      const actualHandoverShortage = 240000.0;
      final discrepancyShortage = actualHandoverShortage - expectedCashOnHand;
      expect(discrepancyShortage, -10000.0);

      // Case 3: Overage (ortiqcha)
      const actualHandoverOverage = 255000.0;
      final discrepancyOverage = actualHandoverOverage - expectedCashOnHand;
      expect(discrepancyOverage, 5000.0);
    });
  });
}
