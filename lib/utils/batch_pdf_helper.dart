import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cliente_model.dart';
import '../models/dieta_model.dart';
import '../models/entrenamiento_model.dart';
import '../models/progreso_model.dart'; // Add this for ProgressPdfGenerator
import '../models/exercise_history_model.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';
import 'diet_pdf_generator.dart';
import 'training_pdf_generator.dart';
import 'progress_pdf_generator.dart';
import 'pdf_export_helper.dart';
import 'notification_helper.dart';

class BatchPdfHelper {
  static Future<void> processBatch({
    required BuildContext context,
    required Cliente cliente,
    required Map<String, bool> selectedReports,
    required bool isEmail,
  }) async {
    final api = Provider.of<ApiService>(context, listen: false);
    final settingsService = SettingsService(api);
    final settings = await settingsService.getSettings();
    final pdfSettings = settings.pdfSettings;

    final List<BatchPdfItem> pdfs = [];

    // 1. Generate Diet PDF if selected
    if (selectedReports['dieta'] == true) {
      try {
        final res = await api.get('/dietas/cliente/${cliente.id}/ultima');
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data != null) {
            final dieta = Dieta.fromJson(data);
            final bytes = await DietPdfGenerator.generatePDFBytes(
              dieta,
              pdfSettings,
            );
            pdfs.add(
              BatchPdfItem(
                filename: 'dieta_${cliente.nombre}.pdf',
                bytes: bytes,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error generating Diet PDF in batch: $e');
      }
    } else {
      debugPrint(
        'Diet PDF not selected or selected value is: ${selectedReports['dieta']}',
      );
    }

    // 2. Generate Training PDF if selected
    if (selectedReports['entrenamiento'] == true) {
      try {
        final res = await api.get(
          '/entrenamientos/cliente/${cliente.id}/ultimo',
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data != null) {
            final entrenamiento = Entrenamiento.fromJson(data);
            final bytes = await TrainingPdfGenerator.generatePDFBytes(
              entrenamiento,
              pdfSettings,
            );
            pdfs.add(
              BatchPdfItem(
                filename: 'entrenamiento_${cliente.nombre}.pdf',
                bytes: bytes,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error generating Training PDF in batch: $e');
      }
    } else {
      debugPrint(
        'Training PDF not selected or selected value is: ${selectedReports['entrenamiento']}',
      );
    }

    // 3. Generate Progress PDF if selected
    if (selectedReports['corporal'] == true) {
      try {
        final rawHistorial = cliente.historialProgreso;
        final List<Progreso> historial = (rawHistorial != null)
            ? rawHistorial
                  .whereType<Map>()
                  .map(
                    (json) =>
                        Progreso.fromJson(Map<String, dynamic>.from(json)),
                  )
                  .toList()
            : [];

        final doc = await ProgressPdfGenerator.generateDocument(
          cliente,
          historial,
          pdfSettings,
        );
        final bytes = await doc.save();
        pdfs.add(
          BatchPdfItem(
            filename: 'progreso_corporal_${cliente.nombre}.pdf',
            bytes: bytes,
          ),
        );
      } catch (e) {
        debugPrint('Error generating progress PDF in batch: $e');
      }
    }

    // 4. Generate Performance PDF if selected
    if (selectedReports['rendimiento'] == true) {
      try {
        final res = await api.get(
          '/entrenamientos/registros/cliente/${cliente.id}/historial-completo',
        );
        if (res.statusCode == 200) {
          final Map<String, dynamic> rawData = jsonDecode(res.body);
          final Map<String, List<ExerciseHistoryRecord>> history = {};
          rawData.forEach((key, value) {
            if (value is List) {
              history[key] = value
                  .map((v) => ExerciseHistoryRecord.fromJson(v))
                  .toList();
            }
          });

          if (history.isNotEmpty) {
            final doc = await ProgressPdfGenerator.generatePerformanceDocument(
              cliente,
              history,
              pdfSettings,
            );
            final bytes = await doc.save();
            pdfs.add(
              BatchPdfItem(
                filename: 'rendimiento_${cliente.nombre}.pdf',
                bytes: bytes,
              ),
            );
          } else {
            debugPrint('No historical performance data found for client');
          }
        } else {
          debugPrint('Performance history API failed: ${res.statusCode}');
        }
      } catch (e) {
        debugPrint('Error generating performance PDF in batch: $e');
      }
    }

    if (pdfs.isEmpty) return;

    if (isEmail) {
      // Send via email
      await _sendViaEmail(context, api, cliente, pdfs);
    } else {
      // Download all
      for (final pdf in pdfs) {
        await PdfExportHelper.exportPdf(
          bytes: pdf.bytes,
          fileName: pdf.filename,
        );
      }
    }
  }

  static Future<void> _sendViaEmail(
    BuildContext context,
    ApiService api,
    Cliente cliente,
    List<BatchPdfItem> pdfs,
  ) async {
    try {
      final attachments = pdfs
          .map(
            (pdf) => {
              'filename': pdf.filename,
              'content': base64Encode(pdf.bytes),
              'encoding': 'base64', // Added to ensure correct delivery
            },
          )
          .toList();

      final res = await api.post('/correo/enviar', {
        'to': cliente.email,
        'subject': 'Tus informes y planes actualizados',
        'mensaje':
            'Hola ${cliente.nombre}, aquí tienes los documentos seleccionados.',
        'attachments': attachments,
        'clienteId': cliente.id,
      });

      if (res.statusCode == 200) {
        NotificationHelper.showSuccess(
          context,
          'Correos enviados correctamente',
        );
      } else {
        throw Exception('Error al enviar el correo');
      }
    } catch (e) {
      NotificationHelper.showError(context, 'Error: $e');
    }
  }
}

class BatchPdfItem {
  final String filename;
  final Uint8List bytes;

  BatchPdfItem({required this.filename, required this.bytes});
}
