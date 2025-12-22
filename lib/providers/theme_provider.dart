import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = const Color(0xFF007AFF); // Default iOS Blue

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;

  ThemeProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load theme
    final themeName = prefs.getString('theme') ?? 'system';
    _themeMode = _getThemeModeFromString(themeName);

    // Load accent color
    final colorHex = prefs.getString('accent_color');
    if (colorHex != null) {
      try {
        _accentColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
      } catch (e) {
        _accentColor = const Color(0xFF007AFF);
      }
    }

    notifyListeners();
  }

  Future<void> setTheme(String themeName) async {
    _themeMode = _getThemeModeFromString(themeName);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', themeName);
  }

  Future<void> setAccentColor(String colorHex) async {
    try {
      _accentColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('accent_color', colorHex);
    } catch (e) {
      // Ignore invalid hex
    }
  }

  ThemeMode _getThemeModeFromString(String themeName) {
    switch (themeName) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  String get currentThemeName {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }
}
