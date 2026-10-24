import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';

/// Standardized Modal Bottom Sheet for Dilkash Apps
class DilkashBottomSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final bool showHandle;
  final EdgeInsets padding;

  const DilkashBottomSheet({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.trailing,
    this.showHandle = true,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
  });

  /// Static helper to display bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool isScrollControlled = true,
    bool isDismissible = true,
    Color? backgroundColor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      backgroundColor: backgroundColor ?? Colors.transparent,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: DilkashColors.surface(isDark),
        borderRadius: DilkashRadii.sheet,
        border: Border(
          top: BorderSide(
            color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
            width: 1.0,
          ),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHandle)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 16),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A4235) : const Color(0xFFCBD5E1),
                      borderRadius: DilkashRadii.radiusFull,
                    ),
                  ),
                ),

              if (title != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title!,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: DilkashColors.textPrimary(isDark),
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: DilkashColors.textSecondary(isDark),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null)
                      trailing!
                    else
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        color: isDark ? DilkashColors.textSecondaryDark : DilkashColors.textSecondaryLight,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              child,
            ],
          ),
        ),
      ),
    );
  }
}
