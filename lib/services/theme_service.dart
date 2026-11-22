import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/lesson_style.dart';
import '../models/romanisation.dart';
import 'analytics.dart';
import 'pronunciation_player.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';

class ThemeService extends ChangeNotifier {
  // Sliders call their setter on every drag tick; only the value the learner
  // settles on is reported.
  final Map<String, Timer> _settingTimers = {};

  void _reportSetting(String setting, Object value, {bool debounce = false}) {
    void send() {
      Analytics.track('setting_changed', {'setting': setting, 'value': value});
      Analytics.setPersonProperties({setting: value});
      if (setting == 'voice' || setting == 'lesson_style') {
        Analytics.register(setting, value);
      }
    }

    _settingTimers.remove(setting)?.cancel();
    if (!debounce) return send();
    _settingTimers[setting] = Timer(const Duration(milliseconds: 800), send);
  }

  void _reportLoadedSettings() {
    Analytics.setPersonProperties({
      'dark_mode': _isDarkMode,
      'language': _currentLanguage,
      'lesson_style': _lessonStyle.name,
      'voice': _pronunciationVoice,
      'transliteration': _transliterationMode.name,
      'sound_effects': _soundEffectsEnabled,
      'daily_target': _dailyQuizTarget,
      'weekly_goal': _weeklyGoal,
      'animations': _animationPreference.name,
    });
    Analytics.register('voice', _pronunciationVoice);
    Analytics.register('lesson_style', _lessonStyle.name);
  }

  static const String _themeKey = 'app_theme';
  static const String _languageKey = 'app_language';

  static const String _soundEffectsEnabledKey = 'sound_effects_enabled';
  static const String _soundEffectsVolumeKey = 'sound_effects_volume';
  static const String _pronunciationVolumeKey = 'pronunciation_volume';
  static const String _audioQualityKey = 'audio_quality';
  static const String _pronunciationVoiceKey = 'pronunciation_voice';
  static const String _dailyQuizTargetKey = 'daily_quiz_target';
  static const String _weeklyGoalKey = 'weekly_goal';
  static const String _lessonStyleKey = 'lesson_style';
  static const String _transliterationModeKey = 'transliteration_mode';
  static const String _animationPreferenceKey = 'animation_preference';

  bool _isDarkMode = false;
  String _currentLanguage = 'English';

  bool _soundEffectsEnabled = true;
  double _soundEffectsVolume = 1.0;
  double _pronunciationVolume = 1.0;
  String _audioQuality = 'Standard';
  String _pronunciationVoice = PronunciationVoices.defaultVoice;
  int _dailyQuizTarget = 1;
  int _weeklyGoal = 5;
  LessonStyle _lessonStyle = LessonStyle.mixed;
  TransliterationMode _transliterationMode = TransliterationMode.defaultMode;
  AnimationPreference _animationPreference = AnimationPreference.full;
  bool _isLowRamDevice = false;

  bool get isDarkMode => _isDarkMode;
  String get currentLanguage => _currentLanguage;

  bool get soundEffectsEnabled => _soundEffectsEnabled;
  double get soundEffectsVolume => _soundEffectsVolume;
  double get pronunciationVolume => _pronunciationVolume;
  String get audioQuality => _audioQuality;
  String get pronunciationVoice => _pronunciationVoice;
  int get dailyQuizTarget => _dailyQuizTarget;
  int get weeklyGoal => _weeklyGoal;
  LessonStyle get lessonStyle => _lessonStyle;
  TransliterationMode get transliterationMode => _transliterationMode;

  /// Settings > Animations. Read the effective level with
  /// `Motion.of(context)`, which also folds in the system setting.
  AnimationPreference get animationPreference => _animationPreference;

  /// Set once at start-up from the device's reported RAM.
  bool get isLowRamDevice => _isLowRamDevice;

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
    final voice = prefs.getString(_pronunciationVoiceKey);
    _pronunciationVoice =
        PronunciationVoices.labels.containsKey(voice)
            ? voice!
            : PronunciationVoices.defaultVoice;
    _dailyQuizTarget = prefs.getInt(_dailyQuizTargetKey) ?? 1;
    _weeklyGoal = prefs.getInt(_weeklyGoalKey) ?? 5;
    _lessonStyle = LessonStyle.fromId(prefs.getString(_lessonStyleKey));
    _transliterationMode = TransliterationMode.fromId(
      prefs.getString(_transliterationModeKey),
    );
    _animationPreference = AnimationPreference.fromId(
      prefs.getString(_animationPreferenceKey),
    );
    _reportLoadedSettings();
    notifyListeners();
    unawaited(_detectLowRam());
  }

  /// device_info_plus is already a dependency, so this costs one platform
  /// call. Any failure (web, desktop, tests) leaves motion at full.
  Future<void> _detectLowRam() async {
    if (kIsWeb) return;
    try {
      final info = DeviceInfoPlugin();
      bool lowRam = false;
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final android = await info.androidInfo;
          lowRam = Motion.isLowRam(
            physicalRamMb: android.physicalRamSize,
            osLowRamFlag: android.isLowRamDevice,
          );
        case TargetPlatform.iOS:
          final ios = await info.iosInfo;
          lowRam = Motion.isLowRam(physicalRamMb: ios.physicalRamSize);
        default:
          return;
      }
      if (lowRam == _isLowRamDevice) return;
      _isLowRamDevice = lowRam;
      Analytics.setPersonProperties({'low_ram_device': lowRam});
      notifyListeners();
    } catch (_) {
      // No plugin on this platform: keep full motion.
    }
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    _reportSetting('dark_mode', _isDarkMode);
    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    _currentLanguage = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
    _reportSetting('language', language);
    notifyListeners();
  }

  Future<void> setLessonStyle(LessonStyle value) async {
    _lessonStyle = value;
    _reportSetting('lesson_style', value.name);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lessonStyleKey, value.name);
  }

  Future<void> setTransliterationMode(TransliterationMode value) async {
    _transliterationMode = value;
    _reportSetting('transliteration', value.name);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_transliterationModeKey, value.name);
  }

  Future<void> setAnimationPreference(AnimationPreference value) async {
    _animationPreference = value;
    _reportSetting('animations', value.name);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_animationPreferenceKey, value.name);
  }

  Future<void> setSoundEffectsEnabled(bool value) async {
    _soundEffectsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEffectsEnabledKey, value);
    _reportSetting('sound_effects', value);
    notifyListeners();
  }

  Future<void> setSoundEffectsVolume(double value) async {
    _soundEffectsVolume = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_soundEffectsVolumeKey, value);
    _reportSetting('sound_effects_volume', value, debounce: true);
    notifyListeners();
  }

  Future<void> setPronunciationVolume(double value) async {
    _pronunciationVolume = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_pronunciationVolumeKey, value);
    _reportSetting('pronunciation_volume', value, debounce: true);
    notifyListeners();
  }

  Future<void> setPronunciationVoice(String value) async {
    if (!PronunciationVoices.labels.containsKey(value)) return;
    _pronunciationVoice = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pronunciationVoiceKey, value);
    _reportSetting('voice', value);
    notifyListeners();
  }

  Future<void> setAudioQuality(String value) async {
    _audioQuality = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_audioQualityKey, value);
    _reportSetting('audio_quality', value);
    notifyListeners();
  }

  Future<void> setDailyQuizTarget(int value) async {
    _dailyQuizTarget = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyQuizTargetKey, value);
    _reportSetting('daily_target', value, debounce: true);
    notifyListeners();
  }

  Future<void> setWeeklyGoal(int value) async {
    _weeklyGoal = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_weeklyGoalKey, value);
    _reportSetting('weekly_goal', value, debounce: true);
    notifyListeners();
  }

  ThemeData get lightTheme => ThemeData(
    primarySwatch: Colors.blue,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    brightness: Brightness.light,
    useMaterial3: true,
    textTheme: GoogleFonts.poppinsTextTheme().copyWith(
      headlineLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: const Color(0xFF333333),
      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: const Color(0xFF333333),
      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ).copyWith(fontFamilyFallback: const ['Jomolhari']),
      ),
    ),
  );

  ThemeData get darkTheme => ThemeData(
    primarySwatch: Colors.blue,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: const Color(0xFF1A1A1A),
    brightness: Brightness.dark,
    useMaterial3: true,
    textTheme: GoogleFonts.poppinsTextTheme(
      ThemeData.dark().textTheme,
    ).copyWith(
      headlineLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: Colors.white,
      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Colors.white70,
      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ).copyWith(fontFamilyFallback: const ['Jomolhari']),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF2D2D2D),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ).copyWith(fontFamilyFallback: const ['Jomolhari']),
      ),
    ),
  );
}
