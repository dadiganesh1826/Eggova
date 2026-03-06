import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  String? _token;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;

  final ApiService _api = ApiService();

  AuthProvider() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(AppConstants.tokenKey);
      final userJson = prefs.getString(AppConstants.userKey);

      if (_token != null && userJson != null) {
        _user = UserModel.fromJson(jsonDecode(userJson));
        // Refresh profile from server
        try {
          final response = await _api.getProfile();
          if (response.data['success']) {
            _user = UserModel.fromJson(response.data['data']['user']);
            await prefs.setString(
                AppConstants.userKey, jsonEncode(_user!.toJson()));
          }
        } catch (_) {
          // Use cached data if server is unavailable
        }
        // Register FCM token now that we have auth
        NotificationService.registerToken();
      }
    } catch (_) {
      // Clean start
    }

    _isLoading = false;
    _isInitialized = true;
    notifyListeners();
  }

  // Check if phone has an existing account
  Future<bool?> checkPhone(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _api.checkPhone(phone);
      if (response.data['success']) {
        _isLoading = false;
        notifyListeners();
        return response.data['data']['isExistingUser'] as bool;
      } else {
        _error = response.data['message'];
      }
    } catch (e) {
      _error = _extractError(e);
    }
    _isLoading = false;
    notifyListeners();
    return null;
  }

  // Register new user with mobile + password
  Future<bool> registerUser(String phone, String password, String name, String district) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _api.register(phone, password, name, district);
      if (response.data['success']) {
        final data = response.data['data'];
        _token = data['token'];
        _user = UserModel.fromJson(data['user']);
        await _saveToStorage();
        NotificationService.registerToken();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response.data['message'];
      }
    } catch (e) {
      _error = _extractError(e);
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Login existing user with mobile + password
  Future<bool> loginWithPassword(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _api.userLogin(phone, password);
      if (response.data['success']) {
        final data = response.data['data'];
        _token = data['token'];
        _user = UserModel.fromJson(data['user']);
        await _saveToStorage();
        NotificationService.registerToken();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response.data['message'];
      }
    } catch (e) {
      _error = _extractError(e);
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Legacy email login (for admin)
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.login(email, password);

      if (response.data['success']) {
        _token = response.data['data']['token'];
        _user = UserModel.fromJson(response.data['data']['user']);
        await _saveToStorage();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response.data['message'];
      }
    } catch (e) {
      _error = _extractError(e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Update profile
  Future<bool> updateProfile({
    String? name,
    String? email,
    String? district,
    String? address,
    String? pincode,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (email != null) data['email'] = email;
      if (district != null) data['district'] = district;
      if (address != null) data['address'] = address;
      if (pincode != null) data['pincode'] = pincode;

      final response = await _api.updateProfile(data);

      if (response.data['success']) {
        _user = UserModel.fromJson(response.data['data']['user']);
        await _saveToStorage();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response.data['message'];
      }
    } catch (e) {
      _error = _extractError(e);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
    _user = null;
    _token = null;
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) {
      await prefs.setString(AppConstants.tokenKey, _token!);
    }
    if (_user != null) {
      await prefs.setString(AppConstants.userKey, jsonEncode(_user!.toJson()));
    }
  }

  String _extractError(dynamic e) {
    if (e is Exception) {
      try {
        final dioError = e as dynamic;
        return dioError.response?.data?['message'] ?? 'Something went wrong';
      } catch (_) {}
    }
    return 'Connection error. Please try again.';
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
