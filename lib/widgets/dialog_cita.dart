import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/cliente_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';

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
  final _notesCtrl = TextEditingController();

  bool _sending = false;
  bool _loadingAvailability = false;

  Map<String, dynamic> _calendarSettings = {};
  List<dynamic> _blocks = [];
  List<String> _vacations = [];
  Map<String, List<dynamic>> _appointmentsMap = {}; // dateStr -> list of citas
  List<String> _availableSlots = [];
  String? _selectedSlot;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = "Cita con ${widget.cliente.nombre}";
    final now = DateTime.now();
    _dateCtrl.text = DateFormat('yyyy-MM-dd').format(now);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loadingAvailability = true);
    await _loadSettings();
    await _loadCitasRange();
    _updateAvailableSlots();
    setState(() => _loadingAvailability = false);
  }

  Future<void> _loadSettings() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      final res = await api.get('/users/${auth.userId}/calendar-settings');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _calendarSettings = data;
        _blocks = List.from(data['bloques'] ?? []);
        _vacations = List<String>.from(data['vacationDays'] ?? []);
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _loadCitasRange() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final now = DateTime.now();
    final start = DateFormat(
      'yyyy-MM-dd',
    ).format(now.subtract(const Duration(days: 30)));
    final end = DateFormat(
      'yyyy-MM-dd',
    ).format(now.add(const Duration(days: 90)));

    try {
      final res = await api.get(
        '/citas?asesorId=${auth.userId}&start=$start&end=$end',
      );
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        final Map<String, List<dynamic>> newMap = {};
        for (var c in list) {
          final d = c['date'] as String;
          if (newMap[d] == null) newMap[d] = [];
          newMap[d]!.add(c);
        }
        if (mounted) setState(() => _appointmentsMap = newMap);
      }
    } catch (e) {
      debugPrint('Error loading range: $e');
    }
  }

  void _updateAvailableSlots() {
    final dateStr = _dateCtrl.text;
    final slots = _calculateSlotsForDate(DateTime.parse(dateStr));
    setState(() {
      _availableSlots = slots;
      if (_availableSlots.isNotEmpty) {
        _selectedSlot = _availableSlots.first;
        _timeCtrl.text = _selectedSlot!;
      } else {
        _selectedSlot = null;
        _timeCtrl.text = '';
      }
    });
  }

  List<String> _calculateSlotsForDate(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    if (_vacations.contains(dateStr)) return [];

    final List<String> allPotentialSlots = [];
    final weekday = date.weekday % 7;

    if (_blocks.isNotEmpty) {
      final blocksToday = _blocks
          .where((b) => b['weekday'] == weekday)
          .toList();
      for (var b in blocksToday) {
        final startParts = (b['start'] as String).split(':');
        final endParts = (b['end'] as String).split(':');
        int startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        int endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

        for (int m = startMin; m < endMin; m += 30) {
          final h = m ~/ 60;
          final min = m % 60;
          allPotentialSlots.add(
            '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}',
          );
        }
      }
    } else {
      final workHours =
          _calendarSettings['workHours'] ?? {'startHour': 7, 'endHour': 22};
      final sH = workHours['startHour'] as int;
      final eH = workHours['endHour'] as int;
      for (int h = sH; h < eH; h++) {
        allPotentialSlots.add('${h.toString().padLeft(2, '0')}:00');
        allPotentialSlots.add('${h.toString().padLeft(2, '0')}:30');
      }
    }

    final existingCitas = _appointmentsMap[dateStr] ?? [];
    final takenHours = existingCitas.map((c) => c['hora'] as String).toList();
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    return allPotentialSlots.where((slot) {
      if (takenHours.contains(slot)) return false;
      if (isToday) {
        final parts = slot.split(':');
        final slotTime = DateTime(
          date.year,
          date.month,
          date.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        if (slotTime.isBefore(now)) return false;
      }
      return true;
    }).toList();
  }

  List<DateTime> _calculateUpcomingAvailableDays() {
    List<DateTime> list = [];
    DateTime now = DateTime.now();
    for (int i = 0; i < 60; i++) {
      DateTime d = now.add(Duration(days: i));
      if (_calculateSlotsForDate(d).isNotEmpty) {
        list.add(d);
        if (list.length >= 10) break;
      }
    }
    return list;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El cliente no tiene teléfono válido para WhatsApp'),
          ),
        );
      }
      return;
    }

    final txt = _buildWhatsAppText(
      accion: "crear",
      nombre: widget.cliente.nombre,
      title: _titleCtrl.text,
      date: _dateCtrl.text,
      hora: _timeCtrl.text,
      horaFin: null,
      notas: _notesCtrl.text,
    );

    final url = Uri.parse(
      "https://wa.me/$phone?text=${Uri.encodeComponent(txt)}",
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir WhatsApp')),
          );
        }
      }
    } catch (e) {
      print('Error launching WA: $e');
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime.parse(_dateCtrl.text);
    final theme = Theme.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      selectableDayPredicate: (DateTime day) {
        // Must have at least one slot available
        return _calculateSlotsForDate(day).isNotEmpty;
      },
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      _updateAvailableSlots();
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
        'horaFin': null,
        'clienteId': widget.cliente.id,
        'color': '#1976d2',
        'notas': _notesCtrl.text,
      });

      // Send chat message
      try {
        final chat = Provider.of<ChatService>(context, listen: false);
        final convId = await chat.getOrCreateConversation(widget.cliente.id);
        if (convId != null) {
          chat.sendMessage(
            convId,
            '📅 Nueva cita agendada: ${_titleCtrl.text} para el ${_dateCtrl.text} a las ${_timeCtrl.text}',
          );
        }
      } catch (e) {
        debugPrint('Error sending auto-message: $e');
      }

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
            // Horizontal Date Strip
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Días Disponibles',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_month, size: 20),
                      onPressed: _pickDate,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 70,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _calculateUpcomingAvailableDays().map((d) {
                        final dateStr = DateFormat('yyyy-MM-dd').format(d);
                        final isSelected = _dateCtrl.text == dateStr;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _dateCtrl.text = dateStr;
                              _updateAvailableSlots();
                            });
                          },
                          child: Container(
                            width: 65,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat(
                                    'EEE',
                                    'es',
                                  ).format(d).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  d.day.toString(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _loadingAvailability
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : DropdownButtonFormField<String>(
                          value: _selectedSlot,
                          decoration: const InputDecoration(
                            labelText: 'Hora',
                            border: OutlineInputBorder(),
                          ),
                          items: _availableSlots.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(
                                s,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedSlot = val;
                              _timeCtrl.text = val ?? '';
                            });
                          },
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
                  onPressed: (_sending || _availableSlots.isEmpty)
                      ? null
                      : _save,
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _availableSlots.isEmpty ? 'Sin Huecos' : 'Guardar',
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
