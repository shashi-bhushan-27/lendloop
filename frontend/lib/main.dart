/// LendLoop — Main Application Entry Point
///
/// Initializes:
/// - Firebase (Auth, Messaging)
/// - Riverpod ProviderScope
/// - GoRouter navigation
/// - App theme

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lendloop/core/theme/app_theme.dart';
import 'package:lendloop/routes/app_router.dart';
import 'package:lendloop/services/notification_service.dart';

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

class LendLoopApp extends ConsumerWidget {
  const LendLoopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'LendLoop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
