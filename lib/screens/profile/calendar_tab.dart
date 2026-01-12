import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/cliente_model.dart';
import '../../utils/isolate_utils.dart';
import '../../services/api_service.dart';

class CalendarTab extends StatefulWidget {
  final Cliente cliente;
  final VoidCallback? onPlanSession;
  final bool isClient;

  const CalendarTab({
    super.key,
    required this.cliente,
    this.onPlanSession,
    this.isClient = true,
  });

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  DateTime _selectedDate = DateTime.now();
  Map<DateTime, Map<String, dynamic>> _sessionsMap = {};
  Map<DateTime, List<dynamic>> _citasMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadCitas();
  }

  Future<void> _loadHistory() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get(
        '/entrenamientos/registros/cliente/${widget.cliente.id}/sesiones',
      );

      if (res.statusCode == 200) {
        final result = await processSessionHistoryInIsolate(res.body);
        Map<DateTime, Map<String, dynamic>> sessionsMap = {};
        result.sessionsMap.forEach((key, value) {
          sessionsMap[DateTime.parse(key)] = value;
        });

        if (mounted) {
          setState(() {
            _sessionsMap = sessionsMap;
            _checkLoading();
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCitas() async {
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
            _checkLoading();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading client citas: $e');
      _checkLoading();
    }
  }

  void _checkLoading() {
    // Simple check, real app might be more robust
    setState(() => _isLoading = false);
  }

  List<DateTime> _getWeekDays(DateTime date) {
    // Find the Monday of the current week
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (index) => monday.add(Duration(days: index)));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([_loadHistory(), _loadCitas()]);
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  children: [
                    // 1. Header
                    _buildHeader(theme),
                    const SizedBox(height: 30),

                    // 3. Calendar Title "Hoy"
                    _buildCalendarHeader(theme),
                    const SizedBox(height: 20),

                    // 4. Week Strip
                    _buildWeekStrip(theme),
                    const SizedBox(height: 40),

                    // 5. Content (Empty State or List)
                    _buildDailyContent(theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola ${widget.cliente.nombre.split(' ').first},',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.headlineMedium?.color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tu agenda diaria',
              style: TextStyle(
                fontSize: 16,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () {}, // Navigate to full plan?
          child: const Text(
            'Mi plan',
            style: TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 16,
            ), // Gold color
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Hoy',
          style: TextStyle(
            color: theme.textTheme.titleLarge?.color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        // History/Calendar icons
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.history, color: const Color(0xFFFFD700)),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(
                Icons.calendar_today_outlined,
                color: const Color(0xFFFFD700),
              ),
              onPressed: () {}, // Date picker?
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekStrip(ThemeData theme) {
    final weekDays = _getWeekDays(_selectedDate);

    return SizedBox(
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: weekDays.map((date) {
          final isSelected = _isSameDay(date, _selectedDate);

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = date);
            },
            child: Container(
              width: 45,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4A5568)
                    : Colors.transparent, // Grey-ish blue selection
                borderRadius: BorderRadius.circular(30),
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
                      color:
                          (isSelected
                                  ? Colors.white
                                  : theme.textTheme.bodySmall?.color)
                              ?.withOpacity(isSelected ? 1 : 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : theme.textTheme.titleMedium?.color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDailyContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFD700)),
      );
    }

    final dayKey = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    // Check for Citas
    final citas = _citasMap[dayKey] ?? [];

    // Check for Sessions
    final sessionEntry = _sessionsMap.entries.firstWhere(
      (e) => _isSameDay(e.key, _selectedDate),
      orElse: () => MapEntry(DateTime(1900), {}),
    );
    final sessionData = sessionEntry.value;
    final hasSession = sessionData.isNotEmpty;
    final hasCitas = citas.isNotEmpty;

    if (!hasSession && !hasCitas) {
      // Empty State
      return Column(
        children: [
          const SizedBox(height: 20),
          Icon(
            Icons.calendar_today,
            size: 60,
            color: Colors.grey.withOpacity(0.3),
          ), // Placeholder icon
          const SizedBox(height: 20),
          Text(
            '¿Listo para tu próxima actividad?',
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.onPlanSession != null)
            TextButton(
              onPressed: widget.onPlanSession,
              child: const Text(
                'Planifica algo',
                style: TextStyle(
                  color: Color(0xFFFFD700), // Gold
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      );
    }

    // Show content
    return Column(
      children: [
        if (hasCitas)
          ...citas.map(
            (c) => _buildItemCard(
              theme,
              c['title'],
              '${c['hora']}',
              Icons.event,
              const Color(0xFF409EFF),
            ),
          ),
        if (hasSession)
          _buildItemCard(
            theme,
            'Entrenamiento',
            'Completado',
            Icons.check_circle,
            Colors.green,
          ),
      ],
    );
  }

  Widget _buildItemCard(
    ThemeData theme,
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.textTheme.titleMedium?.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
