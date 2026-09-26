/// LendLoop — Main Application Entry Point
///
/// Initializes:
/// - Firebase (Auth, Messaging)
/// - Riverpod ProviderScope
/// - GoRouter navigation
/// - App theme
/// - Push handling (foreground banner, data refresh, tap-to-open)

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lendloop/core/theme/app_theme.dart';
import 'package:lendloop/models/user_model.dart';
import 'package:lendloop/providers/auth_provider.dart';
import 'package:lendloop/routes/app_router.dart';
import 'package:lendloop/services/notification_service.dart';
import 'package:lendloop/services/push_sync.dart';

final _rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize FCM
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('FCM Initialization error: $e');
  }

  runApp(
    const ProviderScope(
      child: LendLoopApp(),
    ),
  );
}

class LendLoopApp extends ConsumerStatefulWidget {
  const LendLoopApp({super.key});

  @override
  ConsumerState<LendLoopApp> createState() => _LendLoopAppState();
}

class _LendLoopAppState extends ConsumerState<LendLoopApp> {
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;

  /// A tapped push can arrive before the stored session has finished loading
  /// (cold start from the notification tray); hold its route until it has.
  String? _pendingRoute;

  @override
  void initState() {
    super.initState();
    _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundPush);
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(_onPushTapped);
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _onPushTapped(message);
    });

    ref.listenManual<AsyncValue<UserModel?>>(currentUserProvider, (previous, next) {
      final user = next.valueOrNull;
      if (user == null) return;
      if (previous?.valueOrNull?.id != user.id) {
        NotificationService.registerForCurrentUser();
      }
      _openPendingRoute();
    });
  }

  @override
  void dispose() {
    _foregroundSub?.cancel();
    _openedSub?.cancel();
    super.dispose();
  }

  void _onForegroundPush(RemoteMessage message) {
    // Android doesn't display pushes while the app is open, so this is the
    // only feedback the user gets — refresh first, then tell them why.
    refreshForPush(ref);
    final notification = message.notification;
    if (notification == null) return;
    final route = routeForPush(message.data);
    _rootMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.title != null)
              Text(notification.title!, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (notification.body != null) Text(notification.body!),
          ],
        ),
        action: SnackBarAction(label: 'View', onPressed: () => _open(route)),
      ));
  }

  void _onPushTapped(RemoteMessage message) {
    refreshForPush(ref);
    _pendingRoute = routeForPush(message.data);
    _openPendingRoute();
  }

  void _openPendingRoute() {
    final route = _pendingRoute;
    if (route == null || ref.read(currentUserProvider).valueOrNull == null) return;
    _pendingRoute = null;
    _open(route);
  }

  void _open(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(appRouterProvider).push(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'LendLoop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      scaffoldMessengerKey: _rootMessengerKey,
      routerConfig: router,
    );
  }
}
