import 'package:flutter/material.dart';

enum AppTheme { classicLight, softBlue, deepDark, midnight }

ThemeData getAppTheme(AppTheme selection) {
  switch (selection) {
    case AppTheme.classicLight:
      return _buildTheme(Brightness.light, Colors.blueAccent, Colors.white);
    case AppTheme.softBlue:
      return _buildTheme(Brightness.light, Colors.cyan, const Color(0xFFF0F7F9));
    case AppTheme.deepDark:
      return _buildTheme(Brightness.dark, Colors.indigoAccent, const Color(0xFF121212));
    case AppTheme.midnight:
      return _buildTheme(Brightness.dark, Colors.deepPurpleAccent, Colors.black);
  }
}

ThemeData _buildTheme(Brightness brightness, Color primary, Color bg) {
  return ThemeData(
    brightness: brightness,
    primaryColor: primary,
    scaffoldBackgroundColor: bg,
    
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: brightness == Brightness.light ? Colors.black : Colors.white,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(
        color: brightness == Brightness.light ? Colors.black : Colors.white,
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      filled: true,
      fillColor: brightness == Brightness.light ? const Color(0xFFF3F4F6) : Colors.grey.shade800,
      labelStyle: TextStyle(color: Colors.grey.shade600),
    ),
    
    cardTheme: CardThemeData(
      color: brightness == Brightness.light ? Colors.white : Colors.grey.shade900,
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}
