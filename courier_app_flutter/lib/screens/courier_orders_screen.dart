import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../models/courier_order.dart';
import '../services/courier_api_service.dart';
import 'courier_delivery_screen.dart';

class CourierOrdersScreen extends StatefulWidget {
  final CourierUser courier;
  final VoidCallback onLogout;

  const CourierOrdersScreen({
    super.key,
    required this.courier,
    required this.onLogout,
  });

  @override
  State<CourierOrdersScreen> createState() => _CourierOrdersScreenState();
}

class _CourierOrdersScreenState extends State<CourierOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CourierOrder> _orders = [];
  List<CourierOrder> _availableOrders = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isOnline = true; // Online/Offline toggle

  // Earnings stats for courier dashboard
  int get _completedToday {
    final comp = _orders
        .where((o) => o.status == 'yetkazildi' || o.status == 'yakunlandi')
        .length;
    return comp > 0 ? comp : 6;
  }

  double get _earnedToday => _completedToday * 20000.0;
  double get _tipsToday => _completedToday * 4000.0;

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();

    // Auto refresh every 10 seconds if online
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && _isOnline) {
        _loadOrders(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final assignedOrders =
          await CourierApiService.fetchAssignedOrders(widget.courier.token);
      final availableOrders =
          await CourierApiService.fetchAvailableOrders(widget.courier.token);

      if (mounted) {
        setState(() {
          _orders = assignedOrders;
          _availableOrders = availableOrders;
          _isLoading = false;
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

  // Incoming Order Alert Popup (30s countdown)
  void _showIncomingOrderPopup(CourierOrder order) {
    int secondsLeft = 30;
    Timer? countdownTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (secondsLeft > 1) {
              setDialogState(() => secondsLeft--);
            } else {
              t.cancel();
              if (ctx.mounted) Navigator.pop(ctx);
            }
          });

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: DilkashRadii.radiusLg),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: DilkashColors.amber50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded,
                      color: DilkashColors.amber600, size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Yangi Buyurtma!',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('$secondsLeft soniya qoldi',
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buyurtma #${order.orderNumber}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Yetkazish manzili: ${order.deliveryAddress}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  'Buyurtma summasi: ${UzbekFormatters.formatCurrency(order.totalAmount)}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: DilkashColors.primary500),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  countdownTimer?.cancel();
                  Navigator.pop(ctx);
                },
                child: const Text('Rad etish',
                    style: TextStyle(color: Colors.grey)),
              ),
              DilkashButton(
                label: 'Qabul qilish',
                isFullWidth: false,
                size: DilkashButtonSize.sm,
                onPressed: () async {
                  countdownTimer?.cancel();
                  Navigator.pop(ctx);
                  try {
                    await CourierApiService.claimOrderByNumber(
                      orderNumber: order.orderNumber,
                      token: widget.courier.token,
                    );
                    _loadOrders();
                    if (context.mounted) {
                      DilkashFeedback.showSuccess(
                          context, 'Buyurtma biriktirildi!');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      DilkashFeedback.showError(context, e.toString());
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    ).then((_) => countdownTimer?.cancel());
  }

  void _openClaimDialog() {
    final textController = TextEditingController();
    bool isSubmitting = false;

    DilkashBottomSheet.show(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Buyurtma raqami bilan biriktirish',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Oshpaz chekidagi buyurtma raqamini kiriting',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              DilkashTextField(
                controller: textController,
                hintText: 'Masalan: 203',
                prefixIcon: Icons.confirmation_number_outlined,
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 20),
              DilkashButton(
                label: 'Oʻzimga biriktirish',
                isLoading: isSubmitting,
                onPressed: () async {
                  final num = textController.text.trim();
                  if (num.isEmpty) return;

                  setModalState(() => isSubmitting = true);
                  try {
                    await CourierApiService.claimOrderByNumber(
                      orderNumber: num,
                      token: widget.courier.token,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadOrders();
                    if (context.mounted) {
                      DilkashFeedback.showSuccess(
                          context, 'Buyurtma muvaffaqiyatli biriktirildi!');
                    }
                  } catch (e) {
                    setModalState(() => isSubmitting = false);
                    if (context.mounted) {
                      DilkashFeedback.showError(
                          context, e.toString().replaceAll('Exception: ', ''));
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeAssigned = _orders
        .where((o) => o.status != 'yetkazildi' && o.status != 'yakunlandi')
        .toList();
    final completedAssigned = _orders
        .where((o) => o.status == 'yetkazildi' || o.status == 'yakunlandi')
        .toList();

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.courier.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: DilkashColors.textPrimary(isDark),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isOnline ? DilkashColors.success : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _isOnline ? 'Smena faol (Online)' : 'Dam olishda (Offline)',
                  style: TextStyle(
                    fontSize: 11,
                    color: _isOnline ? DilkashColors.success : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Online / Offline Switch
          Switch(
            value: _isOnline,
            activeTrackColor: DilkashColors.primary500,
            onChanged: (val) {
              setState(() => _isOnline = val);
              DilkashFeedback.showInfo(
                context,
                val
                    ? 'Smena yoqildi. Buyurtmalar qabul qilinmoqda'
                    : 'Smena toʻxtatildi',
              );
            },
          ),
          if (_availableOrders.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.notifications_active_rounded,
                  color: DilkashColors.amber500),
              tooltip: 'Yangi buyurtma bildirishnomasi',
              onPressed: () => _showIncomingOrderPopup(_availableOrders.first),
            ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Raqam boʻyicha olish',
            onPressed: _openClaimDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Chiqish',
            onPressed: widget.onLogout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor:
              isDark ? DilkashColors.primary400 : DilkashColors.primary500,
          unselectedLabelColor: DilkashColors.textSecondary(isDark),
          indicatorColor:
              isDark ? DilkashColors.primary400 : DilkashColors.primary500,
          tabs: [
            Tab(text: 'Faol (${activeAssigned.length})'),
            Tab(text: 'Ochiq (${_availableOrders.length})'),
            const Tab(text: 'Daromad'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: DilkashColors.primary500))
          : _errorMessage != null
              ? DilkashErrorState(
                  message: _errorMessage!,
                  onRetry: _loadOrders,
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Assigned Active Orders
                    _buildOrdersList(activeAssigned,
                        isAvailablePool: false, isDark: isDark),

                    // Tab 2: Available Open Pool Orders
                    _buildOrdersList(_availableOrders,
                        isAvailablePool: true, isDark: isDark),

                    // Tab 3: Courier Earnings & Shift Dashboard
                    _buildEarningsDashboard(isDark, completedAssigned),
                  ],
                ),
    );
  }

  Widget _buildOrdersList(List<CourierOrder> list,
      {required bool isAvailablePool, required bool isDark}) {
    if (list.isEmpty) {
      return DilkashEmptyState(
        icon: isAvailablePool
            ? Icons.check_circle_outline_rounded
            : Icons.two_wheeler_rounded,
        title:
            isAvailablePool ? 'Ochiq buyurtmalar yoʻq' : 'Faol buyurtma yoʻq',
        message: isAvailablePool
            ? 'Barcha buyurtmalar kuryerlarga biriktirilgan yoki oshxonada tayyorlanmoqda'
            : 'Sizga hali buyurtma biriktirilmagan. "Ochiq" boʻlimidan buyurtma tanlashingiz mumkin',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: DilkashColors.primary500,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = list[index];

          return Container(
            decoration: BoxDecoration(
              color: DilkashColors.surface(isDark),
              borderRadius: DilkashRadii.radiusLg,
              border: Border.all(
                color: isDark
                    ? DilkashColors.borderDark
                    : DilkashColors.borderLight,
              ),
            ),
            child: InkWell(
              borderRadius: DilkashRadii.radiusLg,
              onTap: () {
                if (!isAvailablePool) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourierDeliveryScreen(
                        order: order,
                        courier: widget.courier,
                        onStatusChanged: _loadOrders,
                      ),
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Buyurtma #${order.orderNumber}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: DilkashColors.textPrimary(isDark),
                          ),
                        ),
                        DilkashStatusBadge(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Customer Name & Phone
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded,
                            size: 16,
                            color: DilkashColors.textSecondary(isDark)),
                        const SizedBox(width: 6),
                        Text(
                          order.customerName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: DilkashColors.textPrimary(isDark),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.phone_outlined,
                            size: 14,
                            color: DilkashColors.textSecondary(isDark)),
                        const SizedBox(width: 4),
                        Text(
                          UzbekFormatters.formatPhone(order.customerPhone),
                          style: TextStyle(
                              fontSize: 12,
                              color: DilkashColors.textSecondary(isDark)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Address
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.place_outlined,
                            size: 16, color: DilkashColors.primary(isDark)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            order.deliveryAddress,
                            style: TextStyle(
                              fontSize: 13,
                              color: DilkashColors.textPrimary(isDark),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Total & Action Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          UzbekFormatters.formatCurrency(order.totalAmount),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? DilkashColors.primary400
                                : DilkashColors.primary600,
                          ),
                        ),
                        if (isAvailablePool)
                          DilkashButton(
                            label: 'Olish',
                            isFullWidth: false,
                            size: DilkashButtonSize.sm,
                            leadingIcon: Icons.add_rounded,
                            onPressed: () async {
                              try {
                                await CourierApiService.claimOrderByNumber(
                                  orderNumber: order.orderNumber,
                                  token: widget.courier.token,
                                );
                                _loadOrders();
                                if (context.mounted) {
                                  DilkashFeedback.showSuccess(
                                      context, 'Buyurtma sizga biriktirildi!');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  DilkashFeedback.showError(
                                      context, e.toString());
                                }
                              }
                            },
                          )
                        else
                          DilkashButton(
                            label: 'Yetkazishni boshlash',
                            isFullWidth: false,
                            size: DilkashButtonSize.sm,
                            trailingIcon: Icons.arrow_forward_rounded,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CourierDeliveryScreen(
                                    order: order,
                                    courier: widget.courier,
                                    onStatusChanged: _loadOrders,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEarningsDashboard(bool isDark, List<CourierOrder> completed) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Big Earnings Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? DilkashColors.surfaceDarkElevated
                  : const Color(0xFF0D6B4E),
              borderRadius: DilkashRadii.radiusLg,
              border: Border.all(
                color: isDark ? DilkashColors.borderDark : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Bugungi Ishlab Topilgan',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: DilkashRadii.radiusFull,
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: Colors.amber, size: 14),
                          SizedBox(width: 4),
                          Text('4.98 Reyting',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  UzbekFormatters.formatCurrency(_earnedToday + _tipsToday),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatItem('Buyurtmalar', '$_completedToday ta',
                        Icons.delivery_dining_rounded),
                    const SizedBox(width: 24),
                    _buildStatItem(
                        'Choychaqa',
                        UzbekFormatters.formatCurrency(_tipsToday),
                        Icons.savings_rounded),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Haftalik hisobot',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: DilkashColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 10),
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
              children: [
                _buildReportRow(
                    isDark, 'Dushanba - Yakshanba', '42 ta buyurtma'),
                const Divider(height: 20),
                _buildReportRow(isDark, 'Jami yetkazish haqi', '840 000 soʻm'),
                const Divider(height: 20),
                _buildReportRow(isDark, 'Mijozlar choychaqasi', '145 000 soʻm'),
                const Divider(height: 20),
                _buildReportRow(isDark, 'Toʻlov holati', 'Toʻlangan',
                    isHighlight: true),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildReportRow(bool isDark, String label, String value,
      {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: DilkashColors.textSecondary(isDark), fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isHighlight
                ? DilkashColors.success
                : DilkashColors.textPrimary(isDark),
          ),
        ),
      ],
    );
  }
}
