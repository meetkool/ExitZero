import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// All brand colors extracted from the ExitZero HTML prototype.
class AppColors {
  AppColors._(); // Prevent instantiation

  static const Color dark = Color(0xFF003049);
  static const Color deep = Color(0xFF001E2E);
  static const Color teal = Color(0xFF126782);
  static const Color burnt = Color(0xFFE75414);
  static const Color orange = Color(0xFFF77F00);
  static const Color cream = Color(0xFFF8F5E4);
  
  static const Color background = deep; // Alias for backward compatibility if needed

  // Derived / utility colors
  static const Color tealLight = Color(0xFF167CA0);
  static const Color inputBorder = cream;
}

/// Centralized theme for the entire app.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleFonts.robotoFlex().fontFamily,
      textTheme: GoogleFonts.robotoFlexTextTheme().apply(
        bodyColor: AppColors.cream,
        displayColor: AppColors.cream,
      ),
      scaffoldBackgroundColor: Colors.black, // Dashboard background is black
      colorScheme: const ColorScheme.dark(
        primary: AppColors.orange,
        secondary: AppColors.burnt,
        surface: AppColors.deep,
        onPrimary: AppColors.cream,
        onSecondary: AppColors.cream,
        onSurface: AppColors.cream,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.cream),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.teal,
        hintStyle: const TextStyle(color: AppColors.cream, fontSize: 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cream, width: 2),
        ),
      ),
    );
  }
}
