// Screen 2: Waiter Order Screen
// Strictly follows KEEP:
// - Menu with category chips and search
// - + / - quantity stepper
// - Optional short note
// - "Oshxonaga yuborish" button (>= 56dp height)
// - Items show "tugagan" when out of stock
// - Add items to an already-open table anytime
// - Cancel an item before it is cooking

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/auth/auth_notifier.dart';

class WaiterOrderEntryScreen extends ConsumerStatefulWidget {
  final String tableNumber;

  const WaiterOrderEntryScreen({
    super.key,
    required this.tableNumber,
  });

  @override
  ConsumerState<WaiterOrderEntryScreen> createState() =>
      _WaiterOrderEntryScreenState();
}

class _WaiterOrderEntryScreenState
    extends ConsumerState<WaiterOrderEntryScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _categories = [];
  Map<String, dynamic>? _tableData;
  String _selectedCategory = 'Barchasi';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _noteController = TextEditingController();

  // Current new cart items: dishId -> quantity
  final Map<int, int> _newQuantities = {};
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMenuAndTable();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadMenuAndTable() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(staffRepositoryProvider);
      final menu = await repo.fetchMenu();
      final tables = await repo.fetchTables();
      final table = tables.firstWhere(
        (t) => t['table_number'] == widget.tableNumber,
        orElse: () => <String, dynamic>{},
      );

      if (mounted) {
        setState(() {
          _categories = menu;
          _tableData = table;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _increment(int dishId) {
    HapticFeedback.selectionClick();
    setState(() {
      _newQuantities[dishId] = (_newQuantities[dishId] ?? 0) + 1;
    });
  }

  void _decrement(int dishId) {
    HapticFeedback.selectionClick();
    setState(() {
      final current = _newQuantities[dishId] ?? 0;
      if (current > 1) {
        _newQuantities[dishId] = current - 1;
      } else {
        _newQuantities.remove(dishId);
      }
    });
  }

  List<Map<String, dynamic>> get _allDishes {
    final List<Map<String, dynamic>> list = [];
    for (final cat in _categories) {
      final dishes = List<Map<String, dynamic>>.from(cat['dishes'] as List? ?? []);
      list.addAll(dishes);
    }
    return list;
  }

  List<Map<String, dynamic>> get _filteredDishes {
    List<Map<String, dynamic>> list;
    if (_selectedCategory == 'Barchasi') {
      list = _allDishes;
    } else {
      final cat = _categories.firstWhere(
        (c) => c['name'] == _selectedCategory,
        orElse: () => {'dishes': []},
      );
      list = List<Map<String, dynamic>>.from(cat['dishes'] as List? ?? []);
    }

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((d) {
        final name = (d['name'] as String? ?? '').toLowerCase();
        final desc = (d['description'] as String? ?? '').toLowerCase();
        return name.contains(query) || desc.contains(query);
      }).toList();
    }

    return list;
  }

  int get _totalNewItemsCount {
    return _newQuantities.values.fold(0, (sum, q) => sum + q);
  }

  double get _totalNewAmount {
    double total = 0.0;
    for (final entry in _newQuantities.entries) {
      final dish = _allDishes.firstWhere(
        (d) => d['id'] == entry.key,
        orElse: () => {'price': 0.0},
      );
      total += ((dish['price'] as num?)?.toDouble() ?? 0.0) * entry.value;
    }
    return total;
  }

  Future<void> _sendToKitchen() async {
    if (_totalNewItemsCount == 0 || _isSending) return;

    setState(() => _isSending = true);
    HapticFeedback.mediumImpact();

    final List<Map<String, dynamic>> itemsToSend = [];
    for (final entry in _newQuantities.entries) {
      final dish = _allDishes.firstWhere((d) => d['id'] == entry.key);
      itemsToSend.add({
        'id': dish['id'],
        'name': dish['name'],
        'price': dish['price'],
        'quantity': entry.value,
      });
    }

    try {
      final repo = ref.read(staffRepositoryProvider);
      final updated = await repo.sendOrderToKitchen(
        tableNumber: widget.tableNumber,
        items: itemsToSend,
        notes: _noteController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _tableData = updated;
          _newQuantities.clear();
          _noteController.clear();
        });
        DilkashFeedback.showSuccess(context, 'Oshxonaga yuborildi!');
      }
    } catch (e) {
      if (mounted) {
        DilkashFeedback.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _cancelItem(int itemId) async {
    HapticFeedback.mediumImpact();
    try {
      final repo = ref.read(staffRepositoryProvider);
      final success = await repo.cancelOrderItem(
        tableNumber: widget.tableNumber,
        itemId: itemId,
      );
      if (success && mounted) {
        DilkashFeedback.showWarning(context, 'Taom bekor qilindi');
        _loadMenuAndTable();
      }
    } catch (e) {
      if (mounted) {
        DilkashFeedback.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: DilkashColors.bgLight,
        body: Center(
          child: CircularProgressIndicator(color: DilkashColors.primary500),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: DilkashColors.bgLight,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(DilkashSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: DilkashColors.error),
                const SizedBox(height: DilkashSpacing.md),
                Text(_error!, style: DilkashTypography.bodyLarge),
                const SizedBox(height: DilkashSpacing.lg),
                ElevatedButton(
                  onPressed: _loadMenuAndTable,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: DilkashColors.primary500),
                  child: const Text('Qayta urinish',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final existingItems = List<Map<String, dynamic>>.from(
      _tableData?['items'] as List? ?? [],
    );

    return Scaffold(
      backgroundColor: DilkashColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Stol ${widget.tableNumber}',
          style: DilkashTypography.h3.copyWith(
            fontWeight: FontWeight.w700,
            color: DilkashColors.textPrimaryLight,
          ),
        ),
        actions: [
          // One-tap action to view/settle Bill
          TextButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/waiter/bill/${widget.tableNumber}').then((_) {
                _loadMenuAndTable();
              });
            },
            icon: const Icon(Icons.receipt_long_rounded,
                size: 20, color: DilkashColors.primary500),
            label: const Text(
              'Hisob',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: DilkashColors.primary500,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: DilkashSpacing.lg,
                vertical: DilkashSpacing.sm,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Taomlarni qidirish...',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: DilkashColors.primary500),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: DilkashColors.bgLight,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: DilkashSpacing.md,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DilkashRadii.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Category Chips
            Container(
              color: Colors.white,
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: DilkashSpacing.lg,
                  vertical: 4,
                ),
                children: [
                  _buildCategoryChip('Barchasi'),
                  ..._categories.map((c) => _buildCategoryChip(c['name'])),
                ],
              ),
            ),
            const Divider(height: 1),

            // Main Menu List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(DilkashSpacing.lg),
                children: [
                  // Existing table items (if already-open table)
                  if (existingItems.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(DilkashSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(DilkashRadii.md),
                        border: Border.all(color: DilkashColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Buyurtma qilingan taomlar (${existingItems.length} ta)',
                                style: DilkashTypography.h3.copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                UzbekFormatters.formatCurrency(
                                  (_tableData?['total_amount'] as num?)
                                          ?.toDouble() ??
                                      0.0,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: DilkashColors.primary500,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          ...existingItems.map((it) {
                            final itemId = it['id'] as int?;
                            final dishName = (it['dish_name'] ?? '').toString();
                            final qty = (it['quantity'] as num?)?.toInt() ?? 1;
                            final price = (it['price'] as num?)?.toDouble() ?? 0.0;
                            final orderStatus = (_tableData?['order_status'] ?? 'yangi').toString();
                            final canCancel = itemId != null && itemId > 0 && orderStatus == 'yangi';

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${qty}x $dishName',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: DilkashTypography.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    UzbekFormatters.formatCurrency(price * qty),
                                    style: DilkashTypography.caption,
                                  ),
                                  if (canCancel) ...[
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () => _cancelItem(itemId),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: DilkashColors.error.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: DilkashColors.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: DilkashSpacing.md),
                  ],

                  // Dishes list
                  ..._filteredDishes.map((dish) {
                    final dishId = dish['id'] as int;
                    final name = dish['name'] as String? ?? '';
                    final price = (dish['price'] as num?)?.toDouble() ?? 0.0;
                    final desc = dish['description'] as String? ?? '';
                    final isAvailable = dish['is_available'] as bool? ?? true;
                    final currentQty = _newQuantities[dishId] ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: DilkashSpacing.sm),
                      padding: const EdgeInsets.all(DilkashSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(DilkashRadii.md),
                        border: Border.all(
                          color: currentQty > 0
                              ? DilkashColors.primary500
                              : DilkashColors.borderLight,
                          width: currentQty > 0 ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: DilkashTypography.bodyLarge.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: isAvailable
                                              ? DilkashColors.textPrimaryLight
                                              : DilkashColors.textMutedLight,
                                        ),
                                      ),
                                    ),
                                    if (!isAvailable)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEE2E2),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Tugagan',
                                          style: TextStyle(
                                            color: DilkashColors.error,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                if (desc.isNotEmpty)
                                  Text(
                                    desc,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DilkashTypography.caption.copyWith(
                                      color: DilkashColors.textSecondaryLight,
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  UzbekFormatters.formatCurrency(price),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isAvailable
                                        ? DilkashColors.primary700
                                        : DilkashColors.textMutedLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: DilkashSpacing.md),

                          // + / - Quantity stepper
                          if (!isAvailable)
                            const SizedBox(width: 80)
                          else if (currentQty == 0)
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () => _increment(dishId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DilkashColors.primary50,
                                  foregroundColor: DilkashColors.primary500,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(DilkashRadii.md),
                                  ),
                                ),
                                child: const Text(
                                  '+ Qo’shish',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  iconSize: 28,
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.remove_circle_outline_rounded),
                                  color: DilkashColors.primary500,
                                  onPressed: () => _decrement(dishId),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '$currentQty',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  iconSize: 28,
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.add_circle_rounded),
                                  color: DilkashColors.primary500,
                                  onPressed: () => _increment(dishId),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: DilkashSpacing.md),

                  // Optional short note
                  TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      hintText: 'Oshxona uchun qisqa izoh (masalan: piyozsiz)...',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(DilkashSpacing.md),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(DilkashRadii.md),
                        borderSide: const BorderSide(
                            color: DilkashColors.borderLight),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // PRIMARY ACTION AT BOTTOM (>= 56dp height)
            Container(
              padding: const EdgeInsets.all(DilkashSpacing.lg),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _totalNewItemsCount == 0 || _isSending
                      ? null
                      : _sendToKitchen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DilkashColors.primary500,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DilkashRadii.md),
                    ),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          _totalNewItemsCount > 0
                              ? 'Oshxonaga yuborish ($_totalNewItemsCount ta • ${UzbekFormatters.formatCurrency(_totalNewAmount)})'
                              : 'Oshxonaga yuborish',
                          style: DilkashTypography.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String name) {
    final isSelected = _selectedCategory == name;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(name),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : DilkashColors.textPrimaryLight,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 13,
        ),
        backgroundColor: DilkashColors.bgLight,
        selectedColor: DilkashColors.primary500,
        showCheckmark: false,
        onSelected: (val) {
          HapticFeedback.selectionClick();
          setState(() => _selectedCategory = name);
        },
      ),
    );
  }
}
