import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/cliente_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart'; // Added

class DialogCita extends StatefulWidget {
  final Cliente cliente;
  final VoidCallback? onSuccess;

  const DialogCita({super.key, required this.cliente, this.onSuccess});

  @override
  State<DialogCita> createState() => _DialogCitaState();
}

class _DialogCitaState extends State<DialogCita> {
  final _titleCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController(text: '10:00');
  final _timeEndCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = "Cita con ${widget.cliente.nombre}";
    final now = DateTime.now();
    _dateCtrl.text =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _timeCtrl.text =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _timeEndCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // Parity with formatPhoneForWa in React
  String? _formatPhoneForWa(String? raw, {String defaultCc = "+34"}) {
    if (raw == null || raw.isEmpty) return null;
    String digits = raw.replaceAll(RegExp(r'[^\d+]'), '');

    if (digits.startsWith("00")) {
      digits = "+${digits.substring(2)}";
    }

    if (!digits.startsWith("+")) {
      // Spanish logic: if 9 digits, assume +34
      if (RegExp(r'^\d{9}$').hasMatch(digits)) {
        return (defaultCc + digits).replaceAll("+", "");
      }
      // If starts with 34 and then 9 digits, it's fine
      if (RegExp(r'^34\d{9}$').hasMatch(digits)) {
        return digits;
      }
      return digits;
    }

    return digits.replaceAll("+", "");
  }

  String _formatDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      return "${d.day}/${d.month}/${d.year}";
    } catch (_) {
      return isoDate;
    }
  }

  // Parity with buildWhatsAppText in React
  String _buildWhatsAppText({
    String accion = "crear",
    required String nombre,
    required String title,
    required String date,
    String? hora,
    String? horaFin,
    String? notas,
  }) {
    final f = _formatDate(date);
    final hIni = (hora != null && hora.isNotEmpty) ? " a las $hora" : "";
    final hFin = (horaFin != null && horaFin.isNotEmpty)
        ? " (hasta $horaFin)"
        : "";

    final encabezado = accion == "crear"
        ? "Cita agendada"
        : (accion == "editar" ? "Cita actualizada" : "Cita");

    String txt = "Hola $nombre,\n\n$encabezado para el $f$hIni$hFin.\n";
    txt += "Título: $title\n";
    if (notas != null && notas.trim().isNotEmpty) {
      txt += "Notas: ${notas.trim()}\n";
    }
    txt += "\nSi necesitas reprogramar, avísame por aquí.";
    return txt;
  }

  Future<void> _openWhatsApp() async {
    final phone = _formatPhoneForWa(widget.cliente.telefono);
    if (phone == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El cliente no tiene teléfono válido para WhatsApp'),
          ),
        );
      return;
    }

    final txt = _buildWhatsAppText(
      accion: "crear",
      nombre: widget.cliente.nombre,
      title: _titleCtrl.text,
      date: _dateCtrl.text,
      hora: _timeCtrl.text,
      horaFin: _timeEndCtrl.text,
      notas: _notesCtrl.text,
    );

    final url = Uri.parse(
      "https://wa.me/$phone?text=${Uri.encodeComponent(txt)}",
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir WhatsApp')),
          );
      }
    } catch (e) {
      print('Error launching WA: $e');
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _dateCtrl.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _pickTime(TextEditingController ctrl) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      setState(() {
        ctrl.text = "$hour:$minute";
      });
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.isEmpty || _dateCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Título y Fecha obligatorios')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);
      final asesorId = auth.user?['_id'];

      if (asesorId == null) {
        throw Exception('No session found. Please login again.');
      }

      await api.post('/citas', {
        'asesorId': asesorId,
        'title': _titleCtrl.text,
        'date': _dateCtrl.text, // YYYY-MM-DD
        'hora': _timeCtrl.text,
        'horaFin': _timeEndCtrl.text,
        'clienteId': widget.cliente.id,
        'color': '#1976d2',
        'notas': _notesCtrl.text,
      });

      // Try WA
      await _openWhatsApp();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cita creada')));
        widget.onSuccess?.call();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
          children: [
            const Text(
              'Añadir Cita',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dateCtrl,
                    readOnly: true,
                    onTap: _pickDate,
                    decoration: const InputDecoration(
                      labelText: 'Fecha (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _timeCtrl,
                    readOnly: true,
                    onTap: () => _pickTime(_timeCtrl),
                    decoration: const InputDecoration(
                      labelText: 'Hora',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _timeEndCtrl,
                    readOnly: true,
                    onTap: () => _pickTime(_timeEndCtrl),
                    decoration: const InputDecoration(
                      labelText: 'Fin',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: _sending ? null : _save,
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
