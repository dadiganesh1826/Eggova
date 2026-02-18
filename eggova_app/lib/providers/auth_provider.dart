import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
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
            await prefs.setString(AppConstants.userKey, jsonEncode(_user!.toJson()));
          }
        } catch (_) {
          // Use cached data if server is unavailable
        }
      }
    } catch (_) {
      // Clean start
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String district,
    String? address,
    String? state,
    String? pincode,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.register({
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        'district': district,
        'address': address,
        'state': state ?? 'Andhra Pradesh',
        'pincode': pincode,
      });

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
