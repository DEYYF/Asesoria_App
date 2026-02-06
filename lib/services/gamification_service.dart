import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/gamification_models.dart';
import 'auth_service.dart';

class GamificationService {
  final AuthService authService;

  GamificationService(this.authService);

  String get baseUrl {
    final url = dotenv.env['API_URL'] ?? 'http://localhost:3000/api';
    return '$url/gamification';
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (authService.token != null)
      'Authorization': 'Bearer ${authService.token}',
  };

  Future<GamificationStats?> fetchStats(String clienteId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stats/$clienteId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return GamificationStats.fromJson(json.decode(response.body));
      }
    } catch (e) {
      print('Error fetching gamification stats: $e');
    }
    return null;
  }

  Future<List<BadgeModel>> fetchBadges(String clienteId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/badges/$clienteId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => BadgeModel.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error fetching badges: $e');
    }
    return [];
  }

  Future<List<ChallengeModel>> fetchChallenges(
    String clienteId, {
    bool active = false,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/challenges/$clienteId?active=$active'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => ChallengeModel.fromJson(item)).toList();
      }
    } catch (e) {
      print('Error fetching challenges: $e');
    }
    return [];
  }

  Future<ChallengeModel?> createChallenge(
    Map<String, dynamic> challengeData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/challenges'),
        headers: _headers,
        body: json.encode(challengeData),
      );

      if (response.statusCode == 200) {
        return ChallengeModel.fromJson(json.decode(response.body));
      }
    } catch (e) {
      print('Error creating challenge: $e');
    }
    return null;
  }

  Future<bool> completeChallengeManual(String challengeId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/challenges/$challengeId/complete'),
        headers: _headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error completing challenge: $e');
      return false;
    }
  }

  Future<bool> deleteChallenge(String challengeId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/challenges/$challengeId'),
        headers: _headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting challenge: $e');
      return false;
    }
  }

  // Backward compatibility / Additional features
  Future<List<dynamic>> getLeaderboard() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/leaderboard'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error fetching leaderboard: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> getClientStats(String clienteId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stats/$clienteId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Error fetching client stats map: $e');
    }
    return {};
  }
}
