import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../models/courier_order.dart';
import '../services/courier_api_service.dart';

class CourierDeliveryScreen extends StatefulWidget {
  final CourierOrder order;
  final CourierUser courier;
  final VoidCallback onStatusChanged;

  const CourierDeliveryScreen({
    super.key,
    required this.order,
    required this.courier,
    required this.onStatusChanged,
  });

  @override
  State<CourierDeliveryScreen> createState() => _CourierDeliveryScreenState();
}

class _CourierDeliveryScreenState extends State<CourierDeliveryScreen> {
  late String _currentStatus;
  bool _isFullscreenMap = false;

  // Restaurant coordinates (Dilkash Restorani)
  static const double restaurantLat = 41.311081;
  static const double restaurantLng = 69.240562;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status;
  }

  // Haversine distance calculation in km
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a));
  }

  Future<void> _makePhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<void> _openYandexNavigator(double lat, double lon) async {
    final yandexNaviUri =
        Uri.parse('yandexnavi://build_route_on_map?lat_to=$lat&lon_to=$lon');
    final yandexMapsUri =
        Uri.parse('yandexmaps://build_route_on_map?lat_to=$lat&lon_to=$lon');
    final webUri = Uri.parse(
        'https://yandex.uz/maps/?rtext=$restaurantLat,$restaurantLng~$lat,$lon&rtt=auto');

    try {
      if (await canLaunchUrl(yandexNaviUri)) {
        await launchUrl(yandexNaviUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(yandexMapsUri)) {
        await launchUrl(yandexMapsUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openGoogleMaps(double lat, double lon) async {
    final googleMapsApp = Uri.parse('google.navigation:q=$lat,$lon&mode=d');
    final googleMapsWeb = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=$restaurantLat,$restaurantLng&destination=$lat,$lon&travelmode=driving');

    try {
      if (await canLaunchUrl(googleMapsApp)) {
        await launchUrl(googleMapsApp, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      await launchUrl(googleMapsWeb, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _updateStatus(String newStatus) async {
    final success = await CourierApiService.updateOrderStatus(
      orderId: widget.order.id,
      token: widget.courier.token,
      newStatus: newStatus,
    );

    if (success && mounted) {
      setState(() => _currentStatus = newStatus);
      widget.onStatusChanged();
      DilkashFeedback.showSuccess(
        context,
        newStatus == 'yolda'
            ? 'Oshxonadan olindi! Yoʻlga chiqdingiz'
            : 'Buyurtma yetkazildi!',
      );

      if (newStatus == 'yetkazildi') {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) Navigator.pop(context);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double destLat = widget.order.latitude ?? 41.2825;
    final double destLng = widget.order.longitude ?? 69.2155;
    final double distanceKm =
        _calculateDistance(restaurantLat, restaurantLng, destLat, destLng);
    final int estimatedMinutes = (distanceKm * 3.5).round().clamp(10, 50);

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      appBar: AppBar(
        title: Text('Yetkazish #${widget.order.orderNumber}'),
        actions: [
          IconButton(
            icon: Icon(_isFullscreenMap
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded),
            tooltip: 'Xaritani toʻliq ekranda koʻrish',
            onPressed: () =>
                setState(() => _isFullscreenMap = !_isFullscreenMap),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Interactive Map View
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: _isFullscreenMap
                ? MediaQuery.of(context).size.height * 0.75
                : 240,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(
                      (restaurantLat + destLat) / 2,
                      (restaurantLng + destLng) / 2,
                    ),
                    initialZoom: 13.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                      userAgentPackageName: 'uz.dilkash.courier',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [
                            const LatLng(restaurantLat, restaurantLng),
                            LatLng(destLat, destLng),
                          ],
                          color: DilkashColors.primary500,
                          strokeWidth: 4.5,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // Restaurant Marker
                        Marker(
                          point: const LatLng(restaurantLat, restaurantLng),
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: DilkashColors.primary500,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.restaurant_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        // Customer Marker
                        Marker(
                          point: LatLng(destLat, destLng),
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.redAccent,
                            size: 44,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Distance & ETA Floating Pill
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: DilkashRadii.radiusFull,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.navigation_rounded,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          '${distanceKm.toStringAsFixed(1)} km • ~$estimatedMinutes daqiqa',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Navigation Launchers & Order Details
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // One-tap navigation buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.map_rounded, size: 18),
                          label: const Text('Yandex Navigator'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: DilkashRadii.radiusSm),
                          ),
                          onPressed: () =>
                              _openYandexNavigator(destLat, destLng),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.navigation_rounded, size: 18),
                          label: const Text('Google Maps'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: DilkashRadii.radiusSm),
                          ),
                          onPressed: () => _openGoogleMaps(destLat, destLng),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Customer Contact Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DilkashColors.surface(isDark),
                      borderRadius: DilkashRadii.radiusLg,
                      border: Border.all(
                        color: isDark
                            ? DilkashColors.borderDark
                            : DilkashColors.borderLight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isDark
                                ? DilkashColors.surfaceDarkElevated
                                : DilkashColors.primary50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            size: 26,
                            color: DilkashColors.primary(isDark),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.order.customerName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: DilkashColors.textPrimary(isDark),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                UzbekFormatters.formatPhone(
                                    widget.order.customerPhone),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: DilkashColors.textSecondary(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Call button
                        IconButton.filled(
                          icon: const Icon(Icons.phone_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: DilkashColors.success,
                          ),
                          onPressed: () =>
                              _makePhoneCall(widget.order.customerPhone),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Delivery Address Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DilkashColors.surface(isDark),
                      borderRadius: DilkashRadii.radiusLg,
                      border: Border.all(
                        color: isDark
                            ? DilkashColors.borderDark
                            : DilkashColors.borderLight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.place_rounded,
                                size: 18, color: DilkashColors.primary(isDark)),
                            const SizedBox(width: 8),
                            Text(
                              'Yetkazish manzili',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: DilkashColors.textSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.order.deliveryAddress,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: DilkashColors.textPrimary(isDark),
                            height: 1.35,
                          ),
                        ),
                        if (widget.order.notes.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? DilkashColors.surfaceDarkElevated
                                  : const Color(0xFFF1F5F9),
                              borderRadius: DilkashRadii.radiusSm,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    size: 16, color: DilkashColors.amber600),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.order.notes,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            DilkashColors.textPrimary(isDark)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Order Items Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DilkashColors.surface(isDark),
                      borderRadius: DilkashRadii.radiusLg,
                      border: Border.all(
                        color: isDark
                            ? DilkashColors.borderDark
                            : DilkashColors.borderLight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buyurtma tarkibi (${widget.order.items.length} ta)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: DilkashColors.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...widget.order.items.map((it) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${it.quantity}x ${it.dishName}',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color:
                                            DilkashColors.textPrimary(isDark)),
                                  ),
                                  Text(
                                    UzbekFormatters.formatCurrency(
                                        it.price * it.quantity),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: DilkashColors.textPrimary(isDark),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Jami summa',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              UzbekFormatters.formatCurrency(
                                  widget.order.totalAmount),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? DilkashColors.primary400
                                    : DilkashColors.primary600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // 3. Bottom Sticky Action: Tactile Swipe-to-Confirm Slider!
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: DilkashColors.surface(isDark),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? DilkashColors.borderDark
                      : DilkashColors.borderLight,
                ),
              ),
            ),
            child: _buildSwipeActionButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeActionButton() {
    if (_currentStatus == 'yetkazildi' || _currentStatus == 'yakunlandi') {
      return Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: DilkashColors.successLight,
          borderRadius: DilkashRadii.radiusFull,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded,
                color: DilkashColors.success, size: 20),
            SizedBox(width: 8),
            Text(
              'Buyurtma Muvaffaqiyatli Yetkazildi',
              style: TextStyle(
                  color: DilkashColors.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_currentStatus == 'yolda') {
      return DilkashSwipeButton(
        label: 'Mijozga topshirdim >> Surish',
        completedLabel: 'Yetkazildi!',
        thumbIcon: Icons.check_circle_outline_rounded,
        thumbColor: DilkashColors.success,
        onSwipeComplete: () => _updateStatus('yetkazildi'),
      );
    }

    // Default: 'tayor' or 'yangi' -> Pick up from kitchen
    return DilkashSwipeButton(
      label: 'Oshxonadan oldim >> Surish',
      completedLabel: 'Yoʻlga chiqildi!',
      thumbIcon: Icons.two_wheeler_rounded,
      thumbColor: DilkashColors.primary500,
      onSwipeComplete: () => _updateStatus('yolda'),
    );
  }
}
