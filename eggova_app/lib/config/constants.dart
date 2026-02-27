class AppConstants {
  // API Base URL - change this to your deployed server
  // static const String apiBaseUrl = 'http://10.0.2.2:3000/api'; // Android emulator
  static const String apiBaseUrl = 'http://192.168.0.109:3000/api'; // Physical device (LAN IP)

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
