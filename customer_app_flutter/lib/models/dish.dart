import '../services/api_service.dart';

class Category {
  final int id;
  final String name;

  Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}

class Dish {
  final int id;
  final String name;
  final String description;
  final double price;
  final String category;
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
    required this.category,
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
      category: json['category'] ?? '',
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
