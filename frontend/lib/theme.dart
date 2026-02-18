import 'package:flutter/material.dart';

ThemeData appTheme() {
  return ThemeData(
    // Switch to Light Mode
    brightness: Brightness.light,
    primaryColor: Colors.blueAccent,
    scaffoldBackgroundColor: Colors.white,

    // Make the App Bar White with Black Text
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black, //Sets title and icon color to black
      elevation: 0, //Removes the shadow for a flat, modern look
      centerTitle: true,
      iconTheme: IconThemeData(color: Colors.black)
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
        borderSide: const BorderSide(color: Colors.blueAccent, width:2),
      ),
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      labelStyle: TextStyle(color: Colors.grey.shade600),
    ),

    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}
