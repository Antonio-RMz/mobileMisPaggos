import 'package:flutter/material.dart';

class AppTheme {
  // Breakpoint para detectar pantallas anchas/tablets (ancho en píxeles lógicos)
  static const double tabletBreakpoint = 500.0;

  // Paleta adaptada para mayor contraste y legibilidad
  static const Color slateBlue = Color(0xFF0F172A); // Azul oscuro
  static const Color turquoise = Color(0xFF0D9488); // Turquesa más oscuro para mejor contraste
  static const Color backgroundLight = Color(0xFFF1F5F9); 
  static const Color cardHighlight = Color(0xFFE2E8F0); 
  static const Color whiteColor = Colors.white;
  
  static const Color textDark = Color(0xFF0F172A);
  static const Color textLight = Color(0xFF334155); // Gris mucho más oscuro para legibilidad

  static const Color primary = slateBlue;
  static const Color accent = turquoise;
  static const Color background = backgroundLight;
  static const Color success = Color(0xFF059669); // Verde más oscuro
  static const Color error = Color(0xFFDC2626); // Rojo más oscuro

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: slateBlue,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: slateBlue,
        secondary: turquoise,
        surface: whiteColor,
      ),
      fontFamily: 'Inter',

      appBarTheme: const AppBarTheme(
        backgroundColor: whiteColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textDark, size: 28), // Iconos más grandes
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 22, // Título más grande
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: slateBlue,
        foregroundColor: whiteColor,
        elevation: 4,
        iconSize: 28, // Icono más grande
      ),

      cardTheme: CardThemeData(
        color: whiteColor,
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.15),
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // Bordes más suaves
          side: BorderSide(color: Colors.grey.withOpacity(0.4), width: 1), // Borde más visible
        ),
        margin: const EdgeInsets.only(bottom: 20),
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textDark, fontSize: 18), // Aumentado
        bodyMedium: TextStyle(color: textDark, fontSize: 16), // Aumentado
        titleLarge: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 24), // Aumentado
        titleMedium: TextStyle(color: textDark, fontWeight: FontWeight.w800, fontSize: 18), // Aumentado
      ),

      inputDecorationTheme: InputDecorationTheme(
        fillColor: whiteColor,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), // Más espacio
        labelStyle: const TextStyle(color: textLight, fontSize: 16, fontWeight: FontWeight.w600), // Label más legible
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 2), // Bordes más gruesos
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: turquoise, width: 3), // Focus muy evidente
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 3),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: slateBlue,
          foregroundColor: whiteColor,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24), // Botones grandes
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 18, // Texto de botón grande
            fontWeight: FontWeight.bold, 
            letterSpacing: 0,
          ),
        ),
      ),
      
      iconTheme: const IconThemeData(
        size: 28, // Iconos base más grandes
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: whiteColor,
        headerBackgroundColor: slateBlue,
        headerForegroundColor: whiteColor,
        rangePickerHeaderBackgroundColor: slateBlue,
        rangePickerHeaderForegroundColor: whiteColor,
        rangeSelectionBackgroundColor: turquoise.withOpacity(0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: cardHighlight, width: 1),
        ),
        headerHeadlineStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
        ),
        headerHelpStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        ),
        rangePickerHeaderHeadlineStyle: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          fontFamily: 'Inter',
        ),
        rangePickerHeaderHelpStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        ),
        dayStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
          fontFamily: 'Inter',
        ),
        weekdayStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: turquoise,
          fontFamily: 'Inter',
        ),
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return turquoise;
          return Colors.transparent;
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return whiteColor;
          return turquoise;
        }),
        todayBorder: const BorderSide(color: turquoise, width: 1.5),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return turquoise;
          return Colors.transparent;
        }),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return whiteColor;
          return textDark;
        }),
        dayShape: WidgetStateProperty.all(const CircleBorder()),
        confirmButtonStyle: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(turquoise),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        cancelButtonStyle: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(textLight),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
