import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:customer_app_flutter/main.dart';
import 'package:customer_app_flutter/services/auth_provider.dart';
import 'package:customer_app_flutter/services/cart_provider.dart';
import 'package:customer_app_flutter/services/theme_provider.dart';

void main() {
  testWidgets('CustomerApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => CartProvider()),
        ],
        child: const CustomerApp(),
      ),
    );
    expect(find.byType(CustomerApp), findsOneWidget);
  });
}
