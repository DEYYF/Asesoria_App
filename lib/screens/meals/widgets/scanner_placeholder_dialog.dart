import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'barcode_scanner_screen.dart';
import '../../../services/ocr_service.dart';
import '../../../widgets/dialogs/add_edit_ingrediente_dialog.dart';

class ScannerPlaceholderDialog extends StatelessWidget {
  final VoidCallback onSuccess;
  const ScannerPlaceholderDialog({super.key, required this.onSuccess});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.qr_code_scanner_rounded, color: Colors.orange),
          SizedBox(width: 12),
          Text('Añadir Producto'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(
            context,
            icon: Icons.camera_alt_rounded,
            title: 'Hacer Foto',
            subtitle: 'Extraer macros de una foto',
            onTap: () async {
              final source = await showModalBottomSheet<ImageSource>(
                context: context,
                builder: (context) => SafeArea(
                  child: Wrap(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.camera_alt),
                        title: const Text('Cámara'),
                        onTap: () => Navigator.pop(context, ImageSource.camera),
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library),
                        title: const Text('Galería'),
                        onTap: () =>
                            Navigator.pop(context, ImageSource.gallery),
                      ),
                    ],
                  ),
                ),
              );

              if (source != null) {
                if (context.mounted) Navigator.pop(context); // Close dialog
                _pickAndProcessImage(context, source);
              }
            },
          ),
          const SizedBox(height: 12),
          _buildOption(
            context,
            icon: Icons.barcode_reader,
            title: 'Scanear',
            subtitle: 'Código de barras',
            onTap: () {
              Navigator.pop(context); // Close dialog
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      BarcodeScannerScreen(onSuccess: onSuccess),
                ),
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }

  Future<void> _pickAndProcessImage(
    BuildContext context,
    ImageSource source,
  ) async {
    final picker = ImagePicker();
    print('Picking image from source: $source');
    final XFile? image = await picker.pickImage(source: source);

    if (image == null) {
      print('No image selected.');
      return;
    }

    print('Image selected: ${image.path}');

    if (!context.mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    OCRService? ocrService; // Declare here to ensure it's in scope for finally
    try {
      ocrService = OCRService(); // Initialize inside try block
      print('Starting OCR extraction...');
      final ingrediente = await ocrService.extractNutritionalData(image.path);
      print('OCR extraction completed.');

      if (!context.mounted) return;
      Navigator.pop(context); // Remove loading

      if (ingrediente != null) {
        print('Opening AddEditIngredienteDialog with pre-filled data.');
        showDialog(
          context: context,
          builder: (context) => AddEditIngredienteDialog(
            ingrediente: ingrediente,
            onSuccess: onSuccess,
          ),
        );
      } else {
        print('Extraction returned null ingrediente.');
      }
    } catch (e) {
      print('Error during OCR processing: $e');
      if (context.mounted) {
        Navigator.pop(context); // Remove loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al procesar imagen: $e')));
      }
    } finally {
      ocrService?.dispose();
    }
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.primaryColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: theme.hintColor),
          ],
        ),
      ),
    );
  }
}
