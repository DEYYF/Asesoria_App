import 'dart:convert';
import '../models/factura_model.dart';
import 'api_service.dart';

class FacturaService {
  final ApiService _api;

  FacturaService(this._api);

  // Obtener todas las facturas con filtros opcionales
  Future<List<Factura>> getFacturas({
    String? clienteId,
    String? estado,
    DateTime? desde,
    DateTime? hasta,
    int limit = 50,
    int skip = 0,
  }) async {
    final queryParams = <String, dynamic>{'limit': limit, 'skip': skip};

    if (clienteId != null) queryParams['clienteId'] = clienteId;
    if (estado != null) queryParams['estado'] = estado;
    if (desde != null) queryParams['desde'] = desde.toIso8601String();
    if (hasta != null) queryParams['hasta'] = hasta.toIso8601String();

    final response = await _api.get('/facturas', params: queryParams);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final facturas = (data['facturas'] as List)
          .map((json) => Factura.fromJson(json))
          .toList();
      return facturas;
    } else {
      throw Exception('Error al cargar facturas: ${response.body}');
    }
  }

  // Obtener factura por ID
  Future<Factura> getFacturaById(String id) async {
    final response = await _api.get('/facturas/$id');

    if (response.statusCode == 200) {
      return Factura.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Error al cargar factura: ${response.body}');
    }
  }

  // Crear nueva factura
  Future<Factura> createFactura(Map<String, dynamic> facturaData) async {
    final response = await _api.post('/facturas', facturaData);

    if (response.statusCode == 201) {
      return Factura.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Error al crear factura: ${response.body}');
    }
  }

  // Actualizar factura completa
  Future<Factura> updateFactura(String id, Map<String, dynamic> data) async {
    final response = await _api.put('/facturas/$id', data);

    if (response.statusCode == 200) {
      return Factura.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Error al actualizar factura: ${response.body}');
    }
  }

  // Actualizar estado de factura
  Future<Factura> updateEstado(
    String id, {
    required String estado,
    DateTime? fechaPago,
    String? metodoPago,
  }) async {
    final data = <String, dynamic>{'estado': estado};

    if (fechaPago != null) data['fechaPago'] = fechaPago.toIso8601String();
    if (metodoPago != null) data['metodoPago'] = metodoPago;

    final response = await _api.put('/facturas/$id/estado', data);

    if (response.statusCode == 200) {
      return Factura.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Error al actualizar factura: ${response.body}');
    }
  }

  // Descargar PDF
  Future<List<int>> downloadPDF(String id) async {
    final response = await _api.get('/facturas/$id/pdf');

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Error al descargar PDF: ${response.body}');
    }
  }

  // Enviar factura por email
  Future<void> sendEmail(String id) async {
    final response = await _api.post('/facturas/$id/send', {});

    if (response.statusCode != 200) {
      throw Exception('Error al enviar email: ${response.body}');
    }
  }

  // Eliminar factura
  Future<void> deleteFactura(String id) async {
    final response = await _api.delete('/facturas/$id');

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar factura: ${response.body}');
    }
  }

  // Obtener estadísticas
  Future<Map<String, dynamic>> getStats({int? year}) async {
    final queryParams = year != null ? {'year': year} : null;

    final response = await _api.get('/facturas/stats', params: queryParams);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al cargar estadísticas: ${response.body}');
    }
  }
}
