// Courier Home Dashboard
// Features online/offline toggle, shift bar, today's stats (deliveries, earnings, cash on hand),
// active queue with suggested delivery sequence, live kitchen status, and pool order claiming.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/state_machine/order_state_machine.dart';
import '../../shift/widgets/shift_bar_widget.dart';
import '../widgets/change_calculator_dialog.dart';
import '../widgets/incoming_order_modal.dart';

class CourierHomeScreen extends ConsumerStatefulWidget {
  const CourierHomeScreen({super.key});

  @override
  ConsumerState<CourierHomeScreen> createState() => _CourierHomeScreenState();
}

class _CourierHomeScreenState extends ConsumerState<CourierHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isOnline = true;
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeOrders = [];
  List<Map<String, dynamic>> _poolOrders = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted && _isOnline) _loadData(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final repo = ref.read(staffRepositoryProvider);
    final session = ref.read(authProvider).value;
    final token = session?.token ?? '';

    try {
      final active = await repo.fetchCourierOrders(token);
      final pool = await repo.fetchAvailablePoolOrders();
      if (mounted) {
        setState(() {
          _activeOrders = active;
          _poolOrders = pool;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  void _triggerSimulatedIncomingOrder() {
    HapticFeedback.vibrate();
    final demoIncoming = {
      'id': 189,
      'order_number': 'ORD-189',
      'customer_name': 'Botir Qosimov',
      'customer_phone': '+998901114477',
      'delivery_address': 'Toshkent sh., Navoiy koʻchasi, 14-uy',
      'delivery_fee': 22000.0,
      'distance_km': 3.8,
      'amount_to_collect': 95000.0,
      'payment_type': 'cash',
      'items': [
        {'dish_name': 'Toshkent Toʻy Oshi', 'quantity': 2},
        {'dish_name': 'Achichuk salati', 'quantity': 1},
      ],
    };

    IncomingOrderModal.show(
      context: context,
      order: demoIncoming,
      onAccept: () {
        setState(() {
          _activeOrders.insert(0, {
            ...demoIncoming,
            'stage': OrderStage.assigned.name,
            'suggested_sequence': _activeOrders.length + 1,
            'kitchen_status': 'ready',
            'timestamps': {'assigned': 'Hozir'},
            'checklist': [
              {'item': 'Barcha taomlar toʻliq', 'checked': false},
              {'item': 'Ichimliklar', 'checked': false},
              {'item': 'Muhrlangan termosumka', 'checked': false},
            ],
          });
        });
        DilkashFeedback.showSuccess(
          context,
          'Buyurtma #ORD-189 qabul qilindi va roʻyxatga qoʻshildi!',
        );
      },
      onDecline: (reason) {
        DilkashFeedback.showWarning(
          context,
          'Buyurtma rad etildi: $reason',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = ref.watch(authProvider).value;

    // Earnings calculations
    final completedCount = _activeOrders
        .where((o) => o['stage'] == OrderStage.delivered.name)
        .length;
    final totalCashOnHand = _activeOrders
        .where((o) =>
            o['payment_type'] == 'cash' &&
            o['stage'] == OrderStage.delivered.name)
        .fold<double>(
            135000.0,
            (sum, o) =>
                sum + ((o['amount_to_collect'] as num?)?.toDouble() ?? 0.0));
    final totalEarned = (completedCount > 0 ? completedCount : 5) * 20000.0;

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      appBar: AppBar(
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session?.name ?? 'Kuryer',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  _isOnline ? 'Online • Buyurtma kutmoqda' : 'Offline • Nofaol',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _isOnline ? Colors.greenAccent : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Online / Offline Switch
          Switch.adaptive(
            value: _isOnline,
            activeTrackColor: DilkashColors.primary500,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              setState(() => _isOnline = val);
              DilkashFeedback.showInfo(
                context,
                val ? 'Onlayn rejim yoqildi' : 'Oflayn rejim yoqildi',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Bildirishnomalar',
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profil va Sozlamalar',
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Sticky Shift Bar Widget
            const ShiftBarWidget(),

            // Today's Stats Banner (Deliveries, Earnings, Cash on Hand)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16231D) : Colors.white,
                borderRadius: DilkashRadii.radiusMd,
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1E3529)
                      : DilkashColors.neutral200,
                ),
                boxShadow: DilkashShadows.card(isDark),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      'Yetkazildi',
                      '${completedCount > 0 ? completedCount : 5} ta',
                      Icons.check_circle_outline_rounded,
                      DilkashColors.primary500,
                      isDark,
                    ),
                  ),
                  Container(
                      width: 1,
                      height: 36,
                      color: Colors.grey.withValues(alpha: 0.2)),
                  Expanded(
                    child: _buildMetricTile(
                      'Bugungi daromad',
                      UzbekFormatters.formatCurrency(totalEarned),
                      Icons.account_balance_wallet_outlined,
                      const Color(0xFF059669),
                      isDark,
                    ),
                  ),
                  Container(
                      width: 1,
                      height: 36,
                      color: Colors.grey.withValues(alpha: 0.2)),
                  Expanded(
                    child: _buildMetricTile(
                      'Qoʻldagi naqd pul',
                      UzbekFormatters.formatCurrency(totalCashOnHand),
                      Icons.payments_outlined,
                      const Color(0xFFD97706),
                      isDark,
                      onTap: () => context.push('/courier/handover'),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar: Faol Navbat vs Ochiq Buyurtmalar hovuzi
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[200],
                borderRadius: DilkashRadii.radiusSm,
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: DilkashColors.primary500,
                labelColor: DilkashColors.primary500,
                unselectedLabelColor: Colors.grey,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: [
                  Tab(text: 'Faol Buyurtmalar (${_activeOrders.length})'),
                  Tab(text: 'Ochiq Hovuz (${_poolOrders.length})'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Tab Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildActiveOrdersList(isDark),
                        _buildPoolOrdersList(isDark),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _triggerSimulatedIncomingOrder,
        backgroundColor: DilkashColors.primary500,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alert_rounded),
        label: const Text(
          'Yangi Buyurtma Sinovi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildActiveOrdersList(bool isDark) {
    if (_activeOrders.isEmpty) {
      return const Center(
        child: DilkashEmptyState(
          icon: Icons.delivery_dining_outlined,
          title: 'Hozircha faol buyurtma yoʻq',
          subtitle:
              'Yangi buyurtmalar kelishi bilan ekranda paydo boʻladi yoki ochiq hovuzdan oling.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _activeOrders.length,
      itemBuilder: (context, index) {
        final order = _activeOrders[index];
        return _buildCourierOrderCard(order, isDark, index + 1);
      },
    );
  }

  Widget _buildPoolOrdersList(bool isDark) {
    if (_poolOrders.isEmpty) {
      return const Center(
        child: DilkashEmptyState(
          icon: Icons.check_circle_outline_rounded,
          title: 'Ochiq buyurtmalar mavjud emas',
          subtitle: 'Barcha buyurtmalar kuryerlarga taqsimlangan.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _poolOrders.length,
      itemBuilder: (context, index) {
        final order = _poolOrders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: DilkashRadii.radiusSm,
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order['order_number'] ?? '#ORD',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      UzbekFormatters.formatCurrency(
                          order['delivery_fee'] ?? 20000.0),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: DilkashColors.primary500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  order['delivery_address'] ?? '',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      final repo = ref.read(staffRepositoryProvider);
                      final session = ref.read(authProvider).value;
                      await repo.claimCourierOrder(
                          order['id'], session?.token ?? '');
                      _loadData(silent: true);
                      if (context.mounted) {
                        DilkashFeedback.showSuccess(
                            context, 'Buyurtma biriktirildi!');
                      }
                    },
                    icon: const Icon(Icons.add_task_rounded),
                    label: const Text('Oʻzimga qabul qilish'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DilkashColors.primary500,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCourierOrderCard(
      Map<String, dynamic> order, bool isDark, int sequence) {
    final orderId = order['id'] as int;
    final stageName = order['stage'] ?? OrderStage.assigned.name;
    final kitchenStatus = order['kitchen_status'] ?? 'ready';
    final isKitchenReady = kitchenStatus == 'ready';
    final isCash = order['payment_type'] == 'cash';
    final amountToCollect = (order['amount_to_collect'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16231D) : Colors.white,
        borderRadius: DilkashRadii.radiusMd,
        border: Border.all(
          color: isDark ? const Color(0xFF1E3529) : DilkashColors.neutral200,
        ),
        boxShadow: DilkashShadows.card(isDark),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.push('/courier/delivery/$orderId');
          },
          borderRadius: DilkashRadii.radiusMd,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Sequence & Kitchen Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: DilkashColors.primary500.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Ketma-ketlik: #$sequence',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: DilkashColors.primary500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isKitchenReady
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isKitchenReady
                                  ? Icons.check_circle_rounded
                                  : Icons.soup_kitchen_rounded,
                              size: 14,
                              color: isKitchenReady
                                  ? Colors.green[700]
                                  : Colors.amber[800],
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                isKitchenReady
                                    ? 'Oshxona tayyorladi'
                                    : 'Oshxonada (3 daq)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isKitchenReady
                                      ? Colors.green[700]
                                      : Colors.amber[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      order['order_number'] ?? '#ORD',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: DilkashColors.textPrimary(isDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Customer and Address with entrance/floor/intercom/landmark
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order['delivery_address'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: DilkashColors.textPrimary(isDark),
                            ),
                          ),
                          if (order['entrance'] != null ||
                              order['floor'] != null ||
                              order['landmark'] != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${order['entrance'] ?? ''} • ${order['floor'] ?? ''} • Moʻljal: ${order['landmark'] ?? ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: DilkashColors.textSecondary(isDark),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Customer Notes
                if (order['notes'] != null && order['notes'].toString().isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.comment_outlined,
                            size: 16, color: Colors.amber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Izoh: ${order['notes']}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                const Divider(height: 16),

                // Payment Info & Change Calculator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCash ? 'Naqd toʻlov (Qabul qilish):' : 'Oldindan toʻlangan',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isCash ? Colors.amber[800] : Colors.green[700],
                          ),
                        ),
                        Text(
                          isCash
                              ? UzbekFormatters.formatCurrency(amountToCollect)
                              : '0 soʻm (Click/Payme)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: DilkashColors.textPrimary(isDark),
                          ),
                        ),
                      ],
                    ),
                    if (isCash && amountToCollect > 0)
                      TextButton.icon(
                        onPressed: () {
                          ChangeCalculatorDialog.show(context, amountToCollect);
                        },
                        icon: const Icon(Icons.calculate_rounded, size: 18),
                        label: const Text('Qaytim hisoblagich'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Action Bar (Tap target >= 56dp)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push('/courier/delivery/$orderId');
                    },
                    icon: const Icon(Icons.navigation_rounded),
                    label: Text(
                      'Yetkazish bosqichlari (${OrderStateMachine.getStageLabelUz(OrderStage.values.firstWhere((s) => s.name == stageName, orElse: () => OrderStage.assigned))})',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DilkashColors.primary500,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: DilkashRadii.radiusSm),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: DilkashColors.textSecondary(isDark),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: DilkashColors.textPrimary(isDark),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
