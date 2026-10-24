// Packing Checklist Sheet for Picked Up Stage
// Mandatory verification of food items, drinks, sauces, and sealed thermal bag before leaving the restaurant.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';

class DeliveryChecklistSheet extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final VoidCallback onComplete;

  const DeliveryChecklistSheet({
    super.key,
    required this.items,
    required this.onComplete,
  });

  static Future<void> show({
    required BuildContext context,
    required List<Map<String, dynamic>> items,
    required VoidCallback onComplete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DeliveryChecklistSheet(
        items: items,
        onComplete: onComplete,
      ),
    );
  }

  @override
  State<DeliveryChecklistSheet> createState() => _DeliveryChecklistSheetState();
}

class _DeliveryChecklistSheetState extends State<DeliveryChecklistSheet> {
  final Map<String, bool> _checks = {
    'Taomlar va porsiyalar toʻliq': false,
    'Ichimliklar (muz yoki issiq qadoqda)': false,
    'Souslar, salatlar va non toʻplami': false,
    'Bir martalik anjomlar va salfetkalar': false,
    'Termosumka toza va muhrlangan': false,
  };

  bool get _allChecked => _checks.values.every((val) => val == true);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
            Row(
              children: [
                const Icon(Icons.checklist_rtl_rounded,
                    color: DilkashColors.primary500, size: 26),
                const SizedBox(width: 10),
                Text(
                  'Qadoqlash Nazorat Roʻyxati',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: DilkashColors.textPrimary(isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Restorandan chiqishdan oldin barcha narsalarni koʻzdan kechiring:',
              style: TextStyle(
                fontSize: 13,
                color: DilkashColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(height: 16),

            // Order dishes preview
            if (widget.items.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : const Color(0xFFF1F5F9),
                  borderRadius: DilkashRadii.radiusSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buyurtma tarkibi:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: DilkashColors.textSecondary(isDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...widget.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.fiber_manual_record,
                                size: 8, color: DilkashColors.primary500),
                            const SizedBox(width: 6),
                            Text(
                              '${item['dish_name']} × ${item['quantity']}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: DilkashColors.textPrimary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),

            // Checklist Tiles
            ..._checks.keys.map((key) {
              final isChecked = _checks[key] ?? false;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isChecked
                      ? DilkashColors.primary500.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: DilkashRadii.radiusSm,
                  border: Border.all(
                    color: isChecked
                        ? DilkashColors.primary500
                        : Colors.grey.withValues(alpha: 0.25),
                  ),
                ),
                child: CheckboxListTile(
                  title: Text(
                    key,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isChecked ? FontWeight.w700 : FontWeight.w500,
                      color: DilkashColors.textPrimary(isDark),
                    ),
                  ),
                  value: isChecked,
                  activeColor: DilkashColors.primary500,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    setState(() => _checks[key] = val ?? false);
                  },
                ),
              );
            }),
            const SizedBox(height: 16),

            // Confirmation Button (>= 56dp height)
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _allChecked
                    ? () {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(context);
                        widget.onComplete();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DilkashColors.primary500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: DilkashRadii.radiusSm),
                ),
                child: Text(
                  _allChecked
                      ? 'Hammasi joyida, yoʻlga chiqish'
                      : 'Barcha bandlarni belgilang (${_checks.values.where((v) => v).length}/5)',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
