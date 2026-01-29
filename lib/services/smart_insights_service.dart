import '../services/api_service.dart';

class SmartInsightsService {
  final ApiService _apiService;

  SmartInsightsService(this._apiService);

  Future<Map<String, dynamic>> getInsights(String clientId) async {
    try {
      final response = await _apiService.get(
        '/clientes/$clientId/intelligent-insights',
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      print('Error fetching smart insights: $e');
      return {'hasInsights': false};
    }
  }
}
