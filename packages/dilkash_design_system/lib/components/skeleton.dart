import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';

/// Shimmer Skeleton Box Loader
class DilkashSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool isCircle;

  const DilkashSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.isCircle = false,
  });

  @override
  State<DilkashSkeleton> createState() => _DilkashSkeletonState();
}

class _DilkashSkeletonState extends State<DilkashSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? DilkashColors.surfaceDarkElevated : const Color(0xFFE2E8F0);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: _animation.value),
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.isCircle
                ? null
                : (widget.borderRadius ?? DilkashRadii.radiusSm),
          ),
        );
      },
    );
  }
}

/// Skeleton for 2-column menu grid items
class DilkashDishGridSkeleton extends StatelessWidget {
  const DilkashDishGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: DilkashColors.surface(isDark),
        borderRadius: DilkashRadii.radiusLg,
        border: Border.all(
          color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 11,
            child: DilkashSkeleton(
              width: double.infinity,
              height: double.infinity,
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(DilkashRadii.lg - 1)),
            ),
          ),
          Expanded(
            flex: 9,
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DilkashSkeleton(width: 110, height: 14),
                      SizedBox(height: 6),
                      DilkashSkeleton(width: 80, height: 10),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      DilkashSkeleton(width: 70, height: 16),
                      DilkashSkeleton(width: 32, height: 32, isCircle: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
