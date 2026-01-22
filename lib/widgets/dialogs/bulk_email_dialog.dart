import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/cliente_model.dart';
import '../../services/auth_service.dart';
import '../../models/template_model.dart';
import 'template_selector_dialog.dart';
import '../../utils/notification_helper.dart';

class BulkEmailDialog extends StatefulWidget {
  final List<Cliente> clientes;

  const BulkEmailDialog({super.key, required this.clientes});

  @override
  State<BulkEmailDialog> createState() => _BulkEmailDialogState();
}

class _BulkEmailDialogState extends State<BulkEmailDialog> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  List<Cliente> get _clientsWithEmail =>
      widget.clientes.where((c) => c.email.isNotEmpty ?? false).toList();

  void _handleSendClick() {
    if (_subjectController.text.trim().isEmpty ||
        _messageController.text.trim().isEmpty) {
      NotificationHelper.showInfo(
        context,
        'Por favor completa el asunto y el mensaje',
      );
      return;
    }

    if (_clientsWithEmail.isEmpty) {
      NotificationHelper.showInfo(
        context,
        'No hay clientes con email en la lista actual',
      );
      return;
    }

    _showConfirmDialog();
  }

  void _showConfirmDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Envío'),
        content: Text(
          '¿Estás seguro de que deseas enviar este email a ${_clientsWithEmail.length} clientes?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleConfirmSend();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Confirmar y Enviar'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTemplate() async {
    final template = await showDialog<MessageTemplate>(
      context: context,
      builder: (_) => const TemplateSelectorDialog(type: 'email'),
    );
    if (template != null) {
      if (mounted) {
        setState(() {
          _subjectController.text = template.subject ?? '';
          _messageController.text = template.content;
        });
      }
    }
  }

  Future<void> _handleConfirmSend() async {
    setState(() => _sending = true);

    final api = Provider.of<ApiService>(context, listen: false);
    final emailAddresses = _clientsWithEmail
        .map((c) => c.email)
        .where((e) => e.isNotEmpty)
        .toList();

    final auth = Provider.of<AuthService>(context, listen: false);

    try {
      await api.post('/correo/enviar', {
        'to': emailAddresses.first,
        'bcc': emailAddresses.skip(1).toList(),
        'subject': _subjectController.text,
        'asesorId': auth.userId,
        'html':
            '''
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #333;">Hola,</h2>
            <div style="white-space: pre-wrap;">${_messageController.text}</div>
            <br/>
            <p style="color: #666; font-size: 12px;">Este email fue enviado desde Asesoría Enterprise</p>
          </div>
        ''',
      });

      if (mounted) {
        NotificationHelper.showSuccess(
          context,
          'Email enviado correctamente a ${_clientsWithEmail.length} clientes',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.showError(context, 'Error al enviar el email: $e');
      }
    } finally {
      if (mounted) {
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
              // HEADER WITH GRADIENT (Blue for Bulk Email)
              Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue[800]!, Colors.blue[600]!],
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
                        Icons.mark_as_unread_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Envío Masivo (Email)',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${_clientsWithEmail.length} destinatarios con email',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_sending) ...[
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
                    ],
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
                      controller: _subjectController,
                      label: 'Asunto de los Emails',
                      hint: 'Ej: Novedades en tu planificación',
                      icon: Icons.subject_rounded,
                      enabled: !_sending,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _messageController,
                      label: 'Mensaje para todos',
                      hint: 'Escribe tu mensaje masivo aquí...',
                      icon: Icons.message_rounded,
                      maxLines: 8,
                      enabled: !_sending,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _sending ? null : _handleSendClick,
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
                                'Iniciar Envío Masivo',
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
    bool enabled = true,
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
          enabled: enabled,
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
