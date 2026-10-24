import 'package:flutter_test/flutter_test.dart';
import 'package:courier_app_flutter/main.dart';

void main() {
  testWidgets('CourierApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CourierApp());
  });
}
