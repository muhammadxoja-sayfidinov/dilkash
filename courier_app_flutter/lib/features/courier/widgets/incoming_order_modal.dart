// Incoming Order Alert Modal for Courier Role
// Features 30s animated circular countdown, loud sound vibration, accept action, and mandatory decline reason dialog.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';

class IncomingOrderModal extends StatefulWidget {
  final Map<String, dynamic> order;
  final VoidCallback onAccept;
  final Function(String reason) onDecline;

  const IncomingOrderModal({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onDecline,
  });

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> order,
    required VoidCallback onAccept,
    required Function(String reason) onDecline,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => IncomingOrderModal(
        order: order,
        onAccept: onAccept,
        onDecline: onDecline,
      ),
    );
  }

  @override
  State<IncomingOrderModal> createState() => _IncomingOrderModalState();
}

class _IncomingOrderModalState extends State<IncomingOrderModal> {
  int _secondsLeft = 30;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Simulate initial loud vibration
    HapticFeedback.vibrate();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
        if (_secondsLeft <= 5) {
          HapticFeedback.heavyImpact();
        }
      } else {
        timer.cancel();
        Navigator.pop(context);
        widget.onDecline('Vaqt tugadi (Avtomatik rad etildi)');
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _showDeclineReasonSheet() {
    final reasons = [
      'Transport vositasi nosoz',
      'Masofa juda uzoq',
      'Smena vaqti tugamoqda',
      'Ob-havo sharoiti ogʻir',
      'Boshqa texnik sabab',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Buyurtmani rad etish sababi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Iltimos, sababni tanlang. Bu maʻlumot dispetcherga yuboriladi.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              ...reasons.map(
                (r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.radio_button_unchecked_rounded,
                      color: DilkashColors.primary500),
                  title: Text(r, style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                    widget.onDecline(r);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _secondsLeft / 30.0;
    final order = widget.order;

    final customerName = order['customer_name'] ?? 'Mijoz';
    final address = order['delivery_address'] ?? 'Toshkent shahar';
    final fee = order['delivery_fee'] ?? 20000.0;
    final distance = order['distance_km'] ?? 3.5;
    final items = (order['items'] as List?) ?? [];

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF14241B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Circular Countdown
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 74,
                  height: 74,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    color: _secondsLeft > 10
                        ? DilkashColors.primary500
                        : Colors.red[600],
                  ),
                ),
                Text(
                  '$_secondsLeft',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: _secondsLeft > 10
                        ? DilkashColors.textPrimary(isDark)
                        : Colors.red[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'YANGI BUYURTMA!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: DilkashColors.primary500,
              ),
            ),
            const SizedBox(height: 12),

            // Delivery Specs
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : const Color(0xFFF8FAFC),
                borderRadius: DilkashRadii.radiusSm,
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Yetkazish haqi (Daromad):',
                        style: TextStyle(
                          fontSize: 13,
                          color: DilkashColors.textSecondary(isDark),
                        ),
                      ),
                      Text(
                        UzbekFormatters.formatCurrency(fee),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: DilkashColors.primary500,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 18, color: Colors.red),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: DilkashColors.textPrimary(isDark),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.route_rounded,
                          size: 18, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text(
                        'Masofa: $distance km',
                        style: TextStyle(
                          fontSize: 12,
                          color: DilkashColors.textSecondary(isDark),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Mijoz: $customerName',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: DilkashColors.textPrimary(isDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Dishes list snippet
            if (items.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tarkibi: ${items.map((i) => "${i['dish_name']} (${i['quantity']})").join(", ")}',
                  style: TextStyle(
                    fontSize: 12,
                    color: DilkashColors.textSecondary(isDark),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 20),

            // Accept and Decline Buttons (>= 56dp height for primary)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  Navigator.pop(context);
                  widget.onAccept();
                },
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text(
                  'QABUL QILISH',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DilkashColors.primary500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: DilkashRadii.radiusSm),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _showDeclineReasonSheet,
              child: Text(
                'Rad etish (Sabab koʻrsatish)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
