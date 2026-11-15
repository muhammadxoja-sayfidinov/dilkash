import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app_flutter/models/dish.dart';
import 'package:customer_app_flutter/models/order.dart';
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

    test('hierarchical categories and stop-list dish model parsing', () {
      final parentCat = Category.fromJson({
        'id': 6,
        'name': 'Choy va ichimliklar',
        'department': 'bar',
        'parent_id': null,
        'subcategories_count': 2,
        'products_count': 10,
      });
      final subCat = Category.fromJson({
        'id': 8,
        'name': 'Issiq choy va qahva',
        'department': 'bar',
        'parent_id': 6,
        'subcategories_count': 0,
        'products_count': 5,
      });

      expect(parentCat.isSubcategory, false);
      expect(subCat.isSubcategory, true);
      expect(subCat.parentId, 6);

      final unavailableDish = Dish.fromJson({
        'id': 99,
        'name': 'Kofe Cappuccino',
        'price': 22000.0,
        'category': 'Issiq choy va qahva',
        'category_id': 8,
        'department': 'bar',
        'is_available': false,
      });

      expect(unavailableDish.isAvailable, false);
      expect(unavailableDish.categoryId, 8);
      expect(unavailableDish.department, 'bar');
    });

    test('CustomerOrder parses live courier tracking and ETA telemetry correctly', () {
      final json = {
        'id': 501,
        'order_number': '501',
        'status': 'yolda',
        'status_display': 'Kuryer yoʻlda',
        'service_type': 'delivery',
        'service_type_display': 'Yetkazib berish',
        'delivery_address': 'Toshkent sh., Chilonzor 7-mavze',
        'total_amount': 85000.0,
        'customer_lat': 41.2825,
        'customer_lng': 69.2155,
        'restaurant_lat': 41.311081,
        'restaurant_lng': 69.240562,
        'restaurant_name': 'Dilkash Restorani (Markaziy filial)',
        'distance_km': 2.35,
        'eta_minutes': 9,
        'courier': {
          'id': 12,
          'name': 'Jasur Rahimov',
          'phone': '+998 90 111 22 33',
          'vehicle': 'Honda Dio Skuter',
          'current_lat': 41.2980,
          'current_lng': 69.2300,
          'distance_km': 2.35,
          'eta_minutes': 9,
          'is_live': true,
        },
        'items': [
          {
            'id': 1,
            'dish_name': 'Toshkent Toʻy Oshi',
            'quantity': 2,
            'price': 40000.0,
          }
        ],
      };

      final order = CustomerOrder.fromJson(json);
      expect(order.id, 501);
      expect(order.status, 'yolda');
      expect(order.customerLat, 41.2825);
      expect(order.customerLng, 69.2155);
      expect(order.distanceKm, 2.35);
      expect(order.etaMinutes, 9);

      final courier = order.courier;
      expect(courier, isNotNull);
      expect(courier!.name, 'Jasur Rahimov');
      expect(courier.phone, '+998 90 111 22 33');
      expect(courier.vehicle, 'Honda Dio Skuter');
      expect(courier.currentLat, 41.2980);
      expect(courier.currentLng, 69.2300);
      expect(courier.isLive, true);
    });
  });
}
