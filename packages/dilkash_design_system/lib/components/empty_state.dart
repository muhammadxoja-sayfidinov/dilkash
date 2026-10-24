import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';
import 'buttons.dart';

/// Standardized Illustrated Empty State
class DilkashEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DilkashEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? DilkashColors.surfaceDarkElevated
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: isDark
                    ? DilkashColors.primary400
                    : DilkashColors.primary500,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: DilkashColors.textPrimary(isDark),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: DilkashColors.textSecondary(isDark),
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              DilkashButton(
                label: actionLabel!,
                onPressed: onAction,
                isFullWidth: false,
                size: DilkashButtonSize.md,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Connection or System Error State with Retry
class DilkashErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const DilkashErrorState({
    super.key,
    this.title = 'Aloqa uzildi',
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: DilkashColors.surface(isDark),
            borderRadius: DilkashRadii.radiusLg,
            border: Border.all(
              color:
                  isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DilkashColors.errorLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 36,
                  color: DilkashColors.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: DilkashColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: DilkashColors.textSecondary(isDark),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              DilkashButton(
                label: 'Qayta urinish',
                leadingIcon: Icons.refresh_rounded,
                onPressed: onRetry,
                size: DilkashButtonSize.md,
                isFullWidth: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
