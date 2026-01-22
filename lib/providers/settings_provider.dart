import 'package:flutter/material.dart';
import '../models/settings_model.dart';
import '../services/settings_service.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsService _settingsService;
  UserSettings? _settings;
  bool _isLoading = false;

  SettingsProvider(this._settingsService);

  UserSettings? get settings => _settings;
  bool get isLoading => _isLoading;

  Future<void> loadSettings({String? userId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _settings = await _settingsService.getSettings(userId: userId);
    } catch (e) {
      debugPrint('Error loading settings in provider: $e');
      _settings = UserSettings(pdfSettings: PdfSettings());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSettings(
    UserSettings newSettings, {
    String? userId,
  }) async {
    final oldSettings = _settings;
    _settings = newSettings;
    notifyListeners();

    try {
      await _settingsService.updateSettings(newSettings, userId: userId);
    } catch (e) {
      debugPrint('Error updating settings in provider: $e');
      _settings = oldSettings;
      notifyListeners();
      rethrow;
    }
  }
}
