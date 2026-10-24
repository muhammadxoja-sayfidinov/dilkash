import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dish.dart';
import '../models/order.dart';
import '../models/user_profile.dart';

class ApiService {
  // Standart Django server manzili (Mahalliy, Wi-Fi yoki tunnel)
  static String baseUrl = 'http://127.0.0.1:8000';

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('api_base_url');
      if (saved != null && saved.isNotEmpty) {
        baseUrl = saved.replaceAll(RegExp(r'/+$'), '');
      }
    } catch (_) {}
  }

  static Future<void> setBaseUrl(String url) async {
    baseUrl = url.replaceAll(RegExp(r'/+$'), '');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_base_url', baseUrl);
    } catch (_) {}
  }

  // 1. Menyu va toifalarni yuklash
  static Future<Map<String, dynamic>> fetchMenu() async {
    final response =
        await http.get(Uri.parse('$baseUrl/api/mobile/customer/menu/'));
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      List<Category> categories = (data['categories'] as List? ?? [])
          .map((c) => Category.fromJson(c))
          .toList();
      List<Dish> dishes =
          (data['dishes'] as List? ?? []).map((d) => Dish.fromJson(d)).toList();
      return {'categories': categories, 'dishes': dishes};
    } else {
      throw Exception('Menyu yuklanmadi (${response.statusCode})');
    }
  }

  // 2. Foydalanuvchi Kirish / Ro'yxatdan o'tish (Auth)
  static Future<UserProfile> authCustomer({
    required String phone,
    String? fullName,
  }) async {
    final body = jsonEncode({
      'phone': phone,
      'full_name': fullName ?? '',
    });

    final response = await http.post(
      Uri.parse('$baseUrl/api/mobile/customer/auth/'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final custData = data['customer'];
      custData['token'] = data['token'] ?? '';
      return UserProfile.fromJson(custData);
    } else {
      final err = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(err['message'] ?? 'Avtorizatsiyada xatolik yuz berdi');
    }
  }

  // 3. Profil ma'lumotlarini yangilash
  static Future<UserProfile> updateProfile({
    required String phone,
    required String fullName,
  }) async {
    final body = jsonEncode({
      'phone': phone,
      'full_name': fullName,
    });

    final response = await http.post(
      Uri.parse('$baseUrl/api/mobile/customer/profile/update/'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return UserProfile.fromJson(data['customer']);
    } else {
      throw Exception('Profilni yangilashda xatolik yuz berdi');
    }
  }

  // 4. Yangi buyurtma yuborish (Dastavka yoki Olib ketish)
  static Future<Map<String, dynamic>> createOrder({
    required String customerName,
    required String customerPhone,
    required String serviceType, // 'delivery' yoki 'pickup'
    required String deliveryAddress,
    double? latitude,
    double? longitude,
    required String notes,
    required String paymentMethod,
    double tipAmount = 0.0,
    required List<Map<String, dynamic>> items,
  }) async {
    final body = jsonEncode({
      'customer_name': customerName,
      'full_name': customerName,
      'customer_phone': customerPhone,
      'phone': customerPhone,
      'service_type': serviceType,
      'delivery_address': deliveryAddress,
      'address': deliveryAddress,
      'latitude': latitude,
      'longitude': longitude,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'payment_method': paymentMethod,
      'tip_amount': tipAmount,
      'notes': notes,
      'items': items,
    });

    final response = await http.post(
      Uri.parse('$baseUrl/api/mobile/customer/order/create/'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final err = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(
          err['message'] ?? err['error'] ?? 'Buyurtma yaratishda xatolik');
    }
  }

  // 5. Telefon raqami bo'yicha barcha buyurtmalar tarixi
  static Future<List<CustomerOrder>> fetchOrders(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final response = await http.get(
      Uri.parse('$baseUrl/api/mobile/customer/orders/$cleanPhone/'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      List<CustomerOrder> orders = (data['orders'] as List? ?? [])
          .map((o) => CustomerOrder.fromJson(o))
          .toList();
      return orders;
    } else {
      return [];
    }
  }

  // 6. Bitta buyurtma holatini jonli kuzatish
  static Future<CustomerOrder> getOrderStatus(int orderId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/mobile/customer/order/$orderId/status/'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return CustomerOrder.fromJson(data);
    } else {
      throw Exception('Buyurtma holati topilmadi (${response.statusCode})');
    }
  }

  // 7. Kuryer va Restoranga choychaqa (Tip) hamda sharh yuborish
  static Future<bool> submitTipAndReview({
    required int orderId,
    required double tipAmount,
    required int rating,
    required String review,
  }) async {
    final body = jsonEncode({
      'order_id': orderId,
      'tip_amount': tipAmount,
      'rating': rating,
      'review': review,
    });

    final response = await http.post(
      Uri.parse('$baseUrl/api/mobile/customer/tip/'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    return response.statusCode == 200;
  }
}
