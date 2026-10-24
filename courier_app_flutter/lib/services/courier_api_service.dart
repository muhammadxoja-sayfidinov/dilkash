import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/courier_order.dart';
import 'staff_api_service.dart';

class CourierApiService {
  static String baseUrl = 'http://127.0.0.1:8000';

  static void setBaseUrl(String url) {
    baseUrl = url;
    StaffApiService.setBaseUrl(url);
  }

  // Kuryer login (Telefon va PIN)
  static Future<CourierUser> login(String phone, String pin) async {
    final staff = await StaffApiService.login(
      role: 'courier',
      phone: phone,
      pin: pin,
    );
    return staff.toCourierUser();
  }

  // Kuryerga biriktirilgan buyurtmalarni olish
  static Future<List<CourierOrder>> fetchAssignedOrders(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/mobile/courier/orders/?token=$token'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      List<CourierOrder> orders = (data['orders'] as List)
          .map((o) => CourierOrder.fromJson(o))
          .toList();
      return orders;
    } else {
      throw Exception('Buyurtmalarni yuklab bo\'lmadi');
    }
  }

  // Statusni o'zgartirish ('yolda' yoki 'yetkazildi')
  static Future<bool> updateOrderStatus({
    required int orderId,
    required String token,
    required String newStatus,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/mobile/courier/order/$orderId/update-status/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'new_status': newStatus,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['status'] == 'success';
    } else {
      final err = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(err['error'] ?? 'Statusni yangilashda xatolik');
    }
  }

  // Kuryer zakaz raqamini yozish orqali buyurtmani o'ziga biriktirib olishi
  static Future<Map<String, dynamic>> claimOrderByNumber({
    required String orderNumber,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/mobile/courier/order/claim/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'order_number': orderNumber,
        'token': token,
      }),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200 &&
        (data['success'] == true || data['status'] == 'success')) {
      return data;
    } else {
      throw Exception(data['message'] ??
          data['error'] ??
          'Buyurtmani biriktirib bo\'lmadi');
    }
  }

  // Kuryer tanlab olishi mumkin bo'lgan ochiq buyurtmalarni olish
  static Future<List<CourierOrder>> fetchAvailableOrders(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/mobile/courier/available-orders/?token=$token'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      List<CourierOrder> orders = (data['orders'] as List? ?? [])
          .map((o) => CourierOrder.fromJson(o))
          .toList();
      return orders;
    } else {
      throw Exception('Ochiq buyurtmalarni yuklab bo\'lmadi');
    }
  }

  // Geolokatsiyani yangilash
  static Future<void> updateLocation({
    required String token,
    required double lat,
    required double lng,
  }) async {
    await http.post(
      Uri.parse('$baseUrl/api/mobile/courier/location/update/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'lat': lat,
        'lng': lng,
      }),
    );
  }
}
