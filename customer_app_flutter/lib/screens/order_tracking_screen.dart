import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../models/order.dart';
import '../services/api_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  final int orderId;
  final String orderNumber;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  CustomerOrder? _order;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _timer;

  // Map coordinates (Restaurant & Customer)
  static const double restaurantLat = 41.311081;
  static const double restaurantLng = 69.240562;
  final double _customerLat = 41.2825;
  final double _customerLng = 69.2155;
  double _courierLat = 41.2980;
  double _courierLng = 69.2300;

  @override
  void initState() {
    super.initState();
    _loadOrderStatus();
    // Lifecycle-friendly update polling (har 8 soniyada yangilash)
    _timer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted) {
        _loadOrderStatus(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrderStatus({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final order = await ApiService.getOrderStatus(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _isLoading = false;
          _errorMessage = null;

          // If courier is on the way, interpolate position towards customer
          if (order.status == 'yolda') {
            _courierLat = (restaurantLat + _customerLat) / 2 + 0.004;
            _courierLng = (restaurantLng + _customerLng) / 2 + 0.003;
          }
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  int _getStatusStep(String status) {
    switch (status.toLowerCase()) {
      case 'yangi':
        return 0;
      case 'tasdiqlangan':
      case 'oshxonada':
        return 1;
      case 'tayor':
      case 'tayyor':
        return 2;
      case 'yolda':
        return 3;
      case 'yetkazildi':
      case 'yakunlandi':
        return 4;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      appBar: AppBar(
        title: Text('Buyurtma #${widget.orderNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yangilash',
            onPressed: () => _loadOrderStatus(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DilkashColors.primary500))
          : _errorMessage != null
              ? DilkashErrorState(
                  message: _errorMessage!,
                  onRetry: _loadMenu,
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Live Interactive Courier Map View
                      if (_order!.serviceType == 'delivery') ...[
                        Container(
                          height: 220,
                          decoration: BoxDecoration(
                            borderRadius: DilkashRadii.radiusLg,
                            border: Border.all(
                              color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: DilkashRadii.radiusLg,
                            child: Stack(
                              children: [
                                FlutterMap(
                                  options: MapOptions(
                                    initialCenter: LatLng(
                                      (restaurantLat + _customerLat) / 2,
                                      (restaurantLng + _customerLng) / 2,
                                    ),
                                    initialZoom: 13.0,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'uz.dilkash.customer',
                                    ),
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: [
                                            const LatLng(restaurantLat, restaurantLng),
                                            LatLng(_courierLat, _courierLng),
                                            LatLng(_customerLat, _customerLng),
                                          ],
                                          color: DilkashColors.primary500,
                                          strokeWidth: 4.0,
                                        ),
                                      ],
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        // Restaurant Marker
                                        Marker(
                                          point: const LatLng(restaurantLat, restaurantLng),
                                          width: 36,
                                          height: 36,
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
                                        // Courier Marker (Moving)
                                        if (_order!.status == 'yolda')
                                          Marker(
                                            point: LatLng(_courierLat, _courierLng),
                                            width: 44,
                                            height: 44,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: DilkashColors.info,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                              ),
                                              child: const Icon(
                                                Icons.two_wheeler_rounded,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        // Customer Delivery Marker
                                        Marker(
                                          point: LatLng(_customerLat, _customerLng),
                                          width: 38,
                                          height: 38,
                                          child: const Icon(
                                            Icons.location_on_rounded,
                                            color: Colors.redAccent,
                                            size: 38,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                // Top live status pill
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.8),
                                      borderRadius: DilkashRadii.radiusFull,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: DilkashColors.success,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _order!.status == 'yolda'
                                              ? 'Kuryer yoʻlda • ~12 daqiqa'
                                              : 'Jonli kuzatuv xaritasi',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 2. Main Order Status Card
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: DilkashColors.surface(isDark),
                          borderRadius: DilkashRadii.radiusLg,
                          border: Border.all(
                            color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _order!.serviceType == 'delivery'
                                          ? Icons.electric_moped_rounded
                                          : Icons.shopping_bag_outlined,
                                      size: 18,
                                      color: DilkashColors.primary(isDark),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _order!.serviceType == 'delivery'
                                          ? 'Yetkazib berish'
                                          : 'Olib ketish',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: DilkashColors.textPrimary(isDark),
                                      ),
                                    ),
                                  ],
                                ),
                                DilkashStatusBadge(status: _order!.status),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              UzbekFormatters.formatCurrency(_order!.totalAmount),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: isDark ? DilkashColors.primary400 : DilkashColors.primary600,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Buyurtma vaqti: ${_order!.createdAt}',
                              style: TextStyle(
                                fontSize: 12,
                                color: DilkashColors.textSecondary(isDark),
                              ),
                            ),
                            if (_order!.deliveryAddress.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 16,
                                    color: DilkashColors.textSecondary(isDark),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _order!.deliveryAddress,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: DilkashColors.textPrimary(isDark),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 3. Status Progress Timeline
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: DilkashColors.surface(isDark),
                          borderRadius: DilkashRadii.radiusLg,
                          border: Border.all(
                            color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buyurtma Jarayoni',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                color: DilkashColors.textPrimary(isDark),
                              ),
                            ),
                            const SizedBox(height: 16),
                            DilkashStatusStepper(
                              currentStep: _getStatusStep(_order!.status),
                              steps: [
                                const DilkashStatusStep(
                                  title: 'Qabul qilindi',
                                  subtitle: 'Buyurtmangiz tizimga tushdi va tasdiqlandi',
                                  icon: Icons.receipt_long_rounded,
                                ),
                                const DilkashStatusStep(
                                  title: 'Oshxonada tayyorlanmoqda',
                                  subtitle: 'Oshpazlar taomni pishirishni boshladi',
                                  icon: Icons.outdoor_grill_rounded,
                                ),
                                DilkashStatusStep(
                                  title: 'Tayyor boʻldi',
                                  subtitle: _order!.serviceType == 'delivery'
                                      ? 'Taomlar issiq qadoqlandi, kuryer kutilmoqda'
                                      : 'Restorandan olib ketishingiz mumkin',
                                  icon: Icons.inventory_2_outlined,
                                ),
                                if (_order!.serviceType == 'delivery')
                                  DilkashStatusStep(
                                    title: 'Kuryer yoʻlda',
                                    subtitle: _order!.courierName != null && _order!.courierName!.isNotEmpty
                                        ? 'Kuryer: ${_order!.courierName}'
                                        : 'Kuryer manzilingiz tomon yoʻl oldi',
                                    icon: Icons.two_wheeler_rounded,
                                  ),
                                const DilkashStatusStep(
                                  title: 'Yetkazildi / Yakunlandi',
                                  subtitle: 'Yoqimli ishtaha! Dilkashni tanlaganingiz uchun rahmat',
                                  icon: Icons.check_circle_outline_rounded,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. Order Items Summary
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: DilkashColors.surface(isDark),
                          borderRadius: DilkashRadii.radiusLg,
                          border: Border.all(
                            color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buyurtma tafsilotlari',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                color: DilkashColors.textPrimary(isDark),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._order!.items.map((item) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item.quantity}x ${item.dishName}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: DilkashColors.textPrimary(isDark),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      UzbekFormatters.formatCurrency(item.price * item.quantity),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: DilkashColors.textPrimary(isDark),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  void _loadMenu() {
    _loadOrderStatus();
  }
}
