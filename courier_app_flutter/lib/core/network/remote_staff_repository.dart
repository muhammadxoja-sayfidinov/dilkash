import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../auth/staff_session.dart';
import '../config/app_config.dart';
import '../state_machine/order_state_machine.dart';
import 'local_discovery_service.dart';
import 'staff_repository.dart';

class RemoteStaffRepository implements StaffRepository {
  RemoteStaffRepository({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _overrideBaseUrl = baseUrl;

  static final RemoteStaffRepository instance = RemoteStaffRepository();

  final http.Client _client;
  final String? _overrideBaseUrl;
  StaffSession? _session;
  bool isLocalPosConnected = false;

  static const Duration _timeout = Duration(seconds: 10);

  String get activeBaseUrlDisplay {
    if (_overrideBaseUrl != null) return _overrideBaseUrl!;
    final resolved = AppConfig.resolveBaseUrl(forCourier: false);
    if (resolved.isEmpty && AppConfig.isLocalPosMode) {
      return 'Wi-Fi POS topilmadi';
    }
    return resolved;
  }

  String _resolveUrl({required bool preferCourier}) {
    if (_overrideBaseUrl != null) return _overrideBaseUrl!;
    final url = AppConfig.resolveBaseUrl(forCourier: preferCourier);
    if (!preferCourier && AppConfig.isLocalPosMode && url.isEmpty) {
      throw Exception(
        'Wi-Fi tarmoqda Dilkash POS Hub topilmadi. Avval POS manzilini izlang yoki kiriting.',
      );
    }
    return url;
  }

  void applySession(StaffSession? session) {
    _session = session;
  }

  Map<String, String> _headers({bool preferCourier = false}) {
    final token = _session == null
        ? ''
        : (preferCourier ? _session!.effectiveCourierToken : _session!.activeToken);
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  String _normalizeTableNum(String raw) {
    var s = raw.trim().toUpperCase();
    if (s.startsWith('T-')) {
      s = s.substring(2);
    }
    if (s.startsWith('#')) {
      s = s.substring(1);
    }
    final parsed = int.tryParse(s);
    if (parsed != null) return parsed.toString();
    return s.isEmpty ? '1' : s;
  }

  Map<String, dynamic> _decodeJson(http.Response res) {
    final text = utf8.decode(res.bodyBytes);
    dynamic parsed;
    try {
      parsed = text.isNotEmpty ? jsonDecode(text) : <String, dynamic>{};
    } catch (_) {
      parsed = <String, dynamic>{};
    }

    final map = parsed is Map<String, dynamic>
        ? parsed
        : <String, dynamic>{'data': parsed};

    if (res.statusCode < 200 || res.statusCode >= 300 || map['success'] == false) {
      final msg = map['message']?.toString() ??
          map['error']?.toString() ??
          'Server xatoligi (${res.statusCode})';
      throw Exception(msg);
    }
    return map;
  }

  Future<Map<String, dynamic>> _get(String path, {bool preferCourier = false}) async {
    final targetBase = _resolveUrl(preferCourier: preferCourier);
    try {
      final res = await _client
          .get(Uri.parse('$targetBase$path'), headers: _headers(preferCourier: preferCourier))
          .timeout(_timeout);
      final parsed = _decodeJson(res);
      if (parsed['source'] == 'pos_local_hub' ||
          (!preferCourier && AppConfig.isLocalPosMode && targetBase == AppConfig.posLocalBaseUrl)) {
        isLocalPosConnected = true;
      } else {
        isLocalPosConnected = false;
      }
      return parsed;
    } on TimeoutException {
      if (!preferCourier && AppConfig.isLocalPosMode) {
        throw Exception(
          'Dilkash POS ($targetBase) javob bermadi. Kompyuterdagi POS ochiqligini va bir xil Wi-Fi ga ulanganingizni tekshiring.',
        );
      }
      throw Exception('Server javob bermadi (vaqt tugadi). Internetni tekshiring.');
    } on SocketException {
      if (!preferCourier && AppConfig.isLocalPosMode) {
        throw Exception(
          'Dilkash POS ($targetBase) ga ulanib bo’lmadi. Wi-Fi tarmoqni va POS dasturini tekshiring.',
        );
      }
      throw Exception('Serverga ulanib bo’lmadi. Tarmoqni tekshiring.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Tarmoq xatoligi: $e');
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool preferCourier = false,
  }) async {
    final targetBase = _resolveUrl(preferCourier: preferCourier);
    try {
      final res = await _client
          .post(
            Uri.parse('$targetBase$path'),
            headers: _headers(preferCourier: preferCourier),
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      final parsed = _decodeJson(res);
      if (!preferCourier && AppConfig.isLocalPosMode && targetBase == AppConfig.posLocalBaseUrl) {
        isLocalPosConnected = true;
      }
      return parsed;
    } on TimeoutException {
      if (!preferCourier && AppConfig.isLocalPosMode) {
        throw Exception(
          'Dilkash POS ($targetBase) javob bermadi. Kompyuterdagi POS ochiqligini va bir xil Wi-Fi ga ulanganingizni tekshiring.',
        );
      }
      throw Exception('Server javob bermadi (vaqt tugadi). Internetni tekshiring.');
    } on SocketException {
      if (!preferCourier && AppConfig.isLocalPosMode) {
        throw Exception(
          'Dilkash POS ($targetBase) ga ulanib bo’lmadi. Wi-Fi tarmoqni va POS dasturini tekshiring.',
        );
      }
      throw Exception('Serverga ulanib bo’lmadi. Tarmoqni tekshiring.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Tarmoq xatoligi: $e');
    }
  }

  @override
  Future<StaffSession> authenticate({
    required String phone,
    required String pin,
  }) async {
    if (_overrideBaseUrl == null && AppConfig.isLocalPosMode && !AppConfig.hasLocalPos) {
      final discovered = await LocalDiscoveryService.discoverPosHub();
      if (discovered != null) {
        await AppConfig.setLocalPosBaseUrl(discovered);
      }
    }

    final res = await _post('/api/mobile/staff/login/', {
      'role': 'auto',
      'phone': phone.trim(),
      'pin': pin.trim(),
    });

    final user = (res['user'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final waiter = res['waiter'] as Map<String, dynamic>?;
    final courier = res['courier'] as Map<String, dynamic>?;

    final rawRoles = (res['assigned_roles'] as List<dynamic>?) ??
        (user['assigned_roles'] as List<dynamic>?) ??
        [res['role'] ?? 'waiter'];
    final assignedRoles = rawRoles.map((e) => e.toString()).toList();
    final activeRole = (user['active_role'] ?? res['role'] ?? assignedRoles.first).toString();

    final session = StaffSession(
      id: (user['id'] as num?)?.toInt() ?? 0,
      waiterId: (user['waiter_id'] as num?)?.toInt() ?? (waiter?['id'] as num?)?.toInt(),
      courierId: (user['courier_id'] as num?)?.toInt() ?? (courier?['id'] as num?)?.toInt(),
      name: (user['name'] ?? '').toString(),
      phone: (user['phone'] ?? phone).toString(),
      staffCode: (user['staff_code'] ?? 'DIL-${user['id'] ?? 1}').toString(),
      token: (user['token'] ?? '').toString(),
      waiterToken: (user['waiter_token'] ?? waiter?['token'])?.toString(),
      courierToken: (user['courier_token'] ?? courier?['token'])?.toString(),
      assignedRoles: assignedRoles,
      activeRole: activeRole,
      vehicleInfo: (user['vehicle_info'] ?? courier?['vehicle_info'] ?? '').toString(),
    );

    _session = session;
    return session;
  }

  Map<String, dynamic> _normalizeTable(Map<String, dynamic> raw) {
    final tableNumber = (raw['table_number'] ?? raw['number'] ?? '').toString();
    final order = raw['order'] as Map<String, dynamic>?;
    final call = raw['call'] as Map<String, dynamic>?;
    final isOccupied = raw['is_occupied'] == true || order != null;

    var stageName = raw['stage']?.toString();
    if (stageName == null || stageName.isEmpty) {
      if (order != null) {
        final callReason = call?['reason']?.toString().toLowerCase() ?? '';
        if (callReason.contains('hisob') || callReason.contains('chek')) {
          stageName = TableStage.billRequested.name;
        } else if (order['status'] == 'tayor') {
          stageName = TableStage.ready.name;
        } else {
          stageName = TableStage.occupied.name;
        }
      } else {
        stageName = TableStage.free.name;
      }
    }

    final rawItems = (order?['items'] as List<dynamic>?) ?? const [];
    final normalizedItems = rawItems.map((entry) {
      final it = Map<String, dynamic>.from(entry as Map);
      return {
        'id': (it['id'] as num?)?.toInt() ?? 0,
        'product_id': (it['product_id'] as num?)?.toInt(),
        'dish_name': (it['dish_name'] ?? it['name'] ?? '').toString(),
        'quantity': (it['quantity'] as num?)?.toInt() ?? 1,
        'price': (it['price'] as num?)?.toDouble() ?? 0.0,
        'total': (it['total'] as num?)?.toDouble() ?? 0.0,
        'status': (it['status'] ?? (order?['status'] == 'tayor' ? 'ready' : 'cooking')).toString(),
      };
    }).toList();

    return {
      'number': (raw['number'] as num?)?.toInt() ?? int.tryParse(tableNumber) ?? 0,
      'table_number': tableNumber,
      'name': (raw['name'] ?? 'Stol #$tableNumber').toString(),
      'capacity': (raw['capacity'] as num?)?.toInt() ?? 4,
      'status': stageName,
      'guest_count': (order?['guests_count'] as num?)?.toInt() ??
          (raw['guests_count'] as num?)?.toInt() ??
          (isOccupied ? 2 : 0),
      'products_total': (order?['products_total'] as num?)?.toDouble() ?? 0.0,
      'service_fee_amount': (order?['service_fee_amount'] as num?)?.toDouble() ?? 0.0,
      'total_amount': (order?['total_amount'] as num?)?.toDouble() ?? 0.0,
      'order_id': (order?['id'] as num?)?.toInt(),
      'order_number': order?['order_number']?.toString() ?? '',
      'order_status': order?['status']?.toString() ?? '',
      'assigned_waiter_id': (raw['assigned_waiter_id'] as num?)?.toInt(),
      'assigned_waiter_name': raw['assigned_waiter_name']?.toString(),
      'call': call,
      'items': normalizedItems,
    };
  }

  // --- WAITER METHODS ---

  @override
  Future<List<Map<String, dynamic>>> fetchTables() async {
    final res = await _get('/api/waiter/floor-status/');
    final rawTables = (res['tables'] as List<dynamic>?) ?? const [];
    return rawTables
        .map((e) => _normalizeTable(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMenu() async {
    final res = await _get('/api/mobile/customer/menu/');
    final cats = (res['categories'] as List<dynamic>?) ?? const [];
    return cats.map((rawCat) {
      final cat = Map<String, dynamic>.from(rawCat as Map);
      final prods = (cat['products'] as List<dynamic>?) ?? const [];
      return {
        'id': (cat['id'] as num?)?.toInt() ?? 0,
        'name': (cat['name'] ?? '').toString(),
        'description': (cat['description'] ?? '').toString(),
        'dishes': prods.map((rawP) {
          final p = Map<String, dynamic>.from(rawP as Map);
          return {
            'id': (p['id'] as num?)?.toInt() ?? 0,
            'name': (p['name'] ?? '').toString(),
            'price': (p['price'] as num?)?.toDouble() ?? 0.0,
            'description': (p['description'] ?? '').toString(),
            'is_available': p['is_available'] != false,
            'image_url': (p['image_url'] ?? p['image'] ?? '').toString(),
          };
        }).toList(),
      };
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> openTable(String tableNumber) async {
    final norm = _normalizeTableNum(tableNumber);
    if (_session != null) {
      await _post('/api/waiter/table/$norm/assign/', {
        'waiter_id': _session!.effectiveWaiterId,
        'waiter_name': _session!.name,
        'token': _session!.effectiveWaiterToken,
      });
    }
    final tables = await fetchTables();
    return tables.firstWhere(
      (t) => t['table_number'] == norm,
      orElse: () => <String, dynamic>{'table_number': norm, 'status': 'free', 'items': <Map<String, dynamic>>[]},
    );
  }

  @override
  Future<Map<String, dynamic>> sendOrderToKitchen({
    required String tableNumber,
    required List<Map<String, dynamic>> items,
    String notes = '',
  }) async {
    final norm = _normalizeTableNum(tableNumber);
    final products = items
        .map((it) => [it['id'] ?? it['product_id'] ?? it['name'] ?? it['dish_name'], it['quantity'] ?? 1])
        .toList();

    await _post('/api/waiter/order/create/', {
      'table_number': norm,
      if (_session != null) 'waiter_id': _session!.effectiveWaiterId,
      if (_session != null) 'waiter_name': _session!.name,
      if (_session != null) 'token': _session!.effectiveWaiterToken,
      'products': products,
      'notes': notes,
    });

    final tables = await fetchTables();
    return tables.firstWhere(
      (t) => t['table_number'] == norm,
      orElse: () => <String, dynamic>{'table_number': norm, 'status': 'occupied', 'items': <Map<String, dynamic>>[]},
    );
  }

  @override
  Future<bool> cancelOrderItem({
    required String tableNumber,
    required int itemId,
  }) async {
    await _post('/api/table/order/item/$itemId/update/', {'action': 'remove'});
    return true;
  }

  @override
  Future<bool> requestTableBill(String tableNumber) async {
    final norm = _normalizeTableNum(tableNumber);
    await _post('/api/waiter/bill-request/$norm/', {});
    return true;
  }

  @override
  Future<bool> dismissWaiterCall(int callId) async {
    await _post('/api/waiter/call/$callId/dismiss/', {});
    return true;
  }

  @override
  Future<bool> markTableDelivered(int orderId) async {
    await _post('/api/waiter/order/$orderId/deliver/', {});
    return true;
  }

  @override
  Future<Map<String, dynamic>> settleTableBill({
    required String tableNumber,
    required String paymentMethod,
  }) async {
    final norm = _normalizeTableNum(tableNumber);
    final tables = await fetchTables();
    final table = tables.firstWhere(
      (t) => t['table_number'] == norm,
      orElse: () => <String, dynamic>{},
    );
    final orderId = table['order_id'] as int?;
    if (orderId == null || orderId <= 0) {
      throw Exception('Ushbu stolda faol buyurtma topilmadi');
    }

    final res = await _post('/api/waiter/order/$orderId/close/', {
      'payment_method': paymentMethod,
    });
    return {
      'success': res['success'] == true,
      'table_number': norm,
      'payment_method': paymentMethod,
      'total': (table['total_amount'] as num?)?.toDouble() ?? 0.0,
    };
  }

  // --- COURIER METHODS ---

  CourierStage _mapBackendStatusToCourierStage(String status, {bool isMine = true}) {
    switch (status) {
      case 'yolda':
        return CourierStage.pickedUp;
      case 'yetkazildi':
        return CourierStage.delivered;
      case 'bekor_qilingan':
        return CourierStage.cancelled;
      case 'tasdiqlangan':
      case 'tayor':
        return isMine ? CourierStage.accepted : CourierStage.assigned;
      default:
        return CourierStage.assigned;
    }
  }

  Map<String, dynamic> _normalizeCourierOrder(Map<String, dynamic> raw, {required bool isMine}) {
    final status = (raw['status'] ?? 'yangi').toString();
    final pay = (raw['payment_method'] ?? '').toString().toLowerCase();
    final isCash = pay.contains('naqd');
    return {
      'id': (raw['id'] as num?)?.toInt() ?? 0,
      'order_number': (raw['order_number'] ?? '').toString(),
      'stage': _mapBackendStatusToCourierStage(status, isMine: isMine).name,
      'customer_name': (raw['customer_name'] ?? 'Mijoz').toString(),
      'customer_phone': (raw['customer_phone'] ?? '').toString(),
      'delivery_address': (raw['delivery_address'] ?? raw['address'] ?? '').toString(),
      'entrance_landmark': '',
      'payment_type': isCash ? 'cash' : 'paid',
      'amount_to_collect': isCash ? ((raw['total_amount'] as num?)?.toDouble() ?? 0.0) : 0.0,
      'kitchen_status': status == 'tayor' ? 'ready' : 'preparing',
      'notes': (raw['notes'] ?? '').toString(),
      'items': (raw['items'] as List<dynamic>?) ?? const [],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCourierOrders() async {
    final res = await _get('/api/mobile/courier/orders/', preferCourier: true);
    final myRaw = (res['my_active_orders'] as List<dynamic>?) ?? const [];
    final availRaw = (res['available_orders'] as List<dynamic>?) ?? const [];

    final seen = <int>{};
    final result = <Map<String, dynamic>>[];

    for (final item in myRaw) {
      final m = Map<String, dynamic>.from(item as Map);
      final id = (m['id'] as num?)?.toInt() ?? 0;
      if (m['status'] == 'yetkazildi' || m['status'] == 'bekor_qilingan') continue;
      if (seen.add(id)) result.add(_normalizeCourierOrder(m, isMine: true));
    }
    for (final item in availRaw) {
      final m = Map<String, dynamic>.from(item as Map);
      final id = (m['id'] as num?)?.toInt() ?? 0;
      if (seen.add(id)) result.add(_normalizeCourierOrder(m, isMine: false));
    }
    return result;
  }

  @override
  Future<bool> claimCourierOrder(int orderId) async {
    await _post('/api/mobile/courier/order/claim/', {
      'order_id': orderId,
      if (_session != null) 'courier_id': _session!.effectiveCourierId,
      if (_session != null) 'token': _session!.effectiveCourierToken,
    }, preferCourier: true);
    return true;
  }

  @override
  Future<bool> updateCourierStage(int orderId, CourierStage stage) async {
    if (stage == CourierStage.accepted) {
      return claimCourierOrder(orderId);
    }
    final status = stage == CourierStage.pickedUp ? 'yolda' : 'yetkazildi';
    await _post('/api/mobile/courier/order/$orderId/update-status/', {
      'status': status,
      if (_session != null) 'token': _session!.effectiveCourierToken,
    }, preferCourier: true);
    return true;
  }

  @override
  Future<bool> reportDeliveryProblem({
    required int orderId,
    required String reason,
    String notes = '',
  }) async {
    return true;
  }

  @override
  Future<Map<String, dynamic>> fetchCourierTodaySummary() async {
    final res = await _get('/api/mobile/courier/orders/', preferCourier: true);
    final myRaw = (res['my_active_orders'] as List<dynamic>?) ?? const [];
    final history = <Map<String, dynamic>>[];
    double cash = 0.0;
    for (final item in myRaw) {
      final m = Map<String, dynamic>.from(item as Map);
      if (m['status'] == 'yetkazildi') {
        final isCash = (m['payment_method'] ?? '').toString().toLowerCase().contains('naqd');
        final amt = (m['total_amount'] as num?)?.toDouble() ?? 0.0;
        if (isCash) cash += amt;
        history.add({
          'id': m['id'],
          'order_number': m['order_number'],
          'delivery_address': m['delivery_address'] ?? m['address'] ?? '',
          'time': m['created_at'] ?? '',
          'amount': amt,
          'payment_type': isCash ? 'cash' : 'paid',
        });
      }
    }
    return {
      'deliveries_count': history.length,
      'cash_collected': cash,
      'history': history,
    };
  }
}
