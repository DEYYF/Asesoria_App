import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'api_service.dart';
// Importamos dart:io con un prefijo para evitar conflictos en web
import 'dart:io' as io;
import 'package:http_parser/http_parser.dart';

class TranscriptionService {
  final ApiService _apiService;

  TranscriptionService(this._apiService);

  Future<String> transcribe(String audioPath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${_apiService.baseUrl}/transcribe'),
      );

      // Obtener el token desde ApiService
      final token = await _apiService.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // En web, audioPath es un Blob URL; en móvil es un path de archivo.
      Uint8List audioBytes;
      if (kIsWeb) {
        // En web, leemos los bytes del Blob URL vía http
        audioBytes = await http.readBytes(Uri.parse(audioPath));
      } else {
        // En móvil/desktop, leemos del sistema de archivos
        audioBytes = await io.File(audioPath).readAsBytes();
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'audio',
          audioBytes,
          filename: 'recording.m4a',
          contentType: MediaType('audio', 'm4a'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['text'] ?? '';
      } else {
        throw Exception('Error en transcripción: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error en TranscriptionService: $e');
      rethrow;
    }
  }
}
