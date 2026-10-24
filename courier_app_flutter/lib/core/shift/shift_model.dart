// Shift Data Model for Dilkash Staff App
// Manages clock in/out, break timers, and shift statistics.

enum ShiftStatus {
  clockedOut,
  clockedIn,
  onBreak,
}

class ShiftData {
  final ShiftStatus status;
  final DateTime? clockedInAt;
  final DateTime? breakStartedAt;
  final Duration totalBreakDuration;
  final int completedOrdersCount;
  final double totalCashCollected;
  final double totalEarnings;
  final double totalTips;

  const ShiftData({
    this.status = ShiftStatus.clockedOut,
    this.clockedInAt,
    this.breakStartedAt,
    this.totalBreakDuration = Duration.zero,
    this.completedOrdersCount = 0,
    this.totalCashCollected = 0.0,
    this.totalEarnings = 0.0,
    this.totalTips = 0.0,
  });

  bool get isActive => status == ShiftStatus.clockedIn;
  bool get isOnBreak => status == ShiftStatus.onBreak;
  bool get isClockedOut => status == ShiftStatus.clockedOut;

  Duration get activeDuration {
    if (clockedInAt == null) return Duration.zero;
    final now = DateTime.now();
    final totalElapsed = now.difference(clockedInAt!);
    final active = totalElapsed - totalBreakDuration;
    return active.isNegative ? Duration.zero : active;
  }

  String get formattedDuration {
    final d = activeDuration;
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  ShiftData copyWith({
    ShiftStatus? status,
    DateTime? clockedInAt,
    DateTime? breakStartedAt,
    Duration? totalBreakDuration,
    int? completedOrdersCount,
    double? totalCashCollected,
    double? totalEarnings,
    double? totalTips,
  }) {
    return ShiftData(
      status: status ?? this.status,
      clockedInAt: clockedInAt ?? this.clockedInAt,
      breakStartedAt: breakStartedAt ?? this.breakStartedAt,
      totalBreakDuration: totalBreakDuration ?? this.totalBreakDuration,
      completedOrdersCount:
          completedOrdersCount ?? this.completedOrdersCount,
      totalCashCollected: totalCashCollected ?? this.totalCashCollected,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      totalTips: totalTips ?? this.totalTips,
    );
  }
}
