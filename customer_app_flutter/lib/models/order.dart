class CustomerOrder {
  final int id;
  final String orderNumber;
  final String serviceType;
  final String serviceTypeDisplay;
  final String status;
  final String statusDisplay;
  final double totalAmount;
  final double deliveryCost;
  final String createdAt;
  final String deliveryAddress;
  final String? courierName;
  final String notes;
  final bool isPaid;
  final String paymentMethod;
  final List<OrderItemModel> items;

  // Live Tracking Telemetry
  final double? customerLat;
  final double? customerLng;
  final double? restaurantLat;
  final double? restaurantLng;
  final String? restaurantName;
  final String? restaurantPhone;
  final String? restaurantAddress;
  final CourierInfo? courier;
  final double? distanceKm;
  final int? etaMinutes;

  CustomerOrder({
    required this.id,
    required this.orderNumber,
    required this.serviceType,
    required this.serviceTypeDisplay,
    required this.status,
    required this.statusDisplay,
    required this.totalAmount,
    this.deliveryCost = 0.0,
    required this.createdAt,
    required this.deliveryAddress,
    this.courierName,
    this.notes = '',
    this.isPaid = false,
    this.paymentMethod = 'naqd',
    required this.items,
    this.customerLat,
    this.customerLng,
    this.restaurantLat,
    this.restaurantLng,
    this.restaurantName,
    this.restaurantPhone,
    this.restaurantAddress,
    this.courier,
    this.distanceKm,
    this.etaMinutes,
  });

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List? ?? [];
    List<OrderItemModel> parsedItems =
        rawItems.map((i) => OrderItemModel.fromJson(i)).toList();

    final orderId = json['id'] ?? json['order_id'] ?? 0;
    final orderNum = (json['order_number'] ?? orderId).toString();

    CourierInfo? parsedCourier;
    if (json['courier'] != null && json['courier'] is Map<String, dynamic>) {
      parsedCourier = CourierInfo.fromJson(json['courier']);
    }

    return CustomerOrder(
      id: orderId,
      orderNumber: orderNum,
      serviceType: json['service_type'] ?? 'delivery',
      serviceTypeDisplay: json['service_type_display'] ??
          (json['service_type'] == 'delivery'
              ? 'Yetkazib berish'
              : 'Olib ketish'),
      status: json['status'] ?? 'yangi',
      statusDisplay: json['status_display'] ?? 'Qabul qilindi',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      deliveryCost: (json['delivery_cost'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] ?? '',
      deliveryAddress: json['delivery_address'] ?? json['address'] ?? '',
      courierName: json['courier_name'] ?? parsedCourier?.name,
      notes: json['notes'] ?? '',
      isPaid: json['is_paid'] ?? false,
      paymentMethod: json['payment_method'] ?? 'naqd',
      items: parsedItems,
      customerLat: (json['customer_lat'] as num?)?.toDouble() ??
          (json['latitude'] as num?)?.toDouble(),
      customerLng: (json['customer_lng'] as num?)?.toDouble() ??
          (json['longitude'] as num?)?.toDouble(),
      restaurantLat: (json['restaurant_lat'] as num?)?.toDouble() ?? 41.311081,
      restaurantLng: (json['restaurant_lng'] as num?)?.toDouble() ?? 69.240562,
      restaurantName: json['restaurant_name'] ?? 'Dilkash Restorani',
      restaurantPhone: json['restaurant_phone'] ?? '+998 71 200 00 00',
      restaurantAddress: json['restaurant_address'] ?? 'Toshkent sh., Navoiy koʻchasi 14-uy',
      courier: parsedCourier,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ??
          parsedCourier?.distanceKm,
      etaMinutes: (json['eta_minutes'] as num?)?.toInt() ??
          parsedCourier?.etaMinutes,
    );
  }
}

class CourierInfo {
  final int id;
  final String name;
  final String phone;
  final String vehicle;
  final double? currentLat;
  final double? currentLng;
  final double? distanceKm;
  final int? etaMinutes;
  final bool isLive;

  CourierInfo({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicle,
    this.currentLat,
    this.currentLng,
    this.distanceKm,
    this.etaMinutes,
    this.isLive = false,
  });

  factory CourierInfo.fromJson(Map<String, dynamic> json) {
    return CourierInfo(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      vehicle: json['vehicle'] ?? 'Tezkor Skuter',
      currentLat: (json['current_lat'] as num?)?.toDouble() ??
          (json['latitude'] as num?)?.toDouble(),
      currentLng: (json['current_lng'] as num?)?.toDouble() ??
          (json['longitude'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      etaMinutes: (json['eta_minutes'] as num?)?.toInt(),
      isLive: json['is_live'] ?? (json['current_lat'] != null),
    );
  }
}

class OrderItemModel {
  final int id;
  final String dishName;
  final int quantity;
  final double price;

  OrderItemModel({
    this.id = 0,
    required this.dishName,
    required this.quantity,
    required this.price,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] ?? 0,
      dishName: json['dish_name'] ?? json['name'] ?? '',
      quantity: json['quantity'] ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
