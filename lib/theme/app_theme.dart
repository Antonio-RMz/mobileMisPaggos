import 'package:flutter/material.dart';

class AppTheme {
  // Paleta Stripe / Linear (B2B Premium)
  static const Color slateBlue = Color(0xFF0F172A); // Azul oscuro casi negro para fondos fuertes y textos
  static const Color turquoise = Color(0xFF2DD4BF); // Turquesa suave como accent color
  static const Color backgroundLight = Color(0xFFF1F5F9); // Fondo gris claro (slate-100) para dar contraste
  static const Color cardHighlight = Color(0xFFF1F5F9); // Fondo sutil para tags
  static const Color whiteColor = Colors.white;
  
  static const Color textDark = Color(0xFF0F172A);
  static const Color textLight = Color(0xFF64748B);

  static const Color primary = slateBlue;
  static const Color accent = turquoise;
  static const Color background = backgroundLight;
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: slateBlue,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: slateBlue,
        secondary: turquoise,
        surface: whiteColor,
      ),
      fontFamily: 'Inter', // Linear/Stripe style font

      appBarTheme: const AppBarTheme(
        backgroundColor: whiteColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textDark),
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: slateBlue,
        foregroundColor: whiteColor,
        elevation: 4,
      ),

      cardTheme: CardTheme(
        color: whiteColor,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.2),
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
        ),
        margin: const EdgeInsets.only(bottom: 16),
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textDark),
        bodyMedium: TextStyle(color: textDark),
        titleLarge: TextStyle(color: textDark, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: textDark, fontWeight: FontWeight.w700),
      ),

      inputDecorationTheme: InputDecorationTheme(
        fillColor: whiteColor,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: textLight),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: turquoise, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: error, width: 2),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: slateBlue,
          foregroundColor: whiteColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15, 
            fontWeight: FontWeight.w600, 
            letterSpacing: -0.2,
          ),
        ),
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: whiteColor,
        headerBackgroundColor: slateBlue,
        headerForegroundColor: whiteColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        dayStyle: const TextStyle(fontWeight: FontWeight.w500),
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return turquoise;
          return Colors.transparent;
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return slateBlue;
          return turquoise;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return turquoise;
          return Colors.transparent;
        }),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return slateBlue;
          return textDark;
        }),
      ),
    );
  }
}
