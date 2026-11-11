// Authenticated Staff Session Model
// Contains server-verified assigned roles and active role.

class StaffSession {
  final int id;
  final int? waiterId;
  final int? courierId;
  final String name;
  final String phone;
  final String staffCode;
  final String token;
  final String? waiterToken;
  final String? courierToken;
  final List<String> assignedRoles; // e.g. ['courier', 'waiter']
  final String activeRole; // 'courier' or 'waiter'
  final String vehicleInfo;

  const StaffSession({
    required this.id,
    this.waiterId,
    this.courierId,
    required this.name,
    required this.phone,
    required this.staffCode,
    required this.token,
    this.waiterToken,
    this.courierToken,
    required this.assignedRoles,
    required this.activeRole,
    this.vehicleInfo = '',
  });

  int get effectiveWaiterId => waiterId ?? id;
  int get effectiveCourierId => courierId ?? id;
  String get effectiveWaiterToken => (waiterToken != null && waiterToken!.isNotEmpty) ? waiterToken! : token;
  String get effectiveCourierToken => (courierToken != null && courierToken!.isNotEmpty) ? courierToken! : token;
  String get activeToken => isWaiter ? effectiveWaiterToken : effectiveCourierToken;

  bool get hasMultipleRoles => assignedRoles.length > 1;
  bool get canActAsCourier => assignedRoles.contains('courier');
  bool get canActAsWaiter => assignedRoles.contains('waiter');
  bool get isCourier => activeRole == 'courier';
  bool get isWaiter => activeRole == 'waiter';

  StaffSession copyWith({
    int? id,
    int? waiterId,
    int? courierId,
    String? name,
    String? phone,
    String? staffCode,
    String? token,
    String? waiterToken,
    String? courierToken,
    List<String>? assignedRoles,
    String? activeRole,
    String? vehicleInfo,
  }) {
    return StaffSession(
      id: id ?? this.id,
      waiterId: waiterId ?? this.waiterId,
      courierId: courierId ?? this.courierId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      staffCode: staffCode ?? this.staffCode,
      token: token ?? this.token,
      waiterToken: waiterToken ?? this.waiterToken,
      courierToken: courierToken ?? this.courierToken,
      assignedRoles: assignedRoles ?? this.assignedRoles,
      activeRole: activeRole ?? this.activeRole,
      vehicleInfo: vehicleInfo ?? this.vehicleInfo,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'waiter_id': waiterId,
        'courier_id': courierId,
        'name': name,
        'phone': phone,
        'staff_code': staffCode,
        'token': token,
        'waiter_token': waiterToken,
        'courier_token': courierToken,
        'assigned_roles': assignedRoles,
        'active_role': activeRole,
        'vehicle_info': vehicleInfo,
      };

  factory StaffSession.fromJson(Map<String, dynamic> json) {
    return StaffSession(
      id: json['id'] as int? ?? 0,
      waiterId: json['waiter_id'] as int?,
      courierId: json['courier_id'] as int?,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      staffCode: json['staff_code'] as String? ?? '',
      token: json['token'] as String? ?? '',
      waiterToken: json['waiter_token'] as String?,
      courierToken: json['courier_token'] as String?,
      assignedRoles: (json['assigned_roles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['waiter'],
      activeRole: json['active_role'] as String? ?? 'waiter',
      vehicleInfo: json['vehicle_info'] as String? ?? '',
    );
  }
}
