import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cliente_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/template_model.dart';
import 'dialogs/template_selector_dialog.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/settings/email_history_screen.dart';
import 'dart:convert';
import 'dart:io';

class DialogCorreo extends StatefulWidget {
  final Cliente cliente;
  final VoidCallback? onSuccess;

  const DialogCorreo({super.key, required this.cliente, this.onSuccess});

  @override
  State<DialogCorreo> createState() => _DialogCorreoState();
}

class _DialogCorreoState extends State<DialogCorreo> {
  final _subjectCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  late TextEditingController _toCtrl;

  bool _sending = false;
  final List<XFile> _attachments = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _toCtrl = TextEditingController(text: widget.cliente.email);
    _msgCtrl.text = "Hola ${widget.cliente.nombre},\n\n";
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _msgCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectTemplate() async {
    final template = await showDialog<MessageTemplate>(
      context: context,
      builder: (_) => const TemplateSelectorDialog(type: 'email'),
    );
    if (template != null) {
      if (mounted) {
        setState(() {
          _subjectCtrl.text = template.subject ?? '';
          _msgCtrl.text = template.content;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _attachments.add(image);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _viewHistory() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmailHistoryScreen(
          clienteId: widget.cliente.id,
          clienteNombre: widget.cliente.nombre,
        ),
      ),
    );
  }

  Future<void> _send() async {
    if (_toCtrl.text.isEmpty ||
        _subjectCtrl.text.isEmpty ||
        _msgCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rellena todos los campos')));
      return;
    }

    setState(() => _sending = true);
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);

    try {
      // Convert attachments to base64
      final List<Map<String, dynamic>> attachmentsData = [];
      for (var file in _attachments) {
        final bytes = await file.readAsBytes();
        attachmentsData.add({
          'filename': file.name,
          'content': base64Encode(bytes),
          'encoding': 'base64',
        });
      }

      await api.post('/correo/enviar', {
        'destinatario': _toCtrl.text,
        'asunto': _subjectCtrl.text,
        'mensaje': _msgCtrl.text,
        'clienteId': widget.cliente.id,
        'asesorId': auth.userId,
        if (attachmentsData.isNotEmpty) 'attachments': attachmentsData,
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Correo enviado')));
        widget.onSuccess?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 550,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER WITH GRADIENT
              Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue[700]!, Colors.blue[500]!],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.email_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Enviar Correo',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _selectTemplate,
                      icon: const Icon(
                        Icons.description_outlined,
                        color: Colors.white,
                      ),
                      tooltip: 'Usar Plantilla',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white10,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _viewHistory,
                      icon: const Icon(
                        Icons.history_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Ver Historial',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white10,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white10,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      controller: _toCtrl,
                      label: 'Para',
                      hint: 'correo@ejemplo.com',
                      icon: Icons.person_outline_rounded,
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _subjectCtrl,
                      label: 'Asunto',
                      hint: 'Ej: Tu actualización semanal',
                      icon: Icons.subject_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _msgCtrl,
                      label: 'Mensaje',
                      hint: 'Escribe tu correo aquí...',
                      icon: Icons.message_rounded,
                      maxLines: 10,
                    ),
                    const SizedBox(height: 16),
                    // ATTACHMENTS SECTION
                    Row(
                      children: [
                        const Text(
                          'Adjuntos',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 20,
                          ),
                          label: const Text('Añadir Imagen'),
                        ),
                      ],
                    ),
                    if (_attachments.isNotEmpty)
                      Container(
                        height: 90,
                        margin: const EdgeInsets.only(top: 8),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _attachments.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    image: DecorationImage(
                                      image: FileImage(
                                        File(_attachments[index].path),
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                    border: Border.all(
                                      color: theme.dividerColor,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onTap: () => _removeAttachment(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _sending ? null : _send,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shadowColor: Colors.blue.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Enviar Correo',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[700]!, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
