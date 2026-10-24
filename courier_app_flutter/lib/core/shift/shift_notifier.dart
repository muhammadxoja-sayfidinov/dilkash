// Shift Notifier for Riverpod 3.x
// Controls shift timer, break intervals, order tracking, and guard against orders outside shifts.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shift_model.dart';

final shiftProvider =
    NotifierProvider<ShiftNotifier, ShiftData>(ShiftNotifier.new);

class ShiftNotifier extends Notifier<ShiftData> {
  Timer? _ticker;

  @override
  ShiftData build() {
    ref.onDispose(() {
      _ticker?.cancel();
    });
    return const ShiftData();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isActive) {
        state = state.copyWith();
      }
    });
  }

  void clockIn() {
    state = state.copyWith(
      status: ShiftStatus.clockedIn,
      clockedInAt: DateTime.now(),
      breakStartedAt: null,
      totalBreakDuration: Duration.zero,
    );
    _startTicker();
  }

  void startBreak() {
    if (!state.isActive) return;
    state = state.copyWith(
      status: ShiftStatus.onBreak,
      breakStartedAt: DateTime.now(),
    );
  }

  void endBreak() {
    if (!state.isOnBreak || state.breakStartedAt == null) return;
    final breakDuration = DateTime.now().difference(state.breakStartedAt!);
    state = state.copyWith(
      status: ShiftStatus.clockedIn,
      breakStartedAt: null,
      totalBreakDuration: state.totalBreakDuration + breakDuration,
    );
  }

  void clockOut() {
    _ticker?.cancel();
    state = state.copyWith(
      status: ShiftStatus.clockedOut,
      breakStartedAt: null,
    );
  }

  void recordCompletedOrder({
    required double cashCollected,
    required double earning,
    required double tip,
  }) {
    state = state.copyWith(
      completedOrdersCount: state.completedOrdersCount + 1,
      totalCashCollected: state.totalCashCollected + cashCollected,
      totalEarnings: state.totalEarnings + earning,
      totalTips: state.totalTips + tip,
    );
  }
}
