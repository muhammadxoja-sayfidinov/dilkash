// Change Calculator Dialog for Courier Cash Orders
// Fast one-handed calculation of change to return to the customer.

import 'package:flutter/material.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';

class ChangeCalculatorDialog extends StatefulWidget {
  final double amountToCollect;

  const ChangeCalculatorDialog({
    super.key,
    required this.amountToCollect,
  });

  static Future<void> show(BuildContext context, double amount) {
    return showDialog(
      context: context,
      builder: (_) => ChangeCalculatorDialog(amountToCollect: amount),
    );
  }

  @override
  State<ChangeCalculatorDialog> createState() => _ChangeCalculatorDialogState();
}

class _ChangeCalculatorDialogState extends State<ChangeCalculatorDialog> {
  final _receivedController = TextEditingController();
  double _received = 0.0;

  @override
  void initState() {
    super.initState();
    _received = widget.amountToCollect;
    _receivedController.text = widget.amountToCollect.toInt().toString();
  }

  @override
  void dispose() {
    _receivedController.dispose();
    super.dispose();
  }

  double get _change => _received - widget.amountToCollect;

  void _setPreset(double val) {
    setState(() {
      _received = val;
      _receivedController.text = val.toInt().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF14241B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.calculate_rounded,
                    color: DilkashColors.primary500),
                const SizedBox(width: 8),
                Text(
                  'Qaytim Kalkulyatori',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: DilkashColors.textPrimary(isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Order Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Toʻlanishi kerak summa:',
                  style: TextStyle(
                    fontSize: 13,
                    color: DilkashColors.textSecondary(isDark),
                  ),
                ),
                Text(
                  UzbekFormatters.formatCurrency(widget.amountToCollect),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: DilkashColors.primary500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Received Amount Field
            TextField(
              controller: _receivedController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Mijoz bergan naqd pul (soʻm)',
                border: OutlineInputBorder(borderRadius: DilkashRadii.radiusSm),
                filled: true,
                fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
              ),
              onChanged: (val) {
                final num = double.tryParse(val.replaceAll(' ', '')) ?? 0.0;
                setState(() => _received = num);
              },
            ),
            const SizedBox(height: 10),

            // Quick Bill Presets
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Aniq summa'),
                  onPressed: () => _setPreset(widget.amountToCollect),
                ),
                ActionChip(
                  label: const Text('100 000'),
                  onPressed: () => _setPreset(100000),
                ),
                ActionChip(
                  label: const Text('150 000'),
                  onPressed: () => _setPreset(150000),
                ),
                ActionChip(
                  label: const Text('200 000'),
                  onPressed: () => _setPreset(200000),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Calculated Change Result
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _change >= 0
                    ? DilkashColors.primary500.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: DilkashRadii.radiusSm,
                border: Border.all(
                  color: _change >= 0 ? DilkashColors.primary500 : Colors.red,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _change >= 0 ? 'Mijozga qaytim:' : 'Yetishmayotgan summa:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: DilkashColors.textSecondary(isDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    UzbekFormatters.formatCurrency(_change.abs()),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _change >= 0
                          ? DilkashColors.primary500
                          : Colors.red[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: DilkashColors.primary500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape:
                    RoundedRectangleBorder(borderRadius: DilkashRadii.radiusSm),
              ),
              child: const Text('Tushunarli', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
