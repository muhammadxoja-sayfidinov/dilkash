import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/auth_provider.dart';
import 'services/cart_provider.dart';
import 'services/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/order_tracking_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const CustomerApp(),
    ),
  );
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Restoran Dastavka & Olib ketish',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const CustomerSplashScreen(),
      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri != null) {
          final segments = uri.pathSegments;
          if (segments.isNotEmpty && segments.contains('order')) {
            final idx = segments.indexOf('order');
            if (idx + 1 < segments.length) {
              final idStr = segments[idx + 1];
              final orderId = int.tryParse(idStr) ?? 0;
              if (orderId > 0) {
                return MaterialPageRoute(
                  builder: (_) => OrderTrackingScreen(
                    orderId: orderId,
                    orderNumber: '$orderId',
                  ),
                );
              }
            }
          }
        }
        return null;
      },
    );
  }
}
