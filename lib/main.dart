import 'screens/script/script_routes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'screens/dialogue_player_screen.dart';
import 'screens/path_navigation.dart';
import 'screens/splash_screen.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'services/analytics.dart';
import 'services/app_check_service.dart';
import 'services/crash_reporting.dart';
import 'services/feature_flags.dart';
import 'services/location_service.dart';
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

/// `host:port` of a Firebase Auth emulator (end-to-end tests only).
const String _authEmulator = String.fromEnvironment('BOJANG_AUTH_EMULATOR');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initServices();
  runApp(const PostHogWidget(child: MyApp()));
  startBackgroundServices();
}

/// Everything main() sets up before the first frame. Split out so the
/// end-to-end suite (integration_test/) starts the app the same way.
Future<void> initServices() async {
  // Initialize services
  if (AppConfig.firebaseEnabled) {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase initialization skipped: $e');
    }
    if (_authEmulator.isNotEmpty && Firebase.apps.isNotEmpty) {
      final parts = _authEmulator.split(':');
      await firebase_auth.FirebaseAuth.instance
          .useAuthEmulator(parts[0], int.parse(parts[1]));
    }
  } else {
    debugPrint('Firebase initialization skipped: iOS config disabled');
  }

  // App Check before any backend or Firebase Auth call, so they carry a token.
  await AppCheckService.init();
  // Crashlytics' error handlers before Analytics, so PostHog's wrap them.
  await CrashReporting.init(collect: true);

  // Server config (/v1/config): the cached one now, revalidated in the
  // background. Before Analytics, so its event blocklist and sampling cover
  // the first events too. Also feeds kill switches and the update wall.
  await FeatureFlags.instance.init();

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
}

/// Work main() starts once the app is on screen.
void startBackgroundServices() {
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
    // Approximate location, if the learner turned it on (at most daily).
    unawaited(LocationService.instance.refreshIfAllowed());
  }
}

/// The app's single `onGenerateRoute` chain: each feature's routes are
/// tried in turn and the first that knows the name builds it.
Route<dynamic>? appOnGenerateRoute(RouteSettings settings) {
  final pathRoute = PathRoutes.onGenerateRoute(settings);
  if (pathRoute != null) return pathRoute;
  final scriptBuilder = ScriptRoutes.all[settings.name];
  if (scriptBuilder != null) {
    return MaterialPageRoute(builder: scriptBuilder, settings: settings);
  }
  return DialoguePlayerScreen.onGenerateRoute(settings);
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
            // One route chain: learning-path node routes, the script course
            // and /dialogue/<id>.
            onGenerateRoute: appOnGenerateRoute,
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
