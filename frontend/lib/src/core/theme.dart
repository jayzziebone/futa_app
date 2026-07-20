import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FutaTheme {
  // Brand color tokens
  static const Color blueDark = Color(0xFF232C87); // Brand deep indigo from logo
  static const Color blueIndigo = Color(0xFF3944AD); // Brand vibrant indigo from logo
  static const Color emeraldGreen = Color(0xFFFD992A); // Brand gold/orange from logo (acting as secondary accent)
  static const Color emeraldLight = Color(0xFFFFF7ED); // Light gold/orange background tint
  static const Color backgroundLight = Color(0xFFF8FAFC); // Modern slate background
  
  // Status Color Tokens
  static const Color success = Color(0xFF059669);
  static const Color partial = Color(0xFFFCD34D); // Soft gold/yellow
  static const Color error = Color(0xFFF65C50); // Brand coral/red from logo
  static const Color textDark = Color(0xFF1E293B);
  static const Color textLight = Color(0xFF64748B);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: blueDark,
      colorScheme: const ColorScheme.light(
        primary: blueDark,
        secondary: emeraldGreen,
        background: backgroundLight,
        surface: Colors.white,
        error: error,
      ),
      scaffoldBackgroundColor: backgroundLight,
      textTheme: GoogleFonts.interTextTheme(const TextTheme(
        headlineLarge: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, color: textDark),
        headlineMedium: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: textDark),
        titleLarge: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, color: textDark),
        bodyLarge: TextStyle(fontSize: 16.0, color: textDark),
        bodyMedium: TextStyle(fontSize: 14.0, color: textLight),
      )),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: textDark),
        titleTextStyle: TextStyle(color: textDark, fontSize: 18, fontWeight: FontWeight.bold),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blueDark, // Matches brand primary deep indigo
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          textStyle: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: emeraldGreen, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textLight, fontSize: 14.0),
      ),
    );
  }
}
