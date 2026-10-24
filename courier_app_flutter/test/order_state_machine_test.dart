import 'package:flutter_test/flutter_test.dart';
import 'package:courier_app_flutter/core/state_machine/order_state_machine.dart';

void main() {
  group('OrderStateMachine Unit Tests', () {
    test('Courier flow transitions through complete 6-stage lifecycle', () {
      var current = OrderStage.assigned;

      // 1. assigned -> headingToCafe
      expect(OrderStateMachine.canTransition(current, OrderStage.headingToCafe), isTrue);
      OrderStateMachine.validateTransition(current, OrderStage.headingToCafe);
      current = OrderStage.headingToCafe;

      // 2. headingToCafe -> pickedUp
      expect(OrderStateMachine.canTransition(current, OrderStage.pickedUp), isTrue);
      OrderStateMachine.validateTransition(current, OrderStage.pickedUp);
      current = OrderStage.pickedUp;

      // 3. pickedUp -> onTheWay
      expect(OrderStateMachine.canTransition(current, OrderStage.onTheWay), isTrue);
      OrderStateMachine.validateTransition(current, OrderStage.onTheWay);
      current = OrderStage.onTheWay;

      // 4. onTheWay -> arrived
      expect(OrderStateMachine.canTransition(current, OrderStage.arrived), isTrue);
      OrderStateMachine.validateTransition(current, OrderStage.arrived);
      current = OrderStage.arrived;

      // 5. arrived -> delivered
      expect(OrderStateMachine.canTransition(current, OrderStage.delivered), isTrue);
      OrderStateMachine.validateTransition(current, OrderStage.delivered);
      current = OrderStage.delivered;

      // Terminal state: delivered cannot transition to anything
      expect(OrderStateMachine.canTransition(current, OrderStage.assigned), isFalse);
      expect(OrderStateMachine.canTransition(current, OrderStage.onTheWay), isFalse);
    });

    test('Courier can report delivery failure from any active stage', () {
      expect(OrderStateMachine.canTransition(OrderStage.assigned, OrderStage.deliveryFailed), isTrue);
      expect(OrderStateMachine.canTransition(OrderStage.headingToCafe, OrderStage.deliveryFailed), isTrue);
      expect(OrderStateMachine.canTransition(OrderStage.pickedUp, OrderStage.deliveryFailed), isTrue);
      expect(OrderStateMachine.canTransition(OrderStage.onTheWay, OrderStage.deliveryFailed), isTrue);
      expect(OrderStateMachine.canTransition(OrderStage.arrived, OrderStage.deliveryFailed), isTrue);
    });

    test('Waiter lifecycle transitions from created to paid', () {
      var stage = OrderStage.created;

      expect(OrderStateMachine.canTransition(stage, OrderStage.sentToKitchen), isTrue);
      stage = OrderStage.sentToKitchen;

      expect(OrderStateMachine.canTransition(stage, OrderStage.kitchenPreparing), isTrue);
      stage = OrderStage.kitchenPreparing;

      expect(OrderStateMachine.canTransition(stage, OrderStage.kitchenReady), isTrue);
      stage = OrderStage.kitchenReady;

      expect(OrderStateMachine.canTransition(stage, OrderStage.served), isTrue);
      stage = OrderStage.served;

      expect(OrderStateMachine.canTransition(stage, OrderStage.billRequested), isTrue);
      stage = OrderStage.billRequested;

      expect(OrderStateMachine.canTransition(stage, OrderStage.paid), isTrue);
      stage = OrderStage.paid;

      expect(OrderStateMachine.allowedTransitions[stage], isEmpty);
    });

    test('Invalid transitions throw OrderStateTransitionException with proper message', () {
      expect(
        () => OrderStateMachine.validateTransition(OrderStage.assigned, OrderStage.delivered),
        throwsA(isA<OrderStateTransitionException>()),
      );

      expect(
        () => OrderStateMachine.validateTransition(OrderStage.created, OrderStage.paid),
        throwsA(isA<OrderStateTransitionException>()),
      );

      expect(
        () => OrderStateMachine.validateTransition(OrderStage.paid, OrderStage.created),
        throwsA(isA<OrderStateTransitionException>()),
      );
    });

    test('Uzbek Latin labels are correct and formatted', () {
      expect(OrderStateMachine.getStageLabelUz(OrderStage.created), 'Yangi buyurtma');
      expect(OrderStateMachine.getStageLabelUz(OrderStage.sentToKitchen), 'Oshxonaga yuborildi');
      expect(OrderStateMachine.getStageLabelUz(OrderStage.kitchenPreparing), 'Tayyorlanmoqda');
      expect(OrderStateMachine.getStageLabelUz(OrderStage.kitchenReady), 'Dasturxonga tayyor');
      expect(OrderStateMachine.getStageLabelUz(OrderStage.served), 'Tortildi');
      expect(OrderStateMachine.getStageLabelUz(OrderStage.billRequested), 'Hisob soʻralgan');
      expect(OrderStateMachine.getStageLabelUz(OrderStage.paid), 'Toʻlangan');
      expect(OrderStateMachine.getStageLabelUz(OrderStage.cancelled), 'Bekor qilingan');
      expect(OrderStateMachine.getStageLabelUz(OrderStage.headingToCafe), 'Restoranga yoʻlda');
      expect(OrderStateMachine.getStageLabelUz(OrderStage.pickedUp), 'Olib ketildi');
      expect(OrderStateMachine.getStageLabelUz(OrderStage.onTheWay), 'Yetkazishda');
      expect(OrderStateMachine.getStageLabelUz(OrderStage.arrived), 'Yetib kelindi');
      expect(OrderStateMachine.getStageLabelUz(OrderStage.delivered), 'Topshirildi');
      expect(OrderStateMachine.getStageLabelUz(OrderStage.deliveryFailed), 'Muammo yuzaga keldi');
    });
  });
}
