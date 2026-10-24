import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/courier_order.dart';
import '../models/staff_user.dart';
import '../models/waiter_models.dart';

class StaffApiService {
  static String baseUrl = 'http://127.0.0.1:8000';

  static void setBaseUrl(String url) {
    baseUrl = url;
  }

  // ==========================================
  // UNIFIED LOGIN (KURYER & OFITSIANT)
  // ==========================================
  static Future<StaffUser> login({
    required String role,
    required String phone,
    required String pin,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/mobile/staff/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': role,
        'phone': phone,
        'pin': pin,
      }),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200 && data['success'] == true) {
      final userData = data['user'] ?? data[role] ?? {};
      return StaffUser.fromJson(userData, role);
    } else {
      throw Exception(
          data['message'] ?? 'Telefon raqam yoki PIN-kod noto\'g\'ri');
    }
  }

  // ==========================================
  // KURYER METODLARI
  // ==========================================
  static Future<List<CourierOrder>> fetchCourierOrders(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/mobile/courier/orders/?token=$token'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      List<CourierOrder> orders = (data['orders'] as List? ?? [])
          .map((o) => CourierOrder.fromJson(o))
          .toList();
      return orders;
    } else {
      throw Exception('Buyurtmalarni yuklab bo\'lmadi');
    }
  }

  static Future<bool> updateCourierOrderStatus({
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
      return data['status'] == 'success' || data['success'] == true;
    } else {
      final err = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(
          err['message'] ?? err['error'] ?? 'Statusni yangilashda xatolik');
    }
  }

  static Future<void> updateCourierLocation({
    required String token,
    required double lat,
    required double lng,
  }) async {
    await http.post(
      Uri.parse('$baseUrl/api/mobile/courier/location/update/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'latitude': lat,
        'longitude': lng,
      }),
    );
  }

  // ==========================================
  // OFITSIANT METODLARI
  // ==========================================
  static Future<List<RestaurantTableModel>> fetchFloorStatus() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/waiter/floor-status/'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final rawTables = data['tables'] as List? ?? [];
      return rawTables.map((t) => RestaurantTableModel.fromJson(t)).toList();
    } else {
      throw Exception('Stollar ma\'lumotini yuklab bo\'lmadi');
    }
  }

  static Future<List<WaiterCategoryModel>> fetchMenu() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/mobile/customer/menu/'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final rawCategories = data['categories'] as List? ?? [];
      return rawCategories.map((c) => WaiterCategoryModel.fromJson(c)).toList();
    } else {
      throw Exception('Menyuni yuklab bo\'lmadi');
    }
  }

  static Future<Map<String, dynamic>> createWaiterOrder({
    required String tableNumber,
    required String waiterName,
    int? waiterId,
    required List<List<dynamic>> products,
    String notes = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/waiter/order/create/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'table_number': tableNumber,
        'waiter_name': waiterName,
        'waiter_id': waiterId,
        'products': products,
        'notes': notes,
        'auto_assign': true,
      }),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200 && data['success'] == true) {
      return Map<String, dynamic>.from(data);
    } else {
      throw Exception(data['message'] ?? 'Buyurtma yaratib bo\'lmadi');
    }
  }

  static Future<Map<String, dynamic>> triggerStationPrint({
    required int orderId,
    String department = 'all',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/orders/$orderId/print/$department/'),
        headers: {'Content-Type': 'application/json'},
      );
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<bool> assignTableToWaiter({
    required String tableNumber,
    required int waiterId,
    required String waiterName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/waiter/table/$tableNumber/assign/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'waiter_id': waiterId,
        'waiter_name': waiterName,
      }),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200 && data['success'] == true) {
      return true;
    } else {
      throw Exception(data['message'] ?? 'Stolga biriktirib bo\'lmadi');
    }
  }

  static Future<bool> releaseTableFromWaiter({
    required String tableNumber,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/waiter/table/$tableNumber/release/'),
      headers: {'Content-Type': 'application/json'},
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return response.statusCode == 200 && data['success'] == true;
  }

  static Future<bool> dismissWaiterCall(int callId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/waiter/call/$callId/dismiss/'),
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['success'] == true;
  }

  static Future<bool> deliverOrderToTable(int orderId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/waiter/order/$orderId/deliver/'),
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['success'] == true;
  }

  static Future<bool> requestTableBill(String tableNumber) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/waiter/bill-request/$tableNumber/'),
    );
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['success'] == true;
  }
}
