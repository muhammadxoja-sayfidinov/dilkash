import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radii.dart';
import '../utils/formatters.dart';

/// Production-Grade Editorial Dish Card (2-Column Grid Item)
class DilkashDishCard extends StatelessWidget {
  final int id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final bool isAvailable;
  final bool isFavorite;
  final int cartQuantity;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;
  final ValueChanged<int>? onQuantityChanged;
  final VoidCallback? onToggleFavorite;

  const DilkashDishCard({
    super.key,
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.isAvailable = true,
    this.isFavorite = false,
    this.cartQuantity = 0,
    required this.onTap,
    required this.onAddToCart,
    this.onQuantityChanged,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: DilkashColors.surface(isDark),
      borderRadius: DilkashRadii.radiusLg,
      child: InkWell(
        onTap: isAvailable ? onTap : null,
        borderRadius: DilkashRadii.radiusLg,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: DilkashRadii.radiusLg,
            border: Border.all(
              color:
                  isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dish Image Container with badges
              Expanded(
                flex: 11,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(DilkashRadii.lg - 1)),
                      child: Container(
                        color: isDark
                            ? DilkashColors.surfaceDarkElevated
                            : const Color(0xFFF1F5F9),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildFallbackImage(isDark),
                              )
                            : _buildFallbackImage(isDark),
                      ),
                    ),

                    // Favorite Button
                    if (onToggleFavorite != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: (isDark ? Colors.black : Colors.white)
                              .withValues(alpha: 0.85),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onToggleFavorite,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 16,
                                color: isFavorite
                                    ? Colors.redAccent
                                    : (isDark
                                        ? Colors.white70
                                        : Colors.black54),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Out of stock overlay
                    if (!isAvailable)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(DilkashRadii.lg - 1)),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: DilkashRadii.radiusFull,
                          ),
                          child: const Text(
                            'Mavjud emas',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Dish Details
              Expanded(
                flex: 9,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            UzbekFormatters.fixUzbekApostrophes(name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: DilkashColors.textPrimary(isDark),
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              UzbekFormatters.fixUzbekApostrophes(description),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: DilkashColors.textSecondary(isDark),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Price and Quick Add Action Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              UzbekFormatters.formatCurrency(price),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? DilkashColors.primary400
                                    : DilkashColors.primary600,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),

                          // Cart Button
                          if (isAvailable) ...[
                            if (cartQuantity > 0 && onQuantityChanged != null)
                              Container(
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? DilkashColors.primary400
                                      : DilkashColors.primary500,
                                  borderRadius: DilkashRadii.radiusFull,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () =>
                                          onQuantityChanged!(cartQuantity - 1),
                                      child: const Padding(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 6),
                                        child: Icon(Icons.remove,
                                            size: 14, color: Colors.white),
                                      ),
                                    ),
                                    Text(
                                      '$cartQuantity',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () =>
                                          onQuantityChanged!(cartQuantity + 1),
                                      child: const Padding(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 6),
                                        child: Icon(Icons.add,
                                            size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              SizedBox(
                                width: 34,
                                height: 34,
                                child: Material(
                                  color: isDark
                                      ? DilkashColors.surfaceDarkElevated
                                      : DilkashColors.primary50,
                                  borderRadius: DilkashRadii.radiusFull,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: onAddToCart,
                                    child: Center(
                                      child: Icon(
                                        Icons.add_rounded,
                                        size: 20,
                                        color: isDark
                                            ? DilkashColors.primary400
                                            : DilkashColors.primary500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackImage(bool isDark) {
    return Center(
      child: Icon(
        Icons.restaurant_menu_rounded,
        size: 36,
        color: isDark ? DilkashColors.textMutedDark : const Color(0xFF94A3B8),
      ),
    );
  }
}

/// Horizontal Dish Card (for Trending / Chef's Specials Carousel)
class DilkashHorizontalDishCard extends StatelessWidget {
  final int id;
  final String name;
  final double price;
  final String imageUrl;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const DilkashHorizontalDishCard({
    super.key,
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: DilkashColors.surface(isDark),
        borderRadius: DilkashRadii.radiusLg,
        border: Border.all(
          color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
          width: 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: DilkashRadii.radiusLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(DilkashRadii.lg - 1)),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(
                            Icons.restaurant_menu_rounded,
                            size: 28,
                            color: isDark
                                ? DilkashColors.textMutedDark
                                : Colors.grey,
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.restaurant_menu_rounded,
                          size: 28,
                          color: isDark
                              ? DilkashColors.textMutedDark
                              : Colors.grey,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    UzbekFormatters.fixUzbekApostrophes(name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: DilkashColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        UzbekFormatters.formatCurrency(price),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? DilkashColors.primary400
                              : DilkashColors.primary600,
                        ),
                      ),
                      InkWell(
                        onTap: onAddToCart,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? DilkashColors.surfaceDarkElevated
                                : DilkashColors.primary50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add,
                            size: 16,
                            color: isDark
                                ? DilkashColors.primary400
                                : DilkashColors.primary500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
