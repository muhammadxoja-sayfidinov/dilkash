import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../models/dish.dart';
import '../services/cart_provider.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import 'dish_detail_sheet.dart';
import 'order_tracking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Category> _categories = [];
  List<Dish> _dishes = [];
  int _selectedCategoryId = 0; // 0 = Hammasi
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMenu() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.fetchMenu();
      if (mounted) {
        setState(() {
          _categories = res['categories'];
          _dishes = res['dishes'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _showTrackOrderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buyurtmani Kuzatish'),
        content: DilkashTextField(
          controller: controller,
          keyboardType: TextInputType.number,
          hintText: 'Masalan: 203',
          label: 'Buyurtma ID raqami',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Yopish'),
          ),
          DilkashButton(
            label: 'Kuzatish',
            isFullWidth: false,
            size: DilkashButtonSize.sm,
            onPressed: () {
              final id = int.tryParse(controller.text.trim());
              if (id != null) {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderTrackingScreen(
                      orderId: id,
                      orderNumber: id.toString(),
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final themeProv = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter dishes by category and search query
    final filteredDishes = _dishes.where((dish) {
      final matchesCategory = _selectedCategoryId == 0 ||
          dish.category ==
              _categories
                  .firstWhere((c) => c.id == _selectedCategoryId,
                      orElse: () => Category(id: 0, name: ''))
                  .name;

      final matchesSearch = _searchQuery.isEmpty ||
          dish.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          dish.description.toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesCategory && matchesSearch;
    }).toList();

    final popularDishes = _dishes.take(5).toList();

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? DilkashColors.surfaceDarkElevated : DilkashColors.primary50,
                borderRadius: DilkashRadii.radiusSm,
                border: Border.all(
                  color: isDark ? DilkashColors.borderDark : DilkashColors.primary200,
                ),
              ),
              child: Icon(
                Icons.restaurant_rounded,
                color: isDark ? DilkashColors.primary400 : DilkashColors.primary500,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auth.user != null ? 'Salom, ${auth.user!.fullName}!' : 'Dilkash Restorani',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.2,
                      color: DilkashColors.textPrimary(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: isDark ? DilkashColors.primary400 : DilkashColors.primary500,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          auth.user?.defaultAddress.isNotEmpty == true
                              ? auth.user!.defaultAddress
                              : 'Toshkent sh., Markaziy filial',
                          style: TextStyle(
                            fontSize: 11,
                            color: DilkashColors.textSecondary(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              themeProv.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: themeProv.isDarkMode ? DilkashColors.amber400 : const Color(0xFF334155),
            ),
            tooltip: 'Mavzuni almashtirish',
            onPressed: () => themeProv.toggleTheme(),
          ),
          IconButton(
            icon: Icon(
              Icons.manage_search_rounded,
              color: isDark ? DilkashColors.textPrimaryDark : const Color(0xFF334155),
            ),
            tooltip: 'Buyurtmani kuzatish',
            onPressed: _showTrackOrderDialog,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingSkeleton()
          : _errorMessage != null
              ? DilkashErrorState(
                  message: _errorMessage!,
                  onRetry: _loadMenu,
                )
              : RefreshIndicator(
                  onRefresh: _loadMenu,
                  color: DilkashColors.primary500,
                  child: CustomScrollView(
                    slivers: [
                      // Search Bar & Restaurant Trust Pill
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            children: [
                              // Search input
                              DilkashTextField(
                                controller: _searchController,
                                hintText: 'Taom yoki toifani qidiring...',
                                prefixIcon: Icons.search_rounded,
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                onChanged: (val) => setState(() => _searchQuery = val),
                              ),
                              const SizedBox(height: 12),

                              // Trust and Meta Bar
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildMetaChip(
                                      isDark,
                                      icon: Icons.star_rounded,
                                      iconColor: DilkashColors.amber500,
                                      text: '4.9 (500+ baho)',
                                    ),
                                    const SizedBox(width: 8),
                                    _buildMetaChip(
                                      isDark,
                                      icon: Icons.access_time_rounded,
                                      iconColor: DilkashColors.primary500,
                                      text: '25-35 daq yetkazish',
                                    ),
                                    const SizedBox(width: 8),
                                    _buildMetaChip(
                                      isDark,
                                      icon: Icons.verified_rounded,
                                      iconColor: DilkashColors.success,
                                      text: 'Halol sifat',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Promo Banner (Editorial, No generic AI gradients)
                      if (_searchQuery.isEmpty)
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDark ? DilkashColors.surfaceDarkElevated : const Color(0xFF0D6B4E),
                              borderRadius: DilkashRadii.radiusLg,
                              border: Border.all(
                                color: isDark ? DilkashColors.borderDark : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: DilkashColors.amber500,
                                          borderRadius: DilkashRadii.radiusXs,
                                        ),
                                        child: const Text(
                                          'AKSIYA • 5% KESHBEK',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Haftalik Maxsus Taklif:\nToʻy Oshi & Tandir Kabob',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          height: 1.25,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Buyurtma bering va ballar yigʻing',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.bolt_rounded,
                                    size: 36,
                                    color: DilkashColors.amber400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // "Mashhur taomlar" (Trending Specials Carousel)
                      if (_searchQuery.isEmpty && popularDishes.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Mashhur taomlar',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                    color: DilkashColors.textPrimary(isDark),
                                  ),
                                ),
                                Text(
                                  'Barchasi',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? DilkashColors.primary400 : DilkashColors.primary500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 185,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: popularDishes.length,
                              itemBuilder: (context, i) {
                                final dish = popularDishes[i];
                                return DilkashHorizontalDishCard(
                                  id: dish.id,
                                  name: dish.name,
                                  price: dish.price,
                                  imageUrl: dish.imageUrl,
                                  onTap: () => DishDetailSheet.show(context, dish),
                                  onAddToCart: () {
                                    cart.addItem(dish);
                                    DilkashFeedback.showSuccess(context, '${dish.name} savatga qoʻshildi');
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      ],

                      // Categories Horizontal Filter Bar
                      SliverToBoxAdapter(
                        child: Container(
                          height: 46,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              DilkashFilterChip(
                                label: 'Hammasi',
                                count: _dishes.length,
                                isSelected: _selectedCategoryId == 0,
                                onSelected: () => setState(() => _selectedCategoryId = 0),
                              ),
                              const SizedBox(width: 8),
                              ..._categories.map((cat) {
                                final count = _dishes.where((d) => d.category == cat.name).length;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: DilkashFilterChip(
                                    label: cat.name,
                                    count: count,
                                    isSelected: _selectedCategoryId == cat.id,
                                    onSelected: () => setState(() => _selectedCategoryId = cat.id),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),

                      // Section Title & Item Count
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedCategoryId == 0
                                    ? 'Barcha Taomlar'
                                    : _categories.firstWhere((c) => c.id == _selectedCategoryId).name,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: DilkashColors.textPrimary(isDark),
                                ),
                              ),
                              Text(
                                '${filteredDishes.length} ta taom',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: DilkashColors.textSecondary(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 2-Column Menu Grid
                      filteredDishes.isEmpty
                          ? SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: DilkashEmptyState(
                                  icon: Icons.search_off_rounded,
                                  title: 'Taom topilmadi',
                                  message: 'Qidiruv soʻrovini oʻzgartiring yoki boshqa toifani tanlang',
                                  actionLabel: 'Barcha taomlarni koʻrish',
                                  onAction: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _selectedCategoryId = 0;
                                    });
                                  },
                                ),
                              ),
                            )
                          : SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                              sliver: SliverGrid(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.69,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final dish = filteredDishes[index];
                                    final isInCart = cart.items.any((i) => i.dish.id == dish.id);
                                    final cartItem = isInCart
                                        ? cart.items.firstWhere((i) => i.dish.id == dish.id)
                                        : null;
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
                                      onQuantityChanged: (newQty) {
                                        cart.updateQuantity(dish.id, newQty);
                                      },
                                      onToggleFavorite: () => auth.toggleFavorite(dish.id),
                                    );
                                  },
                                  childCount: filteredDishes.length,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMetaChip(bool isDark, {required IconData icon, required Color iconColor, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? DilkashColors.surfaceDarkElevated : const Color(0xFFF1F5F9),
        borderRadius: DilkashRadii.radiusFull,
        border: Border.all(
          color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: DilkashColors.textPrimary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.69,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => const DilkashDishGridSkeleton(),
      ),
    );
  }
}
