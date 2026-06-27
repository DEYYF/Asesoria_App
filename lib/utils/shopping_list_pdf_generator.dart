import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'pdf_export_helper.dart';

class ShoppingListPdfGenerator {
  /// Build and export a PDF for [ingredients] grouped by category.
  static Future<void> generatePDF({
    required List<dynamic> ingredients,
    required String dietaNombre,
    required String period,
  }) async {
    final bytes = await _buildPdfBytes(
      ingredients: ingredients,
      dietaNombre: dietaNombre,
      period: period,
    );
    final fileName =
        'lista_compra_${period}_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
    await PdfExportHelper.exportPdf(bytes: bytes, fileName: fileName);
  }

  static Future<Uint8List> _buildPdfBytes({
    required List<dynamic> ingredients,
    required String dietaNombre,
    required String period,
  }) async {
    return compute(
      _buildInIsolate,
      _Params(
        ingredients: ingredients,
        dietaNombre: dietaNombre,
        period: period,
      ),
    );
  }

  static Future<Uint8List> _buildInIsolate(_Params p) async {
    final doc = pw.Document();

    // ── Colours ──────────────────────────────────────────────────────────────
    const primary = PdfColor.fromInt(0xFF34C759);
    const primaryLight = PdfColor.fromInt(0xFFD4EFDB);
    const textDark = PdfColor.fromInt(0xFF1C1C1E);
    const textGrey = PdfColor.fromInt(0xFF8E8E93);
    const bgLight = PdfColor.fromInt(0xFFF2F2F7);

    // ── Data ──────────────────────────────────────────────────────────────────
    final groups = _groupByCategory(p.ingredients);
    final categories = groups.keys.toList()..sort();
    final dateStr = DateFormat('d MMM yyyy', 'es').format(DateTime.now());
    final periodLabel = p.period.toUpperCase();
    final totalItems = p.ingredients.length;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 40),
        header: (ctx) => _header(
          ctx,
          dietaNombre: p.dietaNombre,
          periodLabel: periodLabel,
          dateStr: dateStr,
          totalItems: totalItems,
          primary: primary,
          primaryLight: primaryLight,
          textDark: textDark,
          textGrey: textGrey,
          bgLight: bgLight,
        ),
        footer: (ctx) => _footer(ctx, textGrey: textGrey),
        build: (ctx) => [
          pw.SizedBox(height: 16),
          for (final cat in categories)
            _categorySection(
              cat,
              groups[cat]!,
              primary: primary,
              primaryLight: primaryLight,
              textDark: textDark,
              textGrey: textGrey,
              bgLight: bgLight,
            ),
        ],
      ),
    );

    return doc.save();
  }

  // ── Header ────────────────────────────────────────────────────────────────
  static pw.Widget _header(
    pw.Context ctx, {
    required String dietaNombre,
    required String periodLabel,
    required String dateStr,
    required int totalItems,
    required PdfColor primary,
    required PdfColor primaryLight,
    required PdfColor textDark,
    required PdfColor textGrey,
    required PdfColor bgLight,
  }) {
    if (ctx.pageNumber > 1) {
      return pw.Column(children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Lista de la Compra',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: primary,
              ),
            ),
            pw.Text(
              dietaNombre,
              style: pw.TextStyle(fontSize: 10, color: textGrey),
            ),
          ],
        ),
        pw.Divider(color: primary, thickness: 0.5),
        pw.SizedBox(height: 4),
      ]);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Banner
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: pw.BoxDecoration(
            color: primary,
            borderRadius: pw.BorderRadius.circular(14),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Lista de la Compra',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    dietaNombre,
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColor.fromInt(0xCCFFFFFF),
                    ),
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(20),
                    ),
                    child: pw.Text(
                      periodLabel,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: primary,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    dateStr,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColor.fromInt(0xCCFFFFFF),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
        // Summary strip
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: pw.BoxDecoration(
            color: bgLight,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            children: [
              pw.Text(
                '$totalItems artículos en total',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: textDark,
                ),
              ),
              pw.Spacer(),
              pw.Text(
                'AsesoríaApp',
                style: pw.TextStyle(fontSize: 9, color: textGrey),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  static pw.Widget _footer(pw.Context ctx, {required PdfColor textGrey}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'AsesoríaApp · Lista de la Compra',
          style: pw.TextStyle(fontSize: 8, color: textGrey),
        ),
        pw.Text(
          'Pág. ${ctx.pageNumber} / ${ctx.pagesCount}',
          style: pw.TextStyle(fontSize: 8, color: textGrey),
        ),
      ],
    );
  }

  // ── Category section ──────────────────────────────────────────────────────
  static pw.Widget _categorySection(
    String category,
    List<dynamic> items, {
    required PdfColor primary,
    required PdfColor primaryLight,
    required PdfColor textDark,
    required PdfColor textGrey,
    required PdfColor bgLight,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: primaryLight,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            children: [
              pw.Container(width: 4, height: 14, color: primary),
              pw.SizedBox(width: 8),
              pw.Text(
                category.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: primary,
                  letterSpacing: 1.2,
                ),
              ),
              pw.Spacer(),
              pw.Text(
                '${items.length} artículo${items.length != 1 ? 's' : ''}',
                style: pw.TextStyle(fontSize: 9, color: primary),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
        ...items.asMap().entries.map(
          (e) => _ingredientRow(
            e.value,
            isEven: e.key.isEven,
            textDark: textDark,
            textGrey: textGrey,
            bgLight: bgLight,
            primary: primary,
          ),
        ),
      ],
    );
  }

  // ── Ingredient row ────────────────────────────────────────────────────────
  static pw.Widget _ingredientRow(
    dynamic item, {
    required bool isEven,
    required PdfColor textDark,
    required PdfColor textGrey,
    required PdfColor bgLight,
    required PdfColor primary,
  }) {
    final name = item['name'] ?? '';
    final grams = (item['grams'] as num?) ?? 0;
    final inPantry = item['inPantry'] == true;
    final qty = _formatQuantity(grams);

    return pw.Container(
      color: isEven ? bgLight : PdfColors.white,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: pw.Row(
        children: [
          // Checkbox
          pw.Container(
            width: 14,
            height: 14,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: inPantry ? primary : textGrey,
                width: 1.5,
              ),
              borderRadius: pw.BorderRadius.circular(3),
              color: inPantry ? primary : PdfColors.white,
            ),
            child: inPantry
                ? pw.Center(
                    child: pw.Text(
                      '✓',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.white,
                      ),
                    ),
                  )
                : null,
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Text(
              name,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: inPantry ? textGrey : textDark,
                decoration:
                    inPantry ? pw.TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (grams > 0)
            pw.Text(
              qty,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: primary,
              ),
            ),
          pw.SizedBox(width: 8),
          if (inPantry)
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFFFF3CD),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'DESPENSA',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColor.fromInt(0xFF856404),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static Map<String, List<dynamic>> _groupByCategory(List<dynamic> items) {
    final grouped = <String, List<dynamic>>{};
    for (var item in items) {
      final cat = item['category'] ?? 'General';
      if (!grouped.containsKey(cat)) grouped[cat] = [];
      grouped[cat]!.add(item);
    }
    return grouped;
  }

  static String _formatQuantity(num grams) {
    if (grams >= 1000) {
      final kg = grams / 1000;
      return '${kg.toStringAsFixed(kg.truncateToDouble() == kg ? 0 : 1)} kg';
    }
    return '${grams.round()} g';
  }
}

class _Params {
  final List<dynamic> ingredients;
  final String dietaNombre;
  final String period;
  const _Params({
    required this.ingredients,
    required this.dietaNombre,
    required this.period,
  });
}
