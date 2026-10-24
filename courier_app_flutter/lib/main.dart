import 'package:flutter/material.dart';
import 'screens/staff_login_screen.dart';
import 'theme/staff_theme.dart';

typedef CourierApp = StaffApp;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StaffApp());
}

class StaffApp extends StatelessWidget {
  const StaffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StaffThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Restoran Xodimlar Ilovasi (Kuryer & Ofitsiant)',
          debugShowCheckedModeBanner: false,
          theme: StaffTheme.lightTheme,
          darkTheme: StaffTheme.darkTheme,
          themeMode: StaffThemeController.instance.themeMode,
          home: const StaffLoginScreen(),
        );
      },
    );
  }
}
