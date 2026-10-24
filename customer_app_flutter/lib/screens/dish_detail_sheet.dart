import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../models/dish.dart';
import '../services/cart_provider.dart';
import '../services/auth_provider.dart';

class DishDetailSheet extends StatefulWidget {
  final Dish dish;

  const DishDetailSheet({super.key, required this.dish});

  static void show(BuildContext context, Dish dish) {
    DilkashBottomSheet.show(
      context: context,
      builder: (_) => DishDetailSheet(dish: dish),
    );
  }

  @override
  State<DishDetailSheet> createState() => _DishDetailSheetState();
}

class _DishDetailSheetState extends State<DishDetailSheet> {
  int _quantity = 1;
  String _selectedPortion = '1 porsiya';
  final Set<String> _selectedExtras = {};
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double _calculateCurrentTotal() {
    double base = widget.dish.price;
    if (_selectedPortion == '0.7 porsiya') {
      base = base * 0.75;
    } else if (_selectedPortion == '1.5 porsiya') {
      base = base * 1.45;
    }
    base += _selectedExtras.length * 5000;
    return base * _quantity;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cart = Provider.of<CartProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context);
    final isFav = auth.isFavorite(widget.dish.id);

    final currentTotal = _calculateCurrentTotal();

    return Container(
      decoration: BoxDecoration(
        color: DilkashColors.surface(isDark),
        borderRadius: DilkashRadii.sheet,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A4235) : const Color(0xFFCBD5E1),
                borderRadius: DilkashRadii.radiusFull,
              ),
            ),
          ),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dish Image
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: DilkashRadii.radiusLg,
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          color: isDark ? DilkashColors.surfaceDarkElevated : const Color(0xFFF1F5F9),
                          child: widget.dish.imageUrl.isNotEmpty
                              ? Image.network(
                                  widget.dish.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildFallbackImage(isDark),
                                )
                              : _buildFallbackImage(isDark),
                        ),
                      ),
                      // Favorite button
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Material(
                          color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => auth.toggleFavorite(widget.dish.id),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 20,
                                color: isFav ? Colors.redAccent : (isDark ? Colors.white70 : Colors.black54),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title & Price Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              UzbekFormatters.fixUzbekApostrophes(widget.dish.name),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: DilkashColors.textPrimary(isDark),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 14,
                                  color: DilkashColors.textSecondary(isDark),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.dish.prepTime} daqiqada tayyorlanadi',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: DilkashColors.textSecondary(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        UzbekFormatters.formatCurrency(widget.dish.price),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? DilkashColors.primary400 : DilkashColors.primary600,
                        ),
                      ),
                    ],
                  ),

                  if (widget.dish.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      UzbekFormatters.fixUzbekApostrophes(widget.dish.description),
                      style: TextStyle(
                        fontSize: 14,
                        color: DilkashColors.textSecondary(isDark),
                        height: 1.45,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // 1. Portion Selection
                  Text(
                    'Porsiya hajmini tanlang',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: DilkashColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: widget.dish.portions.map((portion) {
                      final isSelected = _selectedPortion == portion;
                      return DilkashFilterChip(
                        label: portion,
                        isSelected: isSelected,
                        onSelected: () => setState(() => _selectedPortion = portion),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // 2. Extras & Condiments
                  Text(
                    'Qoʻshimchalar (+5 000 soʻm)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: DilkashColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.dish.extras.map((extra) {
                      final isSelected = _selectedExtras.contains(extra);
                      return FilterChip(
                        label: Text(extra),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedExtras.add(extra);
                            } else {
                              _selectedExtras.remove(extra);
                            }
                          });
                        },
                        selectedColor: isDark ? DilkashColors.primary400 : DilkashColors.primary50,
                        checkmarkColor: isDark ? Colors.black : DilkashColors.primary500,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? (isDark ? Colors.black : DilkashColors.primary700)
                              : DilkashColors.textPrimary(isDark),
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // 3. Special Notes
                  Text(
                    'Oshpaz uchun izoh',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: DilkashColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DilkashTextField(
                    controller: _notesController,
                    hintText: 'Masalan: piyoz kamroq boʻlsin, sirka alohida solinsin...',
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),

          // Bottom sticky bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: DilkashColors.surface(isDark),
              border: Border(
                top: BorderSide(
                  color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
                ),
              ),
            ),
            child: Row(
              children: [
                // Stepper
                DilkashQuantityStepper(
                  value: _quantity,
                  minValue: 1,
                  onChanged: (val) => setState(() => _quantity = val),
                ),
                const SizedBox(width: 14),

                // Add to Cart Button
                Expanded(
                  child: DilkashButton(
                    label: 'Savatga • ${UzbekFormatters.formatCurrency(currentTotal)}',
                    leadingIcon: Icons.shopping_bag_outlined,
                    onPressed: () {
                      cart.addItem(
                        widget.dish,
                        quantity: _quantity,
                        selectedPortion: _selectedPortion,
                        selectedExtras: _selectedExtras.toList(),
                        notes: _notesController.text.trim(),
                      );
                      Navigator.pop(context);
                      DilkashFeedback.showSuccess(
                        context,
                        '${widget.dish.name} savatga qoʻshildi',
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackImage(bool isDark) {
    return Center(
      child: Icon(
        Icons.restaurant_menu_rounded,
        size: 54,
        color: isDark ? DilkashColors.textMutedDark : const Color(0xFF94A3B8),
      ),
    );
  }
}
