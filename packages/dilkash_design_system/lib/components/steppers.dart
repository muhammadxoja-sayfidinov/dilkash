import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';

/// Tactile Quantity Stepper for Cart & Dish Details (+ / -)
class DilkashQuantityStepper extends StatelessWidget {
  final int value;
  final int minValue;
  final int maxValue;
  final ValueChanged<int> onChanged;
  final bool isCompact;

  const DilkashQuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.minValue = 0,
    this.maxValue = 99,
    this.isCompact = false,
  });

  void _decrement() {
    if (value > minValue) {
      HapticFeedback.lightImpact();
      onChanged(value - 1);
    }
  }

  void _increment() {
    if (value < maxValue) {
      HapticFeedback.lightImpact();
      onChanged(value + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double btnSize = isCompact ? 32.0 : 40.0;
    final double iconSize = isCompact ? 16.0 : 18.0;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? DilkashColors.surfaceDarkElevated
            : const Color(0xFFF1F5F9),
        borderRadius: DilkashRadii.radiusFull,
        border: Border.all(
          color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decrement button
          SizedBox(
            width: btnSize,
            height: btnSize,
            child: Material(
              color: value <= minValue
                  ? Colors.transparent
                  : (isDark ? DilkashColors.surfaceDark : Colors.white),
              borderRadius: DilkashRadii.radiusFull,
              child: InkWell(
                onTap: value <= minValue ? null : _decrement,
                borderRadius: DilkashRadii.radiusFull,
                child: Center(
                  child: Icon(
                    value <= 1 && minValue == 0
                        ? Icons.delete_outline_rounded
                        : Icons.remove_rounded,
                    size: iconSize,
                    color: value <= minValue
                        ? (isDark
                            ? DilkashColors.textMutedDark
                            : DilkashColors.textMutedLight)
                        : (isDark
                            ? DilkashColors.textPrimaryDark
                            : DilkashColors.textPrimaryLight),
                  ),
                ),
              ),
            ),
          ),

          // Count text
          Container(
            constraints: BoxConstraints(minWidth: isCompact ? 28 : 36),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: isCompact ? 14 : 16,
                fontWeight: FontWeight.w700,
                color: DilkashColors.textPrimary(isDark),
              ),
            ),
          ),

          // Increment button
          SizedBox(
            width: btnSize,
            height: btnSize,
            child: Material(
              color: value >= maxValue
                  ? Colors.transparent
                  : (isDark
                      ? DilkashColors.primary400
                      : DilkashColors.primary500),
              borderRadius: DilkashRadii.radiusFull,
              child: InkWell(
                onTap: value >= maxValue ? null : _increment,
                borderRadius: DilkashRadii.radiusFull,
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    size: iconSize,
                    color: value >= maxValue
                        ? (isDark
                            ? DilkashColors.textMutedDark
                            : DilkashColors.textMutedLight)
                        : (isDark ? Colors.black : Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Order Status Progress Timeline
class DilkashStatusStep {
  final String title;
  final String subtitle;
  final IconData icon;

  const DilkashStatusStep({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class DilkashStatusStepper extends StatelessWidget {
  final int currentStep;
  final List<DilkashStatusStep> steps;

  const DilkashStatusStepper({
    super.key,
    required this.currentStep,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isDone = index < currentStep;
        final isCurrent = index == currentStep;
        final isLast = index == steps.length - 1;

        final Color circleBg = isDone
            ? DilkashColors.primary500
            : isCurrent
                ? (isDark ? DilkashColors.primary400 : DilkashColors.primary500)
                : (isDark
                    ? DilkashColors.surfaceDarkElevated
                    : const Color(0xFFE2E8F0));

        final Color iconColor = isDone || isCurrent
            ? Colors.white
            : (isDark
                ? DilkashColors.textMutedDark
                : DilkashColors.textMutedLight);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicator line & icon
              Column(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: circleBg,
                      shape: BoxShape.circle,
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: (isDark
                                        ? DilkashColors.primary400
                                        : DilkashColors.primary500)
                                    .withValues(alpha: 0.35),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 20)
                          : Icon(step.icon, color: iconColor, size: 18),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2.5,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: isDone
                            ? DilkashColors.primary500
                            : (isDark
                                ? DilkashColors.borderDark
                                : const Color(0xFFCBD5E1)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Title and description
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isCurrent ? FontWeight.w700 : FontWeight.w600,
                          color: isCurrent
                              ? (isDark
                                  ? DilkashColors.primary400
                                  : DilkashColors.primary500)
                              : DilkashColors.textPrimary(isDark),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        step.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: DilkashColors.textSecondary(isDark),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
