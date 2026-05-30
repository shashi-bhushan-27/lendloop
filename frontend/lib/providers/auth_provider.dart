/// Auth Providers for LendLoop
///
/// Manages authentication state using Riverpod.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lendloop/services/auth_service.dart';
import 'package:lendloop/services/api_client.dart';
import 'package:lendloop/models/user_model.dart';
import 'package:lendloop/core/constants/app_constants.dart';

/// Firebase auth state stream
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Current LendLoop user profile
final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, AsyncValue<UserModel?>>(
  (ref) => CurrentUserNotifier(),
);

class CurrentUserNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  CurrentUserNotifier() : super(const AsyncValue.loading()) {
    loadUser();
  }

  final AuthService _authService = AuthService();

  Future<void> loadUser() async {
    state = const AsyncValue.loading();
    try {
      final token = await const FlutterSecureStorage().read(key: AppConstants.accessTokenKey);
      if (token == null) {
        state = const AsyncValue.data(null);
        return;
      }
      final response = await ApiClient.instance.get('/users/me');
      final user = UserModel.fromJson(response.data as Map<String, dynamic>);
      state = AsyncValue.data(user);
    } catch (e) {
      state = const AsyncValue.data(null);
    }
  }

  void setUser(UserModel user) {
    state = AsyncValue.data(user);
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }
}

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
