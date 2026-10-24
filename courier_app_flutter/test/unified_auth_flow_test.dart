import 'package:flutter_test/flutter_test.dart';
import 'package:courier_app_flutter/core/auth/staff_session.dart';
import 'package:courier_app_flutter/core/shift/shift_model.dart';

void main() {
  group('Unified Auth & Shift Model Tests', () {
    test('StaffSession verifies backend assigned roles correctly', () {
      // Single role employee (Courier only)
      const courierSession = StaffSession(
        id: 1,
        name: 'Bobur Aliyev',
        phone: '+998901234567',
        staffCode: 'CR-101',
        token: 'token_abc_1',
        assignedRoles: ['courier'],
        activeRole: 'courier',
        vehicleInfo: 'Honda Dio Scooter',
      );

      expect(courierSession.hasMultipleRoles, isFalse);
      expect(courierSession.canActAsCourier, isTrue);
      expect(courierSession.canActAsWaiter, isFalse);
      expect(courierSession.isCourier, isTrue);
      expect(courierSession.isWaiter, isFalse);

      // Multi-role employee (Both Courier & Waiter)
      const multiRoleSession = StaffSession(
        id: 3,
        name: 'Sardor Rustamov',
        phone: '+998939990011',
        staffCode: 'ST-303',
        token: 'token_xyz_3',
        assignedRoles: ['courier', 'waiter'],
        activeRole: 'waiter',
      );

      expect(multiRoleSession.hasMultipleRoles, isTrue);
      expect(multiRoleSession.canActAsCourier, isTrue);
      expect(multiRoleSession.canActAsWaiter, isTrue);
      expect(multiRoleSession.isCourier, isFalse);
      expect(multiRoleSession.isWaiter, isTrue);

      // Role switching without logout
      final switchedSession = multiRoleSession.copyWith(activeRole: 'courier');
      expect(switchedSession.isCourier, isTrue);
      expect(switchedSession.isWaiter, isFalse);
      expect(switchedSession.token, multiRoleSession.token); // Preserves auth token
    });

    test('ShiftData handles clock-in, break, and resume states', () {
      const initial = ShiftData();
      expect(initial.isClockedOut, isTrue);
      expect(initial.isActive, isFalse);
      expect(initial.isOnBreak, isFalse);

      // Clock In
      final clockInTime = DateTime.now().subtract(const Duration(hours: 2));
      final clockedIn = initial.copyWith(
        status: ShiftStatus.clockedIn,
        clockedInAt: clockInTime,
      );
      expect(clockedIn.isActive, isTrue);
      expect(clockedIn.isClockedOut, isFalse);
      expect(clockedIn.activeDuration.inMinutes >= 119, isTrue);

      // Start Break
      final onBreak = clockedIn.copyWith(
        status: ShiftStatus.onBreak,
        breakStartedAt: DateTime.now(),
      );
      expect(onBreak.isOnBreak, isTrue);
      expect(onBreak.isActive, isFalse);

      // Resume from Break with 15 min accumulated break duration
      final resumed = onBreak.copyWith(
        status: ShiftStatus.clockedIn,
        breakStartedAt: null,
        totalBreakDuration: const Duration(minutes: 15),
      );
      expect(resumed.isActive, isTrue);
      expect(resumed.totalBreakDuration.inMinutes, 15);

      // Clock out
      final clockedOut = resumed.copyWith(
        status: ShiftStatus.clockedOut,
      );
      expect(clockedOut.isClockedOut, isTrue);
    });
  });
}
