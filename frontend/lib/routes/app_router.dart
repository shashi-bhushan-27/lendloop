/// LendLoop Application Router
///
/// GoRouter configuration with:
/// - RouterNotifier (ChangeNotifier) that fires when currentUserProvider changes
/// - refreshListenable so GoRouter re-evaluates redirect on every auth change
/// - Named routes for type-safe navigation
/// - Shell route for bottom navigation bar

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lendloop/features/auth/presentation/pages/login_page.dart';
import 'package:lendloop/features/auth/presentation/pages/register_page.dart';
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
    ref.listen<AsyncValue>(currentUserProvider, (_, __) {
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
      // While loading (e.g. app startup checking stored token), don't redirect.
      final userState = ref.read(currentUserProvider);
      if (userState.isLoading) return null;

      final isAuthenticated = userState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      // Auth Routes
      GoRoute(path: '/login',    name: 'login',    builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', name: 'register', builder: (_, __) => const RegisterPage()),

      // Full-screen pages (no bottom nav) — must be listed before ShellRoute
      GoRoute(
        path: '/items/new',
        name: 'create-item',
        builder: (_, __) => const CreateItemPage(),
      ),
      GoRoute(
        path: '/items/:id',
        name: 'item-detail',
        builder: (_, state) => ItemDetailPage(itemId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/qr/scan', name: 'qr-scanner', builder: (_, __) => const QRScannerPage()),

      // Main Shell (bottom nav bar)
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home',          name: 'home',          builder: (_, __) => const HomePage()),
          GoRoute(path: '/items',         name: 'items',         builder: (_, __) => const ItemsListPage()),
          GoRoute(path: '/borrow',        name: 'borrow',        builder: (_, __) => const BorrowRequestsPage()),
          GoRoute(path: '/transactions',  name: 'transactions',  builder: (_, __) => const TransactionsPage()),
          GoRoute(path: '/profile',       name: 'profile',       builder: (_, __) => const ProfilePage()),
          GoRoute(path: '/notifications', name: 'notifications', builder: (_, __) => const NotificationsPage()),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
