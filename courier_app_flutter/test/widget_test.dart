import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:courier_app_flutter/core/auth/auth_notifier.dart';
import 'package:courier_app_flutter/core/network/mock_staff_repository.dart';
import 'package:courier_app_flutter/main.dart';

void main() {
  testWidgets('CourierApp smoke test with Riverpod ProviderScope',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          staffRepositoryProvider.overrideWithValue(MockStaffRepository.instance),
        ],
        child: const StaffApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(StaffApp), findsOneWidget);
  });
}
