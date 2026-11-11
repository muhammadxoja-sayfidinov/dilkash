import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:courier_app_flutter/core/auth/auth_notifier.dart';
import 'package:courier_app_flutter/core/auth/staff_session.dart';
import 'package:courier_app_flutter/core/network/mock_staff_repository.dart';
import 'package:courier_app_flutter/features/auth/screens/unified_login_screen.dart';
import 'package:courier_app_flutter/features/auth/screens/role_selection_screen.dart';
import 'package:courier_app_flutter/features/courier/screens/courier_home_screen.dart';
import 'package:courier_app_flutter/features/courier/screens/courier_order_detail_screen.dart';
import 'package:courier_app_flutter/features/courier/screens/courier_today_screen.dart';
import 'package:courier_app_flutter/features/waiter/screens/waiter_tables_screen.dart';
import 'package:courier_app_flutter/features/waiter/screens/waiter_order_entry_screen.dart';
import 'package:courier_app_flutter/features/waiter/screens/waiter_bill_screen.dart';
import 'package:courier_app_flutter/features/common/screens/staff_profile_screen.dart';
import 'package:courier_app_flutter/theme/staff_theme.dart';

final String artifactDir = Platform.environment['ARTIFACT_DIR'] ?? Directory.systemTemp.path;

Future<void> loadFonts() async {
  try {
    final robotoFile = File('C:/src/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf');
    if (robotoFile.existsSync()) {
      final robotoBytes = robotoFile.readAsBytesSync();
      final fontLoader = FontLoader('Roboto')..addFont(Future.value(ByteData.view(robotoBytes.buffer)));
      await fontLoader.load();
    }

    final iconFile = File('C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (iconFile.existsSync()) {
      final iconBytes = iconFile.readAsBytesSync();
      final iconLoader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(iconBytes.buffer)));
      await iconLoader.load();
    }
  } catch (_) {}
}

Future<void> captureScreen(WidgetTester tester, String filename) async {
  try {
    final boundaryFinder = find.byKey(const ValueKey('screenshot_boundary'));
    final RenderRepaintBoundary boundary =
        tester.renderObject(boundaryFinder) as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2.5));
    final byteData = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
    final pngBytes = byteData!.buffer.asUint8List();
    final dir = Directory(artifactDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File('$artifactDir/$filename');
    file.writeAsBytesSync(pngBytes);
  } catch (_) {}
}

Widget wrapScreen(Widget child, {StaffSession? session}) {
  return RepaintBoundary(
    key: const ValueKey('screenshot_boundary'),
    child: ProviderScope(
      overrides: [
        staffRepositoryProvider.overrideWithValue(MockStaffRepository.instance),
        if (session != null)
          authProvider.overrideWith(() => _StaticAuthNotifier(session)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: StaffTheme.lightTheme.copyWith(
          textTheme: Typography.material2021().black.apply(fontFamily: 'Roboto'),
        ),
        home: child,
      ),
    ),
  );
}

class _StaticAuthNotifier extends AuthNotifier {
  final StaffSession _session;
  _StaticAuthNotifier(this._session);

  @override
  AsyncValue<StaffSession?> build() => AsyncValue.data(_session);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadFonts();
  });

  const courierSession = StaffSession(
    id: 1,
    name: 'Jasur Rahimov',
    phone: '+998901234567',
    staffCode: 'DIL-101',
    token: 'tok_123',
    assignedRoles: ['courier', 'waiter'],
    activeRole: 'courier',
    vehicleInfo: 'Honda Dio Scooter',
  );

  const waiterSession = StaffSession(
    id: 3,
    name: 'Malika Karimova',
    phone: '+998977778899',
    staffCode: 'DIL-303',
    token: 'tok_456',
    assignedRoles: ['waiter'],
    activeRole: 'waiter',
  );

  group('Radically Simplified Staff App - Capture Real Screenshots', () {
    testWidgets('01 - Login', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapScreen(const UnifiedLoginScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await captureScreen(tester, 'screen_01_login.png');
    });

    testWidgets('02 - Role Selection', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapScreen(const RoleSelectionScreen(), session: courierSession));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await captureScreen(tester, 'screen_02_role_select.png');
    });

    testWidgets('03 - Courier Orders Screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapScreen(const CourierHomeScreen(), session: courierSession));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await captureScreen(tester, 'screen_03_courier_orders.png');
    });

    testWidgets('04 - Courier Order Detail Screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapScreen(const CourierOrderDetailScreen(orderId: 177), session: courierSession));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await captureScreen(tester, 'screen_04_courier_order_detail.png');
    });

    testWidgets('05 - Courier Today Screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapScreen(const CourierTodayScreen(), session: courierSession));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await captureScreen(tester, 'screen_05_courier_today.png');
    });

    testWidgets('06 - Waiter Tables Screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapScreen(const WaiterTablesScreen(), session: waiterSession));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await captureScreen(tester, 'screen_06_waiter_tables.png');
    });

    testWidgets('07 - Waiter Order Entry Screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapScreen(const WaiterOrderEntryScreen(tableNumber: 'T-01'), session: waiterSession));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await captureScreen(tester, 'screen_07_waiter_order.png');
    });

    testWidgets('08 - Waiter Bill Screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapScreen(const WaiterBillScreen(tableNumber: 'T-01'), session: waiterSession));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await captureScreen(tester, 'screen_08_waiter_bill.png');
    });

    testWidgets('09 - Staff Profile Screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapScreen(const StaffProfileScreen(), session: courierSession));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await captureScreen(tester, 'screen_09_staff_profile.png');
    });
  });
}
