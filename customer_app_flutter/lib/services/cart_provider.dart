import 'package:flutter/foundation.dart';
import '../models/dish.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String? _promoCode;
  double _promoDiscount = 0.0;

  List<CartItem> get items => _items;
  String? get promoCode => _promoCode;
  double get promoDiscount => _promoDiscount;

  int get totalCount => _items.fold(0, (sum, i) => sum + i.quantity);

  double get subtotalPrice => _items.fold(0.0, (sum, i) => sum + i.totalPrice);

  double get totalPrice {
    final total = subtotalPrice - _promoDiscount;
    return total < 0 ? 0.0 : total;
  }

  void addItem(
    Dish dish, {
    int quantity = 1,
    String selectedPortion = '1 porsiya',
    List<String> selectedExtras = const [],
    String notes = '',
  }) {
    int index = _items.indexWhere(
      (i) => i.dish.id == dish.id && i.selectedPortion == selectedPortion,
    );

    if (index >= 0) {
      _items[index].quantity += quantity;
    } else {
      _items.add(
        CartItem(
          dish: dish,
          quantity: quantity,
          selectedPortion: selectedPortion,
          selectedExtras: selectedExtras,
          notes: notes,
        ),
      );
    }
    _recalculateDiscount();
    notifyListeners();
  }

  void updateQuantity(int dishId, int newQuantity) {
    int index = _items.indexWhere((i) => i.dish.id == dishId);
    if (index >= 0) {
      if (newQuantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantity = newQuantity;
      }
      _recalculateDiscount();
      notifyListeners();
    }
  }

  void removeOne(Dish dish) {
    int index = _items.indexWhere((i) => i.dish.id == dish.id);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity -= 1;
      } else {
        _items.removeAt(index);
      }
      _recalculateDiscount();
      notifyListeners();
    }
  }

  bool applyPromoCode(String code) {
    final clean = code.trim().toUpperCase();
    if (clean == 'DILKASH5') {
      _promoCode = clean;
      _promoDiscount = subtotalPrice * 0.05;
      notifyListeners();
      return true;
    } else if (clean == 'YANGI') {
      _promoCode = clean;
      _promoDiscount = 10000.0;
      notifyListeners();
      return true;
    } else if (clean == 'MAZA') {
      _promoCode = clean;
      _promoDiscount = subtotalPrice * 0.10;
      notifyListeners();
      return true;
    }
    return false;
  }

  void removePromoCode() {
    _promoCode = null;
    _promoDiscount = 0.0;
    notifyListeners();
  }

  void _recalculateDiscount() {
    if (_promoCode == 'DILKASH5') {
      _promoDiscount = subtotalPrice * 0.05;
    } else if (_promoCode == 'MAZA') {
      _promoDiscount = subtotalPrice * 0.10;
    } else if (_promoCode == 'YANGI') {
      _promoDiscount = 10000.0;
    } else {
      _promoDiscount = 0.0;
    }
  }

  void clearCart() {
    _items.clear();
    _promoCode = null;
    _promoDiscount = 0.0;
    notifyListeners();
  }
}
