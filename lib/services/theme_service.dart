import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'app_theme';
  static const String _languageKey = 'app_language';
  
  static const String _soundEffectsEnabledKey = 'sound_effects_enabled';
  static const String _soundEffectsVolumeKey = 'sound_effects_volume';
  static const String _pronunciationVolumeKey = 'pronunciation_volume';
  static const String _audioQualityKey = 'audio_quality';
  static const String _dailyQuizTargetKey = 'daily_quiz_target';
  static const String _weeklyGoalKey = 'weekly_goal';

  bool _isDarkMode = false;
  String _currentLanguage = 'English';
  
  bool _soundEffectsEnabled = true;
  double _soundEffectsVolume = 1.0;
  double _pronunciationVolume = 1.0;
  String _audioQuality = 'Standard';
  int _dailyQuizTarget = 1;
  int _weeklyGoal = 5;

  bool get isDarkMode => _isDarkMode;
  String get currentLanguage => _currentLanguage;
  
  bool get soundEffectsEnabled => _soundEffectsEnabled;
  double get soundEffectsVolume => _soundEffectsVolume;
  double get pronunciationVolume => _pronunciationVolume;
  String get audioQuality => _audioQuality;
  int get dailyQuizTarget => _dailyQuizTarget;
  int get weeklyGoal => _weeklyGoal;
  
  ThemeService() {
    _loadThemePreference();
  }
  
  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    _currentLanguage = prefs.getString(_languageKey) ?? 'English';
    _soundEffectsEnabled = prefs.getBool(_soundEffectsEnabledKey) ?? true;
    _soundEffectsVolume = prefs.getDouble(_soundEffectsVolumeKey) ?? 1.0;
    _pronunciationVolume = prefs.getDouble(_pronunciationVolumeKey) ?? 1.0;
    _audioQuality = prefs.getString(_audioQualityKey) ?? 'Standard';
    _dailyQuizTarget = prefs.getInt(_dailyQuizTargetKey) ?? 1;
    _weeklyGoal = prefs.getInt(_weeklyGoalKey) ?? 5;
    notifyListeners();
  }
  
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }
  
  Future<void> setLanguage(String language) async {
    _currentLanguage = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
    notifyListeners();
  }

  Future<void> setSoundEffectsEnabled(bool value) async {
    _soundEffectsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEffectsEnabledKey, value);
    notifyListeners();
  }

  Future<void> setSoundEffectsVolume(double value) async {
    _soundEffectsVolume = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_soundEffectsVolumeKey, value);
    notifyListeners();
  }

  Future<void> setPronunciationVolume(double value) async {
    _pronunciationVolume = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_pronunciationVolumeKey, value);
    notifyListeners();
  }

  Future<void> setAudioQuality(String value) async {
    _audioQuality = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_audioQualityKey, value);
    notifyListeners();
  }

  Future<void> setDailyQuizTarget(int value) async {
    _dailyQuizTarget = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyQuizTargetKey, value);
    notifyListeners();
  }

  Future<void> setWeeklyGoal(int value) async {
    _weeklyGoal = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_weeklyGoalKey, value);
    notifyListeners();
  }
  
  ThemeData get lightTheme => ThemeData(
    primarySwatch: Colors.blue,
    primaryColor: const Color(0xFF2C97DD),
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    brightness: Brightness.light,
    useMaterial3: true,
    textTheme: GoogleFonts.poppinsTextTheme().copyWith(
      headlineLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF2C97DD),
        fontFamilyFallback: const ['Jomolhari'],
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF2C97DD),
        fontFamilyFallback: const ['Jomolhari'],
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF2C97DD),
        fontFamilyFallback: const ['Jomolhari'],
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: const Color(0xFF333333),
        fontFamilyFallback: const ['Jomolhari'],
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: const Color(0xFF333333),
        fontFamilyFallback: const ['Jomolhari'],
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF2C97DD),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        fontFamilyFallback: const ['Jomolhari'],
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2C97DD),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamilyFallback: const ['Jomolhari'],
        ),
      ),
    ),
  );
  
  ThemeData get darkTheme => ThemeData(
    primarySwatch: Colors.blue,
    primaryColor: const Color(0xFF2C97DD),
    scaffoldBackgroundColor: const Color(0xFF1A1A1A),
    brightness: Brightness.dark,
    useMaterial3: true,
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).copyWith(
      headlineLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF2C97DD),
        fontFamilyFallback: const ['Jomolhari'],
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF2C97DD),
        fontFamilyFallback: const ['Jomolhari'],
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF2C97DD),
        fontFamilyFallback: const ['Jomolhari'],
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: Colors.white,
        fontFamilyFallback: const ['Jomolhari'],
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Colors.white70,
        fontFamilyFallback: const ['Jomolhari'],
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF2C97DD),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        fontFamilyFallback: const ['Jomolhari'],
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF2D2D2D),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2C97DD),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamilyFallback: const ['Jomolhari'],
        ),
      ),
    ),
  );
}
