import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  // Auth — User (mobile + password)
  Future<Response> checkPhone(String phone) =>
      _dio.post('/auth/check-phone', data: {'phone': phone});

  Future<Response> register(String phone, String password, String name, String district) =>
      _dio.post('/auth/register', data: {
        'phone': phone,
        'password': password,
        'name': name,
        'district': district,
      });

  Future<Response> userLogin(String phone, String password) =>
      _dio.post('/auth/user-login', data: {'phone': phone, 'password': password});

  Future<Response> googleLogin(String idToken) =>
      _dio.post('/auth/google', data: {'idToken': idToken});

  Future<Response> registerDetails(String idToken, String phone, String district) =>
      _dio.post('/auth/register-details', data: {
        'idToken': idToken,
        'phone': phone,
        'district': district,
      });

  Future<Response> forgotPassword(String phone, String newPassword) =>
      _dio.post('/auth/forgot-password', data: {'phone': phone, 'newPassword': newPassword});

  // Auth — Admin (email + password)
  Future<Response> login(String email, String password) =>
      _dio.post('/auth/login', data: {'email': email, 'password': password});

  // Admin — User Management
  Future<Response> getPendingUsers() => _dio.get('/admin/users/pending');
  Future<Response> approveUser(String userId) => _dio.put('/admin/users/$userId/approve');


  Future<Response> getProfile() => _dio.get('/auth/profile');

  Future<Response> updateProfile(Map<String, dynamic> data) =>
      _dio.put('/auth/profile', data: data);

  Future<Response> requestPhoneUpdate(String newPhone) =>
      _dio.post('/auth/request-phone-update', data: {'newPhone': newPhone});


  // Egg Prices
  Future<Response> getCurrentPrice({String? district}) =>
      _dio.get('/egg-prices/current', queryParameters: district != null ? {'district': district} : null);

  Future<Response> setEggPrice(Map<String, dynamic> data) =>
      _dio.post('/egg-prices/set', data: data);

  Future<Response> getPriceHistory({String? district}) =>
      _dio.get('/egg-prices/history', queryParameters: district != null ? {'district': district} : null);

  Future<Response> getTodayAllPrices() => _dio.get('/egg-prices/today-all');

  Future<Response> autoFetchPrices() => _dio.post('/egg-prices/auto-fetch');

  Future<Response> setDailyStock(int totalTrays) =>
      _dio.post('/egg-prices/set-stock', data: {'totalTrays': totalTrays});

  Future<Response> getStockToday() async {
    return await _dio.get('/egg-prices/stock-today');
  }

  Future<Response> placeOfflineOrder({
    required int trayCount,
    required String customerName,
    required String customerPhone,
    String paymentMethod = 'cash',
  }) async {
    return await _dio.post('/admin/place-offline-order', data: {
      'trayCount': trayCount,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'paymentMethod': paymentMethod,
    });
  }
  // Orders
  Future<Response> placeOrder(int trayCount, String paymentMethod) =>
      _dio.post('/orders/place', data: {'trayCount': trayCount, 'paymentMethod': paymentMethod});

  Future<Response> getOrderHistory() => _dio.get('/orders/history');

  Future<Response> getOrderDetail(String orderId) => _dio.get('/orders/$orderId');

  // Payments
  Future<Response> createRazorpayOrder(String orderId) =>
      _dio.post('/payments/create-razorpay', data: {'orderId': orderId});

  Future<Response> verifyPayment(Map<String, dynamic> data) =>
      _dio.post('/payments/verify', data: data);

  Future<Response> cancelUpiOrder(String orderId) =>
      _dio.post('/payments/cancel-upi', data: {'orderId': orderId});

  Future<Response> requestPaymentCompletion(String orderId, String paidVia) =>
      _dio.post('/payments/request-completion', data: {'orderId': orderId, 'paidVia': paidVia});

  Future<Response> markPaymentPaid(String orderId, String paidVia) =>
      _dio.post('/payments/mark-paid', data: {'orderId': orderId, 'paidVia': paidVia});

  // Admin
  Future<Response> getAllUsers() => _dio.get('/admin/users');

  Future<Response> getPendingPayments() => _dio.get('/admin/pending-payments');

  Future<Response> getCompletedPayments() => _dio.get('/admin/completed-payments');

  Future<Response> approvePayment(String orderId) =>
      _dio.post('/admin/approve-payment/$orderId');

  Future<Response> getDashboardStats() => _dio.get('/admin/dashboard');

  // Notifications
  Future<Response> getNotifications() => _dio.get('/notifications/my');

  Future<Response> markNotificationRead(String id) =>
      _dio.put('/notifications/read/$id');

  Future<Response> saveFcmToken(String token) =>
      _dio.post('/notifications/fcm-token', data: {'token': token});


  Future<Response> markAllNotificationsRead() =>
      _dio.put('/notifications/read-all');
}
