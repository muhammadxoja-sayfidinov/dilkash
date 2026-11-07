import 'package:flutter_test/flutter_test.dart';
import 'package:courier_app_flutter/core/auth/staff_session.dart';
import 'package:courier_app_flutter/core/shift/shift_model.dart';

void main() {
  group('Unified Auth & Simple Shift Model Tests', () {
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
      expect(switchedSession.token, multiRoleSession.token);
    });

    test('ShiftData manages single simple toggle and delivery counts', () {
      const initial = ShiftData(isShiftActive: true);
      expect(initial.isShiftActive, isTrue);

      // End shift toggle
      final shiftEnded = initial.copyWith(isShiftActive: false);
      expect(shiftEnded.isShiftActive, isFalse);

      // Restart shift toggle
      final shiftRestarted = shiftEnded.copyWith(isShiftActive: true);
      expect(shiftRestarted.isShiftActive, isTrue);

      // Record delivery
      final deliveryRecorded = shiftRestarted.copyWith(
        completedOrdersCount: shiftRestarted.completedOrdersCount + 1,
        totalCashCollected: shiftRestarted.totalCashCollected + 55000.0,
      );
      expect(deliveryRecorded.completedOrdersCount, shiftRestarted.completedOrdersCount + 1);
      expect(deliveryRecorded.totalCashCollected, shiftRestarted.totalCashCollected + 55000.0);
    });
  });
}
