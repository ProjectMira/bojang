import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'services/app_config.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'services/progress_service.dart';
import 'services/google_auth_service.dart';
import 'services/api_service.dart';

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

  try {
    if (!kIsWeb) {
      await NotificationService().init();
    }
    await GoogleAuthService().initialize();
    await ApiService().initialize();
  } catch (e) {
    debugPrint('Service initialization failed: $e');
  }

  runApp(const MyApp());
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
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
