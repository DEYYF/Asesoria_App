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

  String? get userType => _user?['userType'];
  bool get isAdmin =>
      userType == null ||
      userType == 'admin'; // null for backward compatibility
  bool get isClient => userType == 'client';
  String? get role => _user?['role'];
  bool get isSuperAdmin => role == 'superadmin';
  String? get userId => _user?['_id'];
  String? get userEmail => _user?['email'];

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
    // Don't notify here to avoid router refreshes during loading

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
        notifyListeners(); // Notify only on authentication change
        return true;
      } else {
        _isLoading = false;
        // Don't notify on error, we return false and handling screen will re-render
        return false;
      }
    } catch (e) {
      print('Login error: $e');
      _isLoading = false;
      return false;
    }
  }

  Future<dynamic> clientLogin(
    String email,
    String password, {
    bool isFirstLogin = false,
  }) async {
    _isLoading = true;
    // Don't notify here to avoid router refreshes during loading

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

        // Debug: print response
        print('Client login response: $data');

        // Check if password setup is required
        if (data['requiresPasswordSetup'] == true) {
          print('Password setup required detected');
          _isLoading =
              false; // Reset without notifyListeners to avoid unmounting
          return 'requiresPasswordSetup';
        }

        // Normal login success
        _token = data['token'];
        _user = data['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('auth_user', jsonEncode(_user));

        _isLoading = false;
        notifyListeners(); // Notify only on authentication change
        return true;
      } else {
        _isLoading = false;
        return false;
      }
    } catch (e) {
      print('Client login error: $e');
      _isLoading = false;
      return false;
    } finally {
      // Always ensure loading is false but don't notify unless we explicitly want a rebuild
      _isLoading = false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    // Important: Clear global settings cache to prevent crossover
    await prefs.remove('user_settings_v1');
    notifyListeners();
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    final baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:3000/api';
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/users/me/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final updatedUser = jsonDecode(response.body);
        _user = {..._user!, ...updatedUser};

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_user', jsonEncode(_user));
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Update profile error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> checkClientStatus(String email) async {
    final baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:3000/api';
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/check-client-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      print('Check client status error: $e');
      return {'error': e.toString()};
    }
  }
}
