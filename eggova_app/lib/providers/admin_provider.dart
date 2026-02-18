import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/order.dart';
import '../services/api_service.dart';

class AdminProvider extends ChangeNotifier {
  List<UserModel> _users = [];
  List<OrderModel> _pendingPayments = [];
  List<OrderModel> _completedPayments = [];
  Map<String, dynamic> _dashboardStats = {};
  bool _isLoading = false;
  String? _error;

  List<UserModel> get users => _users;
  List<OrderModel> get pendingPayments => _pendingPayments;
  List<OrderModel> get completedPayments => _completedPayments;
  Map<String, dynamic> get dashboardStats => _dashboardStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final ApiService _api = ApiService();

  Future<void> fetchDashboardStats() async {
    try {
      final response = await _api.getDashboardStats();
      if (response.data['success']) {
        _dashboardStats = response.data['data'];
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> fetchUsers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.getAllUsers();
      if (response.data['success']) {
        _users = (response.data['data'] as List)
            .map((json) => UserModel.fromJson(json))
            .toList();
      }
    } catch (e) {
      _error = 'Failed to fetch users';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchPendingPayments() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.getPendingPayments();
      if (response.data['success']) {
        _pendingPayments = (response.data['data'] as List)
            .map((json) => OrderModel.fromJson(json))
            .toList();
      }
    } catch (e) {
      _error = 'Failed to fetch pending payments';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchCompletedPayments() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.getCompletedPayments();
      if (response.data['success']) {
        _completedPayments = (response.data['data'] as List)
            .map((json) => OrderModel.fromJson(json))
            .toList();
      }
    } catch (e) {
      _error = 'Failed to fetch completed payments';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> approvePayment(String orderId) async {
    try {
      final response = await _api.approvePayment(orderId);
      if (response.data['success']) {
        await fetchPendingPayments();
        await fetchCompletedPayments();
        await fetchDashboardStats();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> markPaymentPaid(String orderId, String paidVia) async {
    try {
      final response = await _api.markPaymentPaid(orderId, paidVia);
      if (response.data['success']) {
        await fetchPendingPayments();
        await fetchCompletedPayments();
        await fetchDashboardStats();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> setEggPrice(String district, double pricePerEgg) async {
    try {
      await _api.setEggPrice({
        'district': district,
        'pricePerEgg': pricePerEgg,
        'pricePerTray': pricePerEgg * 30,
      });
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
