/// LendLoop Application Router
///
/// GoRouter configuration with:
/// - RouterNotifier (ChangeNotifier) that fires when currentUserProvider changes
/// - refreshListenable so GoRouter re-evaluates redirect on every auth change
/// - Named routes for type-safe navigation
/// - Shell route for bottom navigation bar
/// - Email verification gate: unverified email/password users go to /verify-email
///   (Google Sign-In emails are pre-verified by Google)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lendloop/features/auth/presentation/pages/login_page.dart';
import 'package:lendloop/features/auth/presentation/pages/register_page.dart';
import 'package:lendloop/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:lendloop/features/auth/presentation/pages/email_verification_page.dart';
import 'package:lendloop/features/home/presentation/pages/home_page.dart';
import 'package:lendloop/features/items/presentation/pages/items_list_page.dart';
import 'package:lendloop/features/items/presentation/pages/item_detail_page.dart';
import 'package:lendloop/features/items/presentation/pages/create_item_page.dart';
import 'package:lendloop/features/borrow/presentation/pages/borrow_requests_page.dart';
import 'package:lendloop/features/transactions/presentation/pages/transactions_page.dart';
import 'package:lendloop/features/qr/presentation/pages/qr_scanner_page.dart';
import 'package:lendloop/features/profile/presentation/pages/profile_page.dart';
import 'package:lendloop/features/notifications/presentation/pages/notifications_page.dart';
import 'package:lendloop/providers/auth_provider.dart';
import 'package:lendloop/widgets/app_shell.dart';

/// A ChangeNotifier that fires whenever [currentUserProvider] state changes.
/// This is used as [GoRouter.refreshListenable] so the router
/// re-evaluates its redirect function on every auth state transition.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(Ref ref) {
    ref.listen<AsyncValue>(currentUserProvider, (previous, next) {
      debugPrint('RouterNotifier: currentUserProvider changed from $previous to $next');
      notifyListeners();
    });
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    // Start at login — redirect will push to /home if already authenticated.
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final userState = ref.read(currentUserProvider);
      debugPrint('GoRouter redirect: location = ${state.matchedLocation}, userState = $userState');
      
      // While loading (e.g. app startup checking stored token), don't redirect.
      if (userState.isLoading) {
        debugPrint('GoRouter redirect: userState is loading, returning null');
        return null;
      }

      final isAuthenticated = userState.valueOrNull != null;
      final location = state.matchedLocation;

      final isAuthRoute = location == '/login' ||
          location == '/register' ||
          location == '/forgot-password';
      final isVerifyRoute = location == '/verify-email';

      debugPrint('GoRouter redirect check: isAuthenticated = $isAuthenticated, isAuthRoute = $isAuthRoute, location = $location');

      // Not authenticated → go to login (but allow auth routes)
      if (!isAuthenticated && !isAuthRoute && !isVerifyRoute) {
        debugPrint('GoRouter redirect: user not authenticated and not on auth/verify route. Redirecting to /login');
        return '/login';
      }

      // Authenticated → don't show auth pages
      if (isAuthenticated && isAuthRoute) {
        debugPrint('GoRouter redirect: user is authenticated and on auth route. Redirecting to /home');
        return '/home';
      }

      // Email verification gate:
      // If the Firebase user exists but email is NOT verified and they are NOT
      // a Google/OAuth user, redirect them to the verify-email screen.
      if (isAuthenticated && !isVerifyRoute) {
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null && !firebaseUser.emailVerified) {
          // Check if user signed in via Google (provider ID = 'google.com')
          // Google accounts are always verified — skip the gate.
          final isGoogleUser = firebaseUser.providerData
              .any((p) => p.providerId == 'google.com');
          if (!isGoogleUser) {
            return '/verify-email';
          }
        }
      }

      // Already on verify-email but now verified → go home
      if (isAuthenticated && isVerifyRoute) {
        final firebaseUser = FirebaseAuth.instance.currentUser;
        final isVerified = firebaseUser?.emailVerified ?? false;
        final isGoogleUser = firebaseUser?.providerData
                .any((p) => p.providerId == 'google.com') ??
            false;
        if (isVerified || isGoogleUser) return '/home';
      }

      return null;
    },
    routes: [
      // ── Auth Routes ─────────────────────────────────────
      GoRoute(
          path: '/login', name: 'login', builder: (_, __) => const LoginPage()),
      GoRoute(
          path: '/register',
          name: 'register',
          builder: (_, __) => const RegisterPage()),
      GoRoute(
          path: '/forgot-password',
          name: 'forgot-password',
          builder: (_, __) => const ForgotPasswordPage()),
      GoRoute(
          path: '/verify-email',
          name: 'verify-email',
          builder: (_, __) => const EmailVerificationPage()),

      // ── Full-screen pages (no bottom nav) ───────────────
      GoRoute(
        path: '/items/new',
        name: 'create-item',
        builder: (_, __) => const CreateItemPage(),
      ),
      GoRoute(
        path: '/items/:id',
        name: 'item-detail',
        builder: (_, state) =>
            ItemDetailPage(itemId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: '/qr/scan',
          name: 'qr-scanner',
          builder: (_, __) => const QRScannerPage()),

      // ── Main Shell (bottom nav bar) ─────────────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
              path: '/home',
              name: 'home',
              builder: (_, __) => const HomePage()),
          GoRoute(
              path: '/items',
              name: 'items',
              builder: (_, __) => const ItemsListPage()),
          GoRoute(
              path: '/borrow',
              name: 'borrow',
              builder: (_, __) => const BorrowRequestsPage()),
          GoRoute(
              path: '/transactions',
              name: 'transactions',
              builder: (_, __) => const TransactionsPage()),
          GoRoute(
              path: '/profile',
              name: 'profile',
              builder: (_, __) => const ProfilePage()),
          GoRoute(
              path: '/notifications',
              name: 'notifications',
              builder: (_, __) => const NotificationsPage()),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
