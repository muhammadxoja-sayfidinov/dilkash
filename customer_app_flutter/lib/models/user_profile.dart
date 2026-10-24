class UserProfile {
  final int id;
  final String fullName;
  final String phone;
  final String token;
  final int ordersCount;
  final double cashbackPoints;
  final String defaultAddress;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.token,
    this.ordersCount = 0,
    this.cashbackPoints = 0.0,
    this.defaultAddress = '',
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? 0,
      fullName: json['full_name'] ?? 'Mijoz',
      phone: json['phone'] ?? '',
      token: json['token'] ?? '',
      ordersCount: json['orders_count'] ?? 0,
      cashbackPoints: (json['cashback_points'] as num?)?.toDouble() ?? 0.0,
      defaultAddress: json['default_address'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'token': token,
      'orders_count': ordersCount,
      'cashback_points': cashbackPoints,
      'default_address': defaultAddress,
    };
  }

  UserProfile copyWith({
    String? fullName,
    String? phone,
    String? defaultAddress,
    int? ordersCount,
    double? cashbackPoints,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      token: token,
      ordersCount: ordersCount ?? this.ordersCount,
      cashbackPoints: cashbackPoints ?? this.cashbackPoints,
      defaultAddress: defaultAddress ?? this.defaultAddress,
    );
  }
}
