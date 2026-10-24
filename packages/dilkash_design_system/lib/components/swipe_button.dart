import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';

/// Tactile Swipe-to-Confirm Slider for Couriers & Critical Actions
class DilkashSwipeButton extends StatefulWidget {
  final String label;
  final String completedLabel;
  final Future<void> Function() onSwipeComplete;
  final Color? trackColor;
  final Color? thumbColor;
  final IconData thumbIcon;

  const DilkashSwipeButton({
    super.key,
    required this.label,
    this.completedLabel = 'Bajarildi!',
    required this.onSwipeComplete,
    this.trackColor,
    this.thumbColor,
    this.thumbIcon = Icons.arrow_forward_rounded,
  });

  @override
  State<DilkashSwipeButton> createState() => _DilkashSwipeButtonState();
}

class _DilkashSwipeButtonState extends State<DilkashSwipeButton> {
  double _dragPosition = 0.0;
  bool _isLoading = false;
  bool _isCompleted = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color track = widget.trackColor ??
        (isDark ? DilkashColors.surfaceDarkElevated : const Color(0xFFF1F5F9));
    final Color thumb = widget.thumbColor ??
        (isDark ? DilkashColors.primary400 : DilkashColors.primary500);

    const double height = 54.0;
    const double thumbWidth = 50.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag = constraints.maxWidth - thumbWidth - 8.0;

        return Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: track,
            borderRadius: DilkashRadii.radiusFull,
            border: Border.all(
              color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
              width: 1.0,
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Sliding track fill behind thumb
              Container(
                width: _dragPosition + thumbWidth + 8.0,
                height: height,
                decoration: BoxDecoration(
                  color: thumb.withValues(alpha: 0.15),
                  borderRadius: DilkashRadii.radiusFull,
                ),
              ),

              // Centered label text
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 56.0),
                  child: Text(
                    _isLoading
                        ? 'Tasdiqlanmoqda...'
                        : (_isCompleted ? widget.completedLabel : widget.label),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: _isCompleted
                          ? DilkashColors.success
                          : (isDark ? DilkashColors.textPrimaryDark : DilkashColors.textPrimaryLight),
                    ),
                  ),
                ),
              ),

              // Draggable Thumb Button
              Positioned(
                left: 4.0 + _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (_isLoading || _isCompleted)
                      ? null
                      : (details) {
                          setState(() {
                            _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
                          });
                        },
                  onHorizontalDragEnd: (_isLoading || _isCompleted)
                      ? null
                      : (details) async {
                          if (_dragPosition >= maxDrag * 0.8) {
                            // Completed threshold
                            setState(() {
                              _dragPosition = maxDrag;
                              _isLoading = true;
                            });
                            HapticFeedback.heavyImpact();
                            try {
                              await widget.onSwipeComplete();
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                  _isCompleted = true;
                                });
                              }
                            } catch (e) {
                              if (mounted) {
                                setState(() {
                                  _dragPosition = 0.0;
                                  _isLoading = false;
                                });
                              }
                            }
                          } else {
                            // Spring back
                            HapticFeedback.selectionClick();
                            setState(() {
                              _dragPosition = 0.0;
                            });
                          }
                        },
                  child: Container(
                    width: thumbWidth,
                    height: height - 8.0,
                    decoration: BoxDecoration(
                      color: thumb,
                      borderRadius: DilkashRadii.radiusFull,
                      boxShadow: [
                        BoxShadow(
                          color: thumb.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(
                              _isCompleted ? Icons.check_rounded : widget.thumbIcon,
                              color: isDark ? Colors.black : Colors.white,
                              size: 24,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
