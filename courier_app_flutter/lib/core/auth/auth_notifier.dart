// Riverpod Auth Notifier for Dilkash Staff App
// Manages authentication, backend role verification, role switching, and biometrics.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/mock_staff_repository.dart';
import '../network/staff_repository.dart';
import 'biometric_service.dart';
import 'staff_session.dart';

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return MockStaffRepository.instance;
});

final authProvider =
    NotifierProvider<AuthNotifier, AsyncValue<StaffSession?>>(AuthNotifier.new);

class AuthNotifier extends Notifier<AsyncValue<StaffSession?>> {
  static const _sessionKey = 'dilkash_active_staff_session';

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
        state = AsyncValue.data(StaffSession.fromJson(map));
      }
    } catch (_) {
      // Ignore restore error, stay unauthenticated
    }
  }

  Future<void> login({
    String? phone,
    String? staffCode,
    required String pin,
    bool rememberBiometric = true,
  }) async {
    state = const AsyncValue.loading();
    try {
      final session = await _repository.authenticate(
        phone: phone,
        staffCode: staffCode,
        pin: pin,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, jsonEncode(session.toJson()));

      if (rememberBiometric) {
        await BiometricService.setBiometricEnabled(true);
        await BiometricService.saveCredentials(
          phone: phone ?? session.phone,
          staffCode: staffCode ?? session.staffCode,
          pin: pin,
        );
      }

      state = AsyncValue.data(session);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loginWithBiometrics() async {
    state = const AsyncValue.loading();
    try {
      final creds = await BiometricService.getSavedCredentials();
      final phone = creds['phone'];
      final staffCode = creds['staff_code'];
      final pin = creds['pin'];

      if (pin == null || pin.isEmpty) {
        throw Exception('Biometrik maʻlumot topilmadi. PIN orqali kiring.');
      }

      final session = await _repository.authenticate(
        phone: phone,
        staffCode: staffCode,
        pin: pin,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, jsonEncode(session.toJson()));

      state = AsyncValue.data(session);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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

    state = AsyncValue.data(updated);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    state = const AsyncValue.data(null);
  }
}
