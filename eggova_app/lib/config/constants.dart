class AppConstants {
  // API Base URL - change this to your deployed server
  // API Base URL - deployed server
  static const String apiBaseUrl = 'http://77.42.34.63/api'; // Production server

  // App Info
  static const String appName = 'Eggova';
  static const String appTagline = 'Fresh Eggs, Fair Prices';

  // Egg tray info
  static const int eggsPerTray = 30;
  static const int maxTraysPerOrder = 100;
  static const int minTraysPerOrder = 1;

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  // Razorpay
  static const String razorpayKeyId = 'rzp_test_placeholder';
}
