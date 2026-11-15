import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with SingleTickerProviderStateMixin {
  CustomerOrder? _order;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _timer;
  final MapController _mapController = MapController();
  late final AnimationController _pulseController;

  // Live Map coordinates (Restaurant, Customer & Courier)
  double _restaurantLat = 41.311081;
  double _restaurantLng = 69.240562;
  double _customerLat = 41.2825;
  double _customerLng = 69.2155;
  double _courierLat = 41.2980;
  double _courierLng = 69.2300;
  bool _isSimulating = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _loadOrderStatus();

    // Jonli GPS kuzatuv: faol buyurtmalarda har 4 soniyada telemetriyani yangilash
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        if (_order != null &&
            (_order!.status == 'yetkazildi' ||
                _order!.status == 'olib_ketildi' ||
                _order!.status == 'bekor_qilindi')) {
          timer.cancel();
          return;
        }
        _loadOrderStatus(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    _mapController.dispose();
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

          if (order.customerLat != null) _customerLat = order.customerLat!;
          if (order.customerLng != null) _customerLng = order.customerLng!;
          if (order.restaurantLat != null) _restaurantLat = order.restaurantLat!;
          if (order.restaurantLng != null) _restaurantLng = order.restaurantLng!;

          if (order.courier?.currentLat != null &&
              order.courier?.currentLng != null) {
            _courierLat = order.courier!.currentLat!;
            _courierLng = order.courier!.currentLng!;
          } else if (order.status == 'yolda' || order.status == 'kuryerda') {
            _courierLat = (_restaurantLat + _customerLat) / 2 + 0.003;
            _courierLng = (_restaurantLng + _customerLng) / 2 + 0.002;
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

  void _centerOnCourier() {
    _mapController.move(LatLng(_courierLat, _courierLng), 14.5);
  }

  void _fitRouteBounds() {
    final centerLat = (_restaurantLat + _customerLat) / 2;
    final centerLng = (_restaurantLng + _customerLng) / 2;
    _mapController.move(LatLng(centerLat, centerLng), 13.0);
  }

  Future<void> _simulateCourierStep() async {
    if (_isSimulating) return;
    setState(() => _isSimulating = true);

    try {
      final res = await ApiService.simulateCourierStep(widget.orderId);
      if (res['courier_lat'] != null && res['courier_lng'] != null) {
        if (mounted) {
          setState(() {
            _courierLat = (res['courier_lat'] as num).toDouble();
            _courierLng = (res['courier_lng'] as num).toDouble();
          });
          _mapController.move(LatLng(_courierLat, _courierLng), 14.0);
          DilkashFeedback.showSuccess(
            context,
            'Kuryer koordinatasi yangilandi (Jonli simulyatsiya)',
          );
        }
      }
      await _loadOrderStatus(silent: true);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSimulating = false);
    }
  }

  void _showCourierContactModal(String name, String phone) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: DilkashColors.surface(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? DilkashColors.surfaceDarkElevated
                    : DilkashColors.primary50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.two_wheeler_rounded,
                size: 40,
                color: DilkashColors.primary500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: DilkashColors.textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              phone,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: DilkashColors.textSecondary(isDark),
              ),
            ),
            const SizedBox(height: 20),
            DilkashButton(
              label: 'Telefon raqamidan nusxa olish',
              leadingIcon: Icons.copy_rounded,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: phone));
                Navigator.pop(ctx);
                DilkashFeedback.showSuccess(
                  context,
                  'Kuryer raqami nusxalandi: $phone',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  int _getStatusStep(String status) {
    final s = status.toLowerCase();
    switch (s) {
      case 'yangi':
        return 0;
      case 'tasdiqlangan':
      case 'oshxonada':
      case 'tayyorlanmoqda':
        return 1;
      case 'tayor':
      case 'tayyor':
        return 2;
      case 'yolda':
      case 'kuryerda':
        return 3;
      case 'yetkazildi':
      case 'olib_ketildi':
      case 'yakunlandi':
        return _order?.serviceType == 'pickup' ? 3 : 4;
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
          ? const Center(
              child: CircularProgressIndicator(color: DilkashColors.primary500))
          : _errorMessage != null
              ? DilkashErrorState(
                  message: _errorMessage!,
                  onRetry: () => _loadOrderStatus(),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Live Interactive Courier Map View (Delivery holatida)
                      if (_order!.serviceType == 'delivery') ...[
                        _buildLiveTrackingMap(isDark),
                        const SizedBox(height: 14),

                        // Dedicated Live Courier Card
                        _buildCourierCard(isDark),
                        const SizedBox(height: 16),
                      ],

                      // 2. Main Order Status Card
                      Container(
                        padding: const EdgeInsets.all(18),
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
                                        color:
                                            DilkashColors.textPrimary(isDark),
                                      ),
                                    ),
                                  ],
                                ),
                                DilkashStatusBadge(status: _order!.status),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              UzbekFormatters.formatCurrency(
                                  _order!.totalAmount),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? DilkashColors.primary400
                                    : DilkashColors.primary600,
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
                                        color:
                                            DilkashColors.textPrimary(isDark),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. Status Progress Timeline
                      Container(
                        padding: const EdgeInsets.all(18),
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
                                  subtitle:
                                      'Buyurtmangiz tizimga tushdi va tasdiqlandi',
                                  icon: Icons.receipt_long_rounded,
                                ),
                                const DilkashStatusStep(
                                  title: 'Oshxonada tayyorlanmoqda',
                                  subtitle:
                                      'Oshpazlar taomni pishirishni boshladi',
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
                                    subtitle: _order!.courier != null
                                        ? '${_order!.courier!.name} (${_order!.courier!.vehicle})'
                                        : (_order!.courierName != null &&
                                                _order!.courierName!.isNotEmpty
                                            ? 'Kuryer: ${_order!.courierName}'
                                            : 'Kuryer manzilingiz tomon yoʻl oldi'),
                                    icon: Icons.two_wheeler_rounded,
                                  ),
                                const DilkashStatusStep(
                                  title: 'Yetkazildi / Yakunlandi',
                                  subtitle:
                                      'Yoqimli ishtaha! Dilkashni tanlaganingiz uchun rahmat',
                                  icon: Icons.check_circle_outline_rounded,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. Order Items Summary
                      Container(
                        padding: const EdgeInsets.all(18),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item.quantity}x ${item.dishName}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color:
                                              DilkashColors.textPrimary(isDark),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      UzbekFormatters.formatCurrency(
                                          item.price * item.quantity),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            DilkashColors.textPrimary(isDark),
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

  /// Live Interactive Courier Map View
  Widget _buildLiveTrackingMap(bool isDark) {
    final isEnRoute =
        _order!.status == 'yolda' || _order!.status == 'kuryerda';

    return Container(
      height: 260,
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
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(
                  (_restaurantLat + _customerLat) / 2,
                  (_restaurantLng + _customerLng) / 2,
                ),
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                  subdomains: const ['0', '1', '2', '3'],
                  fallbackUrl:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'uz.dilkash.customer',
                  maxZoom: 20,
                ),

                // Polyline: Restoran -> Kuryer -> Mijoz
                PolylineLayer(
                  polylines: [
                    // Restorandan kuryergacha bo'lgan yo'l
                    Polyline(
                      points: [
                        LatLng(_restaurantLat, _restaurantLng),
                        LatLng(_courierLat, _courierLng),
                      ],
                      color: DilkashColors.primary500.withValues(alpha: 0.5),
                      strokeWidth: 3.5,
                    ),
                    // Kuryerdan mijozgacha bo'lgan faol marshrut
                    Polyline(
                      points: [
                        LatLng(_courierLat, _courierLng),
                        LatLng(_customerLat, _customerLng),
                      ],
                      color: DilkashColors.primary500,
                      strokeWidth: 4.5,
                    ),
                  ],
                ),

                MarkerLayer(
                  markers: [
                    // Restoran belgisi
                    Marker(
                      point: LatLng(_restaurantLat, _restaurantLng),
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: DilkashColors.primary500,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.restaurant_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),

                    // Jonli Kuryer belgisi (Pulsatsiya animatsiyasi bilan)
                    if (isEnRoute)
                      Marker(
                        point: LatLng(_courierLat, _courierLng),
                        width: 58,
                        height: 58,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            final pulse = _pulseController.value;
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Radar to'lqini
                                Container(
                                  width: 36 + (22 * pulse),
                                  height: 36 + (22 * pulse),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: DilkashColors.primary500
                                        .withValues(alpha: 0.3 * (1 - pulse)),
                                  ),
                                ),
                                // Asosiy kuryer ikonasi
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: DilkashColors.primary600,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.delivery_dining_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                    // Mijoz yetkazish manzili belgisi
                    Marker(
                      point: LatLng(_customerLat, _customerLng),
                      width: 42,
                      height: 42,
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Colors.redAccent,
                        size: 42,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Yuqori Jonli Status Pilli (Live Indicator)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                      isEnRoute
                          ? 'Kuryer yoʻlda • ~${_order!.etaMinutes ?? 12} daqiqa'
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

            // O'ng tomondagi Xarita boshqaruv tugmalari (Fokus & Fit)
            Positioned(
              top: 12,
              right: 12,
              child: Column(
                children: [
                  Material(
                    color: Colors.black.withValues(alpha: 0.75),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _centerOnCourier,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.my_location_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.black.withValues(alpha: 0.75),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _fitRouteBounds,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.crop_free_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  if (isEnRoute) ...[
                    const SizedBox(height: 8),
                    Material(
                      color: DilkashColors.primary600,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _simulateCourierStep,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: _isSimulating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dedicated Live Courier Profile Card
  Widget _buildCourierCard(bool isDark) {
    final courier = _order!.courier;
    final courierName =
        courier?.name ?? _order!.courierName ?? 'Kuryer tayinlanmoqda';
    final courierPhone = courier?.phone ?? '+998 90 111 22 33';
    final courierVehicle =
        courier?.vehicle ?? 'Tezkor Skuter (Yashil) - 01 A 777 BC';
    final etaMins = _order!.etaMinutes ?? 12;
    final distKm = _order!.distanceKm ?? 2.4;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DilkashColors.surface(isDark),
        borderRadius: DilkashRadii.radiusLg,
        border: Border.all(
          color: isDark ? DilkashColors.borderDark : DilkashColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? DilkashColors.surfaceDarkElevated
                      : DilkashColors.primary50,
                  borderRadius: DilkashRadii.radiusMd,
                  border: Border.all(
                    color: isDark
                        ? DilkashColors.borderDark
                        : DilkashColors.primary200,
                  ),
                ),
                child: Center(
                  child: Text(
                    courierName.isNotEmpty
                        ? courierName
                            .split(' ')
                            .map((e) => e.isNotEmpty ? e[0] : '')
                            .take(2)
                            .join('')
                        : 'K',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: DilkashColors.primary500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Courier details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            courierName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: DilkashColors.textPrimary(isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                DilkashColors.success.withValues(alpha: 0.15),
                            borderRadius: DilkashRadii.radiusXs,
                          ),
                          child: const Text(
                            'Yoʻlda',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: DilkashColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      courierVehicle,
                      style: TextStyle(
                        fontSize: 12,
                        color: DilkashColors.textSecondary(isDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Call Button
              Material(
                color: DilkashColors.success,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () =>
                      _showCourierContactModal(courierName, courierPhone),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.phone_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Telemetry Row: ETA, Distance, Speed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTelemetryItem(
                isDark,
                icon: Icons.timer_outlined,
                iconColor: DilkashColors.primary500,
                label: 'Kutilmoqda',
                value: '~$etaMins daq',
              ),
              Container(
                height: 24,
                width: 1,
                color: isDark
                    ? DilkashColors.borderDark
                    : DilkashColors.borderLight,
              ),
              _buildTelemetryItem(
                isDark,
                icon: Icons.route_outlined,
                iconColor: DilkashColors.info,
                label: 'Qolgan masofa',
                value: '$distKm km',
              ),
              Container(
                height: 24,
                width: 1,
                color: isDark
                    ? DilkashColors.borderDark
                    : DilkashColors.borderLight,
              ),
              _buildTelemetryItem(
                isDark,
                icon: Icons.speed_rounded,
                iconColor: DilkashColors.amber500,
                label: 'Oʻrtacha tezlik',
                value: '26 km/soat',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryItem(
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: DilkashColors.textPrimary(isDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: DilkashColors.textSecondary(isDark),
          ),
        ),
      ],
    );
  }
}
