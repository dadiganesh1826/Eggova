import 'package:flutter/foundation.dart' show kDebugMode;

class AppConstants {
  // API Base URL — auto-switches between local (debug) and production (release)
  static String get apiBaseUrl => kDebugMode
      ? 'http://10.0.2.2:3000/api'   // Android Emulator → localhost
      : 'http://77.42.34.63/api';     // Production server

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
