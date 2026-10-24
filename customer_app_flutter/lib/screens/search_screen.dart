import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../models/dish.dart';
import '../services/cart_provider.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import 'dish_detail_sheet.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Dish> _allDishes = [];
  List<Dish> _filteredDishes = [];
  bool _isLoading = true;
  String _selectedCategory = 'Hammasi';
  List<String> _categories = ['Hammasi'];
  final String _sortBy = 'default'; // 'default', 'price_asc', 'price_desc'

  @override
  void initState() {
    super.initState();
    _loadMenu();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMenu() async {
    try {
      final res = await ApiService.fetchMenu();
      final List<Category> cats = res['categories'];
      final List<Dish> dishes = res['dishes'];

      if (mounted) {
        setState(() {
          _allDishes = dishes;
          _filteredDishes = dishes;
          _categories = ['Hammasi', ...cats.map((c) => c.name)];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    var list = _allDishes.where((dish) {
      final matchesQuery = dish.name.toLowerCase().contains(query) ||
          dish.description.toLowerCase().contains(query);
      final matchesCat = _selectedCategory == 'Hammasi' || dish.category == _selectedCategory;
      return matchesQuery && matchesCat;
    }).toList();

    if (_sortBy == 'price_asc') {
      list.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortBy == 'price_desc') {
      list.sort((a, b) => b.price.compareTo(a.price));
    }

    setState(() {
      _filteredDishes = list;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      appBar: AppBar(
        title: const Text('Qidiruv'),
      ),
      body: Column(
        children: [
          // Search Input Bar
          Container(
            color: DilkashColors.surface(isDark),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                DilkashTextField(
                  controller: _searchController,
                  hintText: 'Taom nomi yoki toifasini yozing...',
                  prefixIcon: Icons.search_rounded,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        )
                      : null,
                ),
                const SizedBox(height: 10),

                // Category chips filter
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, idx) {
                      final cat = _categories[idx];
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: DilkashFilterChip(
                          label: cat,
                          isSelected: isSelected,
                          onSelected: () {
                            setState(() => _selectedCategory = cat);
                            _applyFilters();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Results Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: DilkashColors.primary500))
                : _filteredDishes.isEmpty
                    ? DilkashEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Hech narsa topilmadi',
                        message: 'Qidiruv soʻrovini oʻzgartiring yoki filtrlarni tozalang',
                        actionLabel: 'Tozalash',
                        onAction: () {
                          _searchController.clear();
                          setState(() => _selectedCategory = 'Hammasi');
                          _applyFilters();
                        },
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.69,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _filteredDishes.length,
                        itemBuilder: (context, index) {
                          final dish = _filteredDishes[index];
                          final isInCart = cart.items.any((i) => i.dish.id == dish.id);
                          final cartItem =
                              isInCart ? cart.items.firstWhere((i) => i.dish.id == dish.id) : null;
                          final isFav = auth.isFavorite(dish.id);

                          return DilkashDishCard(
                            id: dish.id,
                            name: dish.name,
                            description: dish.description,
                            price: dish.price,
                            imageUrl: dish.imageUrl,
                            isAvailable: dish.isAvailable,
                            isFavorite: isFav,
                            cartQuantity: cartItem?.quantity ?? 0,
                            onTap: () => DishDetailSheet.show(context, dish),
                            onAddToCart: () {
                              cart.addItem(dish);
                              DilkashFeedback.showSuccess(
                                context,
                                '${dish.name} savatga qoʻshildi',
                              );
                            },
                            onQuantityChanged: (qty) => cart.updateQuantity(dish.id, qty),
                            onToggleFavorite: () => auth.toggleFavorite(dish.id),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
