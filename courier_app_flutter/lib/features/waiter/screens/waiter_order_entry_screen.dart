// Waiter Order Entry Screen
// Features categories + search, modifiers (size, extras, remove ingredients), allergen tags,
// per-guest seat assignment, course timing, ticket station routing, and send to kitchen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/auth/auth_notifier.dart';

class WaiterOrderEntryScreen extends ConsumerStatefulWidget {
  final String tableNumber;

  const WaiterOrderEntryScreen({super.key, required this.tableNumber});

  @override
  ConsumerState<WaiterOrderEntryScreen> createState() =>
      _WaiterOrderEntryScreenState();
}

class _WaiterOrderEntryScreenState
    extends ConsumerState<WaiterOrderEntryScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  String _selectedCategory = '';
  String _searchQuery = '';

  // Current active draft items for this order
  final List<Map<String, dynamic>> _draftItems = [];
  String _courseTiming = 'together'; // 'starters_first' or 'together'
  final _orderNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  @override
  void dispose() {
    _orderNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadMenu() async {
    final repo = ref.read(staffRepositoryProvider);
    try {
      final cats = await repo.fetchMenuCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
          _selectedCategory = cats.isNotEmpty ? cats.first['name'] : '';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _subtotal {
    double sum = 0.0;
    for (final it in _draftItems) {
      sum += ((it['price'] as num) * (it['quantity'] as num));
    }
    return sum;
  }

  void _openDishCustomizationModal(Map<String, dynamic> dish) {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sizes = List<String>.from(dish['sizes'] ?? ['Standart']);
    final extras = List<Map<String, dynamic>>.from(dish['extras'] ?? []);
    final removable =
        List<String>.from(dish['removable_ingredients'] ?? []);
    final allergens = List<String>.from(dish['allergens'] ?? []);

    String selectedSize = sizes.isNotEmpty ? sizes.first : 'Standart';
    final List<String> selectedExtras = [];
    final List<String> selectedRemovals = [];
    int selectedGuest = 1;
    int quantity = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          double calculatedPrice = (dish['price'] as num).toDouble();
          for (final exName in selectedExtras) {
            final match = extras.firstWhere((e) => e['name'] == exName,
                orElse: () => {'price': 0.0});
            calculatedPrice += (match['price'] as num).toDouble();
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Title & Station badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dish['name'],
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: DilkashColors.textPrimary(isDark),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dish['description'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: DilkashColors.textSecondary(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: DilkashColors.primary500
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            dish['station'] ?? 'Oshxona',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: DilkashColors.primary500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Allergens Warning
                    if (allergens.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Allergenlar: ${allergens.join(", ")}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Divider(height: 24),

                    // Guest Seat Assignment
                    Text(
                      'Qaysi mehmonga taalluqli:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DilkashColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(4, (i) {
                        final g = i + 1;
                        final isSelected = selectedGuest == g;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('Mehmon $g'),
                            selected: isSelected,
                            selectedColor: DilkashColors.primary500,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : null,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) =>
                                setSheetState(() => selectedGuest = g),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),

                    // Portion Size Selection
                    if (sizes.length > 1) ...[
                      Text(
                        'Porsiya hajmi:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: DilkashColors.textPrimary(isDark),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: sizes.map((s) {
                          final isSelected = selectedSize == s;
                          return ChoiceChip(
                            label: Text(s),
                            selected: isSelected,
                            selectedColor: DilkashColors.primary500,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : null,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (_) =>
                                setSheetState(() => selectedSize = s),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Extras
                    if (extras.isNotEmpty) ...[
                      Text(
                        'Qoʻshimchalar (Extras):',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: DilkashColors.textPrimary(isDark),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...extras.map((ex) {
                        final exName = ex['name'] as String;
                        final exPrice = (ex['price'] as num).toDouble();
                        final isChecked = selectedExtras.contains(exName);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(exName),
                          subtitle: Text(
                              '+ ${UzbekFormatters.formatCurrency(exPrice)}'),
                          value: isChecked,
                          activeColor: DilkashColors.primary500,
                          onChanged: (val) {
                            setSheetState(() {
                              if (val == true) {
                                selectedExtras.add(exName);
                              } else {
                                selectedExtras.remove(exName);
                              }
                            });
                          },
                        );
                      }),
                    ],

                    // Removable ingredients (piyozsiz, zirasiz)
                    if (removable.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Tarkibdan chiqarish (Oshpazga koʻrsatma):',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: DilkashColors.textPrimary(isDark),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: removable.map((rem) {
                          final isRemoved = selectedRemovals.contains(rem);
                          return FilterChip(
                            label: Text(rem),
                            selected: isRemoved,
                            selectedColor: Colors.red.withValues(alpha: 0.2),
                            checkmarkColor: Colors.red,
                            labelStyle: TextStyle(
                              color: isRemoved ? Colors.red[800] : null,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (val) {
                              setSheetState(() {
                                if (val) {
                                  selectedRemovals.add(rem);
                                } else {
                                  selectedRemovals.remove(rem);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    const Divider(height: 24),

                    // Quantity Stepper & Add to Order Button
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: quantity > 1
                              ? () => setSheetState(() => quantity--)
                              : null,
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '$quantity',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: () => setSheetState(() => quantity++),
                          icon: const Icon(Icons.add_rounded),
                        ),
                        const Spacer(),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                Navigator.pop(ctx);
                                setState(() {
                                  _draftItems.add({
                                    'id': DateTime.now().millisecondsSinceEpoch,
                                    'dish_name': dish['name'],
                                    'price': calculatedPrice,
                                    'quantity': quantity,
                                    'portion': selectedSize,
                                    'extras': List<String>.from(selectedExtras),
                                    'removals':
                                        List<String>.from(selectedRemovals),
                                    'station': dish['station'] ?? 'Oshxona',
                                    'guest_seat': selectedGuest,
                                    'status': 'new',
                                  });
                                });
                                DilkashFeedback.showSuccess(
                                  context,
                                  '${dish['name']} buyurtmaga qoʻshildi',
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DilkashColors.primary500,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: DilkashRadii.radiusSm,
                                ),
                              ),
                              child: Text(
                                'Qoʻshish • ${UzbekFormatters.formatCurrency(calculatedPrice * quantity)}',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _sendToKitchen() async {
    if (_draftItems.isEmpty) {
      DilkashFeedback.showWarning(context, 'Buyurtmaga taomlar qoʻshilmagan');
      return;
    }

    HapticFeedback.heavyImpact();
    final repo = ref.read(staffRepositoryProvider);
    final session = ref.read(authProvider).value;

    await repo.sendOrderToKitchen(
      tableNumber: widget.tableNumber,
      waiterName: session?.name ?? 'Ofitsiant',
      items: _draftItems,
      courseTiming: _courseTiming,
      notes: _orderNotesController.text.trim(),
    );

    if (mounted) {
      DilkashFeedback.showSuccess(
        context,
        'Buyurtma oshxona va barga muvaffaqiyatli uzatildi!',
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentCat = _categories.firstWhere(
      (c) => c['name'] == _selectedCategory,
      orElse: () => {'dishes': []},
    );
    final dishes = List<Map<String, dynamic>>.from(currentCat['dishes'] ?? []);
    final filteredDishes = dishes.where((d) {
      if (_searchQuery.isEmpty) return true;
      return d['name']
          .toString()
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      appBar: AppBar(
        title: Text('Stol ${widget.tableNumber} • Taom tanlash'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Taom yoki shashlik qidirish...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[900] : Colors.grey[200],
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),

            // Horizontal Categories Selector
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final name = cat['name'] as String;
                  final isSelected = _selectedCategory == name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(name),
                      selected: isSelected,
                      selectedColor: DilkashColors.primary500,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : null,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedCategory = name),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Dishes List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredDishes.length,
                      itemBuilder: (context, index) {
                        final dish = filteredDishes[index];
                        final price = (dish['price'] as num).toDouble();
                        final isAvailable = dish['is_available'] ?? true;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF16231D) : Colors.white,
                            borderRadius: DilkashRadii.radiusSm,
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF1E3529)
                                  : DilkashColors.neutral200,
                            ),
                          ),
                          child: ListTile(
                            onTap: isAvailable
                                ? () => _openDishCustomizationModal(dish)
                                : null,
                            leading: CircleAvatar(
                              backgroundColor: DilkashColors.primary500
                                  .withValues(alpha: 0.1),
                              child: const Icon(Icons.restaurant_rounded,
                                  color: DilkashColors.primary500),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    dish['name'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: isAvailable
                                          ? DilkashColors.textPrimary(isDark)
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                                if (!isAvailable)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Tugagan',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.red,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              '${UzbekFormatters.formatCurrency(price)} • ${dish['station'] ?? 'Oshxona'}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle_rounded,
                                  color: DilkashColors.primary500, size: 28),
                              onPressed: isAvailable
                                  ? () => _openDishCustomizationModal(dish)
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Draft Order Summary Bar & Kitchen Submit (>= 56dp height)
            if (_draftItems.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16231D) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Course Timing Selector
                    Row(
                      children: [
                        const Text('Tortish tartibi:',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        ChoiceChip(
                          label: const Text('Barchasi birga'),
                          selected: _courseTiming == 'together',
                          onSelected: (_) =>
                              setState(() => _courseTiming = 'together'),
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('Salat oldin'),
                          selected: _courseTiming == 'starters_first',
                          onSelected: (_) =>
                              setState(() => _courseTiming = 'starters_first'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Buyurtma (${_draftItems.length} ta taom):',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          UzbekFormatters.formatCurrency(_subtotal),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: DilkashColors.primary500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _sendToKitchen,
                        icon: const Icon(Icons.send_rounded),
                        label: const Text(
                          'Oshxona va Barga Yuborish',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DilkashColors.primary500,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: DilkashRadii.radiusSm,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
