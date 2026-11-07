import 'package:flutter/foundation.dart' show kDebugMode;

class AppConstants {
  // Your PC's Local Wi-Fi IPv4 Address (from ipconfig)
  // When testing on a real Android phone over Wi-Fi, the phone connects to this IP.
  static const String localIp = '192.168.1.4';
  static const String localPort = '3000';

  // API Base URL — auto-switches or accepts --dart-define=API_URL=...
  static String get apiBaseUrl {
    const customUrl = String.fromEnvironment('API_URL');
    if (customUrl.isNotEmpty) return customUrl;

    const env = String.fromEnvironment('ENV');
    if (env == 'prod') return 'http://77.42.34.63/api'; // Forced production server
    
    // Always connect to local PC Wi-Fi IP for local testing (both debug and release APKs)
    return 'http://$localIp:$localPort/api';
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
