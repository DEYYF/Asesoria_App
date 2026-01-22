import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFF007AFF); // iOS Blue
  static const accentColor = Color(0xFF5856D6); // iOS Purple
  static const surfaceColor = Colors.white;
  static const backgroundColor = Color(
    0xFFF2F2F7,
  ); // iOS System Grouped Background
  static const errorColor = Color(0xFFFF3B30); // iOS Red

  static ThemeData getTheme(Color primaryColor, {bool isDark = false}) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: isDark ? Brightness.dark : Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: primaryColor,
      canvasColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF000000)
          : backgroundColor,
      fontFamily: '.SF Pro Text',
      colorScheme: baseScheme.copyWith(
        primary: primaryColor,
        surface: isDark ? const Color(0xFF1C1C1E) : surfaceColor,
        error: errorColor,
        surfaceContainerHighest: isDark
            ? const Color(0xFF2C2C2E)
            : const Color(0xFFE5E5EA),
        secondary: primaryColor,
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
        bodyMedium: TextStyle(
          color: isDark ? const Color(0xFFE5E5EA) : Colors.black87,
        ),
        bodySmall: TextStyle(
          color: isDark ? const Color(0xFF8E8E93) : Colors.grey.shade600,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF000000) : backgroundColor,
        scrolledUnderElevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: isDark
            ? const Color(0xFF8E8E93)
            : const Color(0xFF8E8E93),
        indicatorColor: primaryColor,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: isDark
            ? const Color(0xFF38383A)
            : const Color(0xFFC6C6C8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE3E3E8),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF8E8E93) : Colors.grey.shade500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF38383A) : const Color(0xFFC6C6C8),
        thickness: 0.5,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
      ),
    );
  }
}
