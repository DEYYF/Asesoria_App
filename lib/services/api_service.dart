import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/isolate_utils.dart';

class ApiService {
  String get baseUrl => dotenv.env['API_URL'] ?? 'https://asesoria-backend.onrender.com/api';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> get(
    String endpoint, {
    Map<String, dynamic>? params,
  }) async {
    final headers = await _getHeaders();

    // Construct URI with query parameters if present
    final uri = Uri.parse('$baseUrl$endpoint');
    final finalUri = params != null
        ? uri.replace(
            queryParameters: params.map((k, v) => MapEntry(k, v.toString())),
          )
        : uri;

    try {
      final response = await http.get(finalUri, headers: headers);
      return response;
    } catch (e) {
      throw Exception('Error en GET request: $e');
    }
  }

  Future<http.Response> post(String endpoint, Object? body) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl$endpoint');
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      return response;
    } catch (e) {
      throw Exception('Error en POST request: $e');
    }
  }

  Future<http.Response> put(String endpoint, Object? body) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl$endpoint');
    try {
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      return response;
    } catch (e) {
      throw Exception('Error en PUT request: $e');
    }
  }

  Future<http.Response> patch(String endpoint, Object? body) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl$endpoint');
    try {
      final response = await http.patch(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      return response;
    } catch (e) {
      throw Exception('Error en PATCH request: $e');
    }
  }

  Future<http.Response> delete(String endpoint) async {
    final headers = await _getHeaders();
    final url = Uri.parse('$baseUrl$endpoint');
    try {
      final response = await http.delete(url, headers: headers);
      return response;
    } catch (e) {
      throw Exception('Error en DELETE request: $e');
    }
  }

  // ============================================================================
  // ISOLATE-BASED HELPER METHODS
  // ============================================================================

  /// Parse JSON response in isolate for better performance
  /// Use this for large JSON responses
  Future<dynamic> parseJsonResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return await parseJsonInIsolate(response.body);
    }
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  /// GET request with automatic JSON parsing in isolate
  /// Returns parsed data directly
  Future<dynamic> getAndParse(
    String endpoint, {
    Map<String, dynamic>? params,
  }) async {
    final response = await get(endpoint, params: params);
    return await parseJsonResponse(response);
  }
}
