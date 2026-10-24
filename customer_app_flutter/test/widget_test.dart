import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app_flutter/main.dart';

void main() {
  testWidgets('CustomerApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CustomerApp());
  });
}
