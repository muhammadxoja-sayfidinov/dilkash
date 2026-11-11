// Simplified Staff Repository Interface for Dilkash Restaurant App
// Strictly follows KEEP specifications.

import '../auth/staff_session.dart';
import '../state_machine/order_state_machine.dart';

abstract class StaffRepository {
  Future<StaffSession> authenticate({
    required String phone,
    required String pin,
  });

  // Courier Methods (3 screens)
  Future<List<Map<String, dynamic>>> fetchCourierOrders();
  Future<bool> claimCourierOrder(int orderId);
  Future<bool> updateCourierStage(int orderId, CourierStage stage);
  Future<bool> reportDeliveryProblem({
    required int orderId,
    required String reason,
    String notes,
  });
  Future<Map<String, dynamic>> fetchCourierTodaySummary();

  // Waiter Methods (3 screens)
  Future<List<Map<String, dynamic>>> fetchTables();
  Future<List<Map<String, dynamic>>> fetchMenu();
  Future<Map<String, dynamic>> openTable(String tableNumber);
  Future<Map<String, dynamic>> sendOrderToKitchen({
    required String tableNumber,
    required List<Map<String, dynamic>> items,
    String notes = '',
  });
  Future<bool> cancelOrderItem({
    required String tableNumber,
    required int itemId,
  });
  Future<bool> requestTableBill(String tableNumber);
  Future<bool> dismissWaiterCall(int callId);
  Future<bool> markTableDelivered(int orderId);
  Future<Map<String, dynamic>> settleTableBill({
    required String tableNumber,
    required String paymentMethod,
  });
}
