import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFF007AFF); // iOS Blue
  static const accentColor = Color(0xFF5856D6); // iOS Purple
  static const surfaceColor = Colors.white;
  static const backgroundColor = Color(
    0xFFF2F2F7,
  ); // iOS System Grouped Background
  static const errorColor = Color(0xFFFF3B30); // iOS Red

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: backgroundColor,
    fontFamily: '.SF Pro Text',
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: accentColor,
      surface: surfaceColor,
      background: backgroundColor,
      error: errorColor,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: backgroundColor,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.black,
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
    ),
    // cardTheme: CardTheme(
    //   elevation: 0,
    //   shape: RoundedRectangleBorder(
    //     borderRadius: BorderRadius.circular(10),
    //   ),
    //   color: surfaceColor,
    //   margin: EdgeInsets.zero,
    // ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: const Color(0xFFE3E3E8), // iOS Input Fill
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: TextStyle(color: Colors.grey.shade500),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFC6C6C8), // iOS Separator
      thickness: 0.5, // Hairline
    ),
  );
}
