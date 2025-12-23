import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../../models/settings_model.dart';

class BusinessSettingsDialog extends StatefulWidget {
  final UserSettings settings;
  final Function(UserSettings) onSave;

  const BusinessSettingsDialog({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<BusinessSettingsDialog> createState() => _BusinessSettingsDialogState();
}

class _BusinessSettingsDialogState extends State<BusinessSettingsDialog> {
  late TextEditingController _emailController;
  late TextEditingController _signatureController;
  String? _localBase64Image;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(
      text: widget.settings.businessEmail,
    );
    _signatureController = TextEditingController(
      text: widget.settings.emailSignature,
    );
    _localBase64Image = widget.settings.signatureImageUrl;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Widget _buildLogoPreview(String base64String) {
    try {
      return Image.memory(
        base64Decode(base64String),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 40),
      );
    } catch (e) {
      return const Icon(Icons.broken_image, size: 40);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configuración de Negocio'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Corporativo',
                hintText: 'ejemplo@empresa.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _signatureController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Firma de Email',
                hintText: 'Tu firma en formato HTML o texto...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Logo de Empresa',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                try {
                  final picker = ImagePicker();
                  final image = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 800,
                    maxHeight: 800,
                    imageQuality: 85,
                  );
                  if (image != null) {
                    final bytes = await image.readAsBytes();
                    setState(() {
                      _localBase64Image = base64Encode(bytes);
                    });
                  }
                } catch (e) {
                  debugPrint('Error al seleccionar imagen: $e');
                }
              },
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child:
                    _localBase64Image != null && _localBase64Image!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: _buildLogoPreview(_localBase64Image!),
                            ),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                radius: 14,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _localBase64Image = null;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 32,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Subir Logo',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(
              widget.settings.copyWith(
                businessEmail: _emailController.text,
                emailSignature: _signatureController.text,
                signatureImageUrl: _localBase64Image,
              ),
            );
            Navigator.pop(context);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
