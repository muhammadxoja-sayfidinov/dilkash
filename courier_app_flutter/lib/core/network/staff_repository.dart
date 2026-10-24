// Staff Repository Interface for Dilkash Restaurant App
// Provides unified data contracts for Courier, Waiter, and Kitchen operations.

import '../auth/staff_session.dart';
import '../state_machine/order_state_machine.dart';

abstract class StaffRepository {
  Future<StaffSession> authenticate({
    String? phone,
    String? staffCode,
    required String pin,
  });

  // Courier methods
  Future<List<Map<String, dynamic>>> fetchCourierOrders(String token);
  Future<List<Map<String, dynamic>>> fetchAvailablePoolOrders();
  Future<bool> claimCourierOrder(int orderId, String token);
  Future<bool> updateCourierOrderStatus({
    required int orderId,
    required OrderStage stage,
    required String token,
    Map<String, dynamic>? metadata,
  });
  Future<bool> reportDeliveryProblem({
    required int orderId,
    required String reason,
    required String notes,
    String? photoUrl,
  });
  Future<Map<String, dynamic>> submitCashHandover({
    required double expectedAmount,
    required double actualAmount,
    required String cashierPin,
    required String notes,
  });

  // Waiter methods
  Future<List<Map<String, dynamic>>> fetchFloorTables();
  Future<List<Map<String, dynamic>>> fetchMenuCategories();
  Future<Map<String, dynamic>> openTable({
    required String tableNumber,
    required int guestCount,
    required String waiterName,
  });
  Future<Map<String, dynamic>> sendOrderToKitchen({
    required String tableNumber,
    required String waiterName,
    required List<Map<String, dynamic>> items,
    String courseTiming = 'together', // 'starters_first', 'together'
    String notes = '',
  });
  Future<bool> transferTable({
    required String fromTable,
    required String toTable,
    required String waiterName,
  });
  Future<bool> mergeTables({
    required String primaryTable,
    required String secondaryTable,
  });
  Future<bool> cancelOrderItem({
    required int orderId,
    required int itemId,
    required String reason,
    required String managerPin,
  });
  Future<Map<String, dynamic>> settleTableBill({
    required String tableNumber,
    required String paymentMethod, // 'cash', 'card', 'click', 'payme'
    required double totalAmount,
    double discountPercent = 0.0,
    double tipAmount = 0.0,
    String? managerPinForDiscount,
  });
  Future<bool> dismissWaiterCall(int callId);
  Future<List<Map<String, dynamic>>> fetchTodayReservations();
  Future<bool> markReservationArrived(int reservationId, String assignedTable);
}
