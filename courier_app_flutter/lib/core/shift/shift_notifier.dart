// Shift Notifier for Dilkash Staff App
// One simple toggle to start/end shift.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shift_model.dart';

final shiftProvider =
    NotifierProvider<ShiftNotifier, ShiftData>(ShiftNotifier.new);

class ShiftNotifier extends Notifier<ShiftData> {
  @override
  ShiftData build() {
    return ShiftData(
      isShiftActive: true,
      startedAt: DateTime.now().subtract(const Duration(hours: 4, minutes: 15)),
      completedOrdersCount: 6,
      totalCashCollected: 185000.0,
    );
  }

  void toggleShift() {
    state = state.copyWith(
      isShiftActive: !state.isShiftActive,
      startedAt: !state.isShiftActive ? DateTime.now() : null,
    );
  }

  void recordDelivery({required double cashCollected}) {
    state = state.copyWith(
      completedOrdersCount: state.completedOrdersCount + 1,
      totalCashCollected: state.totalCashCollected + cashCollected,
    );
  }
}
