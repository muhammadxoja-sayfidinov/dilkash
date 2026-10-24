// Shift Bar Widget for Dilkash Staff App
// Sticky glanceable bar with active shift timer, break controls, and shift guard.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/shift/shift_notifier.dart';

class ShiftBarWidget extends ConsumerWidget {
  final VoidCallback? onClockOutRequested;

  const ShiftBarWidget({
    super.key,
    this.onClockOutRequested,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shift = ref.watch(shiftProvider);

    if (shift.isClockedOut) {
      // Prompt to clock in
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          border: Border(
            bottom: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFDC2626), size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Smena ochilmagan! Buyurtmalar qabul qilinmaydi.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF991B1B),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref.read(shiftProvider.notifier).clockIn();
                DilkashFeedback.showSuccess(context, 'Smena muvaffaqiyatli boshlandi!');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Smenani boshlash', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    final isBreak = shift.isOnBreak;
    final statusColor = isBreak ? const Color(0xFFD97706) : const Color(0xFF059669);
    final statusBg = isBreak
        ? (isDark ? const Color(0xFF261D0C) : const Color(0xFFFFFBEB))
        : (isDark ? const Color(0xFF0F231B) : const Color(0xFFECFDF5));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusBg,
        border: Border(
          bottom: BorderSide(color: statusColor.withValues(alpha: 0.25)),
        ),
      ),
      child: Row(
        children: [
          // Pulse Indicator
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isBreak ? 'Tanaffusda' : 'Faol smena',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
              Text(
                shift.formattedDuration,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: DilkashColors.textPrimary(isDark),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const Spacer(),

          // Break Toggle Action
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              if (isBreak) {
                ref.read(shiftProvider.notifier).endBreak();
                DilkashFeedback.showSuccess(context, 'Smena davom ettirilmoqda');
              } else {
                ref.read(shiftProvider.notifier).startBreak();
                DilkashFeedback.showInfo(context, 'Tanaffus rejimi yoqildi');
              }
            },
            icon: Icon(
              isBreak ? Icons.play_arrow_rounded : Icons.pause_rounded,
              size: 18,
              color: statusColor,
            ),
            label: Text(
              isBreak ? 'Davom etish' : 'Tanaffus',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: statusColor.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),

          // Clock Out Action
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined, size: 22),
            color: Colors.red[400],
            tooltip: 'Smenani yakunlash',
            onPressed: () {
              if (onClockOutRequested != null) {
                onClockOutRequested!();
              } else {
                _showClockOutConfirm(context, ref);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showClockOutConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Smenani yakunlash'),
        content: const Text(
          'Haqiqatan ham bugungi smenani yopmoqchimisiz? Barcha ochiq buyurtmalar va naqd pullar tekshiriladi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              HapticFeedback.heavyImpact();
              ref.read(shiftProvider.notifier).clockOut();
              DilkashFeedback.showSuccess(context, 'Smena muvaffaqiyatli yakunlandi!');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Yakunlash'),
          ),
        ],
      ),
    );
  }
}
