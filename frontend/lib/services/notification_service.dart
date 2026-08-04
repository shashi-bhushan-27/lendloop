/// Firebase Cloud Messaging Service
///
/// Handles:
/// - FCM initialization
/// - Foreground/background message handling
/// - FCM token retrieval and registration with backend
/// - Local notification display

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:lendloop/services/api_client.dart';
import 'package:lendloop/core/constants/app_constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages here
  // Note: Firebase.initializeApp() is called automatically
}

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final _storage = const FlutterSecureStorage();

  static Future<void> initialize() async {
    // Request permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // TODO: Show local notification overlay using flutter_local_notifications
    });

    // Handle tap on notification when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // TODO: Navigate to relevant screen based on message.data
    });

    // Get and store FCM token
    await _refreshFCMToken();

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) async {
      await _storage.write(key: AppConstants.fcmTokenKey, value: newToken);
      await _registerTokenWithBackend(newToken);
    });
  }

  static Future<void> _refreshFCMToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _storage.write(key: AppConstants.fcmTokenKey, value: token);
        await _registerTokenWithBackend(token);
      }
    } catch (e) {
      print('FCM Token error (non-fatal): $e');
    }
  }

  static Future<void> _registerTokenWithBackend(String token) async {
    try {
      await ApiClient.instance.post('/auth/fcm-token', data: {
        'token': token,
        'device_type': 'android',
      });
    } catch (_) {
      // Silently fail — token will be registered on next successful request
    }
  }
}
