import '../services/api_service.dart';

class Category {
  final int id;
  final String name;
  final String department;
  final String description;
  final int? parentId;
  final int subcategoriesCount;
  final int productsCount;

  Category({
    required this.id,
    required this.name,
    this.department = '',
    this.description = '',
    this.parentId,
    this.subcategoriesCount = 0,
    this.productsCount = 0,
  });

  bool get isSubcategory => parentId != null && parentId! > 0;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      department: json['department'] ?? '',
      description: json['description'] ?? '',
      parentId: json['parent_id'],
      subcategoriesCount: json['subcategories_count'] ?? 0,
      productsCount: json['products_count'] ?? 0,
    );
  }
}

class Dish {
  final int id;
  final String name;
  final String description;
  final double price;
  final int categoryId;
  final String category;
  final String department;
  final String imageUrl;
  final bool isAvailable;
  final int prepTime;
  final List<String> portions;
  final List<String> extras;

  Dish({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.categoryId = 0,
    required this.category,
    this.department = '',
    required this.imageUrl,
    required this.isAvailable,
    required this.prepTime,
    this.portions = const ['1 porsiya', '0.7 porsiya', '1.5 porsiya'],
    this.extras = const ['Qoʻshimcha sous', 'Sirka', 'Tandir non', 'Qazi'],
  });

  factory Dish.fromJson(Map<String, dynamic> json) {
    String img = json['image_url'] ?? json['image'] ?? '';
    if (img.isNotEmpty && !img.startsWith('http')) {
      img = '${ApiService.baseUrl}$img';
    }
    return Dish(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      categoryId: json['category_id'] ?? 0,
      category: json['category'] ?? '',
      department: json['department'] ?? '',
      imageUrl: img,
      isAvailable: json['is_available'] ?? true,
      prepTime: json['prep_time'] ?? 15,
    );
  }
}

class CartItem {
  final Dish dish;
  int quantity;
  String selectedPortion;
  List<String> selectedExtras;
  String notes;

  CartItem({
    required this.dish,
    this.quantity = 1,
    this.selectedPortion = '1 porsiya',
    this.selectedExtras = const [],
    this.notes = '',
  });

  double get unitPrice {
    double base = dish.price;
    if (selectedPortion == '0.7 porsiya') {
      base = base * 0.75;
    } else if (selectedPortion == '1.5 porsiya') {
      base = base * 1.45;
    }
    // Extras cost (e.g. Qazi or extra bread)
    base += selectedExtras.length * 5000;
    return base;
  }

  double get totalPrice => unitPrice * quantity;
}
