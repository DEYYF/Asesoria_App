import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/settings_model.dart';
import '../models/cliente_model.dart';
import '../models/progreso_model.dart';
import '../models/exercise_history_model.dart';

class ProgressPdfGenerator {
  static Future<pw.Document> generateDocument(
    Cliente cliente,
    List<Progreso> historial,
    PdfSettings settings,
  ) async {
    final doc = pw.Document();
    final primary = _getPdfColor(settings.primaryColor);
    final secondary = _getPdfColor(settings.secondaryColor);
    final accent = _getPdfColor(settings.accentColor);

    final fontRegular = await _getFont(settings.fontFamily, false);
    final fontBold = await _getFont(settings.fontFamily, true);
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    // Pre-load logo
    pw.MemoryImage? logoImage;
    if (settings.logoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(settings.logoUrl));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        debugPrint('Error loading Progress PDF logo: $e');
      }
    }

    final pageFormat = _getPageFormat(settings.pageOrientation);
    final margins = _getMargins(settings.pageMargins);

    // Cover Page
    if (settings.includeCoverPage) {
      doc.addPage(
        _buildCoverPage(
          cliente.nombre,
          settings,
          logoImage,
          theme,
          primary,
          accent,
          pageFormat,
        ),
      );
    }

    // Main Page(s)
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: pageFormat,
          theme: theme,
          margin: margins,
          buildBackground: (context) => _buildBackground(context, settings),
        ),
        header: (context) => _buildHeader(
          'REPORTE DE EVOLUCIÓN',
          DateFormat('dd/MM/yyyy').format(DateTime.now()),
          settings,
          logoImage,
          primary,
          secondary,
          accent,
        ),
        footer: (context) => _buildFooter(context, settings, secondary),
        build: (context) => [
          _buildClientSummary(
            cliente,
            settings,
            primary,
            secondary,
            weight: historial.where((p) => p.peso != null).lastOrNull?.peso,
            fat: historial
                .where((p) => p.grasaCorporal != null)
                .lastOrNull
                ?.grasaCorporal,
            muscle: historial
                .where((p) => p.masaMusculoEsqueletica != null)
                .lastOrNull
                ?.masaMusculoEsqueletica,
          ),
          pw.SizedBox(height: settings.sectionSpacing),
          if (historial.isNotEmpty) ...[
            _buildEvolutionSummary(historial, settings, primary, secondary),
            pw.SizedBox(height: settings.sectionSpacing),

            // General body metrics charts
            _buildMetricChart(
              'EVOLUCIÓN DE PESO',
              historial,
              (p) => p.peso,
              'kg',
              settings,
              primary,
            ),
            pw.SizedBox(height: settings.sectionSpacing),
            _buildMetricChart(
              'EVOLUCIÓN DE GRASA CORPORAL',
              historial,
              (p) => p.grasaCorporal,
              '%',
              settings,
              PdfColors.pink,
            ),
            pw.SizedBox(height: settings.sectionSpacing),
            _buildMetricChart(
              'EVOLUCIÓN DE MASA MUSCULAR',
              historial,
              (p) => p.masaMusculoEsqueletica,
              'kg',
              settings,
              secondary,
            ),
            pw.SizedBox(height: settings.sectionSpacing),

            // Individual muscle charts
            ..._buildIndividualMuscleCharts(historial, settings, secondary),

            _buildDetailedTable(historial, settings, primary, secondary),
            pw.SizedBox(height: settings.sectionSpacing),
            _buildMuscleMeasuresSection(
              historial,
              settings,
              primary,
              secondary,
            ),
          ] else
            pw.Center(
              child: pw.Text(
                'No hay registros de progreso disponibles.',
                style: pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: settings.bodyFontSize,
                ),
              ),
            ),
        ],
      ),
    );

    return doc;
  }

  static pw.Widget _buildBackground(pw.Context context, PdfSettings settings) {
    if (settings.watermarkText.isEmpty) return pw.Container();
    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Center(
        child: pw.Transform.rotate(
          angle: 0.5,
          child: pw.Text(
            settings.watermarkText,
            style: pw.TextStyle(
              color: PdfColors.grey300.shade(settings.watermarkOpacity),
              fontSize: 60,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  static pw.Page _buildCoverPage(
    String name,
    PdfSettings settings,
    pw.MemoryImage? logo,
    pw.ThemeData theme,
    PdfColor primary,
    PdfColor accent,
    PdfPageFormat pageFormat,
  ) {
    return pw.Page(
      pageFormat: pageFormat,
      theme: theme,
      build: (context) => pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: accent, width: 2),
        ),
        child: pw.Center(
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
              pw.SizedBox(height: 30),
              pw.Text(
                'REPORTE DE PROGRESO',
                style: pw.TextStyle(
                  fontSize: 32,
                  fontWeight: pw.FontWeight.bold,
                  color: primary,
                ),
              ),
              pw.SizedBox(height: 80),
              pw.Text(
                'PREPARADO PARA:',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
              ),
              pw.Text(
                name,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildHeader(
    String title,
    String date,
    PdfSettings settings,
    pw.MemoryImage? logo,
    PdfColor primary,
    PdfColor secondary,
    PdfColor accent,
  ) {
    final headerTitle = settings.headerTitle.isNotEmpty
        ? settings.headerTitle
        : title;

    final logoSize = settings.logoSize == 'large'
        ? 60.0
        : (settings.logoSize == 'small' ? 30.0 : 45.0);
    final logoWidget = logo != null
        ? pw.Container(height: logoSize, width: logoSize, child: pw.Image(logo))
        : pw.Container();

    final textColumn = pw.Column(
      crossAxisAlignment: settings.headerStyle == 'modern'
          ? pw.CrossAxisAlignment.center
          : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          headerTitle,
          style: pw.TextStyle(
            fontSize: settings.headerFontSize,
            fontWeight: pw.FontWeight.bold,
            color: primary,
          ),
        ),
        pw.Text(
          date,
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
        pw.Container(height: 1, color: accent.shade(0.2)),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildClientSummary(
    Cliente cliente,
    PdfSettings settings,
    PdfColor primary,
    PdfColor secondary, {
    double? weight,
    double? fat,
    double? muscle,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'CLIENTE',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: primary,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                cliente.nombre,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                cliente.email,
                style: pw.TextStyle(
                  fontSize: settings.bodyFontSize - 1,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.Row(
            children: [
              if (weight != null)
                _buildSummaryStat(
                  'PESO',
                  '${weight.toStringAsFixed(1)} kg',
                  primary,
                ),
              if (fat != null) pw.SizedBox(width: 15),
              if (fat != null)
                _buildSummaryStat(
                  'GRASA',
                  '${fat.toStringAsFixed(1)} %',
                  PdfColors.pink,
                ),
              if (muscle != null) pw.SizedBox(width: 15),
              if (muscle != null)
                _buildSummaryStat(
                  'MÚSCULO',
                  '${muscle.toStringAsFixed(1)} kg',
                  secondary,
                ),
              if (cliente.altura != null) pw.SizedBox(width: 15),
              if (cliente.altura != null)
                _buildSummaryStat(
                  'ESTATURA',
                  '${cliente.altura} cm',
                  secondary,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryStat(
    String label,
    String value,
    PdfColor color,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 7,
            color: color,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  static double _calculateImmediateDiff(
    List<Progreso> historial,
    double? Function(Progreso) getValue,
  ) {
    Progreso? latest;
    Progreso? previous;

    for (var i = historial.length - 1; i >= 0; i--) {
      if (getValue(historial[i]) != null) {
        if (latest == null) {
          latest = historial[i];
        } else {
          previous = historial[i];
          break;
        }
      }
    }

    if (latest == null || previous == null) return 0;
    return (getValue(latest) ?? 0) - (getValue(previous) ?? 0);
  }

  static pw.Widget _buildEvolutionSummary(
    List<Progreso> historial,
    PdfSettings settings,
    PdfColor primary,
    PdfColor secondary,
  ) {
    final weightDiff = _calculateImmediateDiff(historial, (p) => p.peso);
    final fatDiff = _calculateImmediateDiff(historial, (p) => p.grasaCorporal);
    final muscleDiff = _calculateImmediateDiff(
      historial,
      (p) => p.masaMusculoEsqueletica,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'RESUMEN DE VARIACIÓN',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildVariationCard('PESO', weightDiff, 'kg', primary),
            _buildVariationCard('GRASA', fatDiff, '%', PdfColors.pink),
            _buildVariationCard('MÚSCULO', muscleDiff, 'kg', secondary),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildVariationCard(
    String label,
    double diff,
    String unit,
    PdfColor color,
  ) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(12),
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
            '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)} $unit',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildIndividualMuscleCharts(
    List<Progreso> historial,
    PdfSettings settings,
    PdfColor color,
  ) {
    // Collect all unique muscle names
    final muscleNames = <String>{};
    for (var entry in historial) {
      if (entry.musculo != null) {
        for (var m in entry.musculo!) {
          muscleNames.add(m.nombre);
        }
      }
    }

    final charts = <pw.Widget>[];
    for (var name in muscleNames) {
      final muscleData = historial
          .where(
            (p) =>
                p.musculo?.any((m) => m.nombre == name && m.medida > 0) ??
                false,
          )
          .toList();

      if (muscleData.length >= 2) {
        charts.add(
          _buildMetricChart(
            'EVOLUCIÓN: ${name.toUpperCase()}',
            historial,
            (p) => p.musculo?.firstWhere((m) => m.nombre == name).medida,
            'cm',
            settings,
            color,
          ),
        );
        charts.add(pw.SizedBox(height: settings.sectionSpacing));
      }
    }
    return charts;
  }

  static pw.Widget _buildMetricChart(
    String title,
    List<Progreso> historial,
    double? Function(Progreso) getValue,
    String unit,
    PdfSettings settings,
    PdfColor color,
  ) {
    final data = historial.where((p) => getValue(p) != null).toList();
    if (data.length < 2) return pw.Container();

    final values = data.map((p) => getValue(p)!).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);

    // Add some padding to Y axis
    final range = maxVal - minVal;
    final padding = range > 0 ? range * 0.2 : 2.0;
    final start = (minVal - padding).floorToDouble();
    final end = (maxVal + padding).ceilToDouble();

    final step = (end - start) / 5;
    final yValues = List<double>.generate(6, (i) => start + (i * step));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          height: 120, // Slightly smaller to fit more charts
          child: pw.Chart(
            grid: pw.CartesianGrid(
              xAxis: pw.FixedAxis(
                List<double>.generate(data.length, (i) => i.toDouble()),
                format: (v) {
                  final index = v.toInt();
                  if (index >= 0 && index < data.length) {
                    return DateFormat('dd/MM').format(data[index].fecha);
                  }
                  return '';
                },
              ),
              yAxis: pw.FixedAxis(
                yValues,
                format: (v) => '${v.toStringAsFixed(1)}$unit',
              ),
            ),
            datasets: [
              pw.LineDataSet(
                color: color,
                pointColor: color,
                pointSize: 2,
                data: List<pw.PointChartValue>.generate(
                  data.length,
                  (i) => pw.PointChartValue(i.toDouble(), getValue(data[i])!),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildDetailedTable(
    List<Progreso> historial,
    PdfSettings settings,
    PdfColor primary,
    PdfColor secondary,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'HISTORIAL DE MEDICIONES',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['FECHA', 'PESO', 'GRASA %', 'MÚSCULO kg'],
          data: historial.reversed
              .map(
                (p) => [
                  DateFormat('dd/MM/yyyy').format(p.fecha),
                  '${p.peso ?? '-'} kg',
                  '${p.grasaCorporal ?? '-'} %',
                  '${p.masaMusculoEsqueletica ?? '-'} kg',
                ],
              )
              .toList(),
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: settings.tableFontSize,
          ),
          headerDecoration: pw.BoxDecoration(
            color: settings.tableHeaderColor.isEmpty
                ? primary.shade(0.8)
                : _getPdfColor(settings.tableHeaderColor),
          ),
          cellStyle: pw.TextStyle(fontSize: settings.tableFontSize - 1),
          cellPadding: const pw.EdgeInsets.all(8),
        ),
      ],
    );
  }

  static pw.Widget _buildMuscleMeasuresSection(
    List<Progreso> historial,
    PdfSettings settings,
    PdfColor primary,
    PdfColor secondary,
  ) {
    final entriesWithMeasures = historial
        .where((p) => p.musculo != null && p.musculo!.isNotEmpty)
        .toList();
    if (entriesWithMeasures.isEmpty) return pw.Container();

    final muscleNames = <String>{};
    for (var entry in entriesWithMeasures) {
      for (var m in entry.musculo!) {
        muscleNames.add(m.nombre);
      }
    }

    final sortedMuscleNames = muscleNames.toList()..sort();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'MEDIDAS CORPORALES DETALLADAS',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['FECHA', ...sortedMuscleNames.map((n) => n.toUpperCase())],
          data: entriesWithMeasures.reversed.map((p) {
            return [
              DateFormat('dd/MM/yyyy').format(p.fecha),
              ...sortedMuscleNames.map((name) {
                final measure = p.musculo!.firstWhere(
                  (m) => m.nombre == name,
                  orElse: () => MedidaMusculo(nombre: name, medida: 0),
                );
                return measure.medida > 0 ? '${measure.medida} cm' : '-';
              }),
            ];
          }).toList(),
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: settings.tableFontSize - 1,
          ),
          headerDecoration: pw.BoxDecoration(
            color: settings.tableHeaderColor.isEmpty
                ? secondary.shade(0.8)
                : _getPdfColor(settings.tableHeaderColor),
          ),
          cellStyle: pw.TextStyle(fontSize: settings.tableFontSize - 2),
          cellPadding: const pw.EdgeInsets.all(6),
        ),
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
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            settings.footerText,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
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
      case 'landscape':
        return PdfPageFormat.a4.landscape;
      case 'portrait':
        return PdfPageFormat.a4;
      case 'auto':
      default:
        return PdfPageFormat.a4;
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

  // --- PERFORMANCE PDF GENERATION ---

  static Future<pw.Document> generatePerformanceDocument(
    Cliente cliente,
    Map<String, List<ExerciseHistoryRecord>> exerciseHistories,
    PdfSettings settings,
  ) async {
    final doc = pw.Document();
    final primary = _getPdfColor(settings.primaryColor);
    final secondary = _getPdfColor(settings.secondaryColor);
    final accent = _getPdfColor(settings.accentColor);

    final fontRegular = await _getFont(settings.fontFamily, false);
    final fontBold = await _getFont(settings.fontFamily, true);
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    pw.MemoryImage? logoImage;
    if (settings.logoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(settings.logoUrl));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        debugPrint('Error loading Performance PDF logo: $e');
      }
    }

    final pageFormat = _getPageFormat(settings.pageOrientation);
    final margins = _getMargins(settings.pageMargins);

    // Extract latest corporal metrics for header
    final rawHistorial = cliente.historialProgreso;
    final List<Progreso> historial = (rawHistorial != null)
        ? rawHistorial
              .whereType<Map>()
              .map((json) => Progreso.fromJson(Map<String, dynamic>.from(json)))
              .toList()
        : [];

    final latestWeight = historial
        .where((p) => p.peso != null)
        .lastOrNull
        ?.peso;
    final latestFat = historial
        .where((p) => p.grasaCorporal != null)
        .lastOrNull
        ?.grasaCorporal;
    final latestMuscle = historial
        .where((p) => p.masaMusculoEsqueletica != null)
        .lastOrNull
        ?.masaMusculoEsqueletica;

    // Cover Page
    if (settings.includeCoverPage) {
      doc.addPage(
        _buildCoverPage(
          '${cliente.nombre} - RENDIMIENTO',
          settings,
          logoImage,
          theme,
          primary,
          accent,
          pageFormat,
        ),
      );
    }

    // Main Performance Page(s)
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: pageFormat,
          theme: theme,
          margin: margins,
          buildBackground: (context) => _buildBackground(context, settings),
        ),
        header: (context) => _buildHeader(
          'REPORTE DE RENDIMIENTO',
          DateFormat('dd/MM/yyyy').format(DateTime.now()),
          settings,
          logoImage,
          primary,
          secondary,
          accent,
        ),
        footer: (context) => _buildFooter(context, settings, secondary),
        build: (context) => [
          _buildClientSummary(
            cliente,
            settings,
            primary,
            secondary,
            weight: latestWeight,
            fat: latestFat,
            muscle: latestMuscle,
          ),
          pw.SizedBox(height: settings.sectionSpacing),
          _buildPerformanceOverview(exerciseHistories, settings, primary),
          pw.SizedBox(height: settings.sectionSpacing),
          ..._buildDetailedExerciseReports(
            exerciseHistories,
            settings,
            primary,
            secondary,
          ),
        ],
      ),
    );

    return doc;
  }

  static pw.Widget _buildPerformanceOverview(
    Map<String, List<ExerciseHistoryRecord>> histories,
    PdfSettings settings,
    PdfColor primary,
  ) {
    if (histories.isEmpty) return pw.Container();

    final headers = [
      'EJERCICIO',
      'ÚLT. PESO',
      'ÚLT. 1RM',
      'VOL. TOTAL',
      'RECORDS',
    ];
    final data = histories.entries.map((entry) {
      final last = entry.value.lastOrNull;
      if (last == null) return [entry.key, '-', '-', '-', '-'];

      final maxWeight = entry.value
          .map((e) => e.maxWeight)
          .reduce((a, b) => a > b ? a : b);

      return [
        entry.key.toUpperCase(),
        '${last.maxWeight.toStringAsFixed(1)} kg',
        '${last.estimated1RM.toStringAsFixed(1)} kg',
        '${last.totalVolume.toStringAsFixed(0)} kg',
        'PR: ${maxWeight.toStringAsFixed(1)} kg',
      ];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'RESUMEN GENERAL DE RENDIMIENTO',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: data,
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: 8,
          ),
          headerDecoration: pw.BoxDecoration(color: primary),
          cellStyle: pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(1.5),
          },
        ),
      ],
    );
  }

  static List<pw.Widget> _buildDetailedExerciseReports(
    Map<String, List<ExerciseHistoryRecord>> histories,
    PdfSettings settings,
    PdfColor primary,
    PdfColor secondary,
  ) {
    final widgets = <pw.Widget>[];

    for (var entry in histories.entries) {
      final name = entry.key;
      final data = entry.value;
      if (data.isEmpty) continue;

      widgets.add(
        pw.Text(
          name.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: primary,
          ),
        ),
      );
      widgets.add(pw.SizedBox(height: 8));

      // NEW: Highlight Cards for Latest Session
      final last = data.last;
      widgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildHighlightCard(
              'PESO MÁX',
              '${last.maxWeight.toStringAsFixed(1)}kg',
              secondary,
            ),
            _buildHighlightCard(
              '1RM EST.',
              '${last.estimated1RM.toStringAsFixed(1)}kg',
              primary,
            ),
            _buildHighlightCard(
              'VOLUMEN',
              '${last.totalVolume.toInt()}kg',
              secondary,
            ),
            _buildHighlightCard('REPS MÁX', '${last.maxReps}', primary),
          ],
        ),
      );
      widgets.add(pw.SizedBox(height: 15));

      // NEW: Multi-line PR Evolution Chart (Max Weight vs 1RM)
      if (data.length >= 2) {
        widgets.add(
          _buildMultiMetricChart(
            'EVOLUCIÓN PR: $name',
            data,
            [(e) => e.maxWeight, (e) => e.estimated1RM],
            ['MAX KG', '1RM KG'],
            [secondary, primary],
            settings,
          ),
        );
        widgets.add(pw.SizedBox(height: 15));

        // NEW: Volume Evolution Chart
        widgets.add(
          _buildVolumeBarChart(
            'EVOLUCIÓN VOLUMEN TOTAL: $name',
            data,
            (e) => e.totalVolume,
            'kg',
            settings,
            secondary,
          ),
        );
        widgets.add(pw.SizedBox(height: 15));
      }

      // Smaller History table (last 5 entries)
      final tableHeaders = ['FECHA', 'PESO MÁX', '1RM EST.', 'VOLUMEN', 'REPS'];
      final tableData = data.reversed
          .take(5)
          .map(
            (e) => [
              DateFormat('dd/MM/yy').format(e.fecha),
              '${e.maxWeight.toStringAsFixed(1)} kg',
              '${e.estimated1RM.toStringAsFixed(1)} kg',
              '${e.totalVolume.toStringAsFixed(0)} kg',
              '${e.maxReps}',
            ],
          )
          .toList();

      widgets.add(
        pw.TableHelper.fromTextArray(
          headers: tableHeaders,
          data: tableData,
          border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: 7,
          ),
          headerDecoration: pw.BoxDecoration(color: secondary),
          cellStyle: pw.TextStyle(fontSize: 7),
          cellAlignment: pw.Alignment.center,
        ),
      );

      widgets.add(pw.SizedBox(height: settings.sectionSpacing));
    }

    return widgets;
  }

  // Helper to reuse _buildMetricChart with Exercise data

  static pw.Widget _buildHighlightCard(
    String title,
    String value,
    PdfColor color,
  ) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: _withOpacity(color, 0.1),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: color, width: 1),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            title.toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black, // Force black for visibility
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black, // Force black for visibility
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMultiMetricChart(
    String title,
    List<ExerciseHistoryRecord> data,
    List<double Function(ExerciseHistoryRecord)> getters,
    List<String> labels,
    List<PdfColor> colors,
    PdfSettings settings,
  ) {
    // Find absolute min/max across all metrics
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (var getter in getters) {
      for (var e in data) {
        final val = getter(e);
        if (val < minVal) minVal = val;
        if (val > maxVal) maxVal = val;
      }
    }

    final range = maxVal - minVal;
    final padding = range > 0 ? range * 0.2 : 5.0;
    final start = (minVal - padding).floorToDouble();
    final end = (maxVal + padding).ceilToDouble();
    final step = (end - start) / 5;
    final yValues = List<double>.generate(6, (i) => start + (i * step));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
            pw.Row(
              children: List.generate(labels.length, (i) {
                return pw.Row(
                  children: [
                    pw.Container(width: 8, height: 8, color: colors[i]),
                    pw.SizedBox(width: 4),
                    pw.Text(labels[i], style: const pw.TextStyle(fontSize: 7)),
                    pw.SizedBox(width: 8),
                  ],
                );
              }),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          height: 120,
          child: pw.Chart(
            grid: pw.CartesianGrid(
              xAxis: pw.FixedAxis(
                List<double>.generate(data.length, (i) => i.toDouble()),
                format: (v) {
                  final index = v.toInt();
                  if (index >= 0 && index < data.length) {
                    return DateFormat('dd/MM').format(data[index].fecha);
                  }
                  return '';
                },
              ),
              yAxis: pw.FixedAxis(
                yValues,
                format: (v) => '${v.toStringAsFixed(1)}kg',
              ),
            ),
            datasets: List.generate(getters.length, (i) {
              return pw.LineDataSet(
                color: colors[i],
                pointColor: colors[i],
                pointSize: 2,
                data: List<pw.PointChartValue>.generate(
                  data.length,
                  (j) => pw.PointChartValue(j.toDouble(), getters[i](data[j])),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildVolumeBarChart(
    String title,
    List<ExerciseHistoryRecord> data,
    double Function(ExerciseHistoryRecord) getValue,
    String unit,
    PdfSettings settings,
    PdfColor color,
  ) {
    if (data.isEmpty) return pw.Container();

    final values = data.map((e) => getValue(e)).toList();
    final maxVal = values.isNotEmpty
        ? values.reduce((a, b) => a > b ? a : b)
        : 0.0;

    // Y axis range
    final padding = maxVal * 0.1;
    final end = (maxVal + padding).ceilToDouble();
    final yValues = List<double>.generate(6, (i) => (end / 5) * i);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          height: 120,
          child: pw.Chart(
            grid: pw.CartesianGrid(
              xAxis: pw.FixedAxis(
                List<double>.generate(data.length, (i) => i.toDouble()),
                format: (v) {
                  final index = v.toInt();
                  if (index >= 0 && index < data.length) {
                    return DateFormat('dd/MM').format(data[index].fecha);
                  }
                  return '';
                },
              ),
              yAxis: pw.FixedAxis(
                yValues,
                format: (v) => v >= 1000
                    ? '${(v / 1000).toStringAsFixed(1)}k'
                    : v.toStringAsFixed(0),
              ),
            ),
            datasets: [
              pw.BarDataSet(
                color: color,
                width: 15,
                offset: 0,
                data: List<pw.PointChartValue>.generate(
                  data.length,
                  (i) => pw.PointChartValue(i.toDouble(), getValue(data[i])),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
