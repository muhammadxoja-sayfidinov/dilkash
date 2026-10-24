import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app_flutter/models/dish.dart';
import 'package:customer_app_flutter/services/cart_provider.dart';

void main() {
  group('Customer Cart & Pricing Tests', () {
    late CartProvider cart;
    late Dish sampleDish;

    setUp(() {
      cart = CartProvider();
      sampleDish = Dish(
        id: 1,
        name: 'Toshkent Toʻy Oshi',
        description: 'Mayin goʻsht, sariq sabzi va noʻxat bilan',
        price: 40000.0,
        category: 'Oshlar',
        imageUrl: '',
        isAvailable: true,
        prepTime: 15,
      );
    });

    test('adding items increases total count and subtotal', () {
      cart.addItem(sampleDish, quantity: 2);
      expect(cart.totalCount, 2);
      expect(cart.subtotalPrice, 80000.0);
    });

    test('portion size recalculates unit price correctly', () {
      final itemNormal =
          CartItem(dish: sampleDish, selectedPortion: '1 porsiya');
      final itemSmall =
          CartItem(dish: sampleDish, selectedPortion: '0.7 porsiya');
      final itemLarge =
          CartItem(dish: sampleDish, selectedPortion: '1.5 porsiya');

      expect(itemNormal.unitPrice, 40000.0);
      expect(itemSmall.unitPrice, 30000.0); // 40000 * 0.75
      expect(itemLarge.unitPrice, 58000.0); // 40000 * 1.45
    });

    test('extra condiments increase item price by 5 000 soʻm each', () {
      final itemWithExtras = CartItem(
        dish: sampleDish,
        selectedExtras: ['Qazi', 'Tandir non'],
      );
      expect(itemWithExtras.unitPrice, 50000.0); // 40000 + 2 * 5000
    });

    test('promo code DILKASH5 applies 5% discount', () {
      cart.addItem(sampleDish, quantity: 2); // 80 000 soʻm
      final applied = cart.applyPromoCode('DILKASH5');
      expect(applied, true);
      expect(cart.promoDiscount, 4000.0); // 80000 * 0.05
      expect(cart.totalPrice, 76000.0);
    });

    test('promo code YANGI applies 10 000 soʻm discount', () {
      cart.addItem(sampleDish, quantity: 1); // 40 000 soʻm
      final applied = cart.applyPromoCode('YANGI');
      expect(applied, true);
      expect(cart.promoDiscount, 10000.0);
      expect(cart.totalPrice, 30000.0);
    });

    test('updating quantity works or removes item when 0', () {
      cart.addItem(sampleDish, quantity: 3);
      cart.updateQuantity(sampleDish.id, 1);
      expect(cart.totalCount, 1);

      cart.updateQuantity(sampleDish.id, 0);
      expect(cart.totalCount, 0);
      expect(cart.items.isEmpty, true);
    });
  });
}
