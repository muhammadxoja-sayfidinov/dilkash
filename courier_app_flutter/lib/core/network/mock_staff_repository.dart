// Mock Staff Repository with Realistic Uzbek Restaurant Data
// Dilkash Milliy Taomlar Restorani (Toshkent)

import 'dart:async';
import '../auth/staff_session.dart';
import '../state_machine/order_state_machine.dart';
import 'staff_repository.dart';

class MockStaffRepository implements StaffRepository {
  MockStaffRepository._();
  static final MockStaffRepository instance = MockStaffRepository._();

  // In-memory staff list
  final List<Map<String, dynamic>> _staffAccounts = [
    {
      'id': 1,
      'name': 'Jasur Rahimov',
      'phone': '+998901234567',
      'staff_code': 'DIL-101',
      'pin': '1234',
      'assigned_roles': ['courier', 'waiter'],
      'vehicle_info': 'Honda Dio Scooter (Oq)',
    },
    {
      'id': 2,
      'name': 'Bobur Mirzayev',
      'phone': '+998935551122',
      'staff_code': 'DIL-202',
      'pin': '1234',
      'assigned_roles': ['courier'],
      'vehicle_info': 'Chevrolet Spark (Qora)',
    },
    {
      'id': 3,
      'name': 'Malika Karimova',
      'phone': '+998977778899',
      'staff_code': 'DIL-303',
      'pin': '1234',
      'assigned_roles': ['waiter'],
      'vehicle_info': '',
    },
  ];

  // In-memory Tables (ONLY 4 statuses: free, occupied, ready, billRequested)
  final List<Map<String, dynamic>> _tables = [
    {
      'table_number': 'T-01',
      'status': TableStage.occupied.name,
      'guest_count': 4,
      'elapsed_minutes': 14,
      'total_amount': 150000.0,
      'items': [
        {
          'id': 1,
          'dish_name': 'Toshkent To’y Oshi',
          'quantity': 2,
          'price': 45000.0,
          'status': 'cooking', // cooking or ready
        },
        {
          'id': 2,
          'dish_name': 'Achichuk salati',
          'quantity': 2,
          'price': 15000.0,
          'status': 'cooking',
        },
        {
          'id': 3,
          'dish_name': 'Rayhon sharbati 1L',
          'quantity': 1,
          'price': 30000.0,
          'status': 'cooking',
        },
      ],
    },
    {
      'table_number': 'T-02',
      'status': TableStage.free.name,
      'guest_count': 0,
      'elapsed_minutes': 0,
      'total_amount': 0.0,
      'items': <Map<String, dynamic>>[],
    },
    {
      'table_number': 'T-03',
      'status': TableStage.ready.name, // Kitchen marked ready!
      'guest_count': 6,
      'elapsed_minutes': 22,
      'total_amount': 348000.0,
      'items': [
        {
          'id': 4,
          'dish_name': 'Qozon Kabob (Barra qo’y)',
          'quantity': 4,
          'price': 65000.0,
          'status': 'ready',
        },
        {
          'id': 5,
          'dish_name': 'G’ijduvon shashlik',
          'quantity': 4,
          'price': 22000.0,
          'status': 'ready',
        },
      ],
    },
    {
      'table_number': 'T-04',
      'status': TableStage.occupied.name,
      'guest_count': 2,
      'elapsed_minutes': 8,
      'total_amount': 76000.0,
      'items': [
        {
          'id': 6,
          'dish_name': 'Lag’mon Cho’zma',
          'quantity': 2,
          'price': 38000.0,
          'status': 'cooking',
        },
      ],
    },
    {
      'table_number': 'T-05',
      'status': TableStage.billRequested.name,
      'guest_count': 3,
      'elapsed_minutes': 35,
      'total_amount': 150000.0,
      'items': [
        {
          'id': 7,
          'dish_name': 'Toshkent To’y Oshi',
          'quantity': 2,
          'price': 45000.0,
          'status': 'ready',
        },
        {
          'id': 8,
          'dish_name': 'Tandir Somsa',
          'quantity': 5,
          'price': 12000.0,
          'status': 'ready',
        },
      ],
    },
    {
      'table_number': 'T-06',
      'status': TableStage.free.name,
      'guest_count': 0,
      'elapsed_minutes': 0,
      'total_amount': 0.0,
      'items': <Map<String, dynamic>>[],
    },
    {
      'table_number': 'T-07',
      'status': TableStage.occupied.name,
      'guest_count': 5,
      'elapsed_minutes': 18,
      'total_amount': 150000.0,
      'items': [
        {
          'id': 9,
          'dish_name': 'Jaz shashlik (Mol go’shti)',
          'quantity': 6,
          'price': 25000.0,
          'status': 'cooking',
        },
      ],
    },
    {
      'table_number': 'T-08',
      'status': TableStage.free.name,
      'guest_count': 0,
      'elapsed_minutes': 0,
      'total_amount': 0.0,
      'items': <Map<String, dynamic>>[],
    },
  ];

  // In-memory Menu with out-of-stock "tugagan" status
  final List<Map<String, dynamic>> _menuCategories = [
    {
      'name': 'Milliy Taomlar',
      'dishes': [
        {
          'id': 101,
          'name': 'Toshkent To’y Oshi',
          'price': 45000.0,
          'description': 'Devzira guruch, barra mol go’shti, sariq sabzi, mayiz',
          'is_available': true,
        },
        {
          'id': 102,
          'name': 'Qozon Kabob (Barra qo’y)',
          'price': 65000.0,
          'description': 'Tillarang qovurilgan kartoshka va suvli qo’y go’shti',
          'is_available': true,
        },
        {
          'id': 103,
          'name': 'Lag’mon Cho’zma',
          'price': 38000.0,
          'description': 'Cho’zilgan yangi xamir, barra go’sht va sabzavotlar',
          'is_available': false, // "tugagan"
        },
      ],
    },
    {
      'name': 'Shashliklar',
      'dishes': [
        {
          'id': 201,
          'name': 'G’ijduvon Qiymali Shashlik',
          'price': 22000.0,
          'description': 'Charvi yog’i va xushbo’y ziravorlar bilan qorilgan',
          'is_available': true,
        },
        {
          'id': 202,
          'name': 'Jaz Shashlik (Mol go’shti)',
          'price': 25000.0,
          'description': 'Marinadlangan lahm go’sht va piyoz',
          'is_available': true,
        },
      ],
    },
    {
      'name': 'Salat & Somsa',
      'dishes': [
        {
          'id': 301,
          'name': 'Achichuk Salati',
          'price': 15000.0,
          'description': 'Yulduz pomidori, shirin piyoz, yangi rayhon',
          'is_available': true,
        },
        {
          'id': 302,
          'name': 'Tandir Go’shtli Somsa',
          'price': 12000.0,
          'description': 'Qatlama xamir, mayda to’g’ralgan mol go’shti, sedana',
          'is_available': true,
        },
      ],
    },
    {
      'name': 'Ichimliklar',
      'dishes': [
        {
          'id': 401,
          'name': 'Rayhon Sharbati 1L',
          'price': 25000.0,
          'description': 'Binafsharang rayhon va limon sharbati',
          'is_available': true,
        },
        {
          'id': 402,
          'name': 'Ko’k Choy (Limon & Novvot)',
          'price': 10000.0,
          'description': 'Samovarda damlangan xushbo’y choy',
          'is_available': true,
        },
      ],
    },
  ];

  // In-memory Courier Orders
  final List<Map<String, dynamic>> _courierOrders = [
    {
      'id': 177,
      'order_number': 'ORD-177',
      'stage': CourierStage.accepted.name, // accepted -> pickedUp -> delivered
      'customer_name': 'Alisher Usmonov',
      'customer_phone': '+998901234567',
      'delivery_address': 'Chilonzor 9-mavze, 14-uy',
      'entrance_landmark': '2-kirish, 4-qavat, 28-x. Rayhon ro’parasida',
      'payment_type': 'cash', // 'cash' or 'paid'
      'amount_to_collect': 105000.0,
      'kitchen_status': 'ready', // 'tayyor' or 'tayyorlanmoqda'
      'notes': 'Iltimos, eshik qo’ng’irog’i chalmang',
      'items': [
        {'dish_name': 'Toshkent To’y Oshi', 'quantity': 2, 'price': 45000.0},
        {'dish_name': 'Achichuk salati', 'quantity': 1, 'price': 15000.0},
      ],
    },
    {
      'id': 178,
      'order_number': 'ORD-178',
      'stage': CourierStage.assigned.name, // New order!
      'customer_name': 'Nodira Azimova',
      'customer_phone': '+998935559988',
      'delivery_address': 'Amir Temur shoh ko’chasi, 25-uy',
      'entrance_landmark': '1-kirish, 7-qavat, Wyndham mehmonxonasi yonida',
      'payment_type': 'paid', // to’langan
      'amount_to_collect': 0.0,
      'kitchen_status': 'preparing', // tayyorlanmoqda
      'notes': '',
      'items': [
        {'dish_name': 'Qozon Kabob', 'quantity': 1, 'price': 65000.0},
        {'dish_name': 'Tandir Somsa', 'quantity': 4, 'price': 12000.0},
      ],
    },
    {
      'id': 179,
      'order_number': 'ORD-179',
      'stage': CourierStage.assigned.name, // New order!
      'customer_name': 'Dilshod Rahmatov',
      'customer_phone': '+998971112233',
      'delivery_address': 'Mirobod ko’chasi, 8-uy',
      'entrance_landmark': '3-kirish, 2-qavat, 12-x. Rossiya mehmonxonasi yaqinida',
      'payment_type': 'cash',
      'amount_to_collect': 125000.0,
      'kitchen_status': 'ready', // tayyor
      'notes': 'Tezroq yetkazilsin iltimos',
      'items': [
        {'dish_name': 'G’ijduvon shashlik', 'quantity': 5, 'price': 22000.0},
        {'dish_name': 'Achichuk salati', 'quantity': 1, 'price': 15000.0},
      ],
    },
  ];

  // History of completed deliveries for Today screen
  final List<Map<String, dynamic>> _todayHistory = [
    {
      'id': 170,
      'order_number': 'ORD-170',
      'delivery_address': 'Yunusobod 4-mavze, 12-uy',
      'time': '16:40',
      'amount': 85000.0,
      'payment_type': 'cash',
    },
    {
      'id': 171,
      'order_number': 'ORD-171',
      'delivery_address': 'Mustaqillik shoh ko’chasi, 7-uy',
      'time': '17:15',
      'amount': 120000.0,
      'payment_type': 'paid',
    },
    {
      'id': 172,
      'order_number': 'ORD-172',
      'delivery_address': 'Navoiy ko’chasi, 44-uy',
      'time': '17:55',
      'amount': 160000.0,
      'payment_type': 'cash',
    },
  ];

  @override
  Future<StaffSession> authenticate({
    required String phone,
    required String pin,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    Map<String, dynamic>? match;
    for (final staff in _staffAccounts) {
      final matchesPhone =
          staff['phone'].toString().contains(phone.replaceAll(RegExp(r'\D'), ''));
      if (matchesPhone && staff['pin'] == pin) {
        match = staff;
        break;
      }
    }

    if (match == null) {
      if (pin == '1234') {
        match = _staffAccounts[0]; // Jasur Rahimov (courier & waiter)
      } else {
        throw Exception('Telefon raqami yoki PIN-kod noto’g’ri!');
      }
    }

    final assignedRoles = List<String>.from(match['assigned_roles']);
    return StaffSession(
      id: match['id'] as int,
      name: match['name'] as String,
      phone: match['phone'] as String,
      staffCode: match['staff_code'] as String,
      token: 'tok_${match['id']}_${DateTime.now().millisecondsSinceEpoch}',
      assignedRoles: assignedRoles,
      activeRole: assignedRoles.first,
      vehicleInfo: match['vehicle_info'] as String? ?? '',
    );
  }

  // --- COURIER METHODS ---

  @override
  Future<List<Map<String, dynamic>>> fetchCourierOrders() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return List<Map<String, dynamic>>.from(_courierOrders);
  }

  @override
  Future<bool> claimCourierOrder(int orderId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final index = _courierOrders.indexWhere((o) => o['id'] == orderId);
    if (index != -1) {
      _courierOrders[index]['stage'] = CourierStage.accepted.name;
      return true;
    }
    return false;
  }

  @override
  Future<bool> updateCourierStage(int orderId, CourierStage stage) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final index = _courierOrders.indexWhere((o) => o['id'] == orderId);
    if (index != -1) {
      _courierOrders[index]['stage'] = stage.name;
      if (stage == CourierStage.delivered) {
        final completed = _courierOrders.removeAt(index);
        _todayHistory.insert(0, {
          'id': completed['id'],
          'order_number': completed['order_number'],
          'delivery_address': completed['delivery_address'],
          'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
          'amount': completed['amount_to_collect'],
          'payment_type': completed['payment_type'],
        });
      }
      return true;
    }
    return false;
  }

  @override
  Future<bool> reportDeliveryProblem({
    required int orderId,
    required String reason,
    String notes = '',
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _courierOrders.indexWhere((o) => o['id'] == orderId);
    if (index != -1) {
      _courierOrders[index]['stage'] = CourierStage.problem.name;
      _courierOrders[index]['problem_reason'] = reason;
      return true;
    }
    return false;
  }

  @override
  Future<Map<String, dynamic>> fetchCourierTodaySummary() async {
    await Future.delayed(const Duration(milliseconds: 150));
    double cash = 0.0;
    for (final h in _todayHistory) {
      if (h['payment_type'] == 'cash') {
        cash += (h['amount'] as num).toDouble();
      }
    }
    return {
      'deliveries_count': _todayHistory.length,
      'cash_collected': cash,
      'history': List<Map<String, dynamic>>.from(_todayHistory),
    };
  }

  // --- WAITER METHODS ---

  @override
  Future<List<Map<String, dynamic>>> fetchTables() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return List<Map<String, dynamic>>.from(_tables);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMenu() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return List<Map<String, dynamic>>.from(_menuCategories);
  }

  @override
  Future<Map<String, dynamic>> openTable(String tableNumber) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final index = _tables.indexWhere((t) => t['table_number'] == tableNumber);
    if (index != -1) {
      if (_tables[index]['status'] == TableStage.free.name) {
        _tables[index]['status'] = TableStage.occupied.name;
        _tables[index]['guest_count'] = 2;
        _tables[index]['elapsed_minutes'] = 1;
        _tables[index]['total_amount'] = 0.0;
        _tables[index]['items'] = <Map<String, dynamic>>[];
      }
      return _tables[index];
    }
    throw Exception('Stol topilmadi');
  }

  @override
  Future<Map<String, dynamic>> sendOrderToKitchen({
    required String tableNumber,
    required List<Map<String, dynamic>> items,
    String notes = '',
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _tables.indexWhere((t) => t['table_number'] == tableNumber);
    if (index != -1) {
      _tables[index]['status'] = TableStage.occupied.name;
      final existingItems = List<Map<String, dynamic>>.from(_tables[index]['items'] as List);
      for (final it in items) {
        existingItems.add({
          'id': DateTime.now().millisecondsSinceEpoch + existingItems.length,
          'dish_name': it['name'] ?? it['dish_name'],
          'quantity': it['quantity'],
          'price': it['price'],
          'status': 'cooking',
        });
      }
      double total = 0.0;
      for (final it in existingItems) {
        total += ((it['price'] as num) * (it['quantity'] as num));
      }
      _tables[index]['items'] = existingItems;
      _tables[index]['total_amount'] = total;
      return _tables[index];
    }
    throw Exception('Stol topilmadi');
  }

  @override
  Future<bool> cancelOrderItem({
    required String tableNumber,
    required int itemId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final index = _tables.indexWhere((t) => t['table_number'] == tableNumber);
    if (index != -1) {
      final items = List<Map<String, dynamic>>.from(_tables[index]['items'] as List);
      final itemIndex = items.indexWhere((i) => i['id'] == itemId);
      if (itemIndex != -1) {
        // Can only cancel if cooking (before ready)
        items.removeAt(itemIndex);
        _tables[index]['items'] = items;
        double total = 0.0;
        for (final it in items) {
          total += ((it['price'] as num) * (it['quantity'] as num));
        }
        _tables[index]['total_amount'] = total;
        return true;
      }
    }
    return false;
  }

  @override
  Future<bool> requestTableBill(String tableNumber) async {
    await Future.delayed(const Duration(milliseconds: 120));
    final index = _tables.indexWhere((t) => t['table_number'] == tableNumber);
    if (index != -1) {
      _tables[index]['status'] = TableStage.billRequested.name;
      return true;
    }
    return false;
  }

  @override
  Future<bool> dismissWaiterCall(int callId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return true;
  }

  @override
  Future<bool> markTableDelivered(int orderId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return true;
  }

  @override
  Future<Map<String, dynamic>> settleTableBill({
    required String tableNumber,
    required String paymentMethod,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _tables.indexWhere((t) => t['table_number'] == tableNumber);
    if (index != -1) {
      final total = _tables[index]['total_amount'] as double;
      // Clear table
      _tables[index]['status'] = TableStage.free.name;
      _tables[index]['guest_count'] = 0;
      _tables[index]['elapsed_minutes'] = 0;
      _tables[index]['total_amount'] = 0.0;
      _tables[index]['items'] = <Map<String, dynamic>>[];
      return {
        'success': true,
        'table_number': tableNumber,
        'payment_method': paymentMethod,
        'total': total,
      };
    }
    throw Exception('Stol topilmadi');
  }
}
