import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';

/// Dilkash Premium Input Field
class DilkashTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? errorText;
  final String? helperText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool readOnly;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool autofocus;

  const DilkashTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: DilkashColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: obscureText,
          readOnly: readOnly,
          maxLines: maxLines,
          autofocus: autofocus,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          onTap: onTap,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: DilkashColors.textPrimary(isDark),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            helperText: helperText,
            errorText: errorText,
            filled: true,
            fillColor: DilkashColors.input(isDark),
            prefixIcon: prefixIcon != null
                ? Icon(
                    prefixIcon,
                    size: 20,
                    color: isDark ? DilkashColors.textSecondaryDark : DilkashColors.textSecondaryLight,
                  )
                : null,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: DilkashRadii.radiusSm,
              borderSide: BorderSide(
                color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
                width: 1.0,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: DilkashRadii.radiusSm,
              borderSide: BorderSide(
                color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
                width: 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: DilkashRadii.radiusSm,
              borderSide: BorderSide(
                color: DilkashColors.primary(isDark),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: DilkashRadii.radiusSm,
              borderSide: const BorderSide(
                color: DilkashColors.error,
                width: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
