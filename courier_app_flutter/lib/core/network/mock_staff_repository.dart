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
      'vehicle_info': 'Honda Dio Scooter (Oq, 01 A 777 BC)',
    },
    {
      'id': 2,
      'name': 'Bobur Mirzayev',
      'phone': '+998935551122',
      'staff_code': 'DIL-202',
      'pin': '1234',
      'assigned_roles': ['courier'],
      'vehicle_info': 'Chevrolet Spark (Qora, 01 X 123 AB)',
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

  // In-memory Tables
  final List<Map<String, dynamic>> _tables = [
    // Asosiy Zal
    {
      'table_number': 'T-01',
      'zone': 'Zal',
      'status': 'in_kitchen', // free, occupied, in_kitchen, ready, bill_requested, reserved
      'guest_count': 4,
      'waiter_name': 'Jasur Rahimov',
      'elapsed_minutes': 14,
      'total_amount': 240000.0,
      'active_call': false,
      'items': [
        {
          'id': 1,
          'dish_name': 'Toshkent Toʻy Oshi',
          'quantity': 3,
          'price': 45000.0,
          'portion': '1.0 pors',
          'extras': ['Qazi', 'Tuxum'],
          'status': 'preparing', // new, preparing, ready, served
          'station': 'Oshxona',
          'guest_seat': 1,
          'course': 'Asosiy taom',
        },
        {
          'id': 2,
          'dish_name': 'Achichuk salati',
          'quantity': 2,
          'price': 15000.0,
          'portion': 'standart',
          'extras': [],
          'status': 'served',
          'station': 'Salatxona',
          'guest_seat': 2,
          'course': 'Salat',
        },
        {
          'id': 3,
          'dish_name': 'Rayhon sharbati (1L)',
          'quantity': 1,
          'price': 25000.0,
          'portion': '1 litr',
          'extras': ['Muz bilan'],
          'status': 'served',
          'station': 'Bar',
          'guest_seat': 1,
          'course': 'Ichimlik',
        },
      ],
    },
    {
      'table_number': 'T-02',
      'zone': 'Zal',
      'status': 'free',
      'guest_count': 0,
      'waiter_name': '',
      'elapsed_minutes': 0,
      'total_amount': 0.0,
      'active_call': false,
      'items': [],
    },
    {
      'table_number': 'T-03',
      'zone': 'Zal',
      'status': 'ready', // Oshxona tayyorladi!
      'guest_count': 6,
      'waiter_name': 'Jasur Rahimov',
      'elapsed_minutes': 22,
      'total_amount': 390000.0,
      'active_call': true, // Stol ofitsiantni chaqirdi!
      'items': [
        {
          'id': 4,
          'dish_name': 'Qozon Kabob (Qoʻy goʻshti)',
          'quantity': 4,
          'price': 65000.0,
          'portion': '1.0 pors',
          'extras': ['Qovurilgan piyoz'],
          'status': 'ready',
          'station': 'Oshxona',
          'guest_seat': 1,
          'course': 'Asosiy taom',
        },
        {
          'id': 5,
          'dish_name': 'Gʻijduvon qiymali shashlik',
          'quantity': 4,
          'price': 22000.0,
          'portion': 'dona',
          'extras': ['Sirka va piyoz'],
          'status': 'ready',
          'station': 'Mangal',
          'guest_seat': 3,
          'course': 'Issiq taom',
        },
        {
          'id': 6,
          'dish_name': 'Koʻk choy limon va novvot bilan',
          'quantity': 2,
          'price': 10000.0,
          'portion': 'choynak',
          'extras': [],
          'status': 'served',
          'station': 'Bar',
          'guest_seat': 2,
          'course': 'Ichimlik',
        },
      ],
    },
    {
      'table_number': 'T-04',
      'zone': 'Zal',
      'status': 'occupied',
      'guest_count': 2,
      'waiter_name': 'Malika Karimova',
      'elapsed_minutes': 8,
      'total_amount': 95000.0,
      'active_call': false,
      'items': [
        {
          'id': 7,
          'dish_name': 'Lagʻmon (Choʻzma)',
          'quantity': 2,
          'price': 38000.0,
          'portion': '1.0 pors',
          'extras': ['Achchiq laza'],
          'status': 'preparing',
          'station': 'Oshxona',
          'guest_seat': 1,
          'course': 'Birinchi taom',
        },
      ],
    },
    {
      'table_number': 'T-05',
      'zone': 'Zal',
      'status': 'bill_requested',
      'guest_count': 3,
      'waiter_name': 'Jasur Rahimov',
      'elapsed_minutes': 35,
      'total_amount': 185000.0,
      'active_call': false,
      'items': [
        {
          'id': 8,
          'dish_name': 'Toshkent Toʻy Oshi',
          'quantity': 2,
          'price': 45000.0,
          'portion': '1.0 pors',
          'extras': [],
          'status': 'served',
          'station': 'Oshxona',
          'guest_seat': 1,
          'course': 'Asosiy taom',
        },
        {
          'id': 9,
          'dish_name': 'Tandir Goʻshtli Somsa',
          'quantity': 5,
          'price': 12000.0,
          'portion': 'dona',
          'extras': ['Tomatli sous'],
          'status': 'served',
          'station': 'Tandir',
          'guest_seat': 2,
          'course': 'Pishiriq',
        },
      ],
    },

    // Terrasa (Ochiq havo)
    {
      'table_number': 'T-06',
      'zone': 'Terrasa',
      'status': 'free',
      'guest_count': 0,
      'waiter_name': '',
      'elapsed_minutes': 0,
      'total_amount': 0.0,
      'active_call': false,
      'items': [],
    },
    {
      'table_number': 'T-07',
      'zone': 'Terrasa',
      'status': 'in_kitchen',
      'guest_count': 5,
      'waiter_name': 'Jasur Rahimov',
      'elapsed_minutes': 11,
      'total_amount': 295000.0,
      'active_call': false,
      'items': [
        {
          'id': 10,
          'dish_name': 'Jaz shashlik (Mol goʻshti)',
          'quantity': 6,
          'price': 25000.0,
          'portion': 'dona',
          'extras': ['Marinadlangan piyoz'],
          'status': 'preparing',
          'station': 'Mangal',
          'guest_seat': 1,
          'course': 'Asosiy taom',
        },
      ],
    },
    {
      'table_number': 'T-08',
      'zone': 'Terrasa',
      'status': 'reserved',
      'guest_count': 8,
      'waiter_name': 'Malika Karimova',
      'elapsed_minutes': 0,
      'total_amount': 0.0,
      'active_call': false,
      'reservation_info': 'Sardor aka (19:30, 8 kishi, Tugʻilgan kun)',
      'items': [],
    },

    // VIP Xonalar
    {
      'table_number': 'VIP-1',
      'zone': 'VIP',
      'status': 'occupied',
      'guest_count': 10,
      'waiter_name': 'Jasur Rahimov',
      'elapsed_minutes': 45,
      'total_amount': 880000.0,
      'active_call': false,
      'items': [
        {
          'id': 11,
          'dish_name': 'Dilkash Xonadon Oshi (Maxsus tovoqda)',
          'quantity': 2,
          'price': 250000.0,
          'portion': 'katta tovoq',
          'extras': ['Bedana tuxumi', 'Qozi', 'Ot goʻshti'],
          'status': 'served',
          'station': 'Oshxona',
          'guest_seat': 1,
          'course': 'Asosiy taom',
        },
      ],
    },
    {
      'table_number': 'VIP-2',
      'zone': 'VIP',
      'status': 'free',
      'guest_count': 0,
      'waiter_name': '',
      'elapsed_minutes': 0,
      'total_amount': 0.0,
      'active_call': false,
      'items': [],
    },
  ];

  // In-memory Menu Categories
  final List<Map<String, dynamic>> _menuCategories = [
    {
      'name': 'Milliy Taomlar',
      'icon': 'restaurant',
      'dishes': [
        {
          'id': 101,
          'name': 'Toshkent Toʻy Oshi',
          'price': 45000.0,
          'description': 'Devzira guruch, barra mol goʻshti, sariq sabzi, noʻxat, mayiz',
          'station': 'Oshxona',
          'is_available': true,
          'sizes': ['1.0 pors (45 000)', '0.7 pors (35 000)'],
          'extras': [
            {'name': 'Qoʻshimcha Qazi', 'price': 12000.0},
            {'name': 'Bedana tuxumi (2 dona)', 'price': 5000.0},
            {'name': 'Achichuk salati', 'price': 15000.0},
          ],
          'removable_ingredients': ['Noʻxatsiz', 'Mayizsiz', 'Zirasiz'],
          'allergens': [],
        },
        {
          'id': 102,
          'name': 'Qozon Kabob (Barra qoʻy)',
          'price': 65000.0,
          'description': 'Qozonda qovurilgan tillarang kartoshka va suvli qoʻy goʻshti',
          'station': 'Oshxona',
          'is_available': true,
          'sizes': ['1.0 pors (65 000)'],
          'extras': [
            {'name': 'Qoʻshimcha qovurilgan piyoz', 'price': 4000.0},
            {'name': 'Sarimsoqli sous', 'price': 6000.0},
          ],
          'removable_ingredients': ['Piyozsiz'],
          'allergens': [],
        },
        {
          'id': 103,
          'name': 'Lagʻmon Choʻzma (Qovurma)',
          'price': 38000.0,
          'description': 'Qoʻlda choʻzilgan yangi xamir, mol goʻshti, bulgʻor qalampiri',
          'station': 'Oshxona',
          'is_available': true,
          'sizes': ['1.0 pors (38 000)'],
          'extras': [
            {'name': 'Achchiq Laza sousi', 'price': 3000.0},
          ],
          'removable_ingredients': ['Qalampirsiz', 'Sarimsoqsiz'],
          'allergens': ['Kleykovina (Gluten)'],
        },
      ],
    },
    {
      'name': 'Mangal & Shashliklar',
      'icon': 'outdoor_grill',
      'dishes': [
        {
          'id': 201,
          'name': 'Gʻijduvon Qiymali Shashlik',
          'price': 22000.0,
          'description': 'Yupqa charvi yogʻi bilan qorilgan xushboʻy qiymali shashlik',
          'station': 'Mangal',
          'is_available': true,
          'sizes': ['1 dona (22 000)'],
          'extras': [
            {'name': 'Marinadlangan piyoz', 'price': 3000.0},
            {'name': 'Sirka achchiq qalampir bilan', 'price': 2000.0},
          ],
          'removable_ingredients': ['Yogʻsiz'],
          'allergens': [],
        },
        {
          'id': 202,
          'name': 'Jaz Mol Goʻshti Shashlik',
          'price': 25000.0,
          'description': 'Koriandr va zira bilan marinadlangan mol lahm goʻshti',
          'station': 'Mangal',
          'is_available': true,
          'sizes': ['1 dona (25 000)'],
          'extras': [],
          'removable_ingredients': [],
          'allergens': [],
        },
      ],
    },
    {
      'name': 'Salatlar & Tandir',
      'icon': 'local_dining',
      'dishes': [
        {
          'id': 301,
          'name': 'Achichuk Salati',
          'price': 15000.0,
          'description': 'Yupqa toʻgʻralgan Yulduz pomidori, shirin piyoz, yangi rayhon',
          'station': 'Salatxona',
          'is_available': true,
          'sizes': ['1 pors (15 000)'],
          'extras': [],
          'removable_ingredients': ['Piyozsiz', 'Achchiqsiz'],
          'allergens': [],
        },
        {
          'id': 302,
          'name': 'Tandir Goʻshtli Somsa',
          'price': 12000.0,
          'description': 'Qatlama xamir, mayda toʻgʻralgan mol goʻshti, zira, sedana',
          'station': 'Tandir',
          'is_available': true,
          'sizes': ['1 dona (12 000)'],
          'extras': [
            {'name': 'Qatiqli sous', 'price': 4000.0},
          ],
          'removable_ingredients': [],
          'allergens': ['Gluten'],
        },
      ],
    },
    {
      'name': 'Ichimliklar & Choylar',
      'icon': 'local_cafe',
      'dishes': [
        {
          'id': 401,
          'name': 'Rayhon Sharbati (Maxsus)',
          'price': 25000.0,
          'description': 'Yangi binafsharang rayhon, limon sharbati va shakar sharbati',
          'station': 'Bar',
          'is_available': true,
          'sizes': ['1 litr (25 000)', '0.5 litr (15 000)'],
          'extras': [{'name': 'Qoʻshimcha muz', 'price': 0.0}],
          'removable_ingredients': ['Muzsiz'],
          'allergens': [],
        },
        {
          'id': 402,
          'name': 'Koʻk Choy 95 (Limon va Novvot)',
          'price': 10000.0,
          'description': 'Samovar uslubida damlangan xushboʻy koʻk choy',
          'station': 'Bar',
          'is_available': true,
          'sizes': ['Choynak (10 000)'],
          'extras': [],
          'removable_ingredients': ['Novvotsiz', 'Limonsiz'],
          'allergens': [],
        },
      ],
    },
  ];

  // In-memory Courier Active & Available Orders
  final List<Map<String, dynamic>> _courierOrders = [
    {
      'id': 177,
      'order_number': 'ORD-177',
      'stage': OrderStage.headingToCafe.name, // headingToCafe, pickedUp, onTheWay, arrived, delivered
      'customer_name': 'Alisher Usmonov',
      'customer_phone': '+998901234567',
      'delivery_address': 'Toshkent sh., Chilonzor 9-mavze, 14-uy',
      'entrance': '2-podyezd',
      'floor': '4-qavat',
      'apartment': '28-xonadon',
      'intercom': '28K',
      'landmark': 'Rayhon milliy taomlari roʻparasida',
      'latitude': 41.2858,
      'longitude': 69.2045,
      'notes': 'Iltimos, eshik qoʻngʻirogʻini qattiq chalmang, chaqaloq uxlayapti',
      'payment_type': 'cash', // 'cash' or 'paid'
      'amount_to_collect': 104000.0,
      'delivery_fee': 20000.0,
      'distance_km': 3.4,
      'estimated_minutes': 18,
      'kitchen_status': 'ready', // 'preparing' or 'ready'
      'suggested_sequence': 1,
      'timestamps': {
        'assigned': '18:15',
        'heading_to_cafe': '18:17',
      },
      'checklist': [
        {'item': 'Toshkent Toʻy Oshi (2 pors)', 'checked': true},
        {'item': 'Achichuk salati (2 dona)', 'checked': true},
        {'item': 'Rayhon sharbati (1L)', 'checked': false},
        {'item': 'Non va anjomlar toʻplami', 'checked': true},
        {'item': 'Termosumka maxsus muhrlangan', 'checked': false},
      ],
      'items': [
        {'dish_name': 'Toshkent Toʻy Oshi', 'quantity': 2, 'price': 45000.0},
        {'dish_name': 'Achichuk salati', 'quantity': 2, 'price': 15000.0},
        {'dish_name': 'Rayhon sharbati 1L', 'quantity': 1, 'price': 25000.0},
      ],
    },
    {
      'id': 178,
      'order_number': 'ORD-178',
      'stage': OrderStage.assigned.name,
      'customer_name': 'Nodira Azimova',
      'customer_phone': '+998935559988',
      'delivery_address': 'Toshkent sh., Amir Temur shoh koʻchasi, 25-uy',
      'entrance': '1-kirish',
      'floor': '7-qavat',
      'apartment': '54-xonadon',
      'intercom': '54',
      'landmark': 'Wyndham mehmonxonasi yonida',
      'latitude': 41.3210,
      'longitude': 69.2815,
      'notes': 'Konditsionerli termosumkada olib kelinsin',
      'payment_type': 'paid', // Click orqali oldindan toʻlangan
      'amount_to_collect': 0.0,
      'delivery_fee': 20000.0,
      'distance_km': 5.1,
      'estimated_minutes': 25,
      'kitchen_status': 'preparing', // Oshxona hali pishirmoqda (3 daqiqa qoldi)
      'suggested_sequence': 2,
      'timestamps': {
        'assigned': '18:30',
      },
      'checklist': [
        {'item': 'Qozon Kabob (1 pors)', 'checked': false},
        {'item': 'Tandir Somsa (4 dona)', 'checked': false},
        {'item': 'Termosumka maxsus muhrlangan', 'checked': false},
      ],
      'items': [
        {'dish_name': 'Qozon Kabob', 'quantity': 1, 'price': 65000.0},
        {'dish_name': 'Tandir Somsa', 'quantity': 4, 'price': 12000.0},
      ],
    },
  ];

  // Pool of unassigned orders that couriers can claim
  final List<Map<String, dynamic>> _poolOrders = [
    {
      'id': 181,
      'order_number': 'ORD-181',
      'customer_name': 'Dilshod Rahmatov',
      'customer_phone': '+998971112233',
      'delivery_address': 'Toshkent sh., Mirobod koʻchasi, 8-uy',
      'entrance': '3-kirish',
      'floor': '2-qavat',
      'apartment': '12',
      'intercom': '12',
      'landmark': 'Rossiya mehmonxonasi yaqinida',
      'latitude': 41.3005,
      'longitude': 69.2715,
      'payment_type': 'cash',
      'amount_to_collect': 135000.0,
      'delivery_fee': 22000.0,
      'distance_km': 4.2,
      'kitchen_status': 'ready',
      'notes': 'Iltimos, tezroq yetkazilsin',
      'items': [
        {'dish_name': 'Gʻijduvon shashlik', 'quantity': 5, 'price': 22000.0},
        {'dish_name': 'Achichuk', 'quantity': 1, 'price': 15000.0},
      ],
    },
  ];

  // Today's Reservations
  final List<Map<String, dynamic>> _reservations = [
    {
      'id': 501,
      'guest_name': 'Sardor aka Xolmatov',
      'guest_phone': '+998909876543',
      'table_number': 'T-08',
      'zone': 'Terrasa',
      'guest_count': 8,
      'time': '19:30',
      'occasion': 'Tugʻilgan kun tantanasi',
      'is_arrived': false,
    },
    {
      'id': 502,
      'guest_name': 'Sherzod Qodirov',
      'guest_phone': '+998933334455',
      'table_number': 'VIP-2',
      'zone': 'VIP',
      'guest_count': 10,
      'time': '20:00',
      'occasion': 'Muzokaralar kechki ovqati',
      'is_arrived': false,
    },
  ];

  @override
  Future<StaffSession> authenticate({
    String? phone,
    String? staffCode,
    required String pin,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    Map<String, dynamic>? match;
    for (final staff in _staffAccounts) {
      final matchesPhone = phone != null &&
          phone.isNotEmpty &&
          staff['phone'].toString().contains(phone.replaceAll(RegExp(r'\D'), ''));
      final matchesCode = staffCode != null &&
          staffCode.isNotEmpty &&
          staff['staff_code'].toString().toLowerCase() ==
              staffCode.trim().toLowerCase();

      if ((matchesPhone || matchesCode) && staff['pin'] == pin) {
        match = staff;
        break;
      }
    }

    if (match == null) {
      // Default demo login fallback if user inputs valid 4-digit PIN
      if (pin == '1234') {
        match = _staffAccounts[0]; // Jasur Rahimov (both roles)
      } else {
        throw Exception('Telefon raqami/Kod yoki PIN-kod notoʻgʻri!');
      }
    }

    final assignedRoles = List<String>.from(match['assigned_roles']);
    final initialActiveRole = assignedRoles.first;

    return StaffSession(
      id: match['id'] as int,
      name: match['name'] as String,
      phone: match['phone'] as String,
      staffCode: match['staff_code'] as String,
      token: 'token_${match['staff_code']}_${DateTime.now().millisecondsSinceEpoch}',
      assignedRoles: assignedRoles,
      activeRole: initialActiveRole,
      vehicleInfo: match['vehicle_info'] as String? ?? '',
      biometricEnabled: true,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCourierOrders(String token) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List<Map<String, dynamic>>.from(_courierOrders);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAvailablePoolOrders() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List<Map<String, dynamic>>.from(_poolOrders);
  }

  @override
  Future<bool> claimCourierOrder(int orderId, String token) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final index = _poolOrders.indexWhere((o) => o['id'] == orderId);
    if (index != -1) {
      final order = _poolOrders.removeAt(index);
      order['stage'] = OrderStage.assigned.name;
      order['timestamps'] = {'assigned': 'Hozir'};
      order['checklist'] = [
        {'item': 'Barcha taomlar toʻliq', 'checked': false},
        {'item': 'Ichimliklar', 'checked': false},
        {'item': 'Muhrlangan termosumka', 'checked': false},
      ];
      _courierOrders.add(order);
      return true;
    }
    return false;
  }

  @override
  Future<bool> updateCourierOrderStatus({
    required int orderId,
    required OrderStage stage,
    required String token,
    Map<String, dynamic>? metadata,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final index = _courierOrders.indexWhere((o) => o['id'] == orderId);
    if (index != -1) {
      _courierOrders[index]['stage'] = stage.name;
      final timestamps = Map<String, dynamic>.from(
          _courierOrders[index]['timestamps'] as Map? ?? {});
      timestamps[stage.name] = '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
      _courierOrders[index]['timestamps'] = timestamps;
      if (metadata != null) {
        _courierOrders[index].addAll(metadata);
      }
      return true;
    }
    return false;
  }

  @override
  Future<bool> reportDeliveryProblem({
    required int orderId,
    required String reason,
    required String notes,
    String? photoUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final index = _courierOrders.indexWhere((o) => o['id'] == orderId);
    if (index != -1) {
      _courierOrders[index]['stage'] = OrderStage.deliveryFailed.name;
      _courierOrders[index]['problem_reason'] = reason;
      _courierOrders[index]['problem_notes'] = notes;
      _courierOrders[index]['problem_photo'] = photoUrl;
      return true;
    }
    return false;
  }

  @override
  Future<Map<String, dynamic>> submitCashHandover({
    required double expectedAmount,
    required double actualAmount,
    required String cashierPin,
    required String notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (cashierPin != '1234' && cashierPin != '0000') {
      throw Exception('Kassir PIN-kodi notoʻgʻri!');
    }
    final discrepancy = actualAmount - expectedAmount;
    return {
      'success': true,
      'handover_id': 'HANDOVER-${DateTime.now().millisecondsSinceEpoch}',
      'expected': expectedAmount,
      'actual': actualAmount,
      'discrepancy': discrepancy,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchFloorTables() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List<Map<String, dynamic>>.from(_tables);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMenuCategories() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return List<Map<String, dynamic>>.from(_menuCategories);
  }

  @override
  Future<Map<String, dynamic>> openTable({
    required String tableNumber,
    required int guestCount,
    required String waiterName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _tables.indexWhere((t) => t['table_number'] == tableNumber);
    if (index != -1) {
      _tables[index]['status'] = 'occupied';
      _tables[index]['guest_count'] = guestCount;
      _tables[index]['waiter_name'] = waiterName;
      _tables[index]['elapsed_minutes'] = 1;
      _tables[index]['total_amount'] = 0.0;
      _tables[index]['items'] = [];
      return _tables[index];
    }
    throw Exception('Stol topilmadi: $tableNumber');
  }

  @override
  Future<Map<String, dynamic>> sendOrderToKitchen({
    required String tableNumber,
    required String waiterName,
    required List<Map<String, dynamic>> items,
    String courseTiming = 'together',
    String notes = '',
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _tables.indexWhere((t) => t['table_number'] == tableNumber);
    if (index != -1) {
      _tables[index]['status'] = 'in_kitchen';
      _tables[index]['waiter_name'] = waiterName;
      _tables[index]['notes'] = notes;
      _tables[index]['course_timing'] = courseTiming;

      double total = 0.0;
      final existingItems = List<Map<String, dynamic>>.from(_tables[index]['items'] as List);
      for (final it in items) {
        existingItems.add(it);
      }
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
  Future<bool> transferTable({
    required String fromTable,
    required String toTable,
    required String waiterName,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final fromIndex = _tables.indexWhere((t) => t['table_number'] == fromTable);
    final toIndex = _tables.indexWhere((t) => t['table_number'] == toTable);

    if (fromIndex != -1 && toIndex != -1) {
      _tables[toIndex]['status'] = _tables[fromIndex]['status'];
      _tables[toIndex]['guest_count'] = _tables[fromIndex]['guest_count'];
      _tables[toIndex]['waiter_name'] = waiterName;
      _tables[toIndex]['elapsed_minutes'] = _tables[fromIndex]['elapsed_minutes'];
      _tables[toIndex]['total_amount'] = _tables[fromIndex]['total_amount'];
      _tables[toIndex]['items'] = _tables[fromIndex]['items'];

      // Reset fromTable
      _tables[fromIndex]['status'] = 'free';
      _tables[fromIndex]['guest_count'] = 0;
      _tables[fromIndex]['waiter_name'] = '';
      _tables[fromIndex]['elapsed_minutes'] = 0;
      _tables[fromIndex]['total_amount'] = 0.0;
      _tables[fromIndex]['items'] = [];
      return true;
    }
    return false;
  }

  @override
  Future<bool> mergeTables({
    required String primaryTable,
    required String secondaryTable,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final pIndex = _tables.indexWhere((t) => t['table_number'] == primaryTable);
    final sIndex = _tables.indexWhere((t) => t['table_number'] == secondaryTable);

    if (pIndex != -1 && sIndex != -1) {
      _tables[pIndex]['guest_count'] = (_tables[pIndex]['guest_count'] as int) +
          (_tables[sIndex]['guest_count'] as int);
      final pItems = List<Map<String, dynamic>>.from(_tables[pIndex]['items'] as List);
      final sItems = List<Map<String, dynamic>>.from(_tables[sIndex]['items'] as List);
      pItems.addAll(sItems);
      _tables[pIndex]['items'] = pItems;
      _tables[pIndex]['total_amount'] = (_tables[pIndex]['total_amount'] as double) +
          (_tables[sIndex]['total_amount'] as double);

      // Free secondary table
      _tables[sIndex]['status'] = 'free';
      _tables[sIndex]['guest_count'] = 0;
      _tables[sIndex]['items'] = [];
      _tables[sIndex]['total_amount'] = 0.0;
      return true;
    }
    return false;
  }

  @override
  Future<bool> cancelOrderItem({
    required int orderId,
    required int itemId,
    required String reason,
    required String managerPin,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    if (managerPin != '1234' && managerPin != '9999') {
      throw Exception('Menejer PIN-kodi notoʻgʻri!');
    }
    for (final table in _tables) {
      final items = List<Map<String, dynamic>>.from(table['items'] as List);
      final itemIndex = items.indexWhere((i) => i['id'] == itemId);
      if (itemIndex != -1) {
        items.removeAt(itemIndex);
        table['items'] = items;
        double newTotal = 0.0;
        for (final i in items) {
          newTotal += ((i['price'] as num) * (i['quantity'] as num));
        }
        table['total_amount'] = newTotal;
        return true;
      }
    }
    return true;
  }

  @override
  Future<Map<String, dynamic>> settleTableBill({
    required String tableNumber,
    required String paymentMethod,
    required double totalAmount,
    double discountPercent = 0.0,
    double tipAmount = 0.0,
    String? managerPinForDiscount,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (discountPercent > 0 && managerPinForDiscount != '1234') {
      throw Exception('Chegirma uchun menejer PIN-kodi notoʻgʻri!');
    }

    final index = _tables.indexWhere((t) => t['table_number'] == tableNumber);
    if (index != -1) {
      final discountAmount = totalAmount * (discountPercent / 100);
      final finalPayable = totalAmount - discountAmount + tipAmount;

      // Close table
      _tables[index]['status'] = 'free';
      _tables[index]['guest_count'] = 0;
      _tables[index]['waiter_name'] = '';
      _tables[index]['elapsed_minutes'] = 0;
      _tables[index]['total_amount'] = 0.0;
      _tables[index]['items'] = [];
      _tables[index]['active_call'] = false;

      return {
        'success': true,
        'table_number': tableNumber,
        'payment_method': paymentMethod,
        'subtotal': totalAmount,
        'discount': discountAmount,
        'tip': tipAmount,
        'final_amount': finalPayable,
        'receipt_qr': 'RECEIPT-DILKASH-${DateTime.now().millisecondsSinceEpoch}',
      };
    }
    throw Exception('Stol topilmadi');
  }

  @override
  Future<bool> dismissWaiterCall(int callId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    for (final t in _tables) {
      t['active_call'] = false;
    }
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTodayReservations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List<Map<String, dynamic>>.from(_reservations);
  }

  @override
  Future<bool> markReservationArrived(int reservationId, String assignedTable) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final rIndex = _reservations.indexWhere((r) => r['id'] == reservationId);
    if (rIndex != -1) {
      _reservations[rIndex]['is_arrived'] = true;
      final tIndex = _tables.indexWhere((t) => t['table_number'] == assignedTable);
      if (tIndex != -1) {
        _tables[tIndex]['status'] = 'occupied';
        _tables[tIndex]['guest_count'] = _reservations[rIndex]['guest_count'];
      }
      return true;
    }
    return false;
  }
}
