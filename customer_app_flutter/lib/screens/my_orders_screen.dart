import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../models/order.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import 'order_tracking_screen.dart';
import 'tip_review_modal.dart';
import 'auth_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CustomerOrder> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final phone = auth.user?.phone ?? '+998 90 123 45 67';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await ApiService.fetchOrders(phone);
      if (mounted) {
        setState(() {
          _orders = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeOrders = _orders
        .where((o) => o.status != 'yetkazildi' && o.status != 'yakunlandi')
        .toList();
    final pastOrders = _orders
        .where((o) => o.status == 'yetkazildi' || o.status == 'yakunlandi')
        .toList();

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      appBar: AppBar(
        title: const Text('Buyurtmalarim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadOrders,
            tooltip: 'Yangilash',
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
            Tab(text: 'Faol (${activeOrders.length})'),
            Tab(text: 'Tarix (${pastOrders.length})'),
          ],
        ),
      ),
      body: !auth.isAuthenticated
          ? DilkashEmptyState(
              icon: Icons.account_circle_outlined,
              title: 'Tizimga kirmagansiz',
              message:
                  'Buyurtmalar tarixini koʻrish uchun profilingizga kiring',
              actionLabel: 'Kirish',
              onAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AuthScreen(returnOnSuccess: true)),
                ).then((val) {
                  if (val == true) _loadOrders();
                });
              },
            )
          : _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: DilkashColors.primary500))
              : _errorMessage != null
                  ? DilkashErrorState(
                      message: _errorMessage!,
                      onRetry: _loadOrders,
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOrdersList(activeOrders,
                            isActive: true, isDark: isDark),
                        _buildOrdersList(pastOrders,
                            isActive: false, isDark: isDark),
                      ],
                    ),
    );
  }

  Widget _buildOrdersList(List<CustomerOrder> list,
      {required bool isActive, required bool isDark}) {
    if (list.isEmpty) {
      return DilkashEmptyState(
        icon: isActive ? Icons.inventory_2_outlined : Icons.history_rounded,
        title: isActive ? 'Faol buyurtma yoʻq' : 'Buyurtmalar tarixi boʻsh',
        message: isActive
            ? 'Ayni vaqtda faol buyurtmangiz yoʻq. Menyudan yangi taom tanlang'
            : 'Siz hali yetkazib berilgan buyurtmalarga ega emassiz',
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderTrackingScreen(
                      orderId: order.id,
                      orderNumber: order.orderNumber,
                    ),
                  ),
                );
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
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: DilkashColors.textPrimary(isDark),
                          ),
                        ),
                        DilkashStatusBadge(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      order.createdAt,
                      style: TextStyle(
                        fontSize: 12,
                        color: DilkashColors.textSecondary(isDark),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Items snippet
                    Text(
                      order.items
                          .map((i) => '${i.quantity}x ${i.dishName}')
                          .join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: DilkashColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Total & Action row
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
                        if (isActive)
                          DilkashButton(
                            label: 'Kuzatish',
                            isFullWidth: false,
                            size: DilkashButtonSize.sm,
                            trailingIcon: Icons.arrow_forward_rounded,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OrderTrackingScreen(
                                    orderId: order.id,
                                    orderNumber: order.orderNumber,
                                  ),
                                ),
                              );
                            },
                          )
                        else
                          Row(
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.star_outline_rounded,
                                    size: 16),
                                label: const Text('Baholash'),
                                onPressed: () {
                                  TipReviewModal.show(
                                      context, order.id, order.orderNumber);
                                },
                              ),
                            ],
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
}
