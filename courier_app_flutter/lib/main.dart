import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/navigation/app_router.dart';
import 'theme/staff_theme.dart';

typedef CourierApp = StaffApp;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: StaffApp()));
}

class StaffApp extends ConsumerWidget {
  const StaffApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return ListenableBuilder(
      listenable: StaffThemeController.instance,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'Dilkash Xodimlar Ilovasi (Kuryer & Ofitsiant)',
          debugShowCheckedModeBanner: false,
          theme: StaffTheme.lightTheme,
          darkTheme: StaffTheme.darkTheme,
          themeMode: StaffThemeController.instance.themeMode,
          routerConfig: router,
        );
      },
    );
  }
}
