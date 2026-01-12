import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/cliente_model.dart';

class AdvisorCalendarScreen extends StatefulWidget {
  const AdvisorCalendarScreen({super.key});

  @override
  State<AdvisorCalendarScreen> createState() => _AdvisorCalendarScreenState();
}

class _AdvisorCalendarScreenState extends State<AdvisorCalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  Map<DateTime, List<dynamic>> _citasMap = {};
  bool _isLoading = false;
  List<Cliente> _clients = [];

  // Settings State
  Map<String, dynamic> _calendarSettings = {};
  List<dynamic> _blocks = [];
  List<String> _vacations = [];

  @override
  void initState() {
    super.initState();
    _loadCitas();
    _loadClients();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      final res = await api.get('/users/${auth.userId}/calendar-settings');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _calendarSettings = data;
            _blocks = List.from(data['bloques'] ?? []);
            _vacations = List<String>.from(data['vacationDays'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  // ... (Other loads remain)

  // ... (Helper methods remain)

  // ... (Build and UI methods remain)

  Future<void> _loadClients() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    try {
      final res = await api.get('/clientes?asesorId=${auth.userId}');
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _clients = list.map((e) => Cliente.fromJson(e)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading clients: $e');
    }
  }

  Future<void> _loadCitas() async {
    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    final monthStr = DateFormat('yyyy-MM').format(_selectedDate);

    try {
      final res = await api.get('/citas?month=$monthStr');
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);

        Map<DateTime, List<dynamic>> newMap = {};
        for (var item in list) {
          final date = DateTime.parse(item['date']);
          final day = DateTime(date.year, date.month, date.day);
          if (newMap[day] == null) newMap[day] = [];
          newMap[day]!.add(item);
        }

        if (mounted) {
          setState(() {
            _citasMap = newMap;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<DateTime> _getWeekDays(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (index) => monday.add(Duration(days: index)));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadCitas,
                color: colorScheme.primary,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  children: [
                    // 1. Header
                    _buildHeader(auth.userEmail ?? 'Asesor'),
                    const SizedBox(height: 30),

                    // 2. Goal Cards (Visual only)
                    _buildGoalsSection(),
                    const SizedBox(height: 30),

                    // 3. Calendar Title "Hoy"
                    _buildCalendarHeader(),
                    const SizedBox(height: 20),

                    // 4. Week Strip
                    _buildWeekStrip(),
                    const SizedBox(height: 40),

                    // 5. Daily Content
                    _buildDailyContent(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colorScheme.primary,
        child: Icon(Icons.add, color: colorScheme.onPrimary),
        onPressed: _showCreateCitaDialog,
      ),
    );
  }

  Widget _buildHeader(String name) {
    final display = name.split('@').first;
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola $display,',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tu agenda',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.settings, color: theme.colorScheme.primary),
              onPressed: _showCalendarSettings,
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'Vista Mes',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGoalsSection() {
    return Row(
      children: [
        Expanded(
          child: _buildGoalCard(
            Icons.calendar_today,
            'Citas Hoy',
            '${_citasTodayCount()}',
            const Color(0xFFE6A23C), // Warning/Orange
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGoalCard(
            Icons.check_circle_outline,
            'Hechas',
            '0',
            const Color(0xFFF56C6C), // Error/Red
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildGoalCard(
            Icons.schedule,
            'Pendientes',
            '${_citasTodayCount()}',
            const Color(0xFF409EFF), // Info/Blue
          ),
        ),
      ],
    );
  }

  int _citasTodayCount() {
    final today = DateTime.now();
    final key = DateTime(today.year, today.month, today.day);
    return (_citasMap[key] ?? []).length;
  }

  Widget _buildGoalCard(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const Spacer(),
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Hoy',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios, color: primary, size: 18),
              onPressed: () {
                setState(
                  () => _selectedDate = _selectedDate.subtract(
                    const Duration(days: 7),
                  ),
                );
                _loadCitas();
              },
            ),
            IconButton(
              icon: Icon(Icons.calendar_today, color: primary),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  builder: (context, child) {
                    return child!; // Theme is already inherited
                  },
                );
                if (d != null) {
                  setState(() => _selectedDate = d);
                  _loadCitas();
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.arrow_forward_ios, color: primary, size: 18),
              onPressed: () {
                setState(
                  () => _selectedDate = _selectedDate.add(
                    const Duration(days: 7),
                  ),
                );
                _loadCitas();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekStrip() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final weekDays = _getWeekDays(_selectedDate);

    return SizedBox(
      height: 90, // Slightly taller for better touch targets
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: weekDays.map((date) {
          final isSelected = _isSameDay(date, _selectedDate);
          final hasCitas =
              (_citasMap[DateTime(date.year, date.month, date.day)] ?? [])
                  .isNotEmpty;

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 50, // Wider for touch
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withOpacity(isDark ? 0.3 : 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
                border: isSelected
                    ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat(
                      'E',
                      'es',
                    ).format(date).toUpperCase().substring(0, 2),
                    style: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (hasCitas) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDailyContent() {
    final theme = Theme.of(context);

    if (_isLoading)
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );

    final dayKey = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final citas = _citasMap[dayKey] ?? [];

    if (citas.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 30),
          Icon(
            Icons.event_note,
            size: 60,
            color: theme.colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 20),
          Text(
            'No tienes citas para hoy',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _showCreateCitaDialog,
            child: Text(
              'Planifica algo',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    return Column(children: citas.map((c) => _buildItemCard(c)).toList());
  }

  Widget _buildItemCard(dynamic cita) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (cita['asistio'] == true)
                  ? Colors.green.withOpacity(0.1)
                  : (cita['asistio'] == false)
                  ? Colors.red.withOpacity(0.1)
                  : theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              (cita['asistio'] == true)
                  ? Icons.check_circle
                  : (cita['asistio'] == false)
                  ? Icons.cancel
                  : Icons.event,
              color: (cita['asistio'] == true)
                  ? Colors.green
                  : (cita['asistio'] == false)
                  ? Colors.red
                  : theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cita['title'],
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${cita['hora']} - ${cita['clienteNombre'] ?? 'Sin cliente'}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            onSelected: (value) {
              if (value == 'delete') {
                _deleteCita(cita['_id']);
              } else if (value == 'present') {
                _toggleAttendance(cita['_id'], true);
              } else if (value == 'absent') {
                _toggleAttendance(cita['_id'], false);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'present',
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text('Asistió', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'absent',
                child: Row(
                  children: [
                    const Icon(
                      Icons.highlight_off,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text('No asistió', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Eliminar', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCita(String id) async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.delete('/citas/$id');
      _loadCitas();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  Future<void> _toggleAttendance(String id, bool asistio) async {
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);

    try {
      await api.put('/citas/$id/asistencia', {
        'asistio': asistio,
        'asesorId': auth.userId,
      });
      _loadCitas();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al marcar asistencia: $e')));
    }
  }

  Future<void> _showCalendarSettings() async {
    final theme = Theme.of(context);
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);

    // Load current settings
    Map<String, dynamic> settings = {};
    List<dynamic> blocks = [];
    List<String> vacations = [];

    try {
      final res = await api.get('/users/${auth.userId}/calendar-settings');
      if (res.statusCode == 200) {
        settings = jsonDecode(res.body);
        blocks = List.from(settings['bloques'] ?? []);
        vacations = List<String>.from(settings['vacationDays'] ?? []);
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }

    final startController = TextEditingController(
      text: settings['workHours']?['startHour']?.toString() ?? '7',
    );
    final endController = TextEditingController(
      text: settings['workHours']?['endHour']?.toString() ?? '22',
    );

    // Helper for weekday names
    final days = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: theme.cardColor,
            title: Text(
              'Configuración Calendario',
              style: theme.textTheme.titleLarge,
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 1. General Hours ---
                    Text(
                      'Horario General (Defecto)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: startController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Inicio (0-24)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: endController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Fin (0-24)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),

                    // --- 2. Vacations ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Vacaciones',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.add_circle,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (d != null) {
                              final iso = DateFormat('yyyy-MM-dd').format(d);
                              if (!vacations.contains(iso)) {
                                setStateDialog(() => vacations.add(iso));
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    if (vacations.isEmpty)
                      Text(
                        'No hay días asignados',
                        style: theme.textTheme.bodySmall,
                      )
                    else
                      Wrap(
                        spacing: 8,
                        children: vacations.map((dateStr) {
                          return Chip(
                            label: Text(dateStr),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setStateDialog(() => vacations.remove(dateStr));
                            },
                          );
                        }).toList(),
                      ),
                    const Divider(height: 30),

                    // --- 3. Blocks ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bloques de Trabajo',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.add_circle,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: () {
                            // Show mini dialog to add block
                            _showAddBlockDialog(context, (newBlock) {
                              setStateDialog(() => blocks.add(newBlock));
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (blocks.isEmpty)
                      Text(
                        'Usa el horario general',
                        style: theme.textTheme.bodySmall,
                      )
                    else
                      Column(
                        children: blocks.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final blk = entry.value;
                          final dayName = days[blk['weekday'] % 7];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              child: Text(
                                dayName.substring(0, 1),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            title: Text(
                              '$dayName: ${blk['start']} - ${blk['end']}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setStateDialog(() => blocks.removeAt(idx));
                              },
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final newSettings = {
                      'workHours': {
                        'startHour': int.tryParse(startController.text) ?? 7,
                        'endHour': int.tryParse(endController.text) ?? 22,
                      },
                      'vacationDays': vacations,
                      'bloques': blocks,
                    };
                    await api.put(
                      '/users/${auth.userId}/calendar-settings',
                      newSettings,
                    );
                    if (mounted) {
                      setState(() {
                        _calendarSettings = newSettings;
                        _blocks = List.from(blocks);
                        _vacations = List<String>.from(vacations);
                      });
                    }
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Configuración guardada')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddBlockDialog(
    BuildContext context,
    Function(Map<String, dynamic>) onAdd,
  ) async {
    int _selectedDay = 1; // Monday default
    TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
    final theme = Theme.of(context);

    // 0=Sun, 1=Mon ...
    final days = [
      {'val': 1, 'label': 'Lunes'},
      {'val': 2, 'label': 'Martes'},
      {'val': 3, 'label': 'Miércoles'},
      {'val': 4, 'label': 'Jueves'},
      {'val': 5, 'label': 'Viernes'},
      {'val': 6, 'label': 'Sábado'},
      {'val': 0, 'label': 'Domingo'},
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateInner) {
          return AlertDialog(
            backgroundColor: theme.cardColor,
            title: const Text('Agregar Bloque'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: _selectedDay,
                  items: days.map((d) {
                    return DropdownMenuItem<int>(
                      value: d['val'] as int,
                      child: Text(d['label'] as String),
                    );
                  }).toList(),
                  onChanged: (val) => setStateInner(() => _selectedDay = val!),
                  decoration: const InputDecoration(labelText: 'Día'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: _start,
                          );
                          if (t != null) setStateInner(() => _start = t);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Inicio',
                          ),
                          child: Text(_start.format(context)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: _end,
                          );
                          if (t != null) setStateInner(() => _end = t);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Fin'),
                          child: Text(_end.format(context)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  final startStr =
                      '${_start.hour.toString().padLeft(2, '0')}:${_start.minute.toString().padLeft(2, '0')}';
                  final endStr =
                      '${_end.hour.toString().padLeft(2, '0')}:${_end.minute.toString().padLeft(2, '0')}';

                  onAdd({
                    'weekday': _selectedDay,
                    'start': startStr,
                    'end': endStr,
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Agregar'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<String> _getAvailableSlots(DateTime date) {
    if (_vacations.contains(DateFormat('yyyy-MM-dd').format(date))) return [];

    final List<String> allPotentialSlots = [];
    final weekday = date.weekday % 7;

    // Use blocks if defined, otherwise general hours
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
      final workHours = _calendarSettings['workHours'];
      final sH = workHours?['startHour'] ?? 7;
      final eH = workHours?['endHour'] ?? 22;
      for (int h = sH; h < eH; h++) {
        allPotentialSlots.add('${h.toString().padLeft(2, '0')}:00');
        allPotentialSlots.add('${h.toString().padLeft(2, '0')}:30');
      }
    }

    // Filter appointments
    final dayKey = DateTime(date.year, date.month, date.day);
    final existingCitas = _citasMap[dayKey] ?? [];
    final takenHours = existingCitas.map((c) => c['hora'] as String).toList();

    // Filter past if today
    final now = DateTime.now();
    final bool isToday = _isSameDay(date, now);

    return allPotentialSlots.where((slot) {
      if (takenHours.contains(slot)) return false;
      if (isToday) {
        final slotParts = slot.split(':');
        final slotTime = DateTime(
          date.year,
          date.month,
          date.day,
          int.parse(slotParts[0]),
          int.parse(slotParts[1]),
        );
        if (slotTime.isBefore(now)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _showCreateCitaDialog() async {
    final _titleController = TextEditingController();
    final _notesController = TextEditingController();
    final availableSlots = _getAvailableSlots(_selectedDate);
    String? _selectedSlot = availableSlots.isNotEmpty
        ? availableSlots.first
        : null;
    String? _selectedClientId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final theme = Theme.of(context);

          return AlertDialog(
            backgroundColor: theme.cardColor,
            title: Text('Nueva Cita', style: theme.textTheme.titleLarge),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _titleController,
                    style: theme.textTheme.bodyMedium,
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      hintText: 'Revisión',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    style: theme.textTheme.bodyMedium,
                    decoration: const InputDecoration(labelText: 'Notas'),
                  ),
                  const SizedBox(height: 12),
                  if (availableSlots.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'No hay horarios disponibles para este día.',
                        style: TextStyle(color: Colors.red, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: _selectedSlot,
                      dropdownColor: theme.cardColor,
                      style: theme.textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        labelText: 'Horario Disponible',
                      ),
                      items: availableSlots
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                s,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setStateDialog(() => _selectedSlot = val),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedClientId,
                    dropdownColor: theme.cardColor,
                    style: theme.textTheme.bodyMedium,
                    decoration: const InputDecoration(labelText: 'Cliente'),
                    items: _clients
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              c.nombre,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setStateDialog(() => _selectedClientId = val),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                ),
                onPressed: availableSlots.isEmpty
                    ? null
                    : () async {
                        if (_titleController.text.isEmpty ||
                            _selectedClientId == null ||
                            _selectedSlot == null)
                          return;

                        final dateStr = DateFormat(
                          'yyyy-MM-dd',
                        ).format(_selectedDate);

                        final api = Provider.of<ApiService>(
                          context,
                          listen: false,
                        );
                        final auth = Provider.of<AuthService>(
                          context,
                          listen: false,
                        );

                        try {
                          await api.post('/citas', {
                            'title': _titleController.text,
                            'notas': _notesController.text,
                            'date': dateStr,
                            'hora': _selectedSlot,
                            'clienteId': _selectedClientId,
                            'asesorId': auth.userId,
                          });
                          Navigator.pop(context);
                          _loadCitas();
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                child: Text(
                  'Crear',
                  style: TextStyle(color: theme.colorScheme.onPrimary),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
