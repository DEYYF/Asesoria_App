import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_service.dart';
import '../models/settings_model.dart';
import '../utils/isolate_utils.dart';

class SettingsService {
  final ApiService _api;
  static const String _storageKey = 'user_settings_v1';

  SettingsService(this._api);

  /// Get user settings
  /// Prioritizes SharedPreferences (Local) for immediate UI response.
  /// Then attempts to fetch from API to sync.
  Future<UserSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Try loading from local storage
    if (prefs.containsKey(_storageKey)) {
      try {
        final jsonString = prefs.getString(_storageKey);
        if (jsonString != null) {
          final Map<String, dynamic> jsonMap = json.decode(jsonString);
          return UserSettings.fromJson(jsonMap);
        }
      } catch (e) {
        // Parse error, ignore and fall through
      }
    }

    // 2. Try fetching from API (and update local)
    try {
      final response = await _api.get('/usuarios/me/settings');
      if (response.statusCode == 200) {
        final data = await parseJsonInIsolate(response.body);
        final settings = UserSettings.fromJson(data as Map<String, dynamic>);

        // Update local cache
        await prefs.setString(_storageKey, json.encode(settings.toJson()));

        return settings;
      }
    } catch (e) {
      // API error, just use defaults if local failed too
    }

    // 3. Return defaults
    return UserSettings();
  }

  /// Update user settings
  /// Saves locally first, then syncs to API.
  Future<void> updateSettings(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Save locally
    await prefs.setString(_storageKey, json.encode(settings.toJson()));

    // 2. Sync to API (Fire and forget, or await if critical)
    try {
      await _api.put('/usuarios/me/settings', settings.toJson());
    } catch (e) {
      // Failed to sync to backend, but saved locally
    }
  }

  /// Export user data
  Future<http.Response> exportData() async {
    return await _api.get('/settings/export');
  }

  /// Delete user account
  Future<void> deleteAccount() async {
    await _api.delete('/settings/account');
    // Clear local settings
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
