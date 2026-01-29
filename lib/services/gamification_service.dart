import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class GamificationService {
  final ApiService _api;

  GamificationService(this._api);

  Future<Map<String, dynamic>> getClientStats(String clientId) async {
    try {
      final response = await _api.get('/gamification/stats/$clientId');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint("Failed to load gamification stats: ${response.body}");
        return {};
      }
    } catch (e) {
      debugPrint("Error loading gamification stats: $e");
      return {};
    }
  }

  Future<List<dynamic>> getLeaderboard({String? advisorId}) async {
    try {
      String endpoint = '/gamification/leaderboard';
      Map<String, dynamic>? params;

      if (advisorId != null) {
        params = {'advisorId': advisorId};
      }

      final response = await _api.get(endpoint, params: params);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint("Failed to load leaderboard");
        return [];
      }
    } catch (e) {
      debugPrint("Error loading leaderboard: $e");
      return [];
    }
  }
}
