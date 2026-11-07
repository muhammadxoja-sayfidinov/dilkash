// Simple Shift Model for Dilkash Staff App
// One clean toggle for start/end shift.

class ShiftData {
  final bool isShiftActive;
  final DateTime? startedAt;
  final int completedOrdersCount;
  final double totalCashCollected;

  const ShiftData({
    this.isShiftActive = true,
    this.startedAt,
    this.completedOrdersCount = 8,
    this.totalCashCollected = 245000.0,
  });

  ShiftData copyWith({
    bool? isShiftActive,
    DateTime? startedAt,
    int? completedOrdersCount,
    double? totalCashCollected,
  }) {
    return ShiftData(
      isShiftActive: isShiftActive ?? this.isShiftActive,
      startedAt: startedAt ?? this.startedAt,
      completedOrdersCount:
          completedOrdersCount ?? this.completedOrdersCount,
      totalCashCollected: totalCashCollected ?? this.totalCashCollected,
    );
  }
}
