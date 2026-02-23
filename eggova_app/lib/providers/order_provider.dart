import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/egg_price.dart';
import '../services/api_service.dart';
import 'package:dio/dio.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class OrderProvider extends ChangeNotifier {
  List<OrderModel> _orders = [];
  EggPrice? _currentPrice;
  Map<String, dynamic> _todayStock = {};
  bool _isLoading = false;
  String? _error;
  late Razorpay _razorpay;

  List<OrderModel> get orders => _orders;
  EggPrice? get currentPrice => _currentPrice;
  Map<String, dynamic> get todayStock => _todayStock;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get availableTrays => (_todayStock['remainingTrays'] ?? 0) as int;
  bool get isStockSet => (_todayStock['isSet'] ?? false) as bool;

  final ApiService _api = ApiService();

  OrderProvider() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // Handle Razorpay events
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    _isLoading = true;
    notifyListeners();
    try {
      final verifyRes = await _api.verifyPayment({
        'razorpayOrderId': response.orderId,
        'razorpayPaymentId': response.paymentId,
        'razorpaySignature': response.signature,
      });

      if (verifyRes.data['success']) {
        await fetchOrders();
        await fetchTodayStock();
      } else {
        _error = verifyRes.data['message'];
      }
    } catch (e) {
      _error = 'Payment verification failed';
    }
    _isLoading = false;
    notifyListeners();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _error = response.message ?? 'Payment failed';
    _isLoading = false;
    notifyListeners();
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _error = 'External wallet selected: ${response.walletName}';
    notifyListeners();
  }

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
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map) {
        _error = e.response!.data['message'] ?? 'Failed to fetch egg price';
      } else {
        _error = 'Network error while fetching price';
      }
    } catch (e) {
      _error = 'Failed to fetch egg price';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Fetch today's stock
  Future<void> fetchTodayStock() async {
    try {
      final response = await _api.getStockToday();
      if (response.data['success']) {
        _todayStock = Map<String, dynamic>.from(response.data['data']);
        notifyListeners();
      }
    } catch (_) {}
  }

  // Place order
  Future<OrderModel?> placeOrder(int trayCount, String paymentMethod, {Map<String, dynamic>? userData}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.placeOrder(trayCount, paymentMethod);
      if (response.data['success']) {
        final order = OrderModel.fromJson(response.data['data']);
        
        if (paymentMethod == 'upi') {
          // Trigger Razorpay
          await _startRazorpay(order, userData);
          return order; // Still return order, but payment happens asynchronously
        }

        _orders.insert(0, order);
        await fetchTodayStock(); // Refresh stock after order
        _isLoading = false;
        notifyListeners();
        return order;
      } else {
        _error = response.data['message'];
      }
    } on DioException catch (e) {
      if (e.response != null && e.response!.data is Map) {
        _error = e.response!.data['message'] ?? 'Failed to place order';
      } else {
        _error = 'Network error while placing order';
      }
    } catch (e) {
      _error = 'Failed to place order';
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  Future<void> _startRazorpay(OrderModel order, Map<String, dynamic>? userData) async {
    try {
      final response = await _api.createRazorpayOrder(order.id);
      if (response.data['success']) {
        final data = response.data['data'];
        
        var options = {
          'key': data['keyId'],
          'amount': data['amount'],
          'name': 'Eggova Poultry',
          'order_id': data['razorpayOrderId'],
          'description': 'Payment for Order ${order.orderNumber}',
          'timeout': 300, // in seconds
          'prefill': {
            'contact': userData?['phone'] ?? '',
            'email': userData?['email'] ?? '',
            'name': userData?['name'] ?? '',
          }
        };

        _razorpay.open(options);
      } else {
        _error = response.data['message'];
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _error = 'Payment initialization failed';
      _isLoading = false;
      notifyListeners();
    }
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
    } on DioException catch (e) {
       // Optional: capture error if needed
    } catch (_) {}
    return false;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
