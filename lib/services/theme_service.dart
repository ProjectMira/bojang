import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'app_theme';
  static const String _languageKey = 'app_language';
  
  bool _isDarkMode = false;
  String _currentLanguage = 'English';
  
  bool get isDarkMode => _isDarkMode;
  String get currentLanguage => _currentLanguage;
  
  ThemeService() {
    _loadThemePreference();
  }
  
  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    _currentLanguage = prefs.getString(_languageKey) ?? 'English';
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
  
  ThemeData get lightTheme => ThemeData(
    primarySwatch: Colors.blue,
    primaryColor: const Color(0xFF2C97DD),
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    brightness: Brightness.light,
    useMaterial3: true,
    textTheme: GoogleFonts.comfortaaTextTheme().copyWith(
      headlineLarge: GoogleFonts.comfortaa(
        fontSize: 32,
        fontWeight: FontWeight.w700, // Feather Bold equivalent
        color: const Color(0xFF2C97DD),
      ),
      headlineMedium: GoogleFonts.comfortaa(
        fontSize: 24,
        fontWeight: FontWeight.w700, // Feather Bold equivalent
        color: const Color(0xFF2C97DD),
      ),
      headlineSmall: GoogleFonts.comfortaa(
        fontSize: 20,
        fontWeight: FontWeight.w700, // Feather Bold equivalent
        color: const Color(0xFF2C97DD),
      ),
      bodyLarge: GoogleFonts.comfortaa(
        fontSize: 16,
        fontWeight: FontWeight.w400, // Feather regular equivalent
        color: const Color(0xFF333333),
      ),
      bodyMedium: GoogleFonts.comfortaa(
        fontSize: 14,
        fontWeight: FontWeight.w400, // Feather regular equivalent
        color: const Color(0xFF333333),
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
        textStyle: GoogleFonts.comfortaa(
          fontSize: 16,
          fontWeight: FontWeight.w700, // Feather Bold equivalent
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
    textTheme: GoogleFonts.comfortaaTextTheme(ThemeData.dark().textTheme).copyWith(
      headlineLarge: GoogleFonts.comfortaa(
        fontSize: 32,
        fontWeight: FontWeight.w700, // Feather Bold equivalent
        color: const Color(0xFF2C97DD),
      ),
      headlineMedium: GoogleFonts.comfortaa(
        fontSize: 24,
        fontWeight: FontWeight.w700, // Feather Bold equivalent
        color: const Color(0xFF2C97DD),
      ),
      headlineSmall: GoogleFonts.comfortaa(
        fontSize: 20,
        fontWeight: FontWeight.w700, // Feather Bold equivalent
        color: const Color(0xFF2C97DD),
      ),
      bodyLarge: GoogleFonts.comfortaa(
        fontSize: 16,
        fontWeight: FontWeight.w400, // Feather regular equivalent
        color: Colors.white,
      ),
      bodyMedium: GoogleFonts.comfortaa(
        fontSize: 14,
        fontWeight: FontWeight.w400, // Feather regular equivalent
        color: Colors.white70,
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
        textStyle: GoogleFonts.comfortaa(
          fontSize: 16,
          fontWeight: FontWeight.w700, // Feather Bold equivalent
        ),
      ),
    ),
  );
}
