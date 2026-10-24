import 'dart:async';
import 'package:flutter/material.dart';
import '../models/staff_user.dart';
import '../models/waiter_models.dart';
import '../services/staff_api_service.dart';
import '../theme/staff_theme.dart';
import '../widgets/order_stations_sheet.dart';
import 'waiter_order_sheet.dart';

class WaiterFloorScreen extends StatefulWidget {
  final StaffUser waiter;
  final VoidCallback onLogout;

  const WaiterFloorScreen({
    super.key,
    required this.waiter,
    required this.onLogout,
  });

  @override
  State<WaiterFloorScreen> createState() => _WaiterFloorScreenState();
}

class _WaiterFloorScreenState extends State<WaiterFloorScreen> {
  List<RestaurantTableModel> _tables = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'all'; // 'all', 'free', 'occupied', 'calls'
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadFloorStatus();
    // Auto-refresh every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadFloorStatus(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadFloorStatus({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final tables = await StaffApiService.fetchFloorStatus();
      if (mounted) {
        setState(() {
          _tables = tables;
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

  Future<void> _dismissCall(int callId) async {
    try {
      await StaffApiService.dismissWaiterCall(callId);
      _loadFloorStatus(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Chaqiruv qabul qilindi'),
            backgroundColor: StaffColors.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: StaffDesign.radiusMd),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Ignored
    }
  }

  Future<void> _deliverDish(int orderId) async {
    try {
      await StaffApiService.deliverOrderToTable(orderId);
      _loadFloorStatus(silent: true);
      if (mounted) {
        Navigator.pop(context); // Close bottomsheet if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Taom stolga yetkazildi!'),
            backgroundColor: StaffColors.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: StaffDesign.radiusMd),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xatolik: $e'),
            backgroundColor: StaffColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: StaffDesign.radiusMd),
          ),
        );
      }
    }
  }

  Future<void> _requestBill(int tableNumber) async {
    try {
      await StaffApiService.requestTableBill(tableNumber.toString());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stol #$tableNumber uchun hisob kassirga yuborildi!'),
            backgroundColor: StaffColors.info,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: StaffDesign.radiusMd),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xatolik: $e'),
            backgroundColor: StaffColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: StaffDesign.radiusMd),
          ),
        );
      }
    }
  }

  Future<void> _assignTable(int tableNumber) async {
    try {
      await StaffApiService.assignTableToWaiter(
        tableNumber: tableNumber.toString(),
        waiterId: widget.waiter.id,
        waiterName: widget.waiter.name,
      );
      _loadFloorStatus(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Stol #$tableNumber sizga muvaffaqiyatli biriktirildi!'),
            backgroundColor: StaffColors.accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: StaffDesign.radiusMd),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xatolik: $e'),
            backgroundColor: StaffColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: StaffDesign.radiusMd),
          ),
        );
      }
    }
  }

  Future<void> _releaseTable(int tableNumber) async {
    try {
      await StaffApiService.releaseTableFromWaiter(
        tableNumber: tableNumber.toString(),
      );
      _loadFloorStatus(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stol #$tableNumber ofitsiantdan bo\'shatildi.'),
            backgroundColor: StaffColors.textSecondaryLight,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: StaffDesign.radiusMd),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xatolik: $e'),
            backgroundColor: StaffColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: StaffDesign.radiusMd),
          ),
        );
      }
    }
  }

  void _openTableDetails(RestaurantTableModel table) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildTableDetailSheet(table),
    );
  }

  void _openTakeOrderSheet(RestaurantTableModel table) async {
    // Bo'sh stolga zakaz olish boshlanganda stol avtomatik shu ofitsiantga belgilanadi
    if (table.assignedWaiterName == null ||
        table.assignedWaiterName != widget.waiter.name) {
      await _assignTable(table.number);
    }
    _openTakeOrderSheetModal(table.number);
  }

  void _openTakeOrderSheetModal(int tableNumber) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WaiterOrderSheet(
        tableNumber: tableNumber,
        waiterName: widget.waiter.name,
        waiterId: widget.waiter.id,
        onOrderCreated: () => _loadFloorStatus(silent: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final occupiedCount = _tables.where((t) => t.isOccupied).length;
    final callsCount = _tables.where((t) => t.call != null).length;

    List<RestaurantTableModel> filteredTables = _tables;
    if (_selectedFilter == 'free') {
      filteredTables = _tables.where((t) => !t.isOccupied).toList();
    } else if (_selectedFilter == 'occupied') {
      filteredTables = _tables.where((t) => t.isOccupied).toList();
    } else if (_selectedFilter == 'calls') {
      filteredTables = _tables.where((t) => t.call != null).toList();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: StaffColors.background(isDark),
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: StaffColors.accent.withValues(alpha: 0.15),
                borderRadius: StaffDesign.radiusSm,
              ),
              child: const Icon(
                Icons.room_service_rounded,
                size: 20,
                color: StaffColors.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.waiter.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: StaffColors.textPrimary(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Ofitsiant Paneli • Restoran Zali',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: StaffColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              StaffThemeController.instance.isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: StaffThemeController.instance.isDarkMode
                  ? Colors.amber
                  : StaffColors.textPrimary(isDark),
              size: 22,
            ),
            tooltip: StaffThemeController.instance.isDarkMode
                ? 'Kunduzgi rejim (Yorug\')'
                : 'Tungi rejim (Qorong\'i)',
            onPressed: () =>
                setState(() => StaffThemeController.instance.toggleTheme()),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: StaffColors.textPrimary(isDark),
              size: 22,
            ),
            onPressed: () => _loadFloorStatus(),
            tooltip: 'Yangilash',
          ),
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: StaffColors.error,
              size: 22,
            ),
            onPressed: widget.onLogout,
            tooltip: 'Chiqish',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Stat cards header (Symmetrical 4-card dashboard)
          Container(
            color: StaffColors.card(isDark),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                _buildStatPill(
                  title: 'Jami',
                  val: '${_tables.length}',
                  color: const Color(0xFF64748B),
                  icon: Icons.table_restaurant_rounded,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildStatPill(
                  title: 'Bo\'sh',
                  val: '${_tables.length - occupiedCount}',
                  color: StaffColors.accent,
                  icon: Icons.check_circle_outline_rounded,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildStatPill(
                  title: 'Band',
                  val: '$occupiedCount',
                  color: StaffColors.warning,
                  icon: Icons.people_alt_outlined,
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildStatPill(
                  title: 'Chaqiruv',
                  val: '$callsCount',
                  color: StaffColors.error,
                  icon: Icons.notifications_active_rounded,
                  isAlert: callsCount > 0,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // Filters row (Symmetrical pill bar)
          Container(
            color: StaffColors.card(isDark),
            padding: const EdgeInsets.only(left: 14, right: 14, bottom: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterTab(
                      'all', 'Barchasi (${_tables.length})', isDark),
                  const SizedBox(width: 8),
                  _buildFilterTab('free',
                      'Bo\'sh (${_tables.length - occupiedCount})', isDark),
                  const SizedBox(width: 8),
                  _buildFilterTab('occupied', 'Band ($occupiedCount)', isDark),
                  const SizedBox(width: 8),
                  _buildFilterTab('calls', 'Chaqiruvlar ($callsCount)', isDark),
                ],
              ),
            ),
          ),

          Divider(
            height: 1,
            thickness: 1,
            color: StaffColors.border(isDark),
          ),

          // Main Floor Grid
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: StaffColors.accent,
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      StaffColors.error.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.error_outline_rounded,
                                  size: 44,
                                  color: StaffColors.error,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: StaffColors.textPrimary(isDark),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _loadFloorStatus(),
                                icon:
                                    const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Qayta urinish'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: StaffColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: StaffDesign.radiusMd,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: StaffColors.accent,
                        onRefresh: () => _loadFloorStatus(),
                        child: GridView.builder(
                          padding: const EdgeInsets.all(14),
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.88,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredTables.length,
                          itemBuilder: (ctx, idx) {
                            return _buildTableCard(filteredTables[idx], isDark);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required String title,
    required String val,
    required Color color,
    required IconData icon,
    required bool isDark,
    bool isAlert = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.14 : 0.08),
          borderRadius: StaffDesign.radiusSm,
          border: Border.all(
            color: isAlert
                ? color
                : (isDark
                    ? color.withValues(alpha: 0.35)
                    : color.withValues(alpha: 0.22)),
            width:
                isAlert ? StaffDesign.borderThick : StaffDesign.borderStandard,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  val,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: color,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color:
                    isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String id, String label, bool isDark) {
    final isSelected = _selectedFilter == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? StaffColors.accent : StaffColors.primary)
              : StaffColors.cardSecondary(isDark),
          borderRadius: StaffDesign.radiusSm,
          border: Border.all(
            color: isSelected ? Colors.transparent : StaffColors.border(isDark),
            width: StaffDesign.borderStandard,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                isSelected ? Colors.white : StaffColors.textSecondary(isDark),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTableCard(RestaurantTableModel table, bool isDark) {
    final isOccupied = table.isOccupied;
    final hasCall = table.call != null;
    final isReady = table.order?.status == 'tayor';

    Color cardBorderColor = StaffColors.border(isDark);
    if (hasCall) {
      cardBorderColor = StaffColors.error;
    } else if (isReady) {
      cardBorderColor = StaffColors.primary;
    }

    return InkWell(
      onTap: () {
        if (!table.isOccupied) {
          _openTakeOrderSheet(table);
        } else {
          _openTableDetails(table);
        }
      },
      borderRadius: StaffDesign.radiusLg,
      child: Container(
        decoration: BoxDecoration(
          color: StaffColors.card(isDark),
          borderRadius: StaffDesign.radiusLg,
          border: Border.all(
            color: cardBorderColor,
            width: (hasCall || isReady)
                ? StaffDesign.borderThick
                : StaffDesign.borderStandard,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Symmetrical Top Row: Table # and Capacity
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: StaffColors.primary,
                      borderRadius: StaffDesign.radiusXs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.table_restaurant_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '#${table.number}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: StaffColors.cardSecondary(isDark),
                      borderRadius: StaffDesign.radiusXs,
                      border: Border.all(
                        color: StaffColors.border(isDark),
                        width: StaffDesign.borderStandard,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 13,
                          color: StaffColors.textSecondary(isDark),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${table.capacity}',
                          style: TextStyle(
                            fontSize: 11,
                            color: StaffColors.textSecondary(isDark),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Waiter Assignment Badge (Symmetrical height and clean quiet styling)
              Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: StaffColors.cardSecondary(isDark),
                  borderRadius: StaffDesign.radiusXs,
                  border: Border.all(
                    color: StaffColors.border(isDark),
                    width: StaffDesign.borderStandard,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      table.assignedWaiterName != null
                          ? Icons.badge_outlined
                          : Icons.person_off_outlined,
                      size: 13,
                      color: table.assignedWaiterName != null
                          ? (table.assignedWaiterName == widget.waiter.name
                              ? StaffColors.primary
                              : StaffColors.textSecondary(isDark))
                          : StaffColors.textMuted(isDark),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        table.assignedWaiterName != null
                            ? (table.assignedWaiterName == widget.waiter.name
                                ? 'Sizning stolingiz'
                                : table.assignedWaiterName!)
                            : 'Biriktirilmagan',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: table.assignedWaiterName != null
                              ? (table.assignedWaiterName == widget.waiter.name
                                  ? (isDark
                                      ? StaffColors.primaryLight
                                      : StaffColors.primary)
                                  : StaffColors.textSecondary(isDark))
                              : StaffColors.textMuted(isDark),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // Active Call Alert OR Status Banner
              if (hasCall) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: StaffColors.error
                        .withValues(alpha: isDark ? 0.20 : 0.10),
                    borderRadius: StaffDesign.radiusXs,
                    border: Border.all(
                      color: StaffColors.error.withValues(alpha: 0.35),
                      width: StaffDesign.borderStandard,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_rounded,
                        size: 13,
                        color: StaffColors.error,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          table.call!.reason,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: StaffColors.error,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isOccupied && table.order != null) ...[
                if (isReady)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: StaffColors.primary
                          .withValues(alpha: isDark ? 0.20 : 0.12),
                      borderRadius: StaffDesign.radiusXs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 12,
                          color: isDark
                              ? StaffColors.primaryLight
                              : StaffColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tayyor • Yetkazing!',
                          style: TextStyle(
                            color: isDark
                                ? StaffColors.primaryLight
                                : StaffColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    '${table.order!.items.length} ta taom buyurtma',
                    style: TextStyle(
                      fontSize: 11,
                      color: StaffColors.textSecondary(isDark),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ] else ...[
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: StaffColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Bo\'sh stol',
                      style: TextStyle(
                        color: isDark
                            ? StaffColors.primaryLight
                            : StaffColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],

              const Spacer(),

              // Symmetrical Bottom Action / Price Bar
              Divider(
                height: 12,
                thickness: 1,
                color: StaffColors.border(isDark),
              ),

              if (isOccupied && table.order != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Jami:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: StaffColors.textMuted(isDark),
                      ),
                    ),
                    Text(
                      '${table.order!.totalAmount.toStringAsFixed(0)} so\'m',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: isDark
                            ? StaffColors.primaryLight
                            : StaffColors.primary,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: StaffColors.primary,
                    borderRadius: StaffDesign.radiusXs,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Buyurtma olish',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableDetailSheet(RestaurantTableModel table) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: StaffColors.card(isDark),
        borderRadius: StaffDesign.radiusSheet,
        border: isDark
            ? Border(
                top: BorderSide(
                    color: StaffColors.border(isDark),
                    width: StaffDesign.borderStandard),
              )
            : null,
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: StaffColors.border(isDark),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Sheet Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (table.isOccupied
                                ? StaffColors.warning
                                : StaffColors.accent)
                            .withValues(alpha: 0.15),
                        borderRadius: StaffDesign.radiusMd,
                      ),
                      child: Icon(
                        Icons.table_restaurant_rounded,
                        color: table.isOccupied
                            ? StaffColors.warning
                            : StaffColors.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stol #${table.number}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: StaffColors.textPrimary(isDark),
                          ),
                        ),
                        Text(
                          table.isOccupied ? 'Band stol' : 'Bo\'sh stol',
                          style: TextStyle(
                            color: table.isOccupied
                                ? StaffColors.warning
                                : StaffColors.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: StaffColors.textSecondary(isDark),
                  ),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: StaffColors.cardSecondary(isDark),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Waiter Info Card (Symmetrical)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: StaffColors.cardSecondary(isDark),
                borderRadius: StaffDesign.radiusMd,
                border: Border.all(
                  color: StaffColors.border(isDark),
                  width: StaffDesign.borderStandard,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    table.assignedWaiterName != null
                        ? Icons.badge_outlined
                        : Icons.person_off_outlined,
                    color: table.assignedWaiterName != null
                        ? StaffColors.accent
                        : StaffColors.warning,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Biriktirilgan ofitsiant:',
                          style: TextStyle(
                            fontSize: 11,
                            color: StaffColors.textSecondary(isDark),
                          ),
                        ),
                        Text(
                          table.assignedWaiterName != null
                              ? '${table.assignedWaiterName} ${table.assignedWaiterName == widget.waiter.name ? "(Siz)" : ""}'
                              : 'Biriktirilmagan (Zakazda avtomatik olinadi)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: StaffColors.textPrimary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (table.assignedWaiterName == null)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StaffColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: StaffDesign.radiusSm),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _assignTable(table.number);
                      },
                      child: const Text('O\'zimga olish',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    )
                  else if (table.assignedWaiterName == widget.waiter.name &&
                      !table.isOccupied)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _releaseTable(table.number);
                      },
                      child: const Text('Bo\'shatish',
                          style: TextStyle(
                              fontSize: 12, color: StaffColors.error)),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Call banner if active
            if (table.call != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: StaffColors.error.withValues(alpha: 0.12),
                  borderRadius: StaffDesign.radiusMd,
                  border: Border.all(
                    color: StaffColors.error.withValues(alpha: 0.3),
                    width: StaffDesign.borderStandard,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded,
                        color: StaffColors.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mehmon chaqiruvi',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: StaffColors.error,
                            ),
                          ),
                          Text(
                            table.call!.reason,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.red.shade200
                                  : Colors.red.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _dismissCall(table.call!.id);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StaffColors.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: StaffDesign.radiusSm),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      child: const Text('Qabul qildim'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Active order details
            if (table.isOccupied && table.order != null) ...[
              Text(
                'Buyurtma tarkibi:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: StaffColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: table.order!.items.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: StaffColors.border(isDark),
                  ),
                  itemBuilder: (ctx, i) {
                    final it = table.order!.items[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${it.quantity}x ${it.name}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: StaffColors.textPrimary(isDark),
                            ),
                          ),
                          Text(
                            '${it.total.toStringAsFixed(0)} so\'m',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: StaffColors.textPrimary(isDark),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Divider(color: StaffColors.border(isDark)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Jami hisob:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: StaffColors.textPrimary(isDark),
                    ),
                  ),
                  Text(
                    '${table.order!.totalAmount.toStringAsFixed(0)} so\'m',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: StaffColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action buttons (Symmetrical styling and heights)
              Row(
                children: [
                  if (table.order!.status == 'tayor') ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _deliverDish(table.order!.id),
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text('Stolga berish'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: StaffColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: StaffDesign.radiusMd),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _requestBill(table.number),
                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                      label: const Text('Hisob so\'rash'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: StaffColors.textPrimary(isDark),
                        side: BorderSide(
                            color: StaffColors.border(isDark),
                            width: StaffDesign.borderStandard),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: StaffDesign.radiusMd),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () {
                      Navigator.pop(context);
                      _openStationReceipts(table);
                    },
                    icon: const Icon(Icons.print_rounded, size: 20),
                    tooltip: 'Bo\'limlar cheklari (Printer)',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(14),
                      backgroundColor: StaffColors.cardSecondary(isDark),
                      foregroundColor: StaffColors.textPrimary(isDark),
                      shape: RoundedRectangleBorder(
                          borderRadius: StaffDesign.radiusMd),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () {
                      Navigator.pop(context);
                      _openTakeOrderSheet(table);
                    },
                    icon: const Icon(Icons.add_rounded, size: 20),
                    tooltip: 'Yana taom qo\'shish',
                    style: IconButton.styleFrom(
                      backgroundColor: StaffColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(
                          borderRadius: StaffDesign.radiusMd),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Free table actions
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: StaffColors.accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.table_restaurant_outlined,
                          size: 48,
                          color: StaffColors.accent,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Stol hozirda bo\'sh',
                        style: TextStyle(
                          color: StaffColors.textSecondary(isDark),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _openTakeOrderSheet(table);
                          },
                          icon: const Icon(Icons.add_shopping_cart_rounded),
                          label: const Text(
                            'Yangi Buyurtma Olish',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: StaffColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: StaffDesign.radiusMd,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openStationReceipts(RestaurantTableModel table) {
    if (table.order == null) return;
    OrderStationsSheet.show(
      context,
      orderId: table.order!.id,
      orderNumber: table.order!.orderNumber,
      tableNumber: table.number.toString(),
      totalAmount: table.order!.totalAmount,
    );
  }
}
