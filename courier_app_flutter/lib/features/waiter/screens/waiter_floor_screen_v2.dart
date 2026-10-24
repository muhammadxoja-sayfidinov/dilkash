// Waiter Floor Screen V2
// Features hall zones (Zal, Terrasa, VIP), live status colors (Free, Occupied, In kitchen, Ready to serve, Bill requested, Reserved),
// "My tables" toggle, search filter, active delay timers, loud kitchen ready alerts, and guest call banner.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../shift/widgets/shift_bar_widget.dart';
import '../widgets/table_actions_modal.dart';

class WaiterFloorScreenV2 extends ConsumerStatefulWidget {
  const WaiterFloorScreenV2({super.key});

  @override
  ConsumerState<WaiterFloorScreenV2> createState() =>
      _WaiterFloorScreenV2State();
}

class _WaiterFloorScreenV2State extends ConsumerState<WaiterFloorScreenV2>
    with SingleTickerProviderStateMixin {
  late TabController _zoneTabController;
  List<Map<String, dynamic>> _tables = [];
  bool _isLoading = true;
  bool _myTablesOnly = false;
  String _searchQuery = '';
  Timer? _refreshTimer;

  final List<String> _zones = ['Barcha stollar', 'Zal', 'Terrasa', 'VIP'];

  @override
  void initState() {
    super.initState();
    _zoneTabController = TabController(length: _zones.length, vsync: this);
    _loadTables();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadTables(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _zoneTabController.dispose();
    super.dispose();
  }

  Future<void> _loadTables({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final repo = ref.read(staffRepositoryProvider);
    try {
      final list = await repo.fetchFloorTables();
      if (mounted) {
        setState(() {
          _tables = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredTables(int zoneIndex) {
    final session = ref.read(authProvider).value;
    final waiterName = session?.name ?? '';
    final zoneName = _zones[zoneIndex];

    return _tables.where((t) {
      if (zoneIndex > 0 && t['zone'] != zoneName) return false;
      if (_myTablesOnly && t['waiter_name'] != waiterName) return false;
      if (_searchQuery.isNotEmpty) {
        final num = t['table_number'].toString().toLowerCase();
        if (!num.contains(_searchQuery.toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ready':
        return const Color(0xFF10B981); // Emerald pulse (Ready to serve)
      case 'in_kitchen':
        return const Color(0xFFF59E0B); // Amber (Cooking)
      case 'bill_requested':
        return const Color(0xFF8B5CF6); // Purple (Bill requested)
      case 'occupied':
        return const Color(0xFF3B82F6); // Blue (Occupied)
      case 'reserved':
        return const Color(0xFFF97316); // Orange (Reserved)
      case 'free':
      default:
        return const Color(0xFF64748B); // Slate Gray (Free)
    }
  }

  String _getStatusLabelUz(String status) {
    switch (status) {
      case 'ready':
        return 'Dasturxonga tayyor!';
      case 'in_kitchen':
        return 'Oshxonada';
      case 'bill_requested':
        return 'Hisob soʻralgan';
      case 'occupied':
        return 'Band';
      case 'reserved':
        return 'Bron qilingan';
      case 'free':
      default:
        return 'Boʻsh';
    }
  }

  void _openTableActions(Map<String, dynamic> table) {
    HapticFeedback.lightImpact();
    final repo = ref.read(staffRepositoryProvider);
    final session = ref.read(authProvider).value;

    TableActionsModal.show(
      context: context,
      table: table,
      allTables: _tables,
      onOpenTable: (count) async {
        await repo.openTable(
          tableNumber: table['table_number'],
          guestCount: count,
          waiterName: session?.name ?? 'Ofitsiant',
        );
        _loadTables(silent: true);
        if (mounted) {
          DilkashFeedback.showSuccess(
            context,
            'Stol ${table['table_number']} ochildi ($count mehmon)',
          );
        }
      },
      onTransferTable: (to) async {
        await repo.transferTable(
          fromTable: table['table_number'],
          toTable: to,
          waiterName: session?.name ?? 'Ofitsiant',
        );
        _loadTables(silent: true);
        if (mounted) {
          DilkashFeedback.showSuccess(
            context,
            'Stol ${table['table_number']} dan Stol $to ga koʻchirildi',
          );
        }
      },
      onMergeTables: (withTable) async {
        await repo.mergeTables(
          primaryTable: table['table_number'],
          secondaryTable: withTable,
        );
        _loadTables(silent: true);
        if (mounted) {
          DilkashFeedback.showSuccess(
            context,
            'Stollar birlashtirildi',
          );
        }
      },
      onDismissCall: () async {
        await repo.dismissWaiterCall(1);
        _loadTables(silent: true);
        if (mounted) {
          DilkashFeedback.showSuccess(context, 'Chaqiruv qabul qilindi');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = ref.watch(authProvider).value;

    // Active calls badge count
    final activeCalls = _tables.where((t) => t['active_call'] == true).toList();
    final readyOrders = _tables.where((t) => t['status'] == 'ready').toList();

    return Scaffold(
      backgroundColor: DilkashColors.background(isDark),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${session?.name ?? "Ofitsiant"} • Zallar',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const Text(
              'Dilkash Milliy Taomlar Restorani',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_seat_rounded),
            tooltip: 'Bugungi Bronlar',
            onPressed: () => context.push('/waiter/reservations'),
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

            // Ready to serve alert banner (Loud chime / Visual alert)
            if (readyOrders.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: DilkashRadii.radiusSm,
                  border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.room_service_rounded,
                        color: Color(0xFF059669), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Oshxona tayyorladi: ${readyOrders.map((o) => o['table_number']).join(", ")} stolga taomlarni olib boring!',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _openTableActions(readyOrders.first);
                      },
                      child: const Text('Ochish', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),

            // Active Customer Call Banner
            if (activeCalls.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: DilkashRadii.radiusSm,
                  border: Border.all(color: Colors.red, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded,
                        color: Colors.red, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ofitsiant chaqiruvi: ${activeCalls.map((t) => t['table_number']).join(", ")} stol mehmonga xizmat kutmoqda',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_rounded, color: Colors.green),
                      onPressed: () async {
                        final repo = ref.read(staffRepositoryProvider);
                        await repo.dismissWaiterCall(1);
                        _loadTables(silent: true);
                      },
                    ),
                  ],
                ),
              ),

            // Filter Controls (My Tables toggle + Search)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Stol raqami boʻyicha qidiruv...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey[900] : Colors.grey[200],
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Mening stollarim'),
                    selected: _myTablesOnly,
                    selectedColor:
                        DilkashColors.primary500.withValues(alpha: 0.2),
                    checkmarkColor: DilkashColors.primary500,
                    onSelected: (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _myTablesOnly = val);
                    },
                  ),
                ],
              ),
            ),

            // Zone Tabs: Barcha stollar, Zal, Terrasa, VIP
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[200],
                borderRadius: DilkashRadii.radiusSm,
              ),
              child: TabBar(
                controller: _zoneTabController,
                indicatorColor: DilkashColors.primary500,
                labelColor: DilkashColors.primary500,
                unselectedLabelColor: Colors.grey,
                indicatorSize: TabBarIndicatorSize.tab,
                isScrollable: true,
                tabs: _zones.map((z) => Tab(text: z)).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Floor Plan Table Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _zoneTabController,
                      children: List.generate(
                        _zones.length,
                        (zoneIndex) => _buildTableGrid(zoneIndex, isDark),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableGrid(int zoneIndex, bool isDark) {
    final tables = _getFilteredTables(zoneIndex);

    if (tables.isEmpty) {
      return const Center(
        child: DilkashEmptyState(
          icon: Icons.table_restaurant_outlined,
          title: 'Stollar topilmadi',
          subtitle: 'Ushbu boʻlimda hozircha stollar yoʻq.',
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        final status = table['status'] ?? 'free';
        final statusColor = _getStatusColor(status);
        final isFree = status == 'free';
        final hasCall = table['active_call'] == true;
        final elapsed = table['elapsed_minutes'] ?? 0;
        final totalAmount = (table['total_amount'] as num?)?.toDouble() ?? 0.0;
        final guestCount = table['guest_count'] ?? 0;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16231D) : Colors.white,
            borderRadius: DilkashRadii.radiusMd,
            border: Border.all(
              color: hasCall
                  ? Colors.red
                  : (status == 'ready'
                      ? const Color(0xFF10B981)
                      : statusColor.withValues(alpha: 0.35)),
              width: (hasCall || status == 'ready') ? 2 : 1,
            ),
            boxShadow: hasCall
                ? [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : DilkashShadows.card(isDark),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openTableActions(table),
              borderRadius: DilkashRadii.radiusMd,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top: Table Number + Status Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          table['table_number'] ?? '',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: DilkashColors.textPrimary(isDark),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getStatusLabelUz(status),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Guests count & Zone
                    Row(
                      children: [
                        Icon(Icons.people_outline_rounded,
                            size: 14, color: DilkashColors.textSecondary(isDark)),
                        const SizedBox(width: 4),
                        Text(
                          isFree ? 'Boʻsh' : '$guestCount kishi',
                          style: TextStyle(
                            fontSize: 12,
                            color: DilkashColors.textSecondary(isDark),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (elapsed > 0) ...[
                          Icon(Icons.timer_outlined,
                              size: 13,
                              color: elapsed > 20 ? Colors.red : Colors.grey),
                          const SizedBox(width: 2),
                          Text(
                            '$elapsed daq',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: elapsed > 20 ? Colors.red : Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),

                    // Total check amount
                    if (!isFree)
                      Text(
                        UzbekFormatters.formatCurrency(totalAmount),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: DilkashColors.primary500,
                        ),
                      )
                    else
                      Text(
                        '+ Stol ochish',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue[600],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
