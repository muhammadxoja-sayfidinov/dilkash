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
  });

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List? ?? [];
    List<OrderItemModel> parsedItems =
        rawItems.map((i) => OrderItemModel.fromJson(i)).toList();

    final orderId = json['id'] ?? json['order_id'] ?? 0;
    final orderNum = (json['order_number'] ?? orderId).toString();

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
      courierName: json['courier_name'],
      notes: json['notes'] ?? '',
      isPaid: json['is_paid'] ?? false,
      paymentMethod: json['payment_method'] ?? 'naqd',
      items: parsedItems,
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
