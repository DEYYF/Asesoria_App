import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cliente_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

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

  @override
  void initState() {
    super.initState();
    _toCtrl = TextEditingController(text: widget.cliente.email);
    // Default welcome message? React does: "Hola {name},\n\n"
    _msgCtrl.text = "Hola ${widget.cliente.nombre},\n\n";
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _msgCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  void _quickInsert(String type) {
    if (type == 'Bienvenida') {
      if (_subjectCtrl.text.isEmpty)
        _subjectCtrl.text = "Bienvenida a la asesoría";
      _msgCtrl.text +=
          "\nTe doy la bienvenida. En breve te compartiré tu planificación y accesos.\n\nCualquier duda, contesta a este correo.";
    } else if (type == 'Cita') {
      if (_subjectCtrl.text.isEmpty) _subjectCtrl.text = "Propuesta de cita";
      _msgCtrl.text += "\n¿Te viene bien una llamada el jueves a las 18:00?\n";
    } else if (type == 'Recordatorio') {
      if (_subjectCtrl.text.isEmpty) _subjectCtrl.text = "Recordatorio";
      _msgCtrl.text +=
          "\nTe recuerdo que tenemos pendiente revisar tu progreso semanal.\n";
    }
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
      await api.post('/correo/enviar', {
        'destinatario': _toCtrl.text,
        'asunto': _subjectCtrl.text,
        'mensaje': _msgCtrl.text,
        'clienteId': widget.cliente.id,
        'asesorId': auth.userId, // Use actual current user id
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enviar correo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _toCtrl,
              decoration: const InputDecoration(
                labelText: 'Para',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjectCtrl,
              decoration: const InputDecoration(
                labelText: 'Asunto',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _msgCtrl,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Mensaje',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: ['Bienvenida', 'Cita', 'Recordatorio']
                  .map(
                    (t) => ActionChip(
                      label: Text(t),
                      onPressed: () => _quickInsert(t),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sending ? null : _send,
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enviar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
