// Simple Problem Reporting Sheet for Courier
// Strictly follows KEEP: Customer not answering / wrong address notifies the manager.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';

class ProblemReportingSheet extends StatefulWidget {
  final int orderId;
  final Function(String reason) onSubmit;

  const ProblemReportingSheet({
    super.key,
    required this.orderId,
    required this.onSubmit,
  });

  static Future<void> show({
    required BuildContext context,
    required int orderId,
    required Function(String reason) onSubmit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ProblemReportingSheet(
        orderId: orderId,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<ProblemReportingSheet> createState() => _ProblemReportingSheetState();
}

class _ProblemReportingSheetState extends State<ProblemReportingSheet> {
  String _selectedReason = 'Mijoz javob bermayapti';

  final List<String> _reasons = [
    'Mijoz javob bermayapti',
    'Manzil noto’g’ri yoki topilmadi',
    'Buyurtmani bekor qilishni so’radi',
    'Boshqa muammo',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: DilkashSpacing.xl,
        right: DilkashSpacing.xl,
        top: DilkashSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + DilkashSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: DilkashColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: DilkashSpacing.lg),
          Text(
            'Yetkazishdagi muammo',
            style: DilkashTypography.h3.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Menejerga darhol bildirishnoma yuboriladi',
            style: DilkashTypography.caption.copyWith(
              color: DilkashColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: DilkashSpacing.lg),

          ..._reasons.map((reason) {
            final isSelected = _selectedReason == reason;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: isSelected ? DilkashColors.primary50 : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DilkashRadii.md),
                  side: BorderSide(
                    color: isSelected
                        ? DilkashColors.primary500
                        : DilkashColors.borderLight,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: ListTile(
                title: Text(
                  reason,
                  style: DilkashTypography.bodyMedium.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? DilkashColors.primary700
                        : DilkashColors.textPrimaryLight,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded,
                        color: DilkashColors.primary500)
                    : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedReason = reason);
                },
              ),
            ),
          );
        }),

          const SizedBox(height: DilkashSpacing.xl),

          // Primary action (>= 56dp height)
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                widget.onSubmit(_selectedReason);
                Navigator.pop(context);
                DilkashFeedback.showWarning(
                  context,
                  'Menejerga xabar yuborildi',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DilkashColors.error,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DilkashRadii.md),
                ),
              ),
              child: Text(
                'Menejerga xabar yuborish',
                style: DilkashTypography.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
