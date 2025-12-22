import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/cliente_model.dart';

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
      widget.clientes.where((c) => c.email?.isNotEmpty ?? false).toList();

  void _handleSendClick() {
    if (_subjectController.text.trim().isEmpty ||
        _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa el asunto y el mensaje'),
        ),
      );
      return;
    }

    if (_clientsWithEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay clientes con email en la lista actual'),
        ),
      );
      return;
    }

    // Show confirmation dialog
    _showConfirmDialog();
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Envío'),
        content: Text(
          '¿Estás seguro de que deseas enviar este email a ${_clientsWithEmail.length} clientes?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleConfirmSend();
            },
            child: const Text('Confirmar y Enviar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirmSend() async {
    setState(() => _sending = true);

    final api = Provider.of<ApiService>(context, listen: false);
    final emailAddresses = _clientsWithEmail
        .map((c) => c.email!)
        .where((e) => e.isNotEmpty)
        .toList();

    try {
      // Send email with all recipients
      await api.post('/correo/enviar', {
        'to': emailAddresses.first,
        'bcc': emailAddresses.skip(1).toList(),
        'subject': _subjectController.text,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Email enviado correctamente a ${_clientsWithEmail.length} clientes',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar el email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientCount = _clientsWithEmail.length;

    return AlertDialog(
      title: const Text('Enviar Email a Todos los Clientes'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se enviará un email individual a $clientCount clientes con email.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Asunto',
                  border: OutlineInputBorder(),
                ),
                enabled: !_sending,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Mensaje',
                  border: OutlineInputBorder(),
                  helperText:
                      'Se enviará un único email a todos los clientes seleccionados',
                ),
                maxLines: 8,
                enabled: !_sending,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed:
              _sending ||
                  _subjectController.text.trim().isEmpty ||
                  _messageController.text.trim().isEmpty
              ? null
              : _handleSendClick,
          child: Text(_sending ? 'Enviando...' : 'Enviar Emails'),
        ),
      ],
    );
  }
}
