import 'courier_order.dart';

class StaffUser {
  final int id;
  final String name;
  final String phone;
  final String role; // 'courier' or 'waiter'
  final String token;
  final String vehicleInfo;

  StaffUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.token,
    this.vehicleInfo = '',
  });

  bool get isCourier => role == 'courier';
  bool get isWaiter => role == 'waiter';

  factory StaffUser.fromJson(Map<String, dynamic> json, String role) {
    return StaffUser(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      role: role,
      token: json['token'] ?? '',
      vehicleInfo: json['vehicle_info'] ?? '',
    );
  }

  CourierUser toCourierUser() {
    return CourierUser(
      id: id,
      name: name,
      phone: phone,
      token: token,
      vehicleInfo: vehicleInfo,
    );
  }
}
