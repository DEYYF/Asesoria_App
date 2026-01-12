import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cliente_model.dart';
import '../../models/template_model.dart';
import '../../services/chat_service.dart';
import 'template_selector_dialog.dart';

class BulkChatDialog extends StatefulWidget {
  final List<Cliente> clientes;

  const BulkChatDialog({super.key, required this.clientes});

  @override
  State<BulkChatDialog> createState() => _BulkChatDialogState();
}

class _BulkChatDialogState extends State<BulkChatDialog> {
  final _messageController = TextEditingController();
  bool _sending = false;
  double _progress = 0;
  String _statusMessage = '';

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _sending = true;
      _progress = 0;
      _statusMessage = 'Iniciando envío...';
    });

    final chatService = Provider.of<ChatService>(context, listen: false);
    final total = widget.clientes.length;
    int successCount = 0;
    int failCount = 0;

    for (var i = 0; i < total; i++) {
      final client = widget.clientes[i];
      try {
        if (!mounted) break;
        setState(() {
          _progress = (i / total);
          _statusMessage = 'Enviando a ${client.nombre} (${i + 1}/$total)...';
        });

        // 1. Get Conversation
        final convId = await chatService.getOrCreateConversation(client.id);
        if (convId != null) {
          // 2. Send Message
          chatService.sendMessage(convId, _messageController.text);
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        print('Error sending bulk chat to ${client.id}: $e');
        failCount++;
      }
    }

    if (mounted) {
      setState(() {
        _sending = false;
        _progress = 1.0;
        _statusMessage = 'Finalizado';
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mensajes enviados: $successCount, Fallidos: $failCount',
          ),
          backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  Future<void> _selectTemplate() async {
    final template = await showDialog<MessageTemplate>(
      context: context,
      builder: (_) => const TemplateSelectorDialog(type: 'chat'),
    );
    if (template != null) {
      if (mounted) {
        setState(() {
          _messageController.text = template.content;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
              // HEADER WITH GRADIENT (Dark Green for Bulk Chat)
              Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.teal[700]!, Colors.teal[500]!],
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
                        Icons.group_rounded,
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
                            'Envío Masivo (Chat)',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${widget.clientes.length} destinatarios seleccionados',
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
                    if (_sending) ...[
                      const Text(
                        'Progreso del envío',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 12,
                          backgroundColor: isDark
                              ? Colors.white10
                              : Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.teal[400]!,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color: theme.hintColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      _buildTextField(
                        controller: _messageController,
                        label: 'Mensaje para todos',
                        hint: 'Escribe tu mensaje masivo aquí...',
                        icon: Icons.message_rounded,
                        maxLines: 8,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _handleSend,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal[700],
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: Colors.teal.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Iniciar Envío Masivo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
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
              borderSide: BorderSide(color: Colors.teal[700]!, width: 1.5),
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
