import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../models/entrenamiento_model.dart';
import '../models/settings_model.dart';
import 'pdf_export_helper.dart';

class TrainingPdfGenerator {
  /// Generate PDF with isolate support for better performance
  static Future<void> generatePDF(
    Entrenamiento entrenamiento,
    PdfSettings pdfSettings,
  ) async {
    final pdfBytes = await generatePDFBytes(entrenamiento, pdfSettings);

    final fileName =
        'rutina_${entrenamiento.titulo.replaceAll(' ', '_')}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
    await PdfExportHelper.exportPdf(bytes: pdfBytes, fileName: fileName);
  }

  static Future<Uint8List> generatePDFBytes(
    Entrenamiento entrenamiento,
    PdfSettings pdfSettings,
  ) async {
    final pdfBytes = await compute(
      _buildPdfInIsolate,
      _PdfBuildParams(entrenamiento: entrenamiento, pdfSettings: pdfSettings),
    );
    return Uint8List.fromList(pdfBytes);
  }

  static Future<List<int>> _buildPdfInIsolate(_PdfBuildParams params) async {
    final doc = pw.Document();
    final settings = params.pdfSettings;

    final fontRegular = await _getFont(settings.fontFamily, false);
    final fontBold = await _getFont(settings.fontFamily, true);
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final primary = _getPdfColor(settings.primaryColor);
    final secondary = _getPdfColor(settings.secondaryColor);
    final accent = _getPdfColor(settings.accentColor);

    pw.MemoryImage? logoImage;
    if (settings.logoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(settings.logoUrl));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        debugPrint('Error loading PDF logo: $e');
      }
    }

    // Determine page format based on settings
    final pageFormat = _getPageFormat(settings.pageOrientation);
    final margins = _getMargins(settings.pageMargins);

    // Cover Page
    if (settings.includeCoverPage) {
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          theme: theme,
          build: (context) => _buildCoverPage(
            params.entrenamiento,
            settings,
            logoImage,
            primary,
            accent,
          ),
        ),
      );
    }

    // Main Content
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: pageFormat,
          theme: theme,
          margin: margins,
        ),
        header: (context) => _buildHeader(
          params.entrenamiento,
          context,
          settings,
          logoImage,
          primary,
          secondary,
          accent,
        ),
        footer: (context) => _buildFooter(context, settings, secondary),
        build: (context) => [
          ...params.entrenamiento.semanas.map(
            (sem) =>
                _buildWeekSection(sem, settings, primary, secondary, accent),
          ),
        ],
      ),
    );

    return await doc.save();
  }

  static pw.Widget _buildCoverPage(
    Entrenamiento routine,
    PdfSettings settings,
    pw.MemoryImage? logo,
    PdfColor primary,
    PdfColor accent,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: accent, width: 2),
      ),
      child: pw.Stack(
        children: [
          pw.Positioned(
            bottom: 0,
            left: 0,
            child: pw.Container(
              width: 150,
              height: 150,
              decoration: pw.BoxDecoration(
                color: _withOpacity(primary, 0.1),
                borderRadius: const pw.BorderRadius.only(
                  topRight: pw.Radius.circular(150),
                ),
              ),
            ),
          ),
          pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (logo != null)
                  pw.Container(height: 120, width: 120, child: pw.Image(logo)),
                pw.SizedBox(height: 40),
                pw.Text(
                  settings.headerTitle.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 16,
                    color: PdfColors.grey700,
                    letterSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Container(height: 2, width: 40, color: accent),
                pw.SizedBox(height: 30),
                pw.Text(
                  routine.titulo,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 42,
                    fontWeight: pw.FontWeight.bold,
                    color: primary,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  routine.objetivo ?? 'PLAN DE ENTRENAMIENTO',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey600,
                    letterSpacing: 1.5,
                  ),
                ),
                pw.SizedBox(height: 80),
                pw.Column(
                  children: [
                    pw.Text(
                      'Asignado a:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey500,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      routine.clienteNombre ?? 'Cliente Especial',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildHeader(
    Entrenamiento routine,
    pw.Context context,
    PdfSettings settings,
    pw.MemoryImage? logo,
    PdfColor primary,
    PdfColor secondary,
    PdfColor accent,
  ) {
    if (context.pageNumber == 1 && settings.includeCoverPage)
      return pw.Container();

    final title = settings.headerTitle.isNotEmpty
        ? settings.headerTitle
        : routine.titulo;
    final subtitle =
        'Entrenamiento · ${routine.objetivo ?? ""} · ${DateFormat('dd/MM/yyyy').format(DateTime.now())}';
    final logoWidget = logo != null
        ? pw.Container(height: 40, width: 40, child: pw.Image(logo))
        : pw.Container();

    final textColumn = pw.Column(
      crossAxisAlignment: settings.headerStyle == 'modern'
          ? pw.CrossAxisAlignment.center
          : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: primary,
          ),
        ),
        pw.Text(
          subtitle,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    );

    pw.Widget layout;
    switch (settings.headerStyle) {
      case 'modern':
        layout = pw.Column(
          children: [logoWidget, pw.SizedBox(height: 10), textColumn],
        );
        break;
      case 'minimal':
        layout = pw.Row(children: [textColumn]);
        break;
      case 'side':
        layout = pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [textColumn, logoWidget],
        );
        break;
      case 'classic':
      default:
        layout = pw.Row(
          children: [
            logoWidget,
            pw.SizedBox(width: 15),
            pw.Expanded(child: textColumn),
          ],
        );
    }

    return pw.Column(
      children: [
        layout,
        pw.SizedBox(height: 10),
        pw.Container(height: 1, color: accent.shade(0.2)),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildWeekSection(
    SemanaEntrenamiento semana,
    PdfSettings settings,
    PdfColor primary,
    PdfColor secondary,
    PdfColor accent,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          width: double.infinity,
          decoration: pw.BoxDecoration(
            color: primary,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            'SEMANA ${semana.numero}',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        ...semana.dias.map(
          (dia) => _buildDaySection(dia, settings, primary, secondary, accent),
        ),
        pw.SizedBox(height: 30),
      ],
    );
  }

  static pw.Widget _buildDaySection(
    DiaEntrenamiento dia,
    PdfSettings settings,
    PdfColor primary,
    PdfColor secondary,
    PdfColor accent,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(width: 3, height: 15, color: accent),
            pw.SizedBox(width: 8),
            pw.Text(
              dia.nombre.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: secondary,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: [
            'EJERCICIO',
            'SERIES',
            'REPS',
            'RIR',
            'DESCANSO',
            'TÉCNICA',
          ],
          data: dia.items.map((item) {
            final s = item.esquema ?? EsquemaSerie();
            final ejName =
                item.ejercicioNombre ?? item.ejercicio?.nombre ?? 'Ejercicio';
            return [
              ejName,
              s.series.toString(),
              '${s.repsMin}-${s.repsMax}',
              s.rir?.toString() ?? '-',
              s.descanso?.toString() ?? '-',
              item.urlVideo != null ? 'VIDEO' : '-',
            ];
          }).toList(),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
            fontSize: 8,
          ),
          headerDecoration: pw.BoxDecoration(color: secondary.shade(0.7)),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellPadding: const pw.EdgeInsets.all(6),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(1),
            5: const pw.FlexColumnWidth(1),
          },
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildFooter(
    pw.Context context,
    PdfSettings settings,
    PdfColor color,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: color.shade(0.1))),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                settings.footerText,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey500,
                ),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          ),
          if (settings.footerContactInfo.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                settings.footerContactInfo,
                style: pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static PdfColor _getPdfColor(String hex) {
    return PdfColor.fromInt(
      int.parse(hex.replaceAll('#', ''), radix: 16) | 0xFF000000,
    );
  }

  static PdfColor _withOpacity(PdfColor color, double opacity) {
    final alpha = (opacity * 255).round();
    return PdfColor(color.red, color.green, color.blue, alpha / 255);
  }

  static PdfPageFormat _getPageFormat(String orientation) {
    switch (orientation) {
      case 'portrait':
        return PdfPageFormat.a4;
      case 'landscape':
        return PdfPageFormat.a4.landscape;
      case 'auto':
      default:
        return PdfPageFormat.a4.landscape;
    }
  }

  static pw.EdgeInsets _getMargins(String size) {
    switch (size) {
      case 'small':
        return const pw.EdgeInsets.all(20);
      case 'large':
        return const pw.EdgeInsets.all(50);
      case 'medium':
      default:
        return const pw.EdgeInsets.all(35);
    }
  }

  static Future<pw.Font> _getFont(String family, bool bold) async {
    switch (family) {
      case 'Times':
        return bold ? pw.Font.timesBold() : pw.Font.times();
      case 'Courier':
        return bold ? pw.Font.courierBold() : pw.Font.courier();
      case 'Helvetica':
      default:
        return bold ? pw.Font.helveticaBold() : pw.Font.helvetica();
    }
  }
}

class _PdfBuildParams {
  final Entrenamiento entrenamiento;
  final PdfSettings pdfSettings;
  _PdfBuildParams({required this.entrenamiento, required this.pdfSettings});
}
