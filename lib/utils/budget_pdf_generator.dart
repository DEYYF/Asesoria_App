import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/settings_model.dart';

class BudgetPdfGenerator {
  static Future<pw.Document> generateDocument(
    dynamic p,
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
        if (response.statusCode == 200)
          logoImage = pw.MemoryImage(response.bodyBytes);
      } catch (e) {
        debugPrint('Error loading Budget PDF logo: $e');
      }
    }

    final clientName = p['clienteId']?['nombre'] ?? p['nombreCliente'] ?? "N/A";
    final clientEmail = p['clienteId']?['email'] ?? p['emailCliente'] ?? "";
    final dateStr = DateFormat(
      'dd/MM/yyyy',
    ).format(DateTime.parse(p['createdAt']));

    // Determine page format and margins
    final pageFormat = _getPageFormat(settings.pageOrientation);
    final margins = _getMargins(settings.pageMargins);

    // Cover Page
    if (settings.includeCoverPage) {
      doc.addPage(
        _buildCoverPage(
          clientName,
          settings,
          logoImage,
          theme,
          primary,
          accent,
          pageFormat,
        ),
      );
    }

    // Main Page
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: pageFormat,
          theme: theme,
          margin: margins,
        ),
        header: (context) => _buildHeader(
          p['_id'],
          dateStr,
          settings,
          logoImage,
          primary,
          secondary,
          accent,
        ),
        footer: (context) => _buildFooter(context, settings, secondary),
        build: (context) => [
          _buildClientInfoBox(clientName, clientEmail, primary, secondary),
          pw.SizedBox(height: 30),
          _buildItemsTable(p, primary, secondary, accent),
          pw.SizedBox(height: 20),
          _buildTotalsSection(p, primary, secondary, accent),
        ],
      ),
    );

    return doc;
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
                'PRESUPUESTO',
                style: pw.TextStyle(
                  fontSize: 42,
                  fontWeight: pw.FontWeight.bold,
                  color: primary,
                ),
              ),
              pw.SizedBox(height: 80),
              pw.Text(
                'PARA:',
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
    String id,
    String date,
    PdfSettings settings,
    pw.MemoryImage? logo,
    PdfColor primary,
    PdfColor secondary,
    PdfColor accent,
  ) {
    final title = settings.headerTitle.isNotEmpty
        ? settings.headerTitle
        : 'PRESUPUESTO';
    final logoWidget = logo != null
        ? pw.Container(height: 45, width: 45, child: pw.Image(logo))
        : pw.Container();
    final textColumn = pw.Column(
      crossAxisAlignment: settings.headerStyle == 'modern'
          ? pw.CrossAxisAlignment.center
          : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: primary,
          ),
        ),
        pw.Text(
          'Nº $id · $date',
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

  static pw.Widget _buildClientInfoBox(
    String name,
    String email,
    PdfColor primary,
    PdfColor secondary,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CLIENTE',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: primary,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  name,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  email,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            width: 1,
            height: 40,
            color: PdfColors.grey300,
            margin: const pw.EdgeInsets.symmetric(horizontal: 20),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'VALIDEZ',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: secondary,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '15 Días naturales',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(
    dynamic p,
    PdfColor primary,
    PdfColor secondary,
    PdfColor accent,
  ) {
    return pw.TableHelper.fromTextArray(
      headers: ['CONCEPTO', 'CANTIDAD', 'PRECIO UNIT.', 'TOTAL'],
      data: [
        [
          p['tarifaId']?['nombre'] ?? 'Cuota Base',
          '1',
          '${p['tarifaId']?['precio'] ?? 0}€',
          '${p['tarifaId']?['precio'] ?? 0}€',
        ],
        ...(p['extras'] as List).map(
          (e) => [
            e['extraId']?['nombre'] ?? 'Servicio Extra',
            '1',
            '${e['precioTotal'] ?? 0}€',
            '${e['precioTotal'] ?? 0}€',
          ],
        ),
      ],
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
      ),
      headerDecoration: pw.BoxDecoration(color: primary.shade(0.8)),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.all(10),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
      },
    );
  }

  static pw.Widget _buildTotalsSection(
    dynamic p,
    PdfColor primary,
    PdfColor secondary,
    PdfColor accent,
  ) {
    final subtotal = (p['extras'] as List).fold<double>(
      (p['tarifaId']?['precio'] ?? 0).toDouble(),
      (sum, e) => sum + (e['precioTotal'] ?? 0),
    );
    final total = p['total'].toDouble();

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 200,
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            color: _withOpacity(accent, 0.05),
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: _withOpacity(accent, 0.2)),
          ),
          child: pw.Column(
            children: [
              _buildTotalRow(
                'Subtotal',
                '${subtotal.toStringAsFixed(2)}€',
                PdfColors.grey700,
                false,
              ),
              if ((p['descuento'] ?? 0) > 0)
                _buildTotalRow(
                  'Descuento (${p['descuento']}%)',
                  '-${(subtotal - total).toStringAsFixed(2)}€',
                  PdfColors.red,
                  false,
                ),
              pw.Divider(color: _withOpacity(accent, 0.3)),
              _buildTotalRow(
                'TOTAL',
                '${total.toStringAsFixed(2)}€',
                primary,
                true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTotalRow(
    String label,
    String value,
    PdfColor color,
    bool bold,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              color: bold ? PdfColors.black : PdfColors.grey700,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: bold ? 14 : 10,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
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
        return PdfPageFormat.a4; // Budgets default to portrait
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
