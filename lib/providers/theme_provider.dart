import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

enum ThemePreset { classic, carbono, neon }

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = const Color(0xFF007AFF); // Default iOS Blue
  ThemePreset _preset = ThemePreset.classic;
  bool _isAutoTheme = false;
  Timer? _timer;

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _getEffectiveAccentColor();
  ThemePreset get preset => _preset;
  bool get isAutoTheme => _isAutoTheme;

  ThemeProvider() {
    _loadSettings();
    // Check every minute if theme needs updating
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_isAutoTheme) notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color _getEffectiveAccentColor() {
    if (_isAutoTheme) {
      final hour = DateTime.now().hour;
      if (hour >= 20 || hour < 7) {
        return const Color(0xFFBB86FC); // Night shift purple
      }
    }

    switch (_preset) {
      case ThemePreset.carbono:
        return const Color(0xFF424242);
      case ThemePreset.neon:
        return const Color(0xFF00E5FF);
      case ThemePreset.classic:
        return _accentColor;
    }
  }

  ThemeMode get effectiveThemeMode {
    if (_isAutoTheme) {
      final hour = DateTime.now().hour;
      if (hour >= 20 || hour < 7) return ThemeMode.dark;
      return ThemeMode.light;
    }
    return _themeMode;
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load theme
    final themeName = prefs.getString('theme') ?? 'system';
    _themeMode = _getThemeModeFromString(themeName);

    // Load preset
    final presetName = prefs.getString('theme_preset') ?? 'classic';
    _preset = _getPresetFromString(presetName);

    // Load auto-theme
    _isAutoTheme = prefs.getBool('auto_theme') ?? false;

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
    _isAutoTheme = false;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', themeName);
    await prefs.setBool('auto_theme', false);
  }

  Future<void> setPreset(ThemePreset preset) async {
    _preset = preset;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_preset', preset.name);
  }

  Future<void> setAutoTheme(bool enabled) async {
    _isAutoTheme = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_theme', enabled);
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

  Future<void> syncWithSettings(Map<String, dynamic>? settings) async {
    if (settings == null) return;

    bool changed = false;
    final prefs = await SharedPreferences.getInstance();

    // Sync theme
    if (settings.containsKey('theme')) {
      final themeName = settings['theme'];
      final newMode = _getThemeModeFromString(themeName);
      if (_themeMode != newMode) {
        _themeMode = newMode;
        changed = true;
        await prefs.setString('theme', themeName);
      }
    }

    // Sync accent color
    if (settings.containsKey('accentColor')) {
      final colorHex = settings['accentColor'];
      try {
        final newColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
        if (_accentColor != newColor) {
          _accentColor = newColor;
          changed = true;
          await prefs.setString('accent_color', colorHex);
        }
      } catch (e) {
        // Ignore invalid hex
      }
    }

    if (changed) {
      notifyListeners();
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

  ThemePreset _getPresetFromString(String name) {
    return ThemePreset.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ThemePreset.classic,
    );
  }

  String get currentThemeName {
    if (_isAutoTheme) return 'auto';
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
