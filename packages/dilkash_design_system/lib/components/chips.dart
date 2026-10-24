import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';

/// Dilkash Category / Filter Chip
class DilkashFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;
  final IconData? icon;
  final int? count;

  const DilkashFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.icon,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isSelected
        ? (isDark ? DilkashColors.primary400 : DilkashColors.primary500)
        : (isDark
            ? DilkashColors.surfaceDarkElevated
            : const Color(0xFFF1F5F9));

    final Color fgColor = isSelected
        ? (isDark ? Colors.black : Colors.white)
        : (isDark
            ? DilkashColors.textPrimaryDark
            : DilkashColors.textSecondaryLight);

    final BorderSide border = BorderSide(
      color: isSelected
          ? Colors.transparent
          : (isDark ? DilkashColors.borderDark : DilkashColors.borderLight),
      width: 1.0,
    );

    return Material(
      color: bgColor,
      borderRadius: DilkashRadii.radiusFull,
      child: InkWell(
        onTap: onSelected,
        borderRadius: DilkashRadii.radiusFull,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: DilkashRadii.radiusFull,
            border: Border.fromBorderSide(border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fgColor),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: fgColor,
                  letterSpacing: -0.1,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? Colors.black.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.25))
                        : (isDark
                            ? DilkashColors.borderDark
                            : const Color(0xFFE2E8F0)),
                    borderRadius: DilkashRadii.radiusFull,
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: fgColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Order / Delivery Status Badge with calm semantic tints
class DilkashStatusBadge extends StatelessWidget {
  final String status;
  final String? label;

  const DilkashStatusBadge({
    super.key,
    required this.status,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    IconData icon;
    String text = label ?? status;

    switch (status.toLowerCase()) {
      case 'yangi':
      case 'new':
        bg = isDark ? const Color(0xFF1E3A8A) : DilkashColors.infoLight;
        fg = isDark ? const Color(0xFF93C5FD) : DilkashColors.info;
        icon = Icons.radio_button_checked_rounded;
        text = label ?? 'Yangi';
        break;

      case 'tasdiqlangan':
      case 'confirmed':
      case 'oshxonada':
      case 'tayyorlanmoqda':
        bg = isDark ? const Color(0xFF78350F) : DilkashColors.amber50;
        fg = isDark ? const Color(0xFFFCD34D) : DilkashColors.amber600;
        icon = Icons.outdoor_grill_rounded;
        text = label ?? 'Oshxonada';
        break;

      case 'tayor':
      case 'tayyor':
      case 'ready':
        bg = isDark ? const Color(0xFF064E3B) : DilkashColors.primary50;
        fg = isDark ? DilkashColors.primary300 : DilkashColors.primary600;
        icon = Icons.inventory_2_outlined;
        text = label ?? 'Tayyor';
        break;

      case 'yolda':
      case 'on_the_way':
      case 'delivering':
        bg = isDark ? const Color(0xFF1E3A8A) : DilkashColors.infoLight;
        fg = isDark ? const Color(0xFF60A5FA) : DilkashColors.info;
        icon = Icons.two_wheeler_rounded;
        text = label ?? 'Kuryer yoʻlda';
        break;

      case 'yetkazildi':
      case 'yakunlandi':
      case 'completed':
      case 'delivered':
        bg = isDark ? const Color(0xFF064E3B) : DilkashColors.successLight;
        fg = isDark ? const Color(0xFF6EE7B7) : DilkashColors.success;
        icon = Icons.check_circle_rounded;
        text = label ?? 'Yetkazildi';
        break;

      case 'bekor':
      case 'cancelled':
        bg = isDark ? const Color(0xFF881337) : DilkashColors.errorLight;
        fg = isDark ? const Color(0xFFFDA4AF) : DilkashColors.error;
        icon = Icons.cancel_rounded;
        text = label ?? 'Bekor qilindi';
        break;

      default:
        bg = isDark
            ? DilkashColors.surfaceDarkElevated
            : const Color(0xFFF1F5F9);
        fg = isDark
            ? DilkashColors.textSecondaryDark
            : DilkashColors.textSecondaryLight;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DilkashRadii.radiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}
