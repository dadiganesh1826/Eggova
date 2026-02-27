import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/api_service.dart';

/// Handles background FCM messages — must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📲 [FCM Background] ${message.notification?.title}');
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _api = ApiService();

  // Local notifications plugin for foreground banners
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  // Android high-importance channel
  static const _channel = AndroidNotificationChannel(
    'eggova_notifications',
    'Eggova Notifications',
    description: 'Order and payment alerts from Eggova',
    importance: Importance.high,
    playSound: true,
  );

  /// Phase 1 — call at app START (no auth needed).
  /// Requests permissions + sets up notification display.
  static Future<void> initialize() async {
    try {
      // Request permissions (Android 13+ / iOS)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('⚠️ Notification permission denied');
        return;
      }

      // Create the Android notification channel
      await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // Init local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _localNotif.initialize(initSettings);

      // Background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Tell FCM to use our channel for Android notifications
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Foreground: show a local notification banner
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📲 [FCM Foreground] ${message.notification?.title}');
        _showLocalNotification(message);
      });

      debugPrint('✅ FCM + local notifications initialized');
    } catch (e) {
      debugPrint('⚠️ FCM initialize error: $e');
    }
  }

  /// Displays a local notification banner for a foreground FCM message.
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotif.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
        ),
      ),
    );
  }

  /// Phase 2 — call AFTER user logs in.
  /// Gets and saves the FCM token to the backend.
  static Future<void> registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('⚠️ FCM token is null');
        return;
      }
      debugPrint('🔑 FCM Token obtained, registering...');
      await _saveFcmToken(token);

      // Re-register if Firebase rotates the token
      _messaging.onTokenRefresh.listen(_saveFcmToken);
    } catch (e) {
      debugPrint('⚠️ FCM registerToken error: $e');
    }
  }

  static Future<void> _saveFcmToken(String token) async {
    try {
      await _api.saveFcmToken(token);
      debugPrint('✅ FCM token saved to backend');
    } catch (e) {
      debugPrint('⚠️ Failed to save FCM token: $e');
    }
  }
}
