import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
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
    final auth = Provider.of<AuthService>(context, listen: false);

    // Load a range (previous month, current, and next 3 months)
    final now = DateTime.now();
    final start = DateFormat(
      'yyyy-MM-dd',
    ).format(now.subtract(const Duration(days: 35)));
    final end = DateFormat(
      'yyyy-MM-dd',
    ).format(now.add(const Duration(days: 120)));

    try {
      final res = await api.get(
        '/citas?asesorId=${auth.userId}&start=$start&end=$end',
      );
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);

        final Map<DateTime, List<dynamic>> newMap = {};
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
                    _buildHeader(auth.userEmail ?? 'Asesor'),
                    const SizedBox(height: 30),
                    _buildGoalsSection(),
                    const SizedBox(height: 30),
                    _buildCalendarHeader(),
                    const SizedBox(height: 20),
                    _buildWeekStrip(),
                    const SizedBox(height: 40),
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
        onPressed: _showCreateCitaDialog,
        child: Icon(Icons.add, color: colorScheme.onPrimary),
      ),
    );
  }

  Widget _buildHeader(String name) {
    final display = name.split('@').first;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola $display,',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      color: theme.textTheme.headlineMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Esta es tu agenda para hoy',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.settings_outlined,
                    color: theme.primaryColor,
                  ),
                  onPressed: _showCalendarSettings,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _buildGoalCard(
                Icons.calendar_today_rounded,
                'Citas',
                '${_citasTodayCount()}',
                const [Color(0xFF64748B), Color(0xFF475569)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGoalCard(
                Icons.check_circle_rounded,
                'Completas',
                '0',
                const [Color(0xFF10B981), Color(0xFF059669)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGoalCard(
                Icons.timer_rounded,
                'Pendientes',
                '${_citasTodayCount()}',
                const [Color(0xFF3B82F6), Color(0xFF2563EB)],
              ),
            ),
          ],
        ),
      ),
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
    List<Color> colors,
  ) {
    // final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          'Junio 2024', // TODO: Make dynamic
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        _buildNavButton(Icons.chevron_left_rounded, () {
          setState(
            () =>
                _selectedDate = _selectedDate.subtract(const Duration(days: 7)),
          );
          _loadCitas();
        }),
        const SizedBox(width: 8),
        _buildNavButton(Icons.calendar_month_rounded, () async {
          final d = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
          if (d != null) {
            setState(() => _selectedDate = d);
            _loadCitas();
          }
        }, isIcon: true),
        const SizedBox(width: 8),
        _buildNavButton(Icons.chevron_right_rounded, () {
          setState(
            () => _selectedDate = _selectedDate.add(const Duration(days: 7)),
          );
          _loadCitas();
        }),
      ],
    );
  }

  Widget _buildNavButton(
    IconData icon,
    VoidCallback onTap, {
    bool isIcon = false,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        ),
        child: Icon(icon, size: 20, color: theme.primaryColor),
      ),
    );
  }

  Widget _buildWeekStrip() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final weekDays = _getWeekDays(_selectedDate);

    return Container(
      height: 100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: weekDays.map((date) {
          final isSelected = _isSameDay(date, _selectedDate);
          final hasCitas =
              (_citasMap[DateTime(date.year, date.month, date.day)] ?? [])
                  .isNotEmpty;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDate = date),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.primaryColor
                      : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat(
                        'E',
                        'es',
                      ).format(date).toUpperCase().substring(0, 1),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white.withOpacity(0.8)
                            : theme.hintColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : theme.textTheme.bodyLarge?.color,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (hasCitas) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : theme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
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

    final bool isCompleted = cita['asistio'] == true;
    final bool isAbsent = cita['asistio'] == false;

    final Color statusColor = isCompleted
        ? Colors.green
        : (isAbsent ? Colors.red : theme.primaryColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: statusColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Icon(
                            isCompleted
                                ? Icons.check_circle_rounded
                                : (isAbsent
                                      ? Icons.cancel_rounded
                                      : Icons.calendar_today_rounded),
                            color: statusColor,
                            size: 24,
                          ),
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
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: theme.hintColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  cita['hora'],
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.person_outline_rounded,
                                  size: 14,
                                  color: theme.hintColor,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    cita['clienteNombre'] ?? 'Sin cliente',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _buildActionMenu(cita, theme),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionMenu(dynamic cita, ThemeData theme) {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.dividerColor.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.more_horiz_rounded, color: theme.hintColor, size: 20),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text('Marcar Asistido'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'absent',
          child: Row(
            children: [
              const Icon(Icons.cancel_rounded, color: Colors.red, size: 20),
              const SizedBox(width: 12),
              const Text('Marcar No Asistió'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text('Eliminar Cita', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
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
      final sH = workHours['startHour'] ?? 7;
      final eH = workHours['endHour'] ?? 22;
      for (int h = sH; h < eH; h++) {
        allPotentialSlots.add('${h.toString().padLeft(2, '0')}:00');
        allPotentialSlots.add('${h.toString().padLeft(2, '0')}:30');
      }
    }

    final dayKey = DateTime(date.year, date.month, date.day);
    final existingCitas = _citasMap[dayKey] ?? [];
    final takenHours = existingCitas.map((c) => c['hora'] as String).toList();
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

  List<DateTime> _getUpcomingAvailableDays() {
    List<DateTime> list = [];
    DateTime now = DateTime.now();
    for (int i = 0; i < 60; i++) {
      DateTime d = now.add(Duration(days: i));
      if (_getAvailableSlots(d).isNotEmpty) {
        list.add(d);
        if (list.length >= 10) break;
      }
    }
    return list;
  }

  Future<void> _showCreateCitaDialog() async {
    final _titleController = TextEditingController();
    final _notesController = TextEditingController();
    DateTime _tempDate = _selectedDate;
    List<String> _tempSlots = _getAvailableSlots(_tempDate);
    String? _selectedSlot = _tempSlots.isNotEmpty ? _tempSlots.first : null;
    String? _selectedClientId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final theme = Theme.of(context);

          return AlertDialog(
            backgroundColor: theme.cardColor,
            title: Text('Nueva Cita', style: theme.textTheme.titleLarge),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
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
                    // Date Selection Strip
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Días Disponibles',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.hintColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.calendar_month, size: 20),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _tempDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 90),
                                  ),
                                  selectableDayPredicate: (DateTime day) {
                                    return _getAvailableSlots(day).isNotEmpty;
                                  },
                                );
                                if (picked != null) {
                                  setStateDialog(() {
                                    _tempDate = picked;
                                    _tempSlots = _getAvailableSlots(_tempDate);
                                    _selectedSlot = _tempSlots.isNotEmpty
                                        ? _tempSlots.first
                                        : null;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 70,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _getUpcomingAvailableDays().map((d) {
                                final isSelected = _isSameDay(d, _tempDate);
                                return GestureDetector(
                                  onTap: () {
                                    setStateDialog(() {
                                      _tempDate = d;
                                      _tempSlots = _getAvailableSlots(
                                        _tempDate,
                                      );
                                      _selectedSlot = _tempSlots.isNotEmpty
                                          ? _tempSlots.first
                                          : null;
                                    });
                                  },
                                  child: Container(
                                    width: 60,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.primaryColor
                                          : theme.cardColor.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? theme.primaryColor
                                            : theme.dividerColor,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                                : theme.hintColor,
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
                                                : theme
                                                      .textTheme
                                                      .bodyLarge
                                                      ?.color,
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
                    const SizedBox(height: 12),

                    if (_tempSlots.isEmpty)
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
                        items: _tempSlots
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
                onPressed: _tempSlots.isEmpty
                    ? null
                    : () async {
                        if (_titleController.text.isEmpty ||
                            _selectedClientId == null ||
                            _selectedSlot == null)
                          return;

                        final dateStr = DateFormat(
                          'yyyy-MM-dd',
                        ).format(_tempDate);

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

                          // Send chat message
                          try {
                            final chat = Provider.of<ChatService>(
                              context,
                              listen: false,
                            );
                            final convId = await chat.getOrCreateConversation(
                              _selectedClientId!,
                            );
                            if (convId != null) {
                              chat.sendMessage(
                                convId,
                                '📅 Nueva cita agendada: ${_titleController.text} para el $dateStr a las $_selectedSlot',
                              );
                            }
                          } catch (e) {
                            debugPrint('Error sending auto-message: $e');
                          }

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
