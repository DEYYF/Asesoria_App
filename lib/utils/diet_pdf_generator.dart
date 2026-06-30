import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../models/dieta_model.dart';
import '../models/macros_model.dart';
import '../models/settings_model.dart';
import 'pdf_export_helper.dart';

class DietPdfGenerator {
  /// Generate PDF with isolate support for better performance
  static Future<void> generatePDF(Dieta dieta, PdfSettings pdfSettings) async {
    final pdfBytes = await generatePDFBytes(dieta, pdfSettings);

    final fileName =
        'dieta_${dieta.nombre.replaceAll(' ', '_')}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
    await PdfExportHelper.exportPdf(bytes: pdfBytes, fileName: fileName);
  }

  static Future<Uint8List> generatePDFBytes(
    Dieta dieta,
    PdfSettings pdfSettings,
  ) async {
    final pdfBytes = await compute(
      _buildPdfInIsolate,
      _PdfBuildParams(dieta: dieta, pdfSettings: pdfSettings),
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
            params.dieta,
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
          params.dieta,
          context,
          settings,
          logoImage,
          primary,
          secondary,
          accent,
        ),
        footer: (context) => _buildFooter(context, settings, secondary),
        build: (context) => [
          if (settings.showMacrosSummary)
            _buildPremiumMacrosSummary(
              params.dieta,
              primary,
              secondary,
              accent,
            ),
          pw.SizedBox(height: settings.sectionSpacing),
          if (params.dieta.tipo.trim().toLowerCase() == 'calendario')
            ..._buildCalendarDietSections(
              params.dieta,
              settings,
              primary,
              secondary,
            )
          else
            ...params.dieta.comidas.map(
              (c) => _buildMealSection(c, settings, primary, secondary),
            ),
        ],
      ),
    );

    return await doc.save();
  }

  static pw.Widget _buildCoverPage(
    Dieta dieta,
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
            top: 0,
            right: 0,
            child: pw.Container(
              width: 200,
              height: 200,
              decoration: pw.BoxDecoration(
                color: _withOpacity(primary, 0.1),
                borderRadius: const pw.BorderRadius.only(
                  bottomLeft: pw.Radius.circular(200),
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
                  dieta.nombre,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 42,
                    fontWeight: pw.FontWeight.bold,
                    color: primary,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'PLAN NUTRICIONAL PERSONALIZADO',
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
                      'Preparado para:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey500,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      dieta.clienteNombre ?? 'Cliente Especial',
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
          pw.Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: pw.Center(
              child: pw.Text(
                DateFormat(
                  'MMMM yyyy',
                  'es',
                ).format(DateTime.now()).toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey400,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildHeader(
    Dieta dieta,
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
        : 'Plan Nutricional';
    final subtitle =
        '${dieta.nombre} · ${DateFormat('dd/MM/yyyy').format(DateTime.now())}';
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
            fontSize: settings.headerFontSize,
            fontWeight: pw.FontWeight.bold,
            color: primary,
          ),
        ),
        pw.Text(
          subtitle,
          style: pw.TextStyle(
            fontSize: settings.bodyFontSize - 1,
            color: PdfColors.grey600,
          ),
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
        pw.Container(height: 1, color: _withOpacity(accent, 0.2)),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildPremiumMacrosSummary(
    Dieta dieta,
    PdfColor primary,
    PdfColor secondary,
    PdfColor accent,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _buildMacroCard(
          'CALORÍAS',
          '${dieta.macros.kcal.round()} kcal',
          primary,
        ),
        _buildMacroCard(
          'PROTEÍNA',
          '${dieta.macros.proteinas.round()}g',
          PdfColor.fromHex('#EF4444'),
        ), // Red for protein
        _buildMacroCard(
          'CHOS',
          '${dieta.macros.carbohidratos.round()}g',
          secondary,
        ),
        _buildMacroCard('GRASAS', '${dieta.macros.grasas.round()}g', accent),
      ],
    );
  }

  static pw.Widget _buildMacroCard(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      width: 120,
      decoration: pw.BoxDecoration(
        color: _withOpacity(color, 0.08),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _withOpacity(color, 0.3)),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }


  static List<pw.Widget> _buildCalendarDietSections(
    Dieta dieta,
    PdfSettings settings,
    PdfColor primary,
    PdfColor secondary,
  ) {
    const order = [
      'lunes',
      'martes',
      'miercoles',
      'jueves',
      'viernes',
      'sabado',
      'domingo',
    ];

    if (dieta.diasSemana.isEmpty) {
      return [
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text('Esta dieta calendario no tiene días configurados.'),
        ),
      ];
    }

    final widgets = <pw.Widget>[];
    for (final key in order) {
      DiaCalendario? dia;
      for (final item in dieta.diasSemana) {
        if (_normalizeDay(item.dia) == key) {
          dia = item;
          break;
        }
      }
      if (dia == null) continue;

      final macros = _sumDayMacros(dia);
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: _withOpacity(primary, 0.08),
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: _withOpacity(primary, 0.25)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                dia.dia.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: primary,
                ),
              ),
              pw.Text(
                '${dia.comidas.length} comidas · ${macros.kcal.round()} kcal · P ${macros.proteinas.round()}g · C ${macros.carbohidratos.round()}g · G ${macros.grasas.round()}g',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
      );

      if (dia.comidas.isEmpty) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8, bottom: 14),
            child: pw.Text(
              'Sin comidas asignadas para este día.',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ),
        );
      } else {
        for (final comida in dia.comidas) {
          widgets.add(_buildMealSection(comida, settings, primary, secondary));
        }
      }
    }

    return widgets;
  }

  static Macros _sumDayMacros(DiaCalendario dia) {
    return dia.comidas.fold<Macros>(
      Macros(),
      (acc, comida) => Macros(
        kcal: acc.kcal + comida.totales.kcal,
        proteinas: acc.proteinas + comida.totales.proteinas,
        carbohidratos: acc.carbohidratos + comida.totales.carbohidratos,
        grasas: acc.grasas + comida.totales.grasas,
      ),
    );
  }

  static String _normalizeDay(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .trim();
  }

  static pw.Widget _buildMealSection(
    Comida comida,
    PdfSettings settings,
    PdfColor primary,
    PdfColor secondary,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: pw.BoxDecoration(
            color: primary,
            borderRadius: pw.BorderRadius.only(
              topRight: pw.Radius.circular(10),
            ),
          ),
          child: pw.Text(
            comida.titulo.toUpperCase(),
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.TableHelper.fromTextArray(
          headers: [
            '#',
            'Nombre / Descripción',
            'Métricas',
            'Ingredientes / Detalles',
          ],
          data: comida.opciones.asMap().entries.map((e) {
            final op = e.value;
            final metrics =
                'Kcal: ${op.macrosTotales?.kcal.round() ?? 0}\n'
                'P: ${op.macrosTotales?.proteinas.round() ?? 0} · C: ${op.macrosTotales?.carbohidratos.round() ?? 0} · G: ${op.macrosTotales?.grasas.round() ?? 0}';
            return [
              (e.key + 1).toString(),
              _getOptionName(op),
              metrics,
              _getIngredientsText(op),
            ];
          }).toList(),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
            fontSize: settings.tableFontSize,
          ),
          headerDecoration: pw.BoxDecoration(
            color: settings.tableHeaderColor.isEmpty
                ? _withOpacity(primary, 0.8)
                : _getPdfColor(settings.tableHeaderColor),
          ),
          cellStyle: pw.TextStyle(fontSize: settings.tableFontSize - 1),
          cellPadding: const pw.EdgeInsets.all(8),
          columnWidths: {
            0: const pw.FixedColumnWidth(25),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(4),
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
        border: pw.Border(top: pw.BorderSide(color: _withOpacity(color, 0.1))),
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
              padding: pw.EdgeInsets.only(top: 4),
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
        return PdfPageFormat.a4.landscape; // Default to landscape for tables
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

  static String _getOptionName(OpcionDieta op) {
    var n = op.nombre ?? 'Sin nombre';
    if ((op.tipo == 'ingrediente' || op.tipo == 'alimento') &&
        op.gramos != null)
      n += ' (${op.gramos} gr)';
    return n;
  }

  static String _getIngredientsText(OpcionDieta op) {
    if (op.items != null && op.items!.isNotEmpty)
      return op.items!
          .map((i) => '${i.nombre ?? "Ingrediente"} (${i.gramos} gr)')
          .join(', ');
    return '-';
  }
}

class _PdfBuildParams {
  final Dieta dieta;
  final PdfSettings pdfSettings;
  _PdfBuildParams({required this.dieta, required this.pdfSettings});
}
