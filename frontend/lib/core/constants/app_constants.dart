/// App-wide constants for LendLoop

class AppConstants {
  AppConstants._();

  // API
  static const String baseUrl = 'https://lendloop-xnuy.onrender.com/api/v1';
  static const String apiVersion = 'v1';
  static const int connectTimeout = 30000; // ms
  static const int receiveTimeout = 30000; // ms

  // Auth
  static const List<String> allowedDomains = ['vit.ac.in', 'vitstudent.ac.in'];

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Trust Score
  static const double maxTrustScore = 100.0;
  static const double minTrustScore = 0.0;
  static const double newUserTrustScore = 50.0;

  // Items
  static const int maxItemImages = 5;
  static const int maxBorrowDays = 90;
  static const int defaultBorrowDays = 7;

  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String fcmTokenKey = 'fcm_token';

  // QR
  static const int qrTokenExpiryMinutes = 30;

  // App Info
  static const String appName = 'LendLoop';
  static const String appVersion = '1.0.0';
  static const String vitEmail1 = '@vit.ac.in';
  static const String vitEmail2 = '@vitstudent.ac.in';
}
