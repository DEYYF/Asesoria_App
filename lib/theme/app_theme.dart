import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';

class AppTheme {
  static const primaryColor = Color(0xFF007AFF); // iOS Blue
  static const backgroundColor = Color(0xFFF2F2F7);
  static const errorColor = Color(0xFFFF3B30);

  static ThemeData getTheme(
    Color primaryColor, {
    bool isDark = false,
    ThemePreset preset = ThemePreset.classic,
  }) {
    Color scaffoldBg = isDark ? const Color(0xFF000000) : backgroundColor;
    Color surfaceColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    Color canvasColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    // Preset Overrides
    if (preset == ThemePreset.carbono && isDark) {
      scaffoldBg = const Color(0xFF0A0A0A); // Absolute Carbon
      surfaceColor = const Color(0xFF161616);
      canvasColor = const Color(0xFF161616);
    } else if (preset == ThemePreset.neon && isDark) {
      scaffoldBg = const Color(0xFF00050A); // Deep Night Blue
      surfaceColor = const Color(0xFF000F1F).withOpacity(0.8);
    }

    final baseScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: isDark ? Brightness.dark : Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: primaryColor,
      canvasColor: canvasColor,
      scaffoldBackgroundColor: scaffoldBg,
      fontFamily: '.SF Pro Text',
      colorScheme: baseScheme.copyWith(
        primary: primaryColor,
        surface: surfaceColor,
        error: errorColor,
        surfaceContainerHighest: isDark
            ? (preset == ThemePreset.carbono
                  ? const Color(0xFF1F1F1F)
                  : const Color(0xFF2C2C2E))
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
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: scaffoldBg,
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
        unselectedLabelColor: const Color(0xFF8E8E93),
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
        fillColor: isDark ? surfaceColor : const Color(0xFFE3E3E8),
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
