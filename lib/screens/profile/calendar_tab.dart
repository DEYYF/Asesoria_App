import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/cliente_model.dart';
import '../../models/entrenamiento_model.dart';
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
  List<Entrenamiento> _entrenamientos = [];
  bool _isLoading = true;

  // Mapping Spanish day names to weekday numbers (1=Monday, 7=Sunday)
  static const Map<String, int> _diaToWeekday = {
    'Lunes': 1,
    'Martes': 2,
    'Miércoles': 3,
    'Jueves': 4,
    'Viernes': 5,
    'Sábado': 6,
    'Domingo': 7,
  };

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadCitas();
    _loadEntrenamientos();
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

  Future<void> _loadEntrenamientos() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get(
        '/entrenamientos?clienteId=${widget.cliente.id}',
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _entrenamientos =
                list.map((e) => Entrenamiento.fromJson(e)).toList();
            _checkLoading();
          });
        }
      } else {
        _checkLoading();
      }
    } catch (e) {
      _checkLoading();
    }
  }

  void _checkLoading() {
    setState(() => _isLoading = false);
  }

  List<DateTime> _getWeekDays(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (index) => monday.add(Duration(days: index)));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Returns list of (Entrenamiento, DiaEntrenamiento) pairs that match
  /// the weekday of [date].
  List<_TrainingDayMatch> _getTrainingsForDate(DateTime date) {
    final weekday = date.weekday; // 1=Mon, 7=Sun
    final matches = <_TrainingDayMatch>[];

    for (final ent in _entrenamientos) {
      if (!ent.activo) continue;
      for (final semana in ent.semanas) {
        for (final dia in semana.dias) {
          if (dia.diaSemana != null &&
              _diaToWeekday[dia.diaSemana] == weekday) {
            matches.add(_TrainingDayMatch(entrenamiento: ent, dia: dia));
          }
        }
      }
    }

    // Deduplicate: show once per (entrenamiento, diaSemana) combination
    final seen = <String>{};
    return matches.where((m) {
      final key = '${m.entrenamiento.id}_${m.dia.diaSemana}';
      return seen.add(key);
    }).toList();
  }

  bool _hasTrainingOnDate(DateTime date) =>
      _getTrainingsForDate(date).isNotEmpty;

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
                  setState(() => _isLoading = true);
                  await Future.wait([
                    _loadHistory(),
                    _loadCitas(),
                    _loadEntrenamientos(),
                  ]);
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

    return SizedBox(
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

    final citas = _citasMap[dayKey] ?? [];
    final sessionEntry = _sessionsMap.entries.firstWhere(
      (e) => _isSameDay(e.key, _selectedDate),
      orElse: () => MapEntry(DateTime(1900), {}),
    );
    final hasSession = sessionEntry.value.isNotEmpty;
    final hasCitas = citas.isNotEmpty;
    final trainingMatches = _getTrainingsForDate(_selectedDate);
    final hasTraining = trainingMatches.isNotEmpty;

    if (!hasSession && !hasCitas && !hasTraining) {
      return Column(
        children: [
          const SizedBox(height: 20),
          Icon(
            Icons.calendar_today,
            size: 60,
            color: Colors.grey.withOpacity(0.3),
          ),
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
                  color: Color(0xFFFFD700),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      );
    }

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
        ...trainingMatches.map(
          (match) => _buildTrainingEventCard(theme, match),
        ),
      ],
    );
  }

  // ─── Training event card ───────────────────────────────────────────────────

  Widget _buildTrainingEventCard(ThemeData theme, _TrainingDayMatch match) {
    const orange = Color(0xFFFF9500);
    final ent = match.entrenamiento;
    final dia = match.dia;

    return GestureDetector(
      onTap: () {
        if (ent.id != null) {
          context.push('/entrenamientos/sesion/${ent.id}');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: orange.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 6, color: orange),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF9500), Color(0xFFFFBE5C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: orange.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.fitness_center_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ent.titulo,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: orange.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      dia.diaSemana ?? '',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: orange,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      dia.nombre,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.hintColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (ent.objetivo != null &&
                                  ent.objetivo!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  ent.objetivo!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.hintColor.withOpacity(0.7),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: orange,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Generic item card (citas / completed session) ─────────────────────────

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

  // ─── Week strip event dots ─────────────────────────────────────────────────

  Widget _buildEventDots(DateTime date, bool isSelected, bool isDark) {
    final dayKey = DateTime(date.year, date.month, date.day);
    final hasCita = _citasMap.containsKey(dayKey);
    final hasSession = _sessionsMap.entries.any((e) => _isSameDay(e.key, date));
    final hasTraining = _hasTrainingOnDate(date);

    if (!hasCita && !hasSession && !hasTraining) return const SizedBox(height: 6);

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
        if (hasCita && (hasSession || hasTraining)) const SizedBox(width: 2),
        if (hasSession)
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: isSelected ? Colors.black.withOpacity(0.5) : Colors.green,
              shape: BoxShape.circle,
            ),
          ),
        if (hasSession && hasTraining) const SizedBox(width: 2),
        if (hasTraining)
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.black.withOpacity(0.5)
                  : const Color(0xFFFF9500),
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

/// Helper to pair a training plan with a specific day that has diaSemana set.
class _TrainingDayMatch {
  final Entrenamiento entrenamiento;
  final DiaEntrenamiento dia;
  const _TrainingDayMatch({required this.entrenamiento, required this.dia});
}

