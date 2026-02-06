import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_service.dart';

class HabitoPreset {
  final String id;
  final String nombre;
  final String? descripcion;
  final String tipo;
  final String? unidad;
  final double? target;
  final String categoria;
  final String? icono;
  final int orden;

  HabitoPreset({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.tipo,
    this.unidad,
    this.target,
    required this.categoria,
    this.icono,
    required this.orden,
  });

  factory HabitoPreset.fromJson(Map<String, dynamic> json) {
    return HabitoPreset(
      id: json['_id'],
      nombre: json['nombre'],
      descripcion: json['descripcion'],
      tipo: json['tipo'],
      unidad: json['unidad'],
      target: json['target']?.toDouble(),
      categoria: json['categoria'],
      icono: json['icono'],
      orden: json['orden'] ?? 0,
    );
  }
}

class HabitoPresetService {
  final AuthService _authService;

  HabitoPresetService(this._authService);

  String get _baseUrl => dotenv.env['API_URL'] ?? 'http://localhost:3000/api';

  Future<List<HabitoPreset>> fetchPresets({String? categoria}) async {
    try {
      final token = _authService.token;
      if (token == null) throw Exception('No auth token');

      var url = '$_baseUrl/presets/habitos';
      if (categoria != null) {
        url += '?categoria=$categoria';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => HabitoPreset.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load presets');
      }
    } catch (e) {
      print('Error fetching presets: $e');
      return [];
    }
  }
}
