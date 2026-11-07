import 'package:flutter_test/flutter_test.dart';
import 'package:courier_app_flutter/core/state_machine/order_state_machine.dart';

void main() {
  group('Simplified OrderStateMachine Tests', () {
    test('Courier flow moves sequentially: assigned -> accepted -> pickedUp -> delivered', () {
      expect(OrderStateMachine.nextCourierStage[CourierStage.assigned], CourierStage.accepted);
      expect(OrderStateMachine.nextCourierStage[CourierStage.accepted], CourierStage.pickedUp);
      expect(OrderStateMachine.nextCourierStage[CourierStage.pickedUp], CourierStage.delivered);
      expect(OrderStateMachine.nextCourierStage[CourierStage.delivered], isNull);
    });

    test('Courier next button labels match single primary action specification', () {
      expect(OrderStateMachine.courierNextButtonLabel(CourierStage.assigned), 'Qabul qilish');
      expect(OrderStateMachine.courierNextButtonLabel(CourierStage.accepted), 'Olib oldim');
      expect(OrderStateMachine.courierNextButtonLabel(CourierStage.pickedUp), 'Yetkazildi');
    });

    test('Table stages support ONLY 4 statuses', () {
      expect(TableStage.values.length, 4);
      expect(OrderStateMachine.tableStageLabel(TableStage.free), 'Bo’sh');
      expect(OrderStateMachine.tableStageLabel(TableStage.occupied), 'Band');
      expect(OrderStateMachine.tableStageLabel(TableStage.ready), 'Dasturxonga tayyor');
      expect(OrderStateMachine.tableStageLabel(TableStage.billRequested), 'Hisob so’ralgan');
    });

    test('Courier stage labels in correct Uzbek Latin', () {
      expect(OrderStateMachine.courierStageLabel(CourierStage.assigned), 'Yangi buyurtma');
      expect(OrderStateMachine.courierStageLabel(CourierStage.accepted), 'Qabul qilindi');
      expect(OrderStateMachine.courierStageLabel(CourierStage.pickedUp), 'Olib oldim');
      expect(OrderStateMachine.courierStageLabel(CourierStage.delivered), 'Yetkazildi');
      expect(OrderStateMachine.courierStageLabel(CourierStage.problem), 'Muammo mavjud');
      expect(OrderStateMachine.courierStageLabel(CourierStage.cancelled), 'Bekor qilingan');
    });
  });
}
