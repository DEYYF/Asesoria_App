import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/cliente_model.dart';
import '../../models/progreso_model.dart';
import '../../models/exercise_history_model.dart';
import '../../widgets/charts/weight_chart.dart';
import '../../widgets/charts/body_fat_chart.dart';
import '../../widgets/charts/muscle_chart.dart';
import '../../widgets/charts/muscle_mass_chart.dart';
import '../../widgets/heatmap_panel.dart';
import '../../services/api_service.dart';
import '../../utils/isolate_utils.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/muscle_mass_bar.dart';
import '../../services/settings_service.dart';
import '../../models/settings_model.dart';

class ProgressTab extends StatefulWidget {
  final Cliente cliente;
  final VoidCallback? onAddProgress;

  const ProgressTab({super.key, required this.cliente, this.onAddProgress});

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  // View Toggle: 'rendimiento' | 'corporal'
  String _viewMode = 'rendimiento';

  // Data for Rendimiento
  List<String> _ejercicios = [];
  String? _selectedEjercicio;
  List<ExerciseHistoryRecord> _historyData = [];
  bool _isLoadingExercises = true;
  bool _isLoadingHistory = false;

  // Controls
  String _metric = 'strength'; // strength | volume | reps
  String _timeFilter = 'ALL'; // 1M, 3M, ALL

  late Future<UserSettings> _settingsFuture;

  @override
  void initState() {
    super.initState();
    _loadEjercicios();
    _settingsFuture = SettingsService(
      Provider.of<ApiService>(context, listen: false),
    ).getSettings();
  }

  Future<void> _loadEjercicios() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get(
        '/entrenamientos/registros/cliente/${widget.cliente.id}/ejercicios',
      );
      if (res.statusCode == 200) {
        // Parse JSON in isolate for better performance
        final data = await parseJsonInIsolate(res.body);
        final List<String> ejercicios = (data as List).cast<String>();

        setState(() {
          _ejercicios = ejercicios;
          if (_ejercicios.isNotEmpty) {
            _selectedEjercicio = _ejercicios[0];
            _loadHistorial(_ejercicios[0]);
          }
          _isLoadingExercises = false;
        });
      } else {
        setState(() => _isLoadingExercises = false);
      }
    } catch (e) {
      debugPrint('Error loading exercises: $e');
      setState(() => _isLoadingExercises = false);
    }
  }

  Future<void> _loadHistorial(String ejercicio) async {
    setState(() => _isLoadingHistory = true);
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get(
        '/entrenamientos/registros/cliente/${widget.cliente.id}/historial?ejercicio=${Uri.encodeComponent(ejercicio)}',
      );
      if (res.statusCode == 200) {
        // Parse JSON in isolate for better performance
        final data = await parseJsonInIsolate(res.body);
        final historyData = (data as List)
            .map((x) => ExerciseHistoryRecord.fromJson(x))
            .toList();
        historyData.sort((a, b) => a.fecha.compareTo(b.fecha));

        setState(() {
          _historyData = historyData;
          _isLoadingHistory = false;
        });
      } else {
        setState(() => _isLoadingHistory = false);
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      setState(() => _isLoadingHistory = false);
    }
  }

  void _navigateToRegisterTraining() async {
    // First, we need to get the active training plan for this client
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get('/entrenamientos/cliente/${widget.cliente.id}');
      if (res.statusCode == 200) {
        // Parse in isolate
        final trainings = await parseJsonInIsolate(res.body);
        if ((trainings as List).isNotEmpty) {
          // Get the most recent active training
          final activeTraining = trainings.first;
          final entrenamientoId = activeTraining['_id'];
          // Navigate to notebook screen
          if (mounted) {
            context.push('/entrenamientos/cuaderno/$entrenamientoId');
          }
        } else {
          // No training plan found
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No hay plan de entrenamiento activo'),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error navigating to training: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar el entrenamiento')),
        );
      }
    }
  }

  List<ExerciseHistoryRecord> get _filteredData {
    if (_historyData.isEmpty) return [];
    if (_timeFilter == 'ALL') return _historyData;

    final now = DateTime.now();
    final months = _timeFilter == '1M' ? 1 : (_timeFilter == '3M' ? 3 : 6);
    final cutoff = now.subtract(Duration(days: months * 30));

    return _historyData.where((d) => d.fecha.isAfter(cutoff)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu Evolución',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: theme.textTheme.headlineMedium?.color,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Seguimiento de tus metas',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.hintColor.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              Builder(
                builder: (context) {
                  final auth = Provider.of<AuthService>(context, listen: false);

                  // For Clients, show a Chat shortcut
                  if (auth.isClient) {
                    return _buildHeaderAction(
                      theme,
                      Icons.chat_bubble_outline_rounded,
                      () {
                        final tabController = DefaultTabController.of(context);
                        tabController.animateTo(tabController.length - 1);
                      },
                      'Chat',
                    );
                  }

                  if (widget.onAddProgress == null)
                    return const SizedBox.shrink();

                  return _buildHeaderAction(
                    theme,
                    _viewMode == 'rendimiento'
                        ? Icons.fitness_center_rounded
                        : Icons.add_rounded,
                    _viewMode == 'rendimiento'
                        ? _navigateToRegisterTraining
                        : widget.onAddProgress!,
                    _viewMode == 'rendimiento' ? 'Registrar' : 'Añadir',
                    isPrimary: true,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Custom Segmented Control
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.dividerColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildToggleOption('RENDIMIENTO', 'rendimiento'),
                _buildToggleOption('CORPORAL', 'corporal'),
              ],
            ),
          ),
          const SizedBox(height: 32),

          if (_viewMode == 'rendimiento')
            _buildRendimientoView()
          else
            _buildCorporalView(),
        ],
      ),
    );
  }

  Widget _buildHeaderAction(
    ThemeData theme,
    IconData icon,
    VoidCallback onTap,
    String tooltip, {
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isPrimary
              ? theme.primaryColor.withOpacity(0.1)
              : theme.dividerColor.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isPrimary ? theme.primaryColor : theme.iconTheme.color,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildToggleOption(String label, String value) {
    final theme = Theme.of(context);
    final isSelected = _viewMode == value;
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _viewMode = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isSelected
                  ? (isDark ? Colors.white : theme.textTheme.bodyLarge?.color)
                  : theme.hintColor.withOpacity(0.6),
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCorporalView() {
    final theme = Theme.of(context);
    final rawHistorial = widget.cliente.historialProgreso;

    final List<Progreso> historial = (rawHistorial != null)
        ? rawHistorial
              .whereType<Map>()
              .map((json) => Progreso.fromJson(Map<String, dynamic>.from(json)))
              .toList()
        : [];

    if (historial.isEmpty) {
      return _buildEmptyState('No hay registros corporales.');
    }

    return FutureBuilder<UserSettings>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        final settings = snapshot.data;
        if (settings == null) return const SizedBox.shrink();

        // Calculate last dates
        DateTime? lastWeight, lastFat, lastMuscle, lastMeasures;
        for (var entry in historial) {
          if (entry.peso != null) lastWeight = entry.fecha;
          if (entry.grasaCorporal != null) lastFat = entry.fecha;
          if (entry.masaMusculoEsqueletica != null) lastMuscle = entry.fecha;
          if (entry.musculo != null && entry.musculo!.isNotEmpty) {
            lastMeasures = entry.fecha;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (settings.enabledProgressFrequencies) ...[
              _sectionTitle('ESTADO DE SEGUIMIENTO'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildStatusBox(
                      'PESO',
                      lastWeight,
                      settings.weightFrequency,
                      Icons.fitness_center_rounded,
                    ),
                    const SizedBox(width: 12),
                    _buildStatusBox(
                      'GRASA',
                      lastFat,
                      settings.fatFrequency,
                      Icons.water_drop_rounded,
                    ),
                    const SizedBox(width: 12),
                    _buildStatusBox(
                      'MEDIDAS',
                      lastMeasures,
                      settings.measuresFrequency,
                      Icons.straighten_rounded,
                    ),
                    const SizedBox(width: 12),
                    _buildStatusBox(
                      'MÚSCULO',
                      lastMuscle,
                      settings.muscleFrequency,
                      Icons.monitor_weight_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Summary Cards for Corporal
            if (historial.isNotEmpty) ...[
              // Metric Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'PESO',
                      '${historial.last.peso ?? '-'}',
                      'kg',
                      Icons.fitness_center_rounded,
                      theme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'GRASA',
                      '${historial.last.grasaCorporal ?? '-'}',
                      '%',
                      Icons.water_drop_rounded,
                      Colors.pink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSummaryCard(
                'MÚSCULO',
                '${historial.last.masaMusculoEsqueletica ?? '-'}',
                'kg',
                Icons.monitor_weight_outlined,
                Colors.teal,
                isFullWidth: true,
              ),
              const SizedBox(height: 24),
              // Trend Cards Row
              Row(
                children: [
                  Expanded(
                    child: _buildTrendCard(
                      'PESO',
                      historial,
                      (p) => p.peso,
                      'kg',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTrendCard(
                      'GRASA',
                      historial,
                      (p) => p.grasaCorporal,
                      '%',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTrendCard(
                      'MÚSCULO',
                      historial,
                      (p) => p.masaMusculoEsqueletica,
                      'kg',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              MuscleMassBar(
                weight: historial.last.peso ?? 0,
                muscleMass: historial.last.masaMusculoEsqueletica ?? 0,
                height: widget.cliente.altura,
                gender: widget.cliente.sexo,
              ),
              const SizedBox(height: 24),
            ],

            _sectionTitle('MAPA CORPORAL'),
            HeatmapPanel(historial: historial),
            const SizedBox(height: 24),

            _sectionTitle('EVOLUCIÓN'),
            WeightChart(historial: historial),
            const SizedBox(height: 16),
            BodyFatChart(historial: historial),
            const SizedBox(height: 16),
            MuscleMassChart(historial: historial),
            const SizedBox(height: 16),
            MuscleChart(historial: historial),
          ],
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).hintColor,
        ),
      ),
    );
  }

  Widget _buildRendimientoView() {
    if (_isLoadingExercises) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_ejercicios.isEmpty) {
      return _buildEmptyState('No hay registros de entrenamiento.');
    }

    final data = _filteredData;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate Records (Always from full history, or filtered? Usually records are all-time)
    double max1RM = 0;
    double maxWeight = 0;
    double maxVolume = 0;

    if (_historyData.isNotEmpty) {
      max1RM = _historyData
          .map((e) => e.estimated1RM)
          .reduce((a, b) => a > b ? a : b);
      maxWeight = _historyData
          .map((e) => e.maxWeight)
          .reduce((a, b) => a > b ? a : b);
      maxVolume = _historyData
          .map((e) => e.totalVolume)
          .reduce((a, b) => a > b ? a : b);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Exercise Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedEjercicio,
              hint: const Text('Seleccionar Ejercicio'),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: theme.primaryColor,
              ),
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: -0.5,
              ),
              dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              items: _ejercicios
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedEjercicio = val);
                  _loadHistorial(val);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Summary Cards
        if (_historyData.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  '1RM ESTIMADO',
                  '${max1RM.toStringAsFixed(1)}',
                  'kg',
                  Icons.emoji_events_rounded,
                  const Color(0xFFFFB800),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'PESO MÁX',
                  '${maxWeight.toStringAsFixed(1)}',
                  'kg',
                  Icons.fitness_center_rounded,
                  theme.primaryColor,
                ),
              ),
            ],
          ),
        if (_historyData.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSummaryCard(
            'VOLUMEN RÉCORD',
            '${(maxVolume / 1000).toStringAsFixed(1)}',
            'tons',
            Icons.bar_chart_rounded,
            isDark ? Colors.purpleAccent : const Color(0xFFAF52DE),
            isFullWidth: true,
          ),
        ],

        const SizedBox(height: 32),

        // Chart Section
        if (data.isNotEmpty) ...[
          // Controls Row (Metric + Time)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Metric Toggles
                Container(
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _buildMetricBtn('Fuerza', 'strength'),
                      _buildMetricBtn('Volumen', 'volume'),
                      _buildMetricBtn('Reps', 'reps'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Time Filter
                Container(
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _buildTimeBtn('1M', '1M'),
                      _buildTimeBtn('3M', '3M'),
                      _buildTimeBtn('TODOS', 'ALL'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Chart
          AspectRatio(
            aspectRatio: 1.4,
            child: Container(
              padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildEvolutionChart(data),
            ),
          ),
        ] else if (!_isLoadingHistory)
          _buildEmptyState('No hay datos en este periodo.'),

        if (_isLoadingHistory)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildEmptyState(String msg) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.dividerColor.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 40,
                color: theme.hintColor.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.hintColor.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBtn(String label, String val) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _metric == val;

    return GestureDetector(
      onTap: () => setState(() => _metric = val),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ), // Compact padding
        decoration: BoxDecoration(
          color: isSelected ? theme.cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? (isDark ? Colors.white : theme.textTheme.bodyLarge?.color)
                : theme.hintColor,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBox(String label, DateTime? lastDate, String frequency, IconData icon) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Logic to determine completeness/status
    bool isPending = true;
    if (lastDate != null) {
      final daysSince = DateTime.now().difference(lastDate).inDays;

      int freqDays = 7;
      switch (frequency.toLowerCase()) {
        case 'daily':
          freqDays = 1;
          break;
        case 'weekly':
          freqDays = 7;
          break;
        case 'biweekly':
          freqDays = 14;
          break;
        case 'monthly':
          freqDays = 30;
          break;
      }

      if (daysSince <= freqDays) isPending = false;
    }

    final color = isPending ? Colors.orange : theme.primaryColor;

    return Container(
      width: 165,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: color),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPending ? 'PENDIENTE' : 'AL DÍA',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: theme.hintColor.withOpacity(0.5), letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(
            lastDate != null ? 'Hace ${DateTime.now().difference(lastDate).inDays} días' : 'Sin datos',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(String title, List<Progreso> historial, double? Function(Progreso) getValue, String unit) {
    if (historial.length < 2) return const SizedBox.shrink();

    final latest = historial.last;
    final latestVal = getValue(latest);
    if (latestVal == null) return const SizedBox.shrink();

    Progreso? previous;
    for (var i = historial.length - 2; i >= 0; i--) {
      if (getValue(historial[i]) != null) {
        previous = historial[i];
        break;
      }
    }

    if (previous == null) return const SizedBox.shrink();

    final prevVal = getValue(previous)!;
    final diff = latestVal - prevVal;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color color;
    IconData icon;
    String label;

    if (diff > 0.01) {
      color = Colors.green;
      icon = Icons.arrow_upward_rounded;
      label = "SUBE";
    } else if (diff < -0.01) {
      color = Colors.red;
      icon = Icons.arrow_downward_rounded;
      label = "BAJA";
    } else {
      color = Colors.blue;
      icon = Icons.horizontal_rule_rounded;
      label = "IGUAL";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: theme.hintColor.withOpacity(0.5), letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  "${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)}$unit",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: theme.textTheme.titleLarge?.color),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color.withOpacity(0.8), letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBtn(String label, String val) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _timeFilter == val;

    return GestureDetector(
      onTap: () => setState(() => _timeFilter = val),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ), // Compact padding
        decoration: BoxDecoration(
          color: isSelected ? theme.cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? (isDark ? Colors.white : theme.primaryColor)
                : theme.hintColor,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String unit,
    IconData icon,
    Color color, {
    bool isFullWidth = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: theme.hintColor.withOpacity(0.6),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.hintColor.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEvolutionChart(List<ExerciseHistoryRecord> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    List<FlSpot> spots = [];
    List<FlSpot> spots2 = [];

    for (int i = 0; i < data.length; i++) {
      final rec = data[i];
      if (_metric == 'strength') {
        spots.add(FlSpot(i.toDouble(), rec.maxWeight));
        spots2.add(FlSpot(i.toDouble(), rec.estimated1RM));
      } else if (_metric == 'volume') {
        spots.add(FlSpot(i.toDouble(), rec.totalVolume));
      } else {
        spots.add(FlSpot(i.toDouble(), rec.maxReps.toDouble()));
      }
    }

    // Calculate dynamic Y-axis range
    double minY = 0;
    double maxY = 100;

    if (spots.isNotEmpty) {
      final allYValues = <double>[];
      allYValues.addAll(spots.map((s) => s.y));
      if (_metric == 'strength' && spots2.isNotEmpty) {
        allYValues.addAll(spots2.map((s) => s.y));
      }

      final dataMin = allYValues.reduce((a, b) => a < b ? a : b);
      final dataMax = allYValues.reduce((a, b) => a > b ? a : b);

      // Add 10% padding above and below for better visualization
      final range = dataMax - dataMin;
      final padding = range > 0 ? range * 0.1 : dataMax * 0.1;

      minY = (dataMin - padding).clamp(0, double.infinity);
      maxY = dataMax + padding;

      // Ensure minimum range for better visualization
      if (maxY - minY < 10) {
        final center = (maxY + minY) / 2;
        minY = (center - 5).clamp(0, double.infinity);
        maxY = center + 5;
      }
    }

    // Calculate appropriate interval for Y-axis labels
    final yRange = maxY - minY;
    double interval = 1;
    if (yRange > 100) {
      interval = (yRange / 5).ceilToDouble();
    } else if (yRange > 50) {
      interval = 10;
    } else if (yRange > 20) {
      interval = 5;
    } else if (yRange > 10) {
      interval = 2;
    }

    // Colors
    final mainColor = _metric == 'strength'
        ? (isDark
              ? const Color(0xFF409CFF)
              : theme.primaryColor) // Lighter blue for dark mode
        : (_metric == 'volume'
              ? const Color(0xFFAF52DE)
              : const Color(0xFF30D158));

    final secondaryColor = isDark
        ? const Color(0xFFFFD60A)
        : const Color(0xFFFFB800);

    final gridColor = isDark
        ? Colors.white.withOpacity(0.12)
        : theme.dividerColor.withOpacity(0.5);

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (val) =>
              FlLine(color: gridColor, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval,
              getTitlesWidget: (val, meta) {
                // Format large numbers
                if (val >= 1000) {
                  return Text(
                    '${(val / 1000).toStringAsFixed(1)}k',
                    style: TextStyle(fontSize: 10, color: theme.hintColor),
                  );
                }
                return Text(
                  val.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: theme.hintColor),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < data.length) {
                  // Show 1 every 3 labels to avoid clutter
                  if (data.length > 5 && idx % (data.length ~/ 4) != 0) {
                    return const SizedBox.shrink();
                  }

                  final date = data[idx].fecha;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${date.day}/${date.month}',
                      style: TextStyle(fontSize: 10, color: theme.hintColor),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: mainColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: data.length < 15,
            ), // Hide dots if too many points
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  mainColor.withOpacity(0.3),
                  mainColor.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          if (_metric == 'strength' && spots2.isNotEmpty)
            LineChartBarData(
              spots: spots2,
              isCurved: true,
              color: secondaryColor,
              barWidth: 2,
              dashArray: [5, 5],
              dotData: FlDotData(show: false),
            ),
        ],
      ),
    );
  }
}
