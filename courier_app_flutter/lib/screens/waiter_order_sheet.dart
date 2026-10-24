import 'package:flutter/material.dart';
import '../models/waiter_models.dart';
import '../services/staff_api_service.dart';
import '../theme/staff_theme.dart';

class WaiterOrderSheet extends StatefulWidget {
  final int tableNumber;
  final String waiterName;
  final int? waiterId;
  final VoidCallback onOrderCreated;

  const WaiterOrderSheet({
    super.key,
    required this.tableNumber,
    required this.waiterName,
    this.waiterId,
    required this.onOrderCreated,
  });

  @override
  State<WaiterOrderSheet> createState() => _WaiterOrderSheetState();
}

class _WaiterOrderSheetState extends State<WaiterOrderSheet> {
  List<WaiterCategoryModel> _categories = [];
  bool _isLoading = true;
  String _selectedCategory = 'Barchasi';
  String _searchQuery = '';
  final Map<int, int> _selectedQuantities = {}; // productId -> count
  final Map<int, WaiterProductModel> _productMap = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    try {
      final categories = await StaffApiService.fetchMenu();
      final map = <int, WaiterProductModel>{};
      for (final cat in categories) {
        for (final p in cat.products) {
          map[p.id] = p;
        }
      }
      if (mounted) {
        setState(() {
          _categories = categories;
          _productMap.addAll(map);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Menyuni yuklashda xatolik: $e'),
            backgroundColor: StaffColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: StaffDesign.radiusMd),
          ),
        );
      }
    }
  }

  double get _totalPrice {
    double sum = 0.0;
    _selectedQuantities.forEach((id, qty) {
      final prod = _productMap[id];
      if (prod != null) {
        sum += prod.price * qty;
      }
    });
    return sum;
  }

  int get _totalItemsCount {
    int count = 0;
    _selectedQuantities.forEach((_, qty) => count += qty);
    return count;
  }

  Future<void> _submitOrder() async {
    if (_selectedQuantities.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final List<List<dynamic>> productsPayload = [];
      _selectedQuantities.forEach((id, qty) {
        final prod = _productMap[id];
        if (prod != null && qty > 0) {
          productsPayload.add([id, qty, prod.price]);
        }
      });

      await StaffApiService.createWaiterOrder(
        tableNumber: widget.tableNumber.toString(),
        waiterName: widget.waiterName,
        waiterId: widget.waiterId,
        products: productsPayload,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onOrderCreated();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.print_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Stol #${widget.tableNumber} buyurtmasi qabul qilindi va cheklar chop etildi!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: StaffColors.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: StaffDesign.radiusMd),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xatolik: $e'),
            backgroundColor: StaffColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: StaffDesign.radiusMd),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List<WaiterProductModel> allProducts = [];
    for (final c in _categories) {
      if (_selectedCategory == 'Barchasi' || c.name == _selectedCategory) {
        allProducts.addAll(c.products);
      }
    }

    if (_searchQuery.isNotEmpty) {
      allProducts = allProducts
          .where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: StaffColors.card(isDark),
        borderRadius: StaffDesign.radiusSheet,
        border: isDark
            ? Border(
                top: BorderSide(
                    color: StaffColors.border(isDark),
                    width: StaffDesign.borderStandard),
              )
            : null,
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 10),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: StaffColors.border(isDark),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: StaffColors.primary.withValues(alpha: isDark ? 0.20 : 0.12),
                            borderRadius: StaffDesign.radiusXs,
                          ),
                          child: Text(
                            'Stol #${widget.tableNumber}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: isDark ? StaffColors.primaryLight : StaffColors.primary,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Buyurtma olish',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: StaffColors.textPrimary(isDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ofitsiant: ${widget.waiterName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: StaffColors.textSecondary(isDark),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: StaffColors.textSecondary(isDark),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: StaffColors.cardSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: StaffColors.border(isDark)),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(color: StaffColors.textPrimary(isDark)),
              decoration: InputDecoration(
                hintText: 'Taom yoki ichimlik qidirish...',
                hintStyle: TextStyle(
                  color: StaffColors.textMuted(isDark),
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: StaffColors.textSecondary(isDark),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                filled: true,
                fillColor: StaffColors.input(isDark),
                border: OutlineInputBorder(
                  borderRadius: StaffDesign.radiusMd,
                  borderSide: BorderSide(
                    color: StaffColors.border(isDark),
                    width: StaffDesign.borderStandard,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: StaffDesign.radiusMd,
                  borderSide: BorderSide(
                    color: StaffColors.border(isDark),
                    width: StaffDesign.borderStandard,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: StaffDesign.radiusMd,
                  borderSide: const BorderSide(
                    color: StaffColors.accent,
                    width: StaffDesign.borderThick,
                  ),
                ),
              ),
            ),
          ),

          // Category Chips
          if (_categories.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildCategoryChip('Barchasi', isDark),
                  ..._categories.map((c) => _buildCategoryChip(c.name, isDark)),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Products List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: StaffColors.accent,
                    ),
                  )
                : allProducts.isEmpty
                    ? Center(
                        child: Text(
                          'Taomlar topilmadi',
                          style: TextStyle(
                            color: StaffColors.textMuted(isDark),
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: allProducts.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: StaffColors.border(isDark),
                        ),
                        itemBuilder: (ctx, idx) {
                          final prod = allProducts[idx];
                          final qty = _selectedQuantities[prod.id] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prod.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: StaffColors.textPrimary(isDark),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${prod.price.toStringAsFixed(0)} so\'m',
                                        style: TextStyle(
                                          color: isDark
                                              ? StaffColors.primaryLight
                                              : StaffColors.primary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Symmetrical Quantity Selector
                                Container(
                                  decoration: BoxDecoration(
                                    color: StaffColors.cardSecondary(isDark),
                                    borderRadius: StaffDesign.radiusSm,
                                    border: Border.all(
                                      color: StaffColors.border(isDark),
                                      width: StaffDesign.borderStandard,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_rounded,
                                            size: 18),
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                        color: StaffColors.textPrimary(isDark),
                                        onPressed: qty > 0
                                            ? () {
                                                setState(() {
                                                  if (qty == 1) {
                                                    _selectedQuantities
                                                        .remove(prod.id);
                                                  } else {
                                                    _selectedQuantities[
                                                        prod.id] = qty - 1;
                                                  }
                                                });
                                              }
                                            : null,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        child: Text(
                                          '$qty',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: qty > 0
                                                ? StaffColors.textPrimary(isDark)
                                                : StaffColors.textMuted(isDark),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_rounded,
                                            size: 18),
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                        color: StaffColors.accent,
                                        onPressed: () {
                                          setState(() {
                                            _selectedQuantities[prod.id] =
                                                qty + 1;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Bottom Checkout Bar
          if (_totalItemsCount > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: StaffColors.card(isDark),
                border: Border(
                  top: BorderSide(
                    color: StaffColors.border(isDark),
                    width: StaffDesign.borderStandard,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_totalItemsCount ta taom tanlandi',
                            style: TextStyle(
                              fontSize: 12,
                              color: StaffColors.textSecondary(isDark),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${_totalPrice.toStringAsFixed(0)} so\'m',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? StaffColors.primaryLight
                                  : StaffColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StaffColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: StaffDesign.radiusMd,
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Row(
                              children: [
                                Icon(Icons.send_rounded, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Oshxonaga Yuborish',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String title, bool isDark) {
    final isSelected = _selectedCategory == title;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = title),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? StaffColors.accent
                : StaffColors.cardSecondary(isDark),
            borderRadius: StaffDesign.radiusSm,
            border: Border.all(
              color: isSelected
                  ? StaffColors.accent
                  : StaffColors.border(isDark),
              width: StaffDesign.borderStandard,
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : StaffColors.textSecondary(isDark),
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
