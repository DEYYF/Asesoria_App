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
                    _buildHeader(theme),
                    const SizedBox(height: 30),
                    _buildCalendarHeader(theme),
                    const SizedBox(height: 20),
                    _buildWeekStrip(theme),
                    const SizedBox(height: 40),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola ${widget.cliente.nombre.split(' ').first},',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: theme.textTheme.headlineMedium?.color,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tu actividad diaria',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.hintColor.withOpacity(0.6),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Mi Plan',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Text(
            'Hoy',
            style: TextStyle(
              color: theme.textTheme.titleLarge?.color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          _buildActionButton(Icons.history_rounded, () {}),
          const SizedBox(width: 8),
          _buildActionButton(Icons.calendar_month_rounded, () {}),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFFFFD700), size: 20),
      ),
    );
  }

  Widget _buildWeekStrip(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final weekDays = _getWeekDays(_selectedDate);

    return Container(
      height: 90,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: weekDays.map((date) {
          final isSelected = _isSameDay(date, _selectedDate);

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedDate = date);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFFD700)
                      : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
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
                            ? Colors.black.withOpacity(0.8)
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
                            ? Colors.black
                            : theme.textTheme.titleMedium?.color,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    // Visual indicator for events
                    const SizedBox(height: 4),
                    _buildEventDots(date, isSelected, isDark),
                  ],
                ),
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
              Container(width: 6, color: iconColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Icon(icon, color: iconColor, size: 24),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: theme.dividerColor,
                      ),
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

  Widget _buildEventDots(DateTime date, bool isSelected, bool isDark) {
    final dayKey = DateTime(date.year, date.month, date.day);
    final hasCita = _citasMap.containsKey(dayKey);
    final hasSession = _sessionsMap.entries.any((e) => _isSameDay(e.key, date));

    if (!hasCita && !hasSession) return const SizedBox(height: 6);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasCita)
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : const Color(0xFFFFD700),
              shape: BoxShape.circle,
            ),
          ),
        if (hasCita && hasSession) const SizedBox(width: 2),
        if (hasSession)
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: isSelected ? Colors.black.withOpacity(0.5) : Colors.green,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}
