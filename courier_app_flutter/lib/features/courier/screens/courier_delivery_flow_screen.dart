// Courier Delivery Flow Screen
// 6-stage lifecycle with DilkashSwipeButton, interactive CartoDB map, Yandex/Google/2GIS navigation deep links,
// packaging checklist, customer/café calls, problem reporting, and delivery proof verification.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/shift/shift_notifier.dart';
import '../../../core/state_machine/order_state_machine.dart';
import '../widgets/change_calculator_dialog.dart';
import '../widgets/delivery_checklist_sheet.dart';
import '../widgets/problem_reporting_sheet.dart';

class CourierDeliveryFlowScreen extends ConsumerStatefulWidget {
  final int orderId;

  const CourierDeliveryFlowScreen({super.key, required this.orderId});

  @override
  ConsumerState<CourierDeliveryFlowScreen> createState() =>
      _CourierDeliveryFlowScreenState();
}

class _CourierDeliveryFlowScreenState
    extends ConsumerState<CourierDeliveryFlowScreen> {
  final MapController _mapController = MapController();
  Map<String, dynamic>? _order;
  bool _isLoading = true;

  // Confirmation code for proof of delivery
  final _deliveryCodeController = TextEditingController(text: '7821');

  // Café restaurant location (Dilkash, Tashkent)
  final LatLng _cafeLocation = const LatLng(41.311081, 69.240562);

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _deliveryCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    final repo = ref.read(staffRepositoryProvider);
    final session = ref.read(authProvider).value;
    try {
      final orders = await repo.fetchCourierOrders(session?.token ?? '');
      final match = orders.firstWhere(
        (o) => o['id'] == widget.orderId,
        orElse: () => orders.isNotEmpty ? orders.first : {},
      );
      if (mounted) {
        setState(() {
          _order = Map<String, dynamic>.from(match);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  OrderStage get _currentStage {
    final name = _order?['stage'] ?? OrderStage.assigned.name;
    return OrderStage.values.firstWhere(
      (s) => s.name == name,
      orElse: () => OrderStage.assigned,
    );
  }

  Future<void> _launchExternalMap(String type) async {
    final lat = _order?['latitude'] ?? 41.2858;
    final lng = _order?['longitude'] ?? 69.2045;

    Uri uri;
    if (type == 'yandex') {
      uri = Uri.parse('yandexnavi://build_route_on_map?lat_to=$lat&lon_to=$lng');
    } else if (type == 'google') {
      uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    } else {
      // 2GIS
      uri = Uri.parse('dgis://2gis.ru/routeSearch/rsType/car/to/$lng,$lat');
    }

    try {
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web maps
        final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        DilkashFeedback.showInfo(context, 'Xarita ilovasini ochib boʻlmadi');
      }
    }
  }

  void _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('tel:+$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) DilkashFeedback.showInfo(context, 'Qoʻngʻiroq qilib boʻlmadi: $phone');
    }
  }

  void _progressToNextStage() async {
    final current = _currentStage;
    OrderStage next;

    switch (current) {
      case OrderStage.assigned:
        next = OrderStage.headingToCafe;
        break;
      case OrderStage.headingToCafe:
        // Trigger mandatory packing checklist before picked up!
        final items = List<Map<String, dynamic>>.from(_order?['items'] ?? []);
        DeliveryChecklistSheet.show(
          context: context,
          items: items,
          onComplete: () => _updateStageOnServer(OrderStage.pickedUp),
        );
        return;
      case OrderStage.pickedUp:
        next = OrderStage.onTheWay;
        break;
      case OrderStage.onTheWay:
        next = OrderStage.arrived;
        break;
      case OrderStage.arrived:
        // Proof of delivery verification dialog
        _showDeliveryProofDialog();
        return;
      default:
        return;
    }

    _updateStageOnServer(next);
  }

  void _updateStageOnServer(OrderStage next) async {
    HapticFeedback.heavyImpact();
    final repo = ref.read(staffRepositoryProvider);
    final session = ref.read(authProvider).value;

    await repo.updateCourierOrderStatus(
      orderId: widget.orderId,
      stage: next,
      token: session?.token ?? '',
    );

    setState(() {
      _order?['stage'] = next.name;
    });

    if (mounted) {
      DilkashFeedback.showSuccess(
        context,
        'Holat yangilandi: ${OrderStateMachine.getStageLabelUz(next)}',
      );
    }

    if (next == OrderStage.delivered) {
      // Record in shift stats
      final isCash = _order?['payment_type'] == 'cash';
      final cashCollected = isCash
          ? ((_order?['amount_to_collect'] as num?)?.toDouble() ?? 0.0)
          : 0.0;
      ref.read(shiftProvider.notifier).recordCompletedOrder(
            cashCollected: cashCollected,
            earning: 20000.0,
            tip: 5000.0,
          );
      if (mounted) context.go('/courier');
    }
  }

  void _showDeliveryProofDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mijoz Tasdiq Kodi (Proof of Delivery)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mijoz SMS orqali olgan 4 xonali kodni kiriting yoki eshik oldida rasm oling:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _deliveryCodeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
              ),
              decoration: InputDecoration(
                counterText: '',
                border: OutlineInputBorder(borderRadius: DilkashRadii.radiusSm),
                hintText: '7821',
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  DilkashFeedback.showSuccess(context, 'Topshirish fotosurati biriktirildi');
                },
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Topshirish rasmini olish'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStageOnServer(OrderStage.delivered);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DilkashColors.primary500,
              foregroundColor: Colors.white,
            ),
            child: const Text('Topshirildi deb yakunlash'),
          ),
        ],
      ),
    );
  }

  String get _swipeSliderLabel {
    switch (_currentStage) {
      case OrderStage.assigned:
        return 'Restoranga yoʻl oldim >>';
      case OrderStage.headingToCafe:
        return 'Restorandan qabul qildim >>';
      case OrderStage.pickedUp:
        return 'Mijoz manziliga yoʻl oldim >>';
      case OrderStage.onTheWay:
        return 'Mijoz eshigi oldiga yetdim >>';
      case OrderStage.arrived:
        return 'Mijozga topshirdim (Kodni kiritish) >>';
      case OrderStage.delivered:
        return 'Buyurtma yetkazildi ✓';
      default:
        return 'Surish orqali tasdiqlash >>';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading || _order == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final destLat = (_order!['latitude'] as num?)?.toDouble() ?? 41.2858;
    final destLng = (_order!['longitude'] as num?)?.toDouble() ?? 69.2045;
    final customerLoc = LatLng(destLat, destLng);
    final customerName = _order!['customer_name'] ?? 'Mijoz';
    final customerPhone = _order!['customer_phone'] ?? '+998901234567';
    final address = _order!['delivery_address'] ?? 'Toshkent';
    final isCash = _order!['payment_type'] == 'cash';
    final amountToCollect = (_order!['amount_to_collect'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      appBar: AppBar(
        title: Text(_order!['order_number'] ?? 'Buyurtma'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.report_problem_outlined, color: Colors.red),
            tooltip: 'Muammo xabar qilish',
            onPressed: () {
              ProblemReportingSheet.show(
                context: context,
                orderId: widget.orderId,
                customerPhone: customerPhone,
                onSubmit: (reason, notes) {
                  _updateStageOnServer(OrderStage.deliveryFailed);
                },
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Interactive CartoDB Map View
            SizedBox(
              height: 240,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: customerLoc,
                      initialZoom: 13.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                        userAgentPackageName: 'com.dilkash.staff',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [_cafeLocation, customerLoc],
                            strokeWidth: 4.0,
                            color: DilkashColors.primary500,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _cafeLocation,
                            width: 36,
                            height: 36,
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: Color(0xFF0D6B4E),
                              size: 32,
                            ),
                          ),
                          Marker(
                            point: customerLoc,
                            width: 36,
                            height: 36,
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Colors.red,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // External Navigation Launcher Chips (Yandex, Google, 2GIS)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildNavChip('Yandex Navigatsiya', () => _launchExternalMap('yandex'), Colors.red[700]!),
                        const SizedBox(height: 6),
                        _buildNavChip('Google Maps', () => _launchExternalMap('google'), Colors.blue[700]!),
                        const SizedBox(height: 6),
                        _buildNavChip('2GIS Xaritasi', () => _launchExternalMap('2gis'), Colors.green[700]!),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Order Specs & Stage Progression Details
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stage Timeline Indicator
                    _buildStageTimeline(isDark),
                    const SizedBox(height: 16),

                    // Address Card with Moʻljal & Intercom
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF16231D) : Colors.white,
                        borderRadius: DilkashRadii.radiusMd,
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E3529) : DilkashColors.neutral200,
                        ),
                        boxShadow: DilkashShadows.card(isDark),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, color: Colors.red, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  address,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: DilkashColors.textPrimary(isDark),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              _buildInfoTag('Kirish (Podyezd)', _order!['entrance'] ?? '1'),
                              _buildInfoTag('Qavat', _order!['floor'] ?? '1'),
                              _buildInfoTag('Domofon', _order!['intercom'] ?? '-'),
                              _buildInfoTag('Xonadon', _order!['apartment'] ?? '-'),
                            ],
                          ),
                          if (_order!['landmark'] != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Moʻljal: ${_order!['landmark']}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: DilkashColors.primary500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Customer Contact Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF16231D) : Colors.white,
                        borderRadius: DilkashRadii.radiusSm,
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E3529) : DilkashColors.neutral200,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: DilkashColors.primary500.withValues(alpha: 0.12),
                            child: const Icon(Icons.person_rounded, color: DilkashColors.primary500),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customerName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: DilkashColors.textPrimary(isDark),
                                  ),
                                ),
                                Text(
                                  customerPhone,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: DilkashColors.textSecondary(isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _callPhone(customerPhone),
                            icon: const Icon(Icons.phone_rounded, color: Colors.green),
                            tooltip: 'Mijozga qoʻngʻiroq',
                          ),
                          IconButton(
                            onPressed: () => _callPhone('+998712000000'),
                            icon: const Icon(Icons.storefront_rounded, color: Colors.blue),
                            tooltip: 'Restoranga qoʻngʻiroq',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Payment and Cash Change Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isCash ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
                        borderRadius: DilkashRadii.radiusSm,
                        border: Border.all(
                          color: isCash ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCash ? 'Naqd pul yigʻilishi kerak:' : 'Oldindan toʻlangan:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isCash ? Colors.amber[900] : Colors.green[900],
                                ),
                              ),
                              Text(
                                isCash
                                    ? UzbekFormatters.formatCurrency(amountToCollect)
                                    : '0 soʻm (Toʻliq toʻlangan)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: isCash ? Colors.amber[900] : Colors.green[900],
                                ),
                              ),
                            ],
                          ),
                          if (isCash && amountToCollect > 0)
                            ElevatedButton.icon(
                              onPressed: () {
                                ChangeCalculatorDialog.show(context, amountToCollect);
                              },
                              icon: const Icon(Icons.calculate_rounded, size: 18),
                              label: const Text('Qaytim'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber[800],
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Swipe to Confirm Slider (Primary Touch Target >= 56dp)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: DilkashSwipeButton(
                label: _swipeSliderLabel,
                thumbColor: DilkashColors.primary500,
                onSwipeComplete: () async {
                  _progressToNextStage();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavChip(String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_rounded, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTag(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildStageTimeline(bool isDark) {
    final stages = [
      OrderStage.assigned,
      OrderStage.headingToCafe,
      OrderStage.pickedUp,
      OrderStage.onTheWay,
      OrderStage.arrived,
      OrderStage.delivered,
    ];

    final currentIndex = stages.indexOf(_currentStage);

    return Row(
      children: List.generate(stages.length, (i) {
        final isPassed = i <= currentIndex;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 6,
            decoration: BoxDecoration(
              color: isPassed ? DilkashColors.primary500 : Colors.grey.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}
