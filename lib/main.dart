import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'services/analytics.dart';
import 'services/app_check_service.dart';
import 'services/crash_reporting.dart';
import 'services/push_service.dart';
import 'services/remote_settings.dart';
import 'services/app_config.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'services/progress_service.dart';
import 'services/google_auth_service.dart';
import 'services/api_service.dart';
import 'widgets/interaction_capture.dart';
import 'widgets/update_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  if (AppConfig.firebaseEnabled) {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase initialization skipped: $e');
    }
  } else {
    debugPrint('Firebase initialization skipped: iOS config disabled');
  }

  // App Check before any backend or Firebase Auth call, so they carry a token.
  await AppCheckService.init();
  // Crashlytics' error handlers before Analytics, so PostHog's wrap them.
  await CrashReporting.init(collect: true);

  // Analytics first, so sign-in restored during start-up is attributed.
  // It also applies the "Share usage analytics" switch to Crashlytics.
  await Analytics.init();
  // Remote Config: cached values now, fresh ones in the background.
  await RemoteSettings.init();

  try {
    await GoogleAuthService().initialize();
    await ApiService().initialize();
  } catch (e) {
    debugPrint('Service initialization failed: $e');
  }

  runApp(const PostHogWidget(child: MyApp()));

  // Set up reminders only once the app is on screen: on a fresh install this
  // shows iOS's notification permission prompt, and awaiting it before
  // runApp left new learners on a blank screen until they answered.
  // Push notifications follow, once that prompt has been answered.
  if (!kIsWeb) {
    unawaited(
      NotificationService()
          .init()
          .catchError((Object e) => debugPrint('Notification setup failed: $e'))
          .whenComplete(() => PushService.instance.init()),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => ProgressService()),
        Provider<GoogleAuthService>(create: (_) => GoogleAuthService()),
        Provider<ApiService>(create: (_) => ApiService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            title: 'Bojang - Tibetan Learning',
            theme: themeService.lightTheme,
            darkTheme: themeService.darkTheme,
            themeMode:
                themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const SplashScreen(),
            // Above the navigator, so an out-of-date install cannot get
            // past the update notice by any route, and every tap, swipe and
            // scroll on any route, dialog or sheet is recorded.
            builder: (context, child) => InteractionCapture(
              child: UpdateGate(child: child ?? const SizedBox.shrink()),
            ),
            navigatorObservers: [Analytics.observer, Analytics.screenObserver],
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
