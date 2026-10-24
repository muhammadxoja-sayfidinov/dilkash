class RestaurantTableModel {
  final int number;
  final String name;
  final int capacity;
  final bool isOccupied;
  final int? assignedWaiterId;
  final String? assignedWaiterName;
  final WaiterOrderModel? order;
  final WaiterCallModel? call;

  RestaurantTableModel({
    required this.number,
    required this.name,
    required this.capacity,
    required this.isOccupied,
    this.assignedWaiterId,
    this.assignedWaiterName,
    this.order,
    this.call,
  });

  factory RestaurantTableModel.fromJson(Map<String, dynamic> json) {
    return RestaurantTableModel(
      number: json['number'] ?? 0,
      name: json['name'] ?? 'Stol',
      capacity: json['capacity'] ?? 4,
      isOccupied: json['is_occupied'] ?? false,
      assignedWaiterId: json['assigned_waiter_id'],
      assignedWaiterName: json['assigned_waiter_name'],
      order: json['order'] != null ? WaiterOrderModel.fromJson(json['order']) : null,
      call: json['call'] != null ? WaiterCallModel.fromJson(json['call']) : null,
    );
  }
}

class WaiterOrderModel {
  final int id;
  final String orderNumber;
  final String status;
  final String statusDisplay;
  final String createdAt;
  final double totalAmount;
  final List<WaiterOrderItemModel> items;

  WaiterOrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.statusDisplay,
    required this.createdAt,
    required this.totalAmount,
    required this.items,
  });

  factory WaiterOrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];
    return WaiterOrderModel(
      id: json['id'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? '',
      statusDisplay: json['status_display'] ?? '',
      createdAt: json['created_at'] ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      items: rawItems.map((i) => WaiterOrderItemModel.fromJson(i)).toList(),
    );
  }
}

class WaiterOrderItemModel {
  final String name;
  final int quantity;
  final double price;
  final double total;

  WaiterOrderItemModel({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
  });

  factory WaiterOrderItemModel.fromJson(Map<String, dynamic> json) {
    return WaiterOrderItemModel(
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class WaiterCallModel {
  final int id;
  final String reason;
  final String createdAt;

  WaiterCallModel({
    required this.id,
    required this.reason,
    required this.createdAt,
  });

  factory WaiterCallModel.fromJson(Map<String, dynamic> json) {
    return WaiterCallModel(
      id: json['id'] ?? 0,
      reason: json['reason'] ?? 'Ofitsiant chaqiruvi',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class WaiterCategoryModel {
  final int id;
  final String name;
  final List<WaiterProductModel> products;

  WaiterCategoryModel({
    required this.id,
    required this.name,
    required this.products,
  });

  factory WaiterCategoryModel.fromJson(Map<String, dynamic> json) {
    final rawProds = json['products'] as List? ?? [];
    return WaiterCategoryModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      products: rawProds.map((p) => WaiterProductModel.fromJson(p)).toList(),
    );
  }
}

class WaiterProductModel {
  final int id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String imageUrl;
  final bool isAvailable;

  WaiterProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrl,
    required this.isAvailable,
  });

  factory WaiterProductModel.fromJson(Map<String, dynamic> json) {
    return WaiterProductModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] ?? '',
      imageUrl: json['image_url'] ?? json['image'] ?? '',
      isAvailable: json['is_available'] ?? true,
    );
  }
}
