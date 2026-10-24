import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:courier_app_flutter/main.dart';

void main() {
  testWidgets('CourierApp smoke test with Riverpod ProviderScope',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: StaffApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(StaffApp), findsOneWidget);
  });
}
