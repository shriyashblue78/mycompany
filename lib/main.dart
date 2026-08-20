import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

import 'features/notifications/presentation/providers/notifications_provider.dart';

import 'features/auth/presentation/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Initialize global notification click handlers on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).initNotifications();
    });

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isLoggedIn && next.user != null) {
        if (next.user!.role != 'super_admin') {
          ref.read(notificationServiceProvider).setupFCM(
            next.user!.companyId,
            next.user!.employeeId,
          );
        }

        // Handle routing for pending notification click from terminated state
        final pendingRoute = ref.read(pendingNotificationRouteProvider);
        if (pendingRoute != null) {
          ref.read(pendingNotificationRouteProvider.notifier).state = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(routerProvider).push(pendingRoute);
          });
        }
      }
    });

    final bool isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);
    final themeMode = isMobile ? ThemeMode.light : ThemeMode.system;

    if (!authState.isInitialized) {
      return MaterialApp(
        title: 'MyCompany',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        },
      );
    }

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'MyCompany',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
