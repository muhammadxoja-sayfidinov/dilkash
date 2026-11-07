// Screen 1: Courier Orders Screen
// Strictly follows KEEP:
// - List of new and active orders as big cards (address, amount, payment type, kitchen status "tayyorlanmoqda / tayyor")
// - New order = loud sound + vibration, one-tap "Qabul qilish"
// - Tapping card opens Order detail

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/state_machine/order_state_machine.dart';

class CourierOrdersScreen extends ConsumerStatefulWidget {
  const CourierOrdersScreen({super.key});

  @override
  ConsumerState<CourierOrdersScreen> createState() => _CourierOrdersScreenState();
}

class _CourierOrdersScreenState extends ConsumerState<CourierOrdersScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    // Realtime background updates without manual refresh
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _fetchOrders(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final repo = ref.read(staffRepositoryProvider);
      final list = await repo.fetchCourierOrders();
      if (mounted) {
        setState(() {
          _orders = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _claimOrder(int orderId) async {
    HapticFeedback.heavyImpact();
    try {
      final repo = ref.read(staffRepositoryProvider);
      final success = await repo.claimCourierOrder(orderId);
      if (success && mounted) {
        DilkashFeedback.showSuccess(context, 'Buyurtma qabul qilindi!');
        _fetchOrders(silent: true);
        context.push('/courier/order/$orderId');
      }
    } catch (e) {
      if (mounted) {
        DilkashFeedback.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  void _triggerSimulatedAlert() {
    // Loud sound + vibration alert for new orders
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DilkashColors.primary500,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.notifications_active_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yangi buyurtma keldi!',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Chilonzor 9-mavze, 14-uy',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                _claimOrder(178);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DilkashColors.primary500,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Qabul qilish',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
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

    if (_error != null) {
      return Scaffold(
        backgroundColor: DilkashColors.bgLight,
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
                  _error!,
                  textAlign: TextAlign.center,
                  style: DilkashTypography.bodyLarge,
                ),
                const SizedBox(height: DilkashSpacing.lg),
                ElevatedButton(
                  onPressed: () => _fetchOrders(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DilkashColors.primary500,
                  ),
                  child: const Text('Qayta urinish',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: DilkashColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Buyurtmalar (${_orders.length})',
          style: DilkashTypography.h3.copyWith(
            fontWeight: FontWeight.w700,
            color: DilkashColors.textPrimaryLight,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sinov yangi buyurtma signali',
            icon: const Icon(Icons.notifications_active_outlined,
                color: DilkashColors.primary500),
            onPressed: _triggerSimulatedAlert,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: DilkashColors.primary500,
          onRefresh: () => _fetchOrders(),
          child: _orders.isEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(DilkashSpacing.xl),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: DilkashColors.bgLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.moped_rounded,
                                  size: 52,
                                  color: DilkashColors.textMutedLight,
                                ),
                              ),
                              const SizedBox(height: DilkashSpacing.lg),
                              Text(
                                'Hozircha buyurtmalar yo’q',
                                style: DilkashTypography.h3.copyWith(
                                  color: DilkashColors.textSecondaryLight,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Yangi yetkazishlar kelishi bilan bu yerda ko’rinadi',
                                textAlign: TextAlign.center,
                                style: DilkashTypography.bodyMedium.copyWith(
                                  color: DilkashColors.textMutedLight,
                                ),
                              ),
                              const SizedBox(height: DilkashSpacing.lg),
                              OutlinedButton.icon(
                                onPressed: () => _fetchOrders(),
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Yangilash'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: DilkashColors.primary500,
                                  side: const BorderSide(color: DilkashColors.primary500),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(DilkashRadii.md),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(DilkashSpacing.lg),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    final orderId = order['id'] as int;
                    final orderNum = order['order_number'] ?? '#$orderId';
                    final address = order['delivery_address'] ?? '';
                    final isCash = order['payment_type'] == 'cash';
                    final amount =
                        (order['amount_to_collect'] as num?)?.toDouble() ?? 0.0;
                    final kitchenStatus =
                        order['kitchen_status'] as String? ?? 'tayyor';
                    final stageName =
                        order['stage'] as String? ?? 'assigned';
                    final isNew = stageName == CourierStage.assigned.name;

                    return Container(
                      margin: const EdgeInsets.only(bottom: DilkashSpacing.lg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(DilkashRadii.lg),
                        border: Border.all(
                          color: isNew
                              ? DilkashColors.primary500
                              : DilkashColors.borderLight,
                          width: isNew ? 2 : 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(DilkashRadii.lg),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.push('/courier/order/$orderId').then((_) {
                              _fetchOrders(silent: true);
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(DilkashSpacing.xl),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top row: Order Number, Kitchen Status badge
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          orderNum,
                                          style: DilkashTypography.h3.copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (isNew) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: DilkashColors.primary500,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Yangi',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    // Kitchen status badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: kitchenStatus == 'ready'
                                            ? DilkashColors.primary50
                                            : const Color(0xFFFEF3C7),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        kitchenStatus == 'ready'
                                            ? 'Tayyor'
                                            : 'Tayyorlanmoqda',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: kitchenStatus == 'ready'
                                              ? DilkashColors.primary700
                                              : const Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: DilkashSpacing.md),

                                // Address (Big bold readable type)
                                Text(
                                  address,
                                  style: DilkashTypography.h2.copyWith(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),

                                const SizedBox(height: DilkashSpacing.md),

                                // Amount and Payment Type
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isCash
                                              ? 'Mijozdan naqd:'
                                              : 'To’lov turi:',
                                          style: DilkashTypography.caption
                                              .copyWith(
                                            color: DilkashColors
                                                .textSecondaryLight,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isCash
                                              ? UzbekFormatters.formatCurrency(
                                                  amount)
                                              : 'To’langan',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: isCash
                                                ? const Color(0xFFB45309)
                                                : DilkashColors.primary700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Status Badge or 1-Tap "Qabul qilish"
                                    if (isNew)
                                      ElevatedButton(
                                        onPressed: () => _claimOrder(orderId),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              DilkashColors.primary500,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text(
                                          'Qabul qilish',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: DilkashColors.primary50,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          OrderStateMachine.courierStageLabel(
                                            CourierStage.values.firstWhere(
                                              (s) => s.name == stageName,
                                              orElse: () =>
                                                  CourierStage.accepted,
                                            ),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: DilkashColors.primary700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
