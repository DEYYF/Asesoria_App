import 'dart:io';

import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/dieta_model.dart';

class DietPdfGenerator {
  static Future<void> generatePDF(Dieta dieta) async {
    final doc = pw.Document();

    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final dateStr = dieta.createdAt != null
        ? DateFormat('dd/MM/yyyy').format(dieta.createdAt!)
        : '-';

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4.landscape,
          theme: theme,
          margin: const pw.EdgeInsets.all(28),
        ),
        header: (context) => _buildHeader(dieta, dateStr, context),
        build: (context) => [
          _buildMacrosTable(dieta),
          pw.SizedBox(height: 20),
          ...dieta.comidas.map((c) => _buildMealSection(c)),
        ],
      ),
    );

    final tempDir = await getTemporaryDirectory();

    final pdfBytes = await doc.save();
    final name = 'dieta_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes(pdfBytes);

    await copyFileIntoDownloadFolder(file.path, name);
    await openDownloadFolder();

  }

  static pw.Widget _buildHeader(
    Dieta dieta,
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
          color: PdfColors.orange200, // Light orange
          height: 8,
          width: double.infinity,
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Dieta · ${dieta.macros.kcal.round()} kcal · $dateStr',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.Text(
          'Detalle de la dieta',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  static pw.Widget _buildMacrosTable(Dieta dieta) {
    return pw.TableHelper.fromTextArray(
      context: null,
      headers: ['Proteínas (g)', 'Carbohidratos (g)', 'Grasas (g)'],
      data: [
        [
          dieta.macros.proteinas.toStringAsFixed(0),
          dieta.macros.carbohidratos.toStringAsFixed(0),
          dieta.macros.grasas.toStringAsFixed(0),
        ],
      ],
      headerDecoration: const pw.BoxDecoration(color: PdfColors.orange100),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellAlignment: pw.Alignment.center,
    );
  }

  static pw.Widget _buildMealSection(Comida comida) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          comida.titulo,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['#', 'Tipo', 'Nombre', 'Métricas', 'Ingredientes'],
          data: comida.opciones.asMap().entries.map((e) {
            final idx = e.key + 1;
            final op = e.value;
            final name = _getOptionName(op);
            final metrics =
                'Kcal: ${op.macrosTotales?.kcal.round() ?? op.macrosTotales?.kcal.round() ?? 0}\n'
                'P: ${op.macrosTotales?.proteinas.toStringAsFixed(1) ?? 0} · C: ${op.macrosTotales?.carbohidratos.toStringAsFixed(1) ?? 0} · G: ${op.macrosTotales?.grasas.toStringAsFixed(1) ?? 0}';

            final ingredients = _getIngredientsText(op);

            return [idx.toString(), op.tipo, name, metrics, ingredients];
          }).toList(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.orange50),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          columnWidths: {
            0: const pw.FixedColumnWidth(25),
            1: const pw.FixedColumnWidth(60),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(3),
          },
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  static String _getOptionName(OpcionDieta op) {
    var n = op.nombre ?? 'Sin nombre';
    if ((op.tipo == 'ingrediente' || op.tipo == 'alimento') &&
        op.gramos != null) {
      n += ' (${op.gramos} gr)';
    }
    return n;
  }

  static String _getIngredientsText(OpcionDieta op) {
    if (op.items != null && op.items!.isNotEmpty) {
      return op.items!
          .map((i) => '${i.nombre ?? "Ingrediente"} (${i.gramos} gr)')
          .join(', ');
    }
    // Note: Recetas might need separate handling if `recetaId` logic was complex, but backend populates ingredients?
    // In Flutter model OpcionDieta, we handled `items` for combinations.
    // If recipes reuse `items` logic or just show name, we rely on `items`.
    return '-';
  }
}
