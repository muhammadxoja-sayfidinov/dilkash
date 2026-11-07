// Simplified go_router configuration for Dilkash Staff App
// Strictly follows KEEP: Courier (3 screens), Waiter (3 screens), Common (Login, Role, Profile)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_notifier.dart';
import '../../features/auth/screens/unified_login_screen.dart';
import '../../features/auth/screens/role_selection_screen.dart';
import '../../features/courier/screens/courier_home_screen.dart';
import '../../features/courier/screens/courier_order_detail_screen.dart';
import '../../features/waiter/screens/waiter_floor_screen_v2.dart';
import '../../features/waiter/screens/waiter_order_entry_screen.dart';
import '../../features/waiter/screens/waiter_bill_screen.dart';
import '../../features/common/screens/staff_profile_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final session = authState.value;
      final isLoggingIn = state.uri.path == '/login';

      if (session == null) {
        return isLoggingIn ? null : '/login';
      }

      // If logged in and on login route, redirect to role home
      if (isLoggingIn) {
        if (session.assignedRoles.length > 1) {
          return session.isCourier ? '/courier' : '/waiter';
        } else {
          return session.isCourier ? '/courier' : '/waiter';
        }
      }

      // Role guards
      if (state.uri.path.startsWith('/courier') && !session.canActAsCourier) {
        return '/waiter';
      }
      if (state.uri.path.startsWith('/waiter') && !session.canActAsWaiter) {
        return '/courier';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const UnifiedLoginScreen(),
      ),
      GoRoute(
        path: '/role-select',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/courier',
        builder: (context, state) => const CourierHomeScreen(),
        routes: [
          GoRoute(
            path: 'order/:id',
            builder: (context, state) {
              final idStr = state.pathParameters['id'] ?? '0';
              return CourierOrderDetailScreen(orderId: int.tryParse(idStr) ?? 0);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/waiter',
        builder: (context, state) => const WaiterFloorScreenV2(),
        routes: [
          GoRoute(
            path: 'order/:table',
            builder: (context, state) {
              final tableNum = state.pathParameters['table'] ?? 'T-01';
              return WaiterOrderEntryScreen(tableNumber: tableNum);
            },
          ),
          GoRoute(
            path: 'bill/:table',
            builder: (context, state) {
              final tableNum = state.pathParameters['table'] ?? 'T-01';
              return WaiterBillScreen(tableNumber: tableNum);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const StaffProfileScreen(),
      ),
    ],
  );
});
