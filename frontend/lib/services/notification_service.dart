/// Firebase Cloud Messaging Service
///
/// Handles:
/// - FCM initialization and notification permission
/// - FCM token retrieval and registration with backend
///
/// Background/terminated pushes are shown by the system tray automatically
/// (they carry a notification payload). Foreground display, data refresh and
/// tap navigation are handled in `LendLoopApp` (main.dart), which has access
/// to Riverpod and the router — see `push_sync.dart`.

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

    // Get and store FCM token
    await _refreshFCMToken();

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) async {
      await _storage.write(key: AppConstants.fcmTokenKey, value: newToken);
      _registerTokenWithBackend(newToken);
    });
  }

  static Future<void> _refreshFCMToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await _storage.write(key: AppConstants.fcmTokenKey, value: token);
        // Do not await to prevent blocking the splash screen if backend is sleeping
        _registerTokenWithBackend(token);
      }
    } catch (e) {
      print('FCM Token error (non-fatal): $e');
    }
  }

  /// Attach this device to whoever is now signed in. The startup registration
  /// alone missed anyone who logged in (or switched accounts) after launch,
  /// so pushes for that account never reached this phone.
  static Future<void> registerForCurrentUser() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) await _registerTokenWithBackend(token);
    } catch (_) {}
  }

  /// Detach this device from the account being signed out so it stops getting
  /// that account's pushes. Must run while the session token is still valid.
  static Future<void> unregisterForCurrentUser() async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      await ApiClient.instance.dio.delete('/auth/fcm-token', data: {'token': token});
    } catch (_) {}
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
