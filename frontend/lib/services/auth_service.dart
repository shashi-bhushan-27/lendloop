/// Firebase Authentication Service for LendLoop
///
/// Handles:
/// - Email/password sign in
/// - Google Sign In
/// - Phone OTP verification
/// - Domain validation
/// - JWT exchange with backend

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lendloop/core/constants/app_constants.dart';
import 'package:lendloop/core/errors/failures.dart';
import 'package:lendloop/services/api_client.dart';
import 'package:dartz/dartz.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiClient _api = ApiClient.instance;

  User? get currentFirebaseUser => _firebaseAuth.currentUser;
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Validates that an email belongs to VIT domains.
  bool isVITEmail(String email) {
    final domain = email.split('@').last.toLowerCase();
    return AppConstants.allowedDomains.contains(domain);
  }

  /// Sign in with email and password via Firebase.
  Future<Either<Failure, Map<String, dynamic>>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      if (!isVITEmail(email)) {
        return const Left(DomainRestrictionFailure());
      }
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return await _exchangeFirebaseToken(credential.user!);
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapFirebaseError(e.code)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Register with email/password via Firebase.
  Future<Either<Failure, Map<String, dynamic>>> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      if (!isVITEmail(email)) {
        return const Left(DomainRestrictionFailure());
      }
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user!.updateDisplayName(fullName);
      await credential.user!.sendEmailVerification();
      return await _exchangeFirebaseToken(credential.user!, fullName: fullName);
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapFirebaseError(e.code)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Exchange Firebase ID token for LendLoop JWT.
  Future<Either<Failure, Map<String, dynamic>>> _exchangeFirebaseToken(
    User firebaseUser, {
    String fullName = '',
  }) async {
    try {
      // Force refresh to always get a fresh, valid token
      final idToken = await firebaseUser.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        return const Left(AuthFailure('Failed to get Firebase ID token.'));
      }

      final response = await _api.post('/auth/login', data: {
        'firebase_token': idToken,
        'full_name': fullName,
      });
      final data = response.data as Map<String, dynamic>;
      await _storage.write(
        key: AppConstants.accessTokenKey,
        value: data['access_token'],
      );
      await _storage.write(
        key: AppConstants.refreshTokenKey,
        value: data['refresh_token'],
      );
      return Right(data);
    } catch (e) {
      return Left(ServerFailure('Backend authentication failed: $e'));
    }
  }

  /// Sign out from Firebase and clear local tokens.
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    await _storage.deleteAll();
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found': return 'No account found for this email.';
      case 'wrong-password': return 'Incorrect password.';
      case 'email-already-in-use': return 'This email is already registered.';
      case 'weak-password': return 'Password must be at least 6 characters.';
      case 'invalid-email': return 'Invalid email address.';
      case 'too-many-requests': return 'Too many attempts. Please try again later.';
      default: return 'Authentication error. Please try again.';
    }
  }
}
