/// Firebase Authentication Service for LendLoop
///
/// Handles:
/// - Email/password sign in & registration
/// - Google Sign-In (with VIT domain validation on backend)
/// - Forgot Password (Firebase password reset email)
/// - Duplicate registration prevention (pre-check before create)
/// - Domain validation (client-side pre-check + server enforced)
/// - JWT exchange with backend

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lendloop/core/constants/app_constants.dart';
import 'package:lendloop/core/errors/failures.dart';
import 'package:dio/dio.dart';
import 'package:lendloop/services/api_client.dart';
import 'package:dartz/dartz.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiClient _api = ApiClient.instance;

  User? get currentFirebaseUser => _firebaseAuth.currentUser;
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // ─────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────

  /// Validates that an email belongs to VIT domains (client-side pre-check).
  bool isVITEmail(String email) {
    final domain = email.split('@').last.toLowerCase();
    return AppConstants.allowedDomains.contains(domain);
  }

  /// Maps Firebase error codes to user-friendly messages.
  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email. Please register first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email. Please log in.';
      case 'weak-password':
        return 'Password must be at least 8 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      default:
        return 'Authentication error. Please try again.';
    }
  }

  // ─────────────────────────────────────────
  // Email / Password
  // ─────────────────────────────────────────

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
  /// Pre-checks for existing account before creating to give a clear error.
  Future<Either<Failure, Map<String, dynamic>>> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    String regNumber = '',
  }) async {
    try {
      if (!isVITEmail(email)) {
        return const Left(DomainRestrictionFailure());
      }

      // Pre-check: does this email already exist in Firebase?
      final methods = await _firebaseAuth.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) {
        return const Left(AuthFailure(
          'An account already exists with this email. Please log in instead.',
        ));
      }

      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user!.updateDisplayName(fullName);
      // OTP verification is handled separately via Postmark (not Firebase links)

      return await _exchangeFirebaseToken(
        credential.user!,
        fullName: fullName,
        regNumber: regNumber,
      );
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapFirebaseError(e.code)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // ─────────────────────────────────────────
  // Google Sign-In
  // ─────────────────────────────────────────

  /// Sign in with Google. Backend enforces VIT domain validation.
  Future<Either<Failure, Map<String, dynamic>>> signInWithGoogle() async {
    GoogleSignInAccount? googleUser;
    try {
      googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in dialog
        return const Left(AuthFailure('Google sign-in was cancelled.'));
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      // Exchange token — backend validates VIT domain server-side
      final result = await _exchangeFirebaseToken(userCredential.user!);

      // If backend rejected (403 domain restriction), sign out from both
      return result.fold(
        (failure) async {
          await _cleanupGoogleSession();
          return Left(failure);
        },
        (data) => Right(data),
      );
    } on FirebaseAuthException catch (e) {
      await _cleanupGoogleSession();
      return Left(AuthFailure(_mapFirebaseError(e.code)));
    } catch (e) {
      await _cleanupGoogleSession();
      return Left(ServerFailure('Google sign-in failed. Please try again.'));
    }
  }

  /// Sign out from both Firebase and Google, clear stored tokens.
  Future<void> _cleanupGoogleSession() async {
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  // ─────────────────────────────────────────
  // Forgot Password
  // ─────────────────────────────────────────

  /// Send a Firebase password reset email.
  Future<Either<Failure, void>> sendPasswordResetEmail(String email) async {
    try {
      if (!isVITEmail(email)) {
        return const Left(DomainRestrictionFailure());
      }
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      return const Right(null);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          // Don't reveal whether account exists (security best practice)
          // Still return success to prevent email enumeration
          return const Right(null);
        case 'invalid-email':
          return const Left(AuthFailure('Please enter a valid email address.'));
        case 'network-request-failed':
          return const Left(AuthFailure('No internet connection.'));
        default:
          return Left(AuthFailure(_mapFirebaseError(e.code)));
      }
    } catch (e) {
      return Left(ServerFailure('Failed to send reset email. Please try again.'));
    }
  }

  // ─────────────────────────────────────────
  // Email Verification
  // ─────────────────────────────────────────

  /// Re-send verification email to the currently signed-in user.
  Future<Either<Failure, void>> resendVerificationEmail() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return const Left(AuthFailure('No user is currently signed in.'));
      }
      await user.sendEmailVerification();
      return const Right(null);
    } on FirebaseAuthException catch (e) {
      return Left(AuthFailure(_mapFirebaseError(e.code)));
    } catch (e) {
      return Left(ServerFailure('Failed to send verification email.'));
    }
  }

  /// Reload the current Firebase user and return whether email is verified.
  Future<bool> checkEmailVerified() async {
    try {
      await _firebaseAuth.currentUser?.reload();
      return _firebaseAuth.currentUser?.emailVerified ?? false;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────
  // OTP Verification (Postmark-based)
  // ─────────────────────────────────────────

  /// Request a 6-digit OTP to be sent to the user's email via Postmark.
  Future<Either<Failure, void>> sendOtp(String email) async {
    try {
      await _api.post('/auth/send-otp', data: {'email': email});
      return const Right(null);
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] as String?;
      if (e.response?.statusCode == 429) {
        return Left(AuthFailure(
          detail ?? 'Too many requests. Please wait before trying again.',
        ));
      }
      return Left(ServerFailure(
        detail ?? 'Failed to send verification code. Please try again.',
      ));
    } catch (e) {
      return Left(ServerFailure('Failed to send verification code.'));
    }
  }

  /// Verify a 6-digit OTP code. Returns JWT tokens on success.
  Future<Either<Failure, Map<String, dynamic>>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _api.post('/auth/verify-otp', data: {
        'email': email,
        'otp': otp,
      });
      final data = response.data as Map<String, dynamic>;

      // Store JWT tokens if returned
      if (data.containsKey('access_token')) {
        await _storage.write(
          key: AppConstants.accessTokenKey,
          value: data['access_token'],
        );
        await _storage.write(
          key: AppConstants.refreshTokenKey,
          value: data['refresh_token'],
        );
      }

      return Right(data);
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] as String?;
      if (e.response?.statusCode == 429) {
        return Left(AuthFailure(
          detail ?? 'Too many failed attempts. Request a new code.',
        ));
      }
      return Left(AuthFailure(
        detail ?? 'Verification failed. Please check the code.',
      ));
    } catch (e) {
      return Left(ServerFailure('Verification failed. Please try again.'));
    }
  }

  // ─────────────────────────────────────────
  // JWT Exchange (private)
  // ─────────────────────────────────────────

  /// Exchange Firebase ID token for LendLoop backend JWT.
  Future<Either<Failure, Map<String, dynamic>>> _exchangeFirebaseToken(
    User firebaseUser, {
    String fullName = '',
    String regNumber = '',
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
        'reg_number': regNumber,
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
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final detail = e.response?.data?['detail'] as String?;

      if (statusCode == 403) {
        return Left(DomainRestrictionFailure());
      } else if (statusCode == 409) {
        return Left(AuthFailure(
          detail ?? 'An account already exists with this email. Please log in.',
        ));
      } else if (statusCode == 401) {
        return Left(AuthFailure(
          detail ?? 'Authentication failed. Please sign in again.',
        ));
      }
      return Left(ServerFailure(
        detail ?? 'Could not connect to server. Please try again.',
      ));
    } catch (e) {
      return Left(ServerFailure('Backend authentication failed. Please try again.'));
    }
  }

  // ─────────────────────────────────────────
  // Sign Out
  // ─────────────────────────────────────────

  /// Sign out from Firebase, Google (if applicable), and clear local tokens.
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _storage.deleteAll();
  }
}
