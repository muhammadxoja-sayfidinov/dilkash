// Order State Machine for Dilkash Restaurant System
// Handles order lifecycle across Waiter, Kitchen, and Courier with transition validation and audit timestamps.

enum OrderStage {
  // Waiter & Table Order Stages
  created, // Stol ochildi, buyurtma tuzildi
  sentToKitchen, // Oshxona va barga yuborildi
  kitchenPreparing, // Taomlar pishirilmoqda
  kitchenReady, // Oshxona tayyorladi (ofitsiantga signal)
  served, // Dasturxonga tortildi
  billRequested, // Hisob soʻraldi
  paid, // Toʻlandi va stol yopildi
  cancelled, // Bekor qilindi (menejer ruxsati bilan)

  // Courier Delivery Stages
  assigned, // Kuryerga biriktirildi
  headingToCafe, // Kuryer restoranga yoʻl oldi
  pickedUp, // Restorandan qabul qilindi (nazorat roʻyxati tekshirildi)
  onTheWay, // Mijoz manziliga yetkazish yoʻlida
  arrived, // Mijoz eshigi oldiga yetib kelindi
  delivered, // Mijozga topshirildi (tasdiq kodi / rasm)
  deliveryFailed, // Yetkazish muammosi (manzil xato / aloqa yoʻq)
}

class OrderStateTransitionException implements Exception {
  final OrderStage from;
  final OrderStage to;
  final String reason;

  const OrderStateTransitionException(this.from, this.to, this.reason);

  @override
  String toString() =>
      'OrderStateTransitionException: ${from.name} dan ${to.name} ga oʻtib boʻlmaydi: $reason';
}

class OrderStateMachine {
  static const Map<OrderStage, List<OrderStage>> allowedTransitions = {
    // Waiter Flow
    OrderStage.created: [OrderStage.sentToKitchen, OrderStage.cancelled],
    OrderStage.sentToKitchen: [
      OrderStage.kitchenPreparing,
      OrderStage.cancelled
    ],
    OrderStage.kitchenPreparing: [
      OrderStage.kitchenReady,
      OrderStage.cancelled
    ],
    OrderStage.kitchenReady: [OrderStage.served, OrderStage.cancelled],
    OrderStage.served: [OrderStage.billRequested, OrderStage.paid],
    OrderStage.billRequested: [OrderStage.paid],
    OrderStage.paid: [],
    OrderStage.cancelled: [],

    // Courier Flow
    OrderStage.assigned: [OrderStage.headingToCafe, OrderStage.deliveryFailed],
    OrderStage.headingToCafe: [OrderStage.pickedUp, OrderStage.deliveryFailed],
    OrderStage.pickedUp: [OrderStage.onTheWay, OrderStage.deliveryFailed],
    OrderStage.onTheWay: [OrderStage.arrived, OrderStage.deliveryFailed],
    OrderStage.arrived: [OrderStage.delivered, OrderStage.deliveryFailed],
    OrderStage.delivered: [],
    OrderStage.deliveryFailed: [OrderStage.headingToCafe, OrderStage.cancelled],
  };

  static bool canTransition(OrderStage current, OrderStage next) {
    final validNextList = allowedTransitions[current] ?? [];
    return validNextList.contains(next);
  }

  static void validateTransition(OrderStage current, OrderStage next) {
    if (!canTransition(current, next)) {
      throw OrderStateTransitionException(
        current,
        next,
        'Ruxsat berilmagan holat oʻzgarishi',
      );
    }
  }

  static String getStageLabelUz(OrderStage stage) {
    switch (stage) {
      case OrderStage.created:
        return 'Yangi buyurtma';
      case OrderStage.sentToKitchen:
        return 'Oshxonaga yuborildi';
      case OrderStage.kitchenPreparing:
        return 'Tayyorlanmoqda';
      case OrderStage.kitchenReady:
        return 'Dasturxonga tayyor';
      case OrderStage.served:
        return 'Tortildi';
      case OrderStage.billRequested:
        return 'Hisob soʻralgan';
      case OrderStage.paid:
        return 'Toʻlangan';
      case OrderStage.cancelled:
        return 'Bekor qilingan';
      case OrderStage.assigned:
        return 'Biriktirildi';
      case OrderStage.headingToCafe:
        return 'Restoranga yoʻlda';
      case OrderStage.pickedUp:
        return 'Olib ketildi';
      case OrderStage.onTheWay:
        return 'Yetkazishda';
      case OrderStage.arrived:
        return 'Yetib kelindi';
      case OrderStage.delivered:
        return 'Topshirildi';
      case OrderStage.deliveryFailed:
        return 'Muammo yuzaga keldi';
    }
  }
}
