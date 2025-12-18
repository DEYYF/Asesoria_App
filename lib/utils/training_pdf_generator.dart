import 'dart:io';

import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/entrenamiento_model.dart';

class TrainingPdfGenerator {
  static Future<void> generatePDF(Entrenamiento entrenamiento) async {
    final doc = pw.Document();

    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final dateStr = entrenamiento.updatedAt != null
        ? DateFormat('dd/MM/yyyy').format(entrenamiento.updatedAt!)
        : '-';

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4.landscape,
          theme: theme,
          margin: const pw.EdgeInsets.all(28),
        ),
        header: (context) => _buildHeader(entrenamiento, dateStr, context),
        build: (context) => [
          ...entrenamiento.semanas.map((sem) => _buildWeekSection(sem)),
        ],
      ),
    );

    final tempDir = await getTemporaryDirectory();

    final pdfBytes = await doc.save();
    final name =
        'entrenamiento_${entrenamiento.titulo.replaceAll(" ", "_")}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes(pdfBytes);

    await copyFileIntoDownloadFolder(file.path, name);
    await openDownloadFolder();
  }

  static pw.Widget _buildHeader(
    Entrenamiento entrenamiento,
    String dateStr,
    pw.Context context,
  ) {
    if (context.pageNumber > 1) {
      return pw.Container();
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          color: PdfColors.blue200,
          height: 8,
          width: double.infinity,
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  entrenamiento.titulo,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
                if (entrenamiento.objetivo != null)
                  pw.Text(
                    'Objetivo: ${entrenamiento.objetivo!}',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
              ],
            ),
            pw.Text(
              'Actualizado: $dateStr',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildWeekSection(SemanaEntrenamiento semana) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          width: double.infinity,
          child: pw.Text(
            'Semana ${semana.numero}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 10),
        ...semana.dias.map((dia) => _buildDaySection(dia)),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildDaySection(DiaEntrenamiento dia) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          dia.nombre,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['Ejercicio', 'Series', 'Reps', 'RIR', 'Descanso', 'Video'],
          data: dia.items.map((item) {
            final s = item.esquema ?? EsquemaSerie();
            final ejName =
                item.ejercicioNombre ?? item.ejercicio?.nombre ?? 'Ejercicio';
            final videoUrl = item.urlVideo ?? item.ejercicio?.urlVideo ?? '';

            return [
              ejName,
              s.series.toString(),
              '${s.repsMin}-${s.repsMax}',
              s.rir?.toString() ?? '-',
              s.descanso?.toString() ?? '-',
              videoUrl.isNotEmpty
                  ? 'LINK'
                  : '-', // PDF links support requires extra widget or text logic
            ];
          }).toList(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerLeft,
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(1),
            5: const pw.FlexColumnWidth(1),
          },
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }
}
