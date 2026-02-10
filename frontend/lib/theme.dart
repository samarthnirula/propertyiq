import 'package:flutter/material.dart';

ThemeData appTheme() {
  return ThemeData.dark().copyWith(
    scaffoldBackgroundColor: const Color(0xFF0F0F14),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      backgroundColor: Color(0xFF151520),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
