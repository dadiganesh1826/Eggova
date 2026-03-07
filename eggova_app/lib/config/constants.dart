import 'package:flutter/foundation.dart' show kDebugMode;

class AppConstants {
  // API Base URL — auto-switches between local (debug) and production (release)
  static String get apiBaseUrl {
    const env = String.fromEnvironment('ENV');
    if (env == 'prod') return 'http://77.42.34.63/api'; // Forced production server
    
    return kDebugMode
        ? 'http://localhost:3000/api'   // Debug: works via `adb reverse tcp:3000 tcp:3000`
        : 'http://77.42.34.63/api';     // Production server (fallback if no ENV passed)
  }

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
