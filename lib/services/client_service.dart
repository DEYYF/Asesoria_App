import 'dart:convert';
import '../models/cliente_model.dart';
import 'api_service.dart';

class ClientService {
  final ApiService _api;

  ClientService(this._api);

  Future<List<Cliente>> getClients() async {
    final response = await _api.get('/clientes');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Cliente.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar clientes: ${response.body}');
    }
  }
}
