// Simplified Order & Table State Machine for Dilkash Staff App
// Strictly follows KEEP specifications.

enum CourierStage {
  assigned, // Yangi buyurtma (one-tap "Qabul qilish")
  accepted, // Qabul qilindi
  pickedUp, // Olib oldim
  delivered, // Yetkazildi
  problem, // Muammo xabari berildi
  cancelled, // Bekor qilingan
}

enum TableStage {
  free, // Bo’sh (yashil/neytral)
  occupied, // Band (ko’k)
  ready, // Dasturxonga tayyor (yorqin yashil)
  billRequested, // Hisob so’ralgan (sariq/olovrang)
}

class OrderStateMachine {
  static const Map<CourierStage, CourierStage?> nextCourierStage = {
    CourierStage.assigned: CourierStage.accepted,
    CourierStage.accepted: CourierStage.pickedUp,
    CourierStage.pickedUp: CourierStage.delivered,
    CourierStage.delivered: null,
    CourierStage.problem: null,
    CourierStage.cancelled: null,
  };

  static String courierStageLabel(CourierStage stage) {
    switch (stage) {
      case CourierStage.assigned:
        return 'Yangi buyurtma';
      case CourierStage.accepted:
        return 'Qabul qilindi';
      case CourierStage.pickedUp:
        return 'Olib oldim';
      case CourierStage.delivered:
        return 'Yetkazildi';
      case CourierStage.problem:
        return 'Muammo mavjud';
      case CourierStage.cancelled:
        return 'Bekor qilingan';
    }
  }

  static String courierNextButtonLabel(CourierStage stage) {
    switch (stage) {
      case CourierStage.assigned:
        return 'Qabul qilish';
      case CourierStage.accepted:
        return 'Olib oldim';
      case CourierStage.pickedUp:
        return 'Yetkazildi';
      default:
        return 'Tugatilgan';
    }
  }

  static String tableStageLabel(TableStage stage) {
    switch (stage) {
      case TableStage.free:
        return 'Bo’sh';
      case TableStage.occupied:
        return 'Band';
      case TableStage.ready:
        return 'Dasturxonga tayyor';
      case TableStage.billRequested:
        return 'Hisob so’ralgan';
    }
  }
}
