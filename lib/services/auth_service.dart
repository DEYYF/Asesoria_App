import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService with ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;

  bool get isAuthenticated => _token != null;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;

  // User type detection
  String? get userType => _user?['userType'];
  bool get isAdmin =>
      userType == null ||
      userType == 'admin'; // null for backward compatibility
  bool get isClient => userType == 'client';
  String? get userId => _user?['_id'];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userStr = prefs.getString('auth_user');
    if (userStr != null) {
      _user = jsonDecode(userStr);
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    final baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:3000/api';

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        _user = data['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('auth_user', jsonEncode(_user));

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('Login error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<dynamic> clientLogin(
    String email,
    String password, {
    bool isFirstLogin = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    final baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:3000/api';

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/client-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'isFirstLogin': isFirstLogin,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check if password setup is required
        if (data['requiresPasswordSetup'] == true) {
          _isLoading = false;
          notifyListeners();
          return 'requiresPasswordSetup';
        }

        // Normal login success
        _token = data['token'];
        _user = data['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('auth_user', jsonEncode(_user));

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('Client login error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    notifyListeners();
  }
}
