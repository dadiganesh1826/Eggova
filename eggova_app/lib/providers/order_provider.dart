import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/egg_price.dart';
import '../services/api_service.dart';

class OrderProvider extends ChangeNotifier {
  List<OrderModel> _orders = [];
  EggPrice? _currentPrice;
  bool _isLoading = false;
  String? _error;

  List<OrderModel> get orders => _orders;
  EggPrice? get currentPrice => _currentPrice;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final ApiService _api = ApiService();

  // Fetch current egg price
  Future<void> fetchCurrentPrice({String? district}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.getCurrentPrice(district: district);
      if (response.data['success']) {
        _currentPrice = EggPrice.fromJson(response.data['data']);
      } else {
        _error = response.data['message'];
      }
    } catch (e) {
      _error = 'Failed to fetch egg price';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Place order
  Future<OrderModel?> placeOrder(int trayCount, String paymentMethod) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.placeOrder(trayCount, paymentMethod);
      if (response.data['success']) {
        final order = OrderModel.fromJson(response.data['data']);
        _orders.insert(0, order);
        _isLoading = false;
        notifyListeners();
        return order;
      } else {
        _error = response.data['message'];
      }
    } catch (e) {
      _error = 'Failed to place order';
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  // Fetch order history
  Future<void> fetchOrders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.getOrderHistory();
      if (response.data['success']) {
        _orders = (response.data['data'] as List)
            .map((json) => OrderModel.fromJson(json))
            .toList();
      }
    } catch (e) {
      _error = 'Failed to fetch orders';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Request payment completion
  Future<bool> requestPaymentCompletion(String orderId, String paidVia) async {
    try {
      final response = await _api.requestPaymentCompletion(orderId, paidVia);
      if (response.data['success']) {
        await fetchOrders();
        return true;
      }
    } catch (_) {}
    return false;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
