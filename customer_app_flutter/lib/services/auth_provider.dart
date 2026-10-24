import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import 'api_service.dart';

class AuthProvider extends ChangeNotifier {
  UserProfile? _user;
  bool _isLoading = true;
  bool _hasSeenOnboarding = false;
  List<String> _favoriteDishIds = [];

  UserProfile? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  List<String> get favoriteDishIds => _favoriteDishIds;

  AuthProvider() {
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasSeenOnboarding = prefs.getBool('seen_onboarding') ?? false;

      final savedUserJson = prefs.getString('user_profile');
      if (savedUserJson != null) {
        final Map<String, dynamic> map = jsonDecode(savedUserJson);
        _user = UserProfile.fromJson(map);
      }

      final savedFavs = prefs.getStringList('favorites');
      if (savedFavs != null) {
        _favoriteDishIds = savedFavs;
      }
    } catch (e) {
      debugPrint('Session load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setOnboardingSeen() async {
    _hasSeenOnboarding = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
  }

  Future<void> loginOrRegister({required String phone, String? fullName}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final profile = await ApiService.authCustomer(phone: phone, fullName: fullName);
      _user = profile;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile', jsonEncode(profile.toJson()));
      await prefs.setString('user_phone', profile.phone);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({required String fullName}) async {
    if (_user == null) return;
    try {
      final updated = await ApiService.updateProfile(phone: _user!.phone, fullName: fullName);
      _user = _user!.copyWith(fullName: updated.fullName);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile', jsonEncode(_user!.toJson()));
      notifyListeners();
    } catch (e) {
      debugPrint('Profile update error: $e');
    }
  }

  Future<void> saveDefaultAddress(String address) async {
    if (_user != null) {
      _user = _user!.copyWith(defaultAddress: address);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile', jsonEncode(_user!.toJson()));
      notifyListeners();
    }
  }

  void toggleFavorite(int dishId) async {
    final strId = dishId.toString();
    if (_favoriteDishIds.contains(strId)) {
      _favoriteDishIds.remove(strId);
    } else {
      _favoriteDishIds.add(strId);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', _favoriteDishIds);
  }

  bool isFavorite(int dishId) => _favoriteDishIds.contains(dishId.toString());

  Future<void> logout() async {
    _user = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_profile');
  }
}
