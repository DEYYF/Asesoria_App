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
    final storageKey = await _getStorageKey(userId);
    final prefs = await SharedPreferences.getInstance();

    // 1. Try loading from local storage
    if (prefs.containsKey(storageKey)) {
      try {
        final jsonString = prefs.getString(storageKey);
        if (jsonString != null) {
          final Map<String, dynamic> jsonMap = json.decode(jsonString);
          return UserSettings.fromJson(jsonMap);
        }
      } catch (e) {
        // Parse error or schema mismatch, clear cache
        await prefs.remove(storageKey);
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

  /// Get settings as raw map (useful for dynamic/new fields like intelligence)
  Future<Map<String, dynamic>> getSettingsMap({String? userId}) async {
    final endpoint = userId != null
        ? '/usuarios/$userId/settings'
        : '/usuarios/me/settings';
    try {
      final response = await _api.get(endpoint);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting settings map: $e');
    }
    return {};
  }

  /// Update settings from raw map
  Future<void> updateSettingsMap(
    Map<String, dynamic> settings, {
    String? userId,
  }) async {
    final endpoint = userId != null
        ? '/usuarios/$userId/settings'
        : '/usuarios/me/settings';
    try {
      await _api.put(endpoint, settings);

      // Update local cache if possible
      final storageKey = await _getStorageKey(userId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (e) {
      throw Exception('Failed to update settings map: $e');
    }
  }

  Future<void> updateSettings(UserSettings settings, {String? userId}) async {
    final storageKey = await _getStorageKey(userId);
    final prefs = await SharedPreferences.getInstance();

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

  /// Private helper to get the consistent storage key for a user
  Future<String> _getStorageKey(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Resolve userId if not provided by checking the saved auth_user
    String? resolvedUserId = userId;
    if (resolvedUserId == null) {
      final userStr = prefs.getString('auth_user');
      if (userStr != null) {
        try {
          final userMap = jsonDecode(userStr);
          resolvedUserId = userMap['_id'];
        } catch (e) {
          // ignore
        }
      }
    }

    return resolvedUserId != null ? '${_storageKey}_$resolvedUserId' : _storageKey;
  }
}
