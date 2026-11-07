// Screen 2: Courier Order Detail Screen
// Strictly follows KEEP:
// - Address with entrance/landmark
// - One-tap call to customer
// - One-tap "Xaritada ochish" (opens Yandex Maps / Google Maps, NO in-app map)
// - Items list
// - Amount to collect (cash) or "to’langan"
// - ONE big primary button moving status forward: Qabul qilindi -> Olib oldim -> Yetkazildi
// - One small "Muammo" action notifying the manager

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/state_machine/order_state_machine.dart';
import '../widgets/problem_reporting_sheet.dart';

class CourierOrderDetailScreen extends ConsumerStatefulWidget {
  final int orderId;

  const CourierOrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<CourierOrderDetailScreen> createState() =>
      _CourierOrderDetailScreenState();
}

class _CourierOrderDetailScreenState
    extends ConsumerState<CourierOrderDetailScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _order;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetail();
  }

  Future<void> _fetchOrderDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(staffRepositoryProvider);
      final orders = await repo.fetchCourierOrders();
      final match = orders.firstWhere(
        (o) => o['id'] == widget.orderId,
        orElse: () => <String, dynamic>{},
      );

      if (mounted) {
        if (match.isEmpty) {
          setState(() {
            _error = 'Buyurtma topilmadi yoki allaqachon topshirilgan';
            _isLoading = false;
          });
        } else {
          setState(() {
            _order = match;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _callCustomer(String phone) async {
    HapticFeedback.lightImpact();
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        DilkashFeedback.showError(context, 'Qo’ng’iroq qilib bo’lmadi: $phone');
      }
    }
  }

  Future<void> _openExternalMap(String address) async {
    HapticFeedback.lightImpact();
    final query = Uri.encodeComponent(address);
    // Try Yandex Maps, fallback to Google Maps web
    final yandexUri = Uri.parse('yandexmaps://build_route_on_map?lat_to=41.2858&lon_to=69.2045');
    final googleUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    if (await canLaunchUrl(yandexUri)) {
      await launchUrl(yandexUri);
    } else if (await canLaunchUrl(googleUri)) {
      await launchUrl(googleUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        DilkashFeedback.showError(context, 'Xarita ilovasini ochib bo’lmadi');
      }
    }
  }

  Future<void> _progressStatus() async {
    if (_order == null || _isActionLoading) return;

    final currentStageName = _order!['stage'] as String? ?? 'assigned';
    final currentStage = CourierStage.values.firstWhere(
      (s) => s.name == currentStageName,
      orElse: () => CourierStage.assigned,
    );

    CourierStage? nextStage;
    if (currentStage == CourierStage.assigned) {
      nextStage = CourierStage.accepted;
    } else if (currentStage == CourierStage.accepted) {
      nextStage = CourierStage.pickedUp;
    } else if (currentStage == CourierStage.pickedUp) {
      nextStage = CourierStage.delivered;
    }

    if (nextStage == null) return;

    setState(() => _isActionLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final repo = ref.read(staffRepositoryProvider);
      final success = await repo.updateCourierStage(widget.orderId, nextStage);
      if (success && mounted) {
        setState(() {
          _order!['stage'] = nextStage!.name;
        });

        DilkashFeedback.showSuccess(
          context,
          'Holat o’zgartirildi: ${OrderStateMachine.courierStageLabel(nextStage)}',
        );

        if (nextStage == CourierStage.delivered) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) Navigator.pop(context, true);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        DilkashFeedback.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: DilkashColors.bgLight,
        body: Center(
          child: CircularProgressIndicator(color: DilkashColors.primary500),
        ),
      );
    }

    if (_error != null || _order == null) {
      return Scaffold(
        backgroundColor: DilkashColors.bgLight,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(DilkashSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: DilkashColors.error),
                const SizedBox(height: DilkashSpacing.md),
                Text(
                  _error ?? 'Xatolik yuz berdi',
                  textAlign: TextAlign.center,
                  style: DilkashTypography.bodyLarge,
                ),
                const SizedBox(height: DilkashSpacing.lg),
                ElevatedButton(
                  onPressed: _fetchOrderDetail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DilkashColors.primary500,
                  ),
                  child: const Text('Qayta yuklash',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final order = _order!;
    final orderNumber = order['order_number'] ?? '#${order['id']}';
    final customerName = order['customer_name'] ?? 'Mijoz';
    final customerPhone = order['customer_phone'] ?? '+998';
    final address = order['delivery_address'] ?? 'Manzil ko’rsatilmagan';
    final landmark = order['entrance_landmark'] ?? '';
    final isCash = order['payment_type'] == 'cash';
    final amountToCollect =
        (order['amount_to_collect'] as num?)?.toDouble() ?? 0.0;
    final items = List<Map<String, dynamic>>.from(order['items'] as List? ?? []);
    final notes = order['notes'] as String? ?? '';
    final kitchenStatus = order['kitchen_status'] as String? ?? 'tayyor';

    final stageName = order['stage'] as String? ?? 'assigned';
    final stage = CourierStage.values.firstWhere(
      (s) => s.name == stageName,
      orElse: () => CourierStage.assigned,
    );

    // Progression button text: Qabul qilindi -> Olib oldim -> Yetkazildi
    String buttonText;
    Color buttonColor = DilkashColors.primary500;
    bool isCompleted = stage == CourierStage.delivered;

    if (stage == CourierStage.assigned) {
      buttonText = 'Qabul qilish';
    } else if (stage == CourierStage.accepted) {
      buttonText = 'Olib oldim';
    } else if (stage == CourierStage.pickedUp) {
      buttonText = 'Yetkazildi';
    } else {
      buttonText = 'Topshirilgan';
      buttonColor = Colors.grey;
    }

    return Scaffold(
      backgroundColor: DilkashColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Buyurtma $orderNumber',
          style: DilkashTypography.h3.copyWith(
            fontWeight: FontWeight.w700,
            color: DilkashColors.textPrimaryLight,
          ),
        ),
        centerTitle: true,
        actions: [
          // Small "Muammo" action notifying the manager
          TextButton.icon(
            onPressed: () {
              ProblemReportingSheet.show(
                context: context,
                orderId: widget.orderId,
                onSubmit: (reason) {
                  ref.read(staffRepositoryProvider).reportDeliveryProblem(
                        orderId: widget.orderId,
                        reason: reason,
                      );
                  setState(() {
                    _order!['stage'] = CourierStage.problem.name;
                  });
                },
              );
            },
            icon: const Icon(Icons.report_problem_outlined,
                size: 18, color: DilkashColors.error),
            label: Text(
              'Muammo',
              style: DilkashTypography.caption.copyWith(
                color: DilkashColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: DilkashColors.primary500,
                onRefresh: _fetchOrderDetail,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(DilkashSpacing.lg),
                  children: [
                  // Kitchen Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DilkashSpacing.md,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: kitchenStatus == 'ready'
                          ? DilkashColors.primary50
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(DilkashRadii.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          kitchenStatus == 'ready'
                              ? Icons.check_circle_rounded
                              : Icons.hourglass_top_rounded,
                          size: 18,
                          color: kitchenStatus == 'ready'
                              ? DilkashColors.primary500
                              : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          kitchenStatus == 'ready'
                              ? 'Oshxona holati: Tayyor'
                              : 'Oshxona holati: Tayyorlanmoqda',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: kitchenStatus == 'ready'
                                ? DilkashColors.primary700
                                : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: DilkashSpacing.md),

                  // Address Card with Entrance/Landmark & 1-tap Actions
                  Container(
                    padding: const EdgeInsets.all(DilkashSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(DilkashRadii.md),
                      border: Border.all(color: DilkashColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yetkazish manzili',
                          style: DilkashTypography.caption.copyWith(
                            color: DilkashColors.textSecondaryLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          address,
                          style: DilkashTypography.h2.copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (landmark.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 16, color: DilkashColors.primary500),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  landmark,
                                  style: DilkashTypography.bodyMedium.copyWith(
                                    color: DilkashColors.textSecondaryLight,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: DilkashSpacing.md),
                        const Divider(height: 1),
                        const SizedBox(height: DilkashSpacing.md),

                        // One-tap Call and One-tap Map Actions
                        Row(
                          children: [
                            // 1-tap Call to Customer
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: () => _callCustomer(customerPhone),
                                  icon: const Icon(Icons.phone_outlined,
                                      size: 18, color: DilkashColors.primary500),
                                  label: Text(
                                    customerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: DilkashColors.primary500,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: DilkashColors.primary500),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(DilkashRadii.sm),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: DilkashSpacing.sm),
                            // 1-tap "Xaritada ochish" (External map)
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: () => _openExternalMap(address),
                                  icon: const Icon(Icons.map_outlined,
                                      size: 18, color: Colors.white),
                                  label: const Text(
                                    'Xaritada ochish',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(DilkashRadii.sm),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: DilkashSpacing.lg),

                  // Amount to Collect (Cash or To’langan)
                  Container(
                    padding: const EdgeInsets.all(DilkashSpacing.lg),
                    decoration: BoxDecoration(
                      color: isCash ? const Color(0xFFFFFBEB) : DilkashColors.primary50,
                      borderRadius: BorderRadius.circular(DilkashRadii.md),
                      border: Border.all(
                        color: isCash
                            ? const Color(0xFFFDE68A)
                            : DilkashColors.primary100,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCash ? 'Mijozdan olinadigan naqd pul:' : 'To’lov holati:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isCash
                                    ? const Color(0xFF92400E)
                                    : DilkashColors.primary700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isCash
                                  ? UzbekFormatters.formatCurrency(amountToCollect)
                                  : 'To’langan (Karta / Click)',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: isCash
                                    ? const Color(0xFFB45309)
                                    : DilkashColors.primary700,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          isCash
                              ? Icons.payments_outlined
                              : Icons.check_circle_outline_rounded,
                          size: 32,
                          color: isCash
                              ? const Color(0xFFD97706)
                              : DilkashColors.primary500,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: DilkashSpacing.lg),

                  // Items List
                  Container(
                    padding: const EdgeInsets.all(DilkashSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(DilkashRadii.md),
                      border: Border.all(color: DilkashColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buyurtma tarkibi (${items.length} ta xil)',
                          style: DilkashTypography.h3.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: DilkashSpacing.md),
                        ...items.map((item) {
                          final dishName = item['dish_name'] ?? '';
                          final qty = item['quantity'] ?? 1;
                          final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: DilkashColors.bgLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${qty}x',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    dishName,
                                    style: DilkashTypography.bodyLarge.copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  UzbekFormatters.formatCurrency(price * qty),
                                  style: DilkashTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: DilkashSpacing.md),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: DilkashColors.bgLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Eslatma: $notes',
                              style: DilkashTypography.caption.copyWith(
                                color: DilkashColors.textSecondaryLight,
                                fontStyle: FontStyle.italic,
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
          ),

            // ONE BIG PRIMARY BUTTON AT BOTTOM WITHIN THUMB REACH (>= 56dp)
            Container(
              padding: const EdgeInsets.all(DilkashSpacing.lg),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 10,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: isCompleted || _isActionLoading ? null : _progressStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DilkashRadii.md),
                    ),
                  ),
                  child: _isActionLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          buttonText,
                          style: DilkashTypography.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
