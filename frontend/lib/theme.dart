import 'package:flutter/material.dart';

enum AppTheme {
  classicLight,
  softLight,
  darkBlue,
  midnightDark,
}

ThemeData getAppTheme(AppTheme theme) {
  switch (theme) {
    case AppTheme.classicLight:
      return ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF2563EB), // Classic Blue
        scaffoldBackgroundColor: Colors.white,
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        dividerColor: Colors.grey.shade300,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      );

    case AppTheme.softLight:
      return ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF3B82F6), // Softer Blue
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Softer White/Slate
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.04),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        dividerColor: const Color(0xFFE2E8F0),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8FAFC),
          foregroundColor: Color(0xFF334155),
          elevation: 0,
        ),
      );

    case AppTheme.darkBlue:
      return ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF60A5FA), // Light Accent Blue
        scaffoldBackgroundColor: const Color(0xFF1E293B), // Lighter Black/Slate
        cardTheme: CardThemeData(
          color: const Color(0xFF334155),
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        dividerColor: const Color(0xFF475569),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      );

    case AppTheme.midnightDark:
      return ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF818CF8), // Indigo Accent
        scaffoldBackgroundColor: const Color(0xFF0B0F19), // Very Dark Black/Navy
        cardTheme: CardThemeData(
          color: const Color(0xFF111827),
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        dividerColor: const Color(0xFF1F2937),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0F19),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      );
  }
}