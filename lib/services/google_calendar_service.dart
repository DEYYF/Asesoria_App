import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'dart:convert';

class GoogleCalendarService extends ChangeNotifier {
  final ApiService _api;

  bool _isConnected = false;
  String? _email;
  bool _isEnabled = false;
  bool _isLoading = false;

  GoogleCalendarService(this._api);

  bool get isConnected => _isConnected;
  String? get email => _email;
  bool get isEnabled => _isEnabled;
  bool get isLoading => _isLoading;

  Future<void> loadStatus() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.get('/google-calendar/status');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _isConnected = data['isConnected'] ?? false;
        _email = data['email'];
        _isEnabled = data['isEnabled'] ?? false;
      }
    } catch (e) {
      debugPrint('Error loading Google Calendar status: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> connect() async {
    try {
      final res = await _api.get('/google-calendar/connect');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final url = Uri.parse(data['url']);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('Error connecting to Google Calendar: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      final res = await _api.post('/google-calendar/disconnect', {});
      if (res.statusCode == 200) {
        await loadStatus();
      }
    } catch (e) {
      debugPrint('Error disconnecting Google Calendar: $e');
      rethrow;
    }
  }
}
