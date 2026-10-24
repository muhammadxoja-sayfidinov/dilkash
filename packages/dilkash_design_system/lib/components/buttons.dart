import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';

enum DilkashButtonVariant { primary, secondary, outline, text, danger }

enum DilkashButtonSize { sm, md, lg }

/// Production-Grade Dilkash Button with all states (normal, pressed, disabled, loading)
class DilkashButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final DilkashButtonVariant variant;
  final DilkashButtonSize size;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  const DilkashButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DilkashButtonVariant.primary,
    this.size = DilkashButtonSize.lg,
    this.isLoading = false,
    this.isFullWidth = true,
    this.leadingIcon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDisabled = onPressed == null || isLoading;

    // Dimensions
    final double height = switch (size) {
      DilkashButtonSize.sm => 36.0,
      DilkashButtonSize.md => 44.0,
      DilkashButtonSize.lg => 52.0, // Wolt/Uber standard (>= 48dp touch target)
    };

    final double fontSize = switch (size) {
      DilkashButtonSize.sm => 13.0,
      DilkashButtonSize.md => 14.0,
      DilkashButtonSize.lg => 16.0,
    };

    final double iconSize = switch (size) {
      DilkashButtonSize.sm => 16.0,
      DilkashButtonSize.md => 18.0,
      DilkashButtonSize.lg => 20.0,
    };

    // Color definitions
    Color bgColor;
    Color fgColor;
    BorderSide border = BorderSide.none;

    switch (variant) {
      case DilkashButtonVariant.primary:
        bgColor = isDisabled
            ? (isDark ? const Color(0xFF1E3529) : const Color(0xFFCBD5E1))
            : (isDark ? DilkashColors.primary400 : DilkashColors.primary500);
        fgColor = isDisabled
            ? (isDark
                ? DilkashColors.textMutedDark
                : DilkashColors.textMutedLight)
            : (isDark ? Colors.black : Colors.white);
        break;

      case DilkashButtonVariant.secondary:
        bgColor = isDark
            ? DilkashColors.surfaceDarkElevated
            : DilkashColors.primary50;
        fgColor = isDark ? DilkashColors.primary300 : DilkashColors.primary700;
        break;

      case DilkashButtonVariant.outline:
        bgColor = Colors.transparent;
        fgColor = isDark
            ? DilkashColors.textPrimaryDark
            : DilkashColors.textPrimaryLight;
        border = BorderSide(
          color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
          width: 1.5,
        );
        break;

      case DilkashButtonVariant.text:
        bgColor = Colors.transparent;
        fgColor = isDark ? DilkashColors.primary400 : DilkashColors.primary500;
        break;

      case DilkashButtonVariant.danger:
        bgColor = DilkashColors.error;
        fgColor = Colors.white;
        break;
    }

    Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (leadingIcon != null) ...[
          Icon(leadingIcon, size: iconSize, color: fgColor),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: fgColor,
          ),
        ),
        if (!isLoading && trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(trailingIcon, size: iconSize, color: fgColor),
        ],
      ],
    );

    return SizedBox(
      height: height,
      width: isFullWidth ? double.infinity : null,
      child: Material(
        color: bgColor,
        borderRadius: DilkashRadii.radiusMd,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          customBorder: RoundedRectangleBorder(
            borderRadius: DilkashRadii.radiusMd,
            side: border,
          ),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: DilkashRadii.radiusMd,
              border: border != BorderSide.none
                  ? Border.fromBorderSide(border)
                  : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
