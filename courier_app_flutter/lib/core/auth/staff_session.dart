// Authenticated Staff Session Model
// Contains server-verified assigned roles and active role.

class StaffSession {
  final int id;
  final String name;
  final String phone;
  final String staffCode;
  final String token;
  final List<String> assignedRoles; // e.g. ['courier', 'waiter']
  final String activeRole; // 'courier' or 'waiter'
  final String vehicleInfo;

  const StaffSession({
    required this.id,
    required this.name,
    required this.phone,
    required this.staffCode,
    required this.token,
    required this.assignedRoles,
    required this.activeRole,
    this.vehicleInfo = '',
  });

  bool get hasMultipleRoles => assignedRoles.length > 1;
  bool get canActAsCourier => assignedRoles.contains('courier');
  bool get canActAsWaiter => assignedRoles.contains('waiter');
  bool get isCourier => activeRole == 'courier';
  bool get isWaiter => activeRole == 'waiter';

  StaffSession copyWith({
    int? id,
    String? name,
    String? phone,
    String? staffCode,
    String? token,
    List<String>? assignedRoles,
    String? activeRole,
    String? vehicleInfo,
  }) {
    return StaffSession(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      staffCode: staffCode ?? this.staffCode,
      token: token ?? this.token,
      assignedRoles: assignedRoles ?? this.assignedRoles,
      activeRole: activeRole ?? this.activeRole,
      vehicleInfo: vehicleInfo ?? this.vehicleInfo,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'staff_code': staffCode,
        'token': token,
        'assigned_roles': assignedRoles,
        'active_role': activeRole,
        'vehicle_info': vehicleInfo,
      };

  factory StaffSession.fromJson(Map<String, dynamic> json) {
    return StaffSession(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      staffCode: json['staff_code'] as String? ?? '',
      token: json['token'] as String? ?? '',
      assignedRoles: (json['assigned_roles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['courier'],
      activeRole: json['active_role'] as String? ?? 'courier',
      vehicleInfo: json['vehicle_info'] as String? ?? '',
    );
  }
}
