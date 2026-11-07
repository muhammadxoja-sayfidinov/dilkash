// Riverpod Auth Notifier for Dilkash Staff App
// Manages authentication, backend role verification, role switching, and last-role memory.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/mock_staff_repository.dart';
import '../network/staff_repository.dart';
import 'staff_session.dart';

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return MockStaffRepository.instance;
});

final authProvider =
    NotifierProvider<AuthNotifier, AsyncValue<StaffSession?>>(AuthNotifier.new);

class AuthNotifier extends Notifier<AsyncValue<StaffSession?>> {
  static const _sessionKey = 'dilkash_active_staff_session';
  static const _lastRoleKey = 'dilkash_last_selected_role';

  StaffRepository get _repository => ref.read(staffRepositoryProvider);

  @override
  AsyncValue<StaffSession?> build() {
    _tryRestoreSession();
    return const AsyncValue.data(null);
  }

  Future<void> _tryRestoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_sessionKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        var session = StaffSession.fromJson(map);

        // If last role remembered, make sure it applies
        final lastRole = prefs.getString(_lastRoleKey);
        if (lastRole != null && session.assignedRoles.contains(lastRole)) {
          session = session.copyWith(activeRole: lastRole);
        }

        state = AsyncValue.data(session);
      }
    } catch (_) {
      // Stay unauthenticated on error
    }
  }

  Future<StaffSession> login({
    required String phone,
    required String pin,
  }) async {
    state = const AsyncValue.loading();
    try {
      final rawSession = await _repository.authenticate(
        phone: phone,
        pin: pin,
      );

      final prefs = await SharedPreferences.getInstance();
      final lastRole = prefs.getString(_lastRoleKey);

      StaffSession session = rawSession;
      if (session.assignedRoles.length == 1) {
        session = session.copyWith(activeRole: session.assignedRoles.first);
      } else if (lastRole != null && session.assignedRoles.contains(lastRole)) {
        session = session.copyWith(activeRole: lastRole);
      }

      await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
      state = AsyncValue.data(session);
      return session;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> switchRole(String newRole) async {
    final current = state.value;
    if (current == null) return;

    if (!current.assignedRoles.contains(newRole)) {
      throw Exception('Sizda $newRole roli uchun ruxsat mavjud emas!');
    }

    final updated = current.copyWith(activeRole: newRole);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(updated.toJson()));
    await prefs.setString(_lastRoleKey, newRole);

    state = AsyncValue.data(updated);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    state = const AsyncValue.data(null);
  }
}
