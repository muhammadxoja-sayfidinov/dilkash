class CourierUser {
  final int id;
  final String name;
  final String phone;
  final String token;
  final String vehicleInfo;

  CourierUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.token,
    required this.vehicleInfo,
  });

  factory CourierUser.fromJson(Map<String, dynamic> json) {
    return CourierUser(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      token: json['token'] ?? '',
      vehicleInfo: json['vehicle_info'] ?? '',
    );
  }
}

class CourierOrder {
  final int id;
  final String orderNumber;
  final String status;
  final String statusDisplay;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final double? latitude;
  final double? longitude;
  final String notes;
  final double totalAmount;
  final String createdAt;
  final List<CourierOrderItem> items;

  CourierOrder({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.statusDisplay,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    this.latitude,
    this.longitude,
    required this.notes,
    required this.totalAmount,
    required this.createdAt,
    required this.items,
  });

  factory CourierOrder.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List? ?? [];
    List<CourierOrderItem> parsedItems =
        rawItems.map((i) => CourierOrderItem.fromJson(i)).toList();

    return CourierOrder(
      id: json['id'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? '',
      statusDisplay: json['status_display'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      deliveryAddress: json['delivery_address'] ?? json['address'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      notes: json['notes'] ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] ?? '',
      items: parsedItems,
    );
  }
}

class CourierOrderItem {
  final String dishName;
  final int quantity;
  final double price;

  CourierOrderItem({
    required this.dishName,
    required this.quantity,
    required this.price,
  });

  factory CourierOrderItem.fromJson(Map<String, dynamic> json) {
    return CourierOrderItem(
      dishName: json['dish_name'] ?? '',
      quantity: json['quantity'] ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
