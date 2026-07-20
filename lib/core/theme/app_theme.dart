import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFF1A73E8);
  static const secondaryColor = Color(0xFF00BFA5);
  static const backgroundColor = Color(0xFFF8F9FA);
  static const surfaceColor = Colors.white;
  static const errorColor = Color(0xFFD93025);

  static const cyberDeepNavy = Color(0xFF020817);
  static const cyberCyan = Color(0xFF00E5FF);
  static const cyberBlue = Color(0xFF00B0FF);
  static const cyberGlass = Color(0x1AFFFFFF);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: cyberCyan,
        primary: cyberCyan,
        secondary: cyberBlue,
        surface: cyberDeepNavy,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: cyberDeepNavy,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cyberCyan.withValues(alpha: 0.2)),
        ),
        color: cyberGlass,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 1,
        ),
        bodyLarge: TextStyle(color: Colors.white70),
        bodyMedium: TextStyle(color: Colors.white60),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF202124),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF202124),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        color: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF202124),
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF202124),
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF3C4043),
        ),
      ),
    );
  }
}
