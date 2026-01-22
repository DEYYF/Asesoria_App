import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:downloadsfolder/downloadsfolder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

class PdfExportHelper {
  /// Unified method to export a PDF across platforms.
  /// On Mobile: Opens native share sheet.
  /// On Desktop: Saves to Downloads folder and opens the folder.
  /// On Web: Opens standard print/share dialog.
  static Future<void> exportPdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    // Ensure filename ends with .pdf
    if (!fileName.toLowerCase().endsWith('.pdf')) {
      fileName = '$fileName.pdf';
    }

    if (kIsWeb) {
      // Standard for web
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      // Best experience on mobile: Native Share Sheet
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // Best experience on Desktop: Direct Download + Notification (Open folder)
      try {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(bytes);

        // Copy to standard Downloads folder
        final success = await copyFileIntoDownloadFolder(
          tempFile.path,
          fileName,
        );

        if (success == true) {
          // Open the folder so the user sees their new file
          await openDownloadFolder();
        } else {
          // Fallback if downloadsfolder fails
          await Printing.sharePdf(bytes: bytes, filename: fileName);
        }
      } catch (e) {
        debugPrint('Error exporting PDF to Downloads: $e');
        // Final fallback: Printing package
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      }
    } else {
      // Fallback for other platforms
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    }
  }
}
