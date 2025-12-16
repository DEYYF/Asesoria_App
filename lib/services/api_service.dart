import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  String get baseUrl => dotenv.env['API_URL'] ?? 'http://localhost:3000/api';

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
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
}
