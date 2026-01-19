import 'dart:convert';
import 'api_service.dart';

class AutomationService {
  final ApiService _api;

  AutomationService(this._api);

  Future<List<dynamic>> getAutomations(String? advisorId) async {
    final param = advisorId != null ? '?advisorId=$advisorId' : '';
    final response = await _api.get('/automations$param');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Error loading automations: ${response.body}');
  }

  Future<dynamic> createAutomation(Map<String, dynamic> data) async {
    final response = await _api.post('/automations', data);
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Error creating automation: ${response.body}');
  }

  Future<dynamic> updateAutomation(String id, Map<String, dynamic> data) async {
    final response = await _api.put('/automations/$id', data);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Error updating automation: ${response.body}');
  }

  Future<void> deleteAutomation(String id) async {
    final response = await _api.delete('/automations/$id');
    if (response.statusCode != 200) {
      throw Exception('Error deleting automation: ${response.body}');
    }
  }
}
