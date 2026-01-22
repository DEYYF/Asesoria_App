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
  Future<UserSettings> getSettings({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    // If userId is provided, use it. Otherwise, we assume 'me' or current user logic elsewhere?
    // Actually, to make this robust, if userId is null, we should probably fetch 'me' to get the ID first or just use 'me' endpoint.
    // However, for caching, we need an ID.
    // Let's assume if userId is passed, we use it. If not, we use 'me' endpoint and cache under 'me' or distinct key.

    final storageKey = userId != null ? '${_storageKey}_$userId' : _storageKey;

    // 1. Try loading from local storage
    if (prefs.containsKey(storageKey)) {
      try {
        final jsonString = prefs.getString(storageKey);
        if (jsonString != null) {
          final Map<String, dynamic> jsonMap = json.decode(jsonString);
          return UserSettings.fromJson(jsonMap);
        }
      } catch (e) {
        // Parse error
      }
    }

    // 2. Try fetching from API
    try {
      final endpoint = userId != null
          ? '/usuarios/$userId/settings'
          : '/usuarios/me/settings';
      final response = await _api.get(endpoint);

      if (response.statusCode == 200) {
        final data = await parseJsonInIsolate(response.body);
        final settings = UserSettings.fromJson(data as Map<String, dynamic>);

        // Update local cache
        await prefs.setString(storageKey, json.encode(settings.toJson()));

        return settings;
      }
    } catch (e) {
      // API error
    }

    // 3. Return defaults
    return UserSettings(pdfSettings: PdfSettings());
  }

  Future<void> updateSettings(UserSettings settings, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = userId != null ? '${_storageKey}_$userId' : _storageKey;

    // 1. Save locally
    await prefs.setString(storageKey, json.encode(settings.toJson()));

    // 2. Sync to API
    try {
      final endpoint = userId != null
          ? '/usuarios/$userId/settings'
          : '/usuarios/me/settings';
      await _api.put(endpoint, settings.toJson());
    } catch (e) {
      // Failed to sync
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
