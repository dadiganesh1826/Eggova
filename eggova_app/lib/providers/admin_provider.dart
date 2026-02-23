import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import 'package:dio/dio.dart';

class AdminProvider extends ChangeNotifier {
  List<UserModel> _users = [];
  List<OrderModel> _pendingPayments = [];
  List<OrderModel> _completedPayments = [];
  Map<String, dynamic> _dashboardStats = {};
  List<Map<String, dynamic>> _todayPrices = [];
  Map<String, dynamic> _todayStock = {};
  bool _isLoading = false;
  String? _error;

  List<UserModel> get users => _users;
  List<OrderModel> get pendingPayments => _pendingPayments;
  List<OrderModel> get completedPayments => _completedPayments;
  Map<String, dynamic> get dashboardStats => _dashboardStats;
  List<Map<String, dynamic>> get todayPrices => _todayPrices;
  Map<String, dynamic> get todayStock => _todayStock;
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

  Future<void> fetchTodayPrices() async {
    try {
      final response = await _api.getTodayAllPrices();
      if (response.data['success']) {
        _todayPrices = (response.data['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _priceTrends = [];
  bool _isLoadingTrends = false;
  List<Map<String, dynamic>> get priceTrends => _priceTrends;
  bool get isLoadingTrends => _isLoadingTrends;

  Future<void> fetchPriceTrends(String district) async {
    _isLoadingTrends = true;
    _priceTrends = [];
    notifyListeners();
    try {
      final response = await _api.getPriceHistory(district: district);
      if (response.data['success']) {
        _priceTrends = (response.data['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetching trends: $e');
    }
    _isLoadingTrends = false;
    notifyListeners();
  }

  Future<bool> autoFetchLatestPrices() async {
    _isLoading = true;
    _error = null;
    _successMessage = null;
    notifyListeners();
    try {
      final response = await _api.autoFetchPrices();
      if (response.data['success']) {
        await fetchTodayPrices();
        _successMessage = response.data['message'];
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = 'Failed to auto-fetch rates';
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> setEggPrice(String district, double pricePerEgg) async {
    try {
      final response = await _api.setEggPrice({
        'district': district,
        'pricePerEgg': pricePerEgg,
        'pricePerTray': pricePerEgg * 30,
      });
      if (response.data['success']) {
        await fetchTodayPrices();
        return true;
      }
    } catch (_) {}
    return false;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> fetchTodayStock() async {
    try {
      final response = await _api.getStockToday();
      if (response.data['success']) {
        _todayStock = Map<String, dynamic>.from(response.data['data']);
        notifyListeners();
      }
    } catch (_) {}
  }

  String? _successMessage;
  String? get successMessage => _successMessage;

  Future<bool> setDailyStock(int totalTrays) async {
    _error = null;
    _successMessage = null;
    try {
      final response = await _api.setDailyStock(totalTrays);
      if (response.data['success']) {
        _todayStock = Map<String, dynamic>.from(response.data['data']);
        _successMessage = response.data['message'];
        notifyListeners();
        return true;
      } else {
        _error = response.data['message'];
      }
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map) {
        _error = e.response!.data['message'] ?? 'Failed to set stock';
      } else {
        _error = 'Network error while setting stock';
      }
    } catch (e) {
      _error = 'Failed to set stock';
    }
    notifyListeners();
    return false;
  }

  Future<bool> placeOfflineOrder({
    required int trayCount,
    required String customerName,
    required String customerPhone,
    String paymentMethod = 'cash',
  }) async {
    _error = null;
    _successMessage = null;
    try {
      final response = await _api.placeOfflineOrder(
        trayCount: trayCount,
        customerName: customerName,
        customerPhone: customerPhone,
        paymentMethod: paymentMethod,
      );
      if (response.data['success']) {
        _successMessage = response.data['message'];
        // Refresh stock and stats
        await fetchTodayStock();
        await fetchDashboardStats();
        notifyListeners();
        return true;
      } else {
        _error = response.data['message'];
      }
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map) {
        _error = e.response!.data['message'] ?? 'Failed to record offline order';
      } else {
        _error = 'Network error while recording offline order';
      }
    } catch (e) {
      _error = 'Failed to record offline order';
    }
    notifyListeners();
    return false;
  }
}
