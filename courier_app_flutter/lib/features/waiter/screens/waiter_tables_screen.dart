// Screen 1: Waiter Tables Screen
// Strictly follows KEEP:
// - Grid of tables with ONLY 4 colors:
//   1. Free (bo’sh)
//   2. Occupied (band)
//   3. Ready to serve (dasturxonga tayyor)
//   4. Bill requested (hisob so’ralgan)
// - Tap a table to open it
// - Push + sound notification when kitchen marks something ready

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/auth/auth_notifier.dart';
import '../../../core/config/app_config.dart';
import '../../../core/state_machine/order_state_machine.dart';

class WaiterTablesScreen extends ConsumerStatefulWidget {
  const WaiterTablesScreen({super.key});

  @override
  ConsumerState<WaiterTablesScreen> createState() => _WaiterTablesScreenState();
}

class _WaiterTablesScreenState extends ConsumerState<WaiterTablesScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _tables = [];
  final Map<String, String> _previousStages = {};
  final Set<int> _seenCallIds = {};
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchTables();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _fetchTables(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTables({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final repo = ref.read(staffRepositoryProvider);
      final list = await repo.fetchTables();
      final newlyReadyTables = <String>[];
      final activeCallIdsNow = <int>{};
      Map<String, dynamic>? newlyArrivedCall;

      for (final t in list) {
        final key = (t['table_number'] ?? '').toString();
        final nextStage = (t['status'] ?? 'free').toString();
        final prevStage = _previousStages[key];
        if (prevStage != null && prevStage != 'ready' && nextStage == 'ready') {
          newlyReadyTables.add((t['name'] ?? 'Stol #$key').toString());
        }
        _previousStages[key] = nextStage;

        final call = t['call'] as Map<String, dynamic>?;
        final callId = (call?['id'] as num?)?.toInt();
        if (call != null && callId != null) {
          activeCallIdsNow.add(callId);
          if (!_seenCallIds.contains(callId)) {
            _seenCallIds.add(callId);
            newlyArrivedCall = {
              'id': callId,
              'table_name': (t['name'] ?? 'Stol #$key').toString(),
              'reason': (call['reason'] ?? 'Ofitsiant chaqirildi').toString(),
            };
          }
        }
      }
      _seenCallIds.retainAll(activeCallIdsNow);

      if (mounted) {
        setState(() {
          _tables = list;
          _isLoading = false;
        });
        if (newlyReadyTables.isNotEmpty) {
          _showKitchenReadyAlert(newlyReadyTables.join(', '));
        } else if (newlyArrivedCall != null) {
          _showWaiterCallAlert(
            callId: newlyArrivedCall['id'] as int,
            tableLabel: newlyArrivedCall['table_name'] as String,
            reason: newlyArrivedCall['reason'] as String,
          );
        }
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

  void _showWaiterCallAlert({
    required int callId,
    required String tableLabel,
    required String reason,
  }) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFB45309),
        duration: const Duration(seconds: 7),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QR Chaqiruv: $tableLabel',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            Text(
              reason,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Qabul qildim',
          textColor: Colors.white,
          onPressed: () => _dismissCall(callId),
        ),
      ),
    );
  }

  Future<void> _dismissCall(int callId) async {
    try {
      await ref.read(staffRepositoryProvider).dismissWaiterCall(callId);
      if (mounted) {
        DilkashFeedback.showSuccess(context, 'Chaqiruv qabul qilindi');
        _fetchTables(silent: true);
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

  void _showKitchenReadyAlert(String tableLabel) {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F172A),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DilkashColors.success,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.soup_kitchen_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Oshxona tayyorladi! ($tableLabel)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                  const Text(
                    'Buyurtma dasturxonga olib chiqishga tayyor',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTableColor(TableStage stage) {
    switch (stage) {
      case TableStage.free:
        return const Color(0xFFF1F5F9); // Bo’sh (Neytral Slate)
      case TableStage.occupied:
        return const Color(0xFFEFF6FF); // Band (Ko’k)
      case TableStage.ready:
        return const Color(0xFFDCFCE7); // Dasturxonga tayyor (Yashil)
      case TableStage.billRequested:
        return const Color(0xFFFEF3C7); // Hisob so’ralgan (Sariq/Olovrang)
    }
  }

  Color _getTableBorderColor(TableStage stage) {
    switch (stage) {
      case TableStage.free:
        return const Color(0xFFCBD5E1);
      case TableStage.occupied:
        return const Color(0xFF3B82F6);
      case TableStage.ready:
        return DilkashColors.success;
      case TableStage.billRequested:
        return const Color(0xFFD97706);
    }
  }

  Color _getTableTextColor(TableStage stage) {
    switch (stage) {
      case TableStage.free:
        return DilkashColors.textSecondaryLight;
      case TableStage.occupied:
        return const Color(0xFF1D4ED8);
      case TableStage.ready:
        return const Color(0xFF15803D);
      case TableStage.billRequested:
        return const Color(0xFFB45309);
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
                Text(_error!, style: DilkashTypography.bodyLarge),
                const SizedBox(height: DilkashSpacing.lg),
                ElevatedButton(
                  onPressed: () => _fetchTables(),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: DilkashColors.primary500),
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
          'Stollar zali',
          style: DilkashTypography.h3.copyWith(
            fontWeight: FontWeight.w700,
            color: DilkashColors.textPrimaryLight,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Yangilash',
            icon: const Icon(Icons.refresh_rounded,
                color: DilkashColors.primary500),
            onPressed: () => _fetchTables(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Legend of exactly 4 colors (fit evenly across all device widths)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: DilkashSpacing.md,
                vertical: DilkashSpacing.sm + 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem(TableStage.free),
                  _buildLegendItem(TableStage.occupied),
                  _buildLegendItem(TableStage.ready),
                  _buildLegendItem(TableStage.billRequested),
                ],
              ),
            ),
            const Divider(height: 1),
            Container(
              width: double.infinity,
              color: AppConfig.isLocalPosMode
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFF0F9FF),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    AppConfig.isLocalPosMode ? Icons.wifi_rounded : Icons.cloud_done_outlined,
                    size: 15,
                    color: AppConfig.isLocalPosMode
                        ? const Color(0xFF047857)
                        : const Color(0xFF0369A1),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      AppConfig.isLocalPosMode
                          ? 'Wi-Fi POS: ${AppConfig.posLocalBaseUrl.replaceFirst('http://', '')}'
                          : 'Cloud: ${AppConfig.cloudBaseUrl}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppConfig.isLocalPosMode
                            ? const Color(0xFF065F46)
                            : const Color(0xFF0C4A6E),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Grid of Tables
            Expanded(
              child: RefreshIndicator(
                color: DilkashColors.primary500,
                onRefresh: () => _fetchTables(),
                child: GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    DilkashSpacing.lg,
                    DilkashSpacing.lg,
                    DilkashSpacing.lg,
                    100,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: DilkashSpacing.md,
                    mainAxisSpacing: DilkashSpacing.md,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _tables.length,
                  itemBuilder: (context, index) {
                    final t = _tables[index];
                    final tableNum = (t['table_number'] ?? '${index + 1}').toString();
                    final tableLabel = (t['name'] ?? 'Stol #$tableNum').toString();
                    final stageName = t['status'] ?? 'free';
                    final stage = TableStage.values.firstWhere(
                      (s) => s.name == stageName,
                      orElse: () => TableStage.free,
                    );
                    final guestCount = (t['guest_count'] as num?)?.toInt() ?? 0;
                    final total = (t['total_amount'] as num?)?.toDouble() ?? 0.0;
                    final callInfo = t['call'] as Map<String, dynamic>?;

                    final cardBg = _getTableColor(stage);
                    final borderColor = _getTableBorderColor(stage);
                    final textColor = _getTableTextColor(stage);

                    return Material(
                      color: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DilkashRadii.md),
                        side: BorderSide(color: borderColor, width: 1.5),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(DilkashRadii.md),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          // Tap a table to open it: opens Order screen
                          context.push('/waiter/order/$tableNum').then((_) {
                            _fetchTables(silent: true);
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(DilkashSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Table Number & Status Label
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      tableLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: DilkashTypography.h2.copyWith(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: DilkashColors.textPrimaryLight,
                                      ),
                                    ),
                                  ),
                                  if (guestCount > 0)
                                    Row(
                                      children: [
                                        Icon(Icons.people_outline_rounded,
                                            size: 16, color: textColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$guestCount',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),

                              // Table State Label (+ Call indicator if customer pressed Waiter/Bill)
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      OrderStateMachine.tableStageLabel(stage),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  if (callInfo != null)
                                    InkWell(
                                      onTap: () {
                                        final cid = (callInfo['id'] as num?)?.toInt();
                                        if (cid != null) {
                                          _dismissCall(cid);
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.notifications_active_rounded,
                                              size: 14,
                                              color: DilkashColors.error,
                                            ),
                                            SizedBox(width: 3),
                                            Text(
                                              'OK',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: DilkashColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              // Total amount or "Bo’sh"
                              Text(
                                stage == TableStage.free
                                    ? 'Ochish uchun bosing'
                                    : UzbekFormatters.formatCurrency(total),
                                style: TextStyle(
                                  fontSize: stage == TableStage.free ? 12 : 16,
                                  fontWeight: FontWeight.w800,
                                  color: stage == TableStage.free
                                      ? DilkashColors.textMutedLight
                                      : DilkashColors.textPrimaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(TableStage stage) {
    String label;
    switch (stage) {
      case TableStage.free:
        label = 'Bo’sh';
        break;
      case TableStage.occupied:
        label = 'Band';
        break;
      case TableStage.ready:
        label = 'Tayyor';
        break;
      case TableStage.billRequested:
        label = 'Hisob';
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _getTableBorderColor(stage),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: DilkashTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: DilkashColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }
}
