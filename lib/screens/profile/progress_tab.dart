import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/cliente_model.dart';
import '../../models/progreso_model.dart';
import '../../models/exercise_history_model.dart';
import '../../widgets/charts/weight_chart.dart';
import '../../widgets/charts/body_fat_chart.dart';
import '../../widgets/charts/muscle_chart.dart';
import '../../widgets/heatmap_panel.dart';
import '../../services/api_service.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void initState() {
    super.initState();
    _loadEjercicios();
  }

  Future<void> _loadEjercicios() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get(
        '/entrenamientos/registros/cliente/${widget.cliente.id}/ejercicios',
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          _ejercicios = data.cast<String>();
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
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          _historyData = data
              .map((x) => ExerciseHistoryRecord.fromJson(x))
              .toList();
          _historyData.sort((a, b) => a.fecha.compareTo(b.fecha));
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
        final List<dynamic> trainings = jsonDecode(res.body);
        if (trainings.isNotEmpty) {
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with View Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progreso',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              if (widget.onAddProgress != null)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_circle,
                      color: Color(0xFF007AFF),
                      size: 24,
                    ),
                  ),
                  onPressed: _viewMode == 'rendimiento'
                      ? _navigateToRegisterTraining
                      : widget.onAddProgress,
                  tooltip: _viewMode == 'rendimiento'
                      ? 'Registrar Entrenamiento'
                      : 'Añadir Progreso',
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Custom Segmented Control
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildToggleOption('RENDIMIENTO', 'rendimiento'),
                _buildToggleOption('CORPORAL', 'corporal'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_viewMode == 'rendimiento')
            _buildRendimientoView()
          else
            _buildCorporalView(),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String label, String value) {
    final isSelected = _viewMode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _viewMode = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? const Color(0xFF1C1C1E)
                  : const Color(0xFF8E8E93),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCorporalView() {
    final List<Progreso> historial = widget.cliente.historialProgreso != null
        ? widget.cliente.historialProgreso!
              .map((json) => Progreso.fromJson(json))
              .toList()
        : [];

    if (historial.isEmpty) {
      return _buildEmptyState('No hay registros corporales.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('MAPA CORPORAL'),
        HeatmapPanel(historial: historial),
        const SizedBox(height: 24),

        _sectionTitle('EVOLUCIÓN'),
        WeightChart(historial: historial),
        const SizedBox(height: 16),
        BodyFatChart(historial: historial),
        const SizedBox(height: 16),
        MuscleChart(historial: historial),
      ],
    );
  }

  Widget _buildRendimientoView() {
    if (_isLoadingExercises)
      return const Center(child: CircularProgressIndicator());

    if (_ejercicios.isEmpty) {
      return _buildEmptyState('No hay registros de entrenamiento.');
    }

    final data = _filteredData;

    // Calculate Records (Always from full history, or filtered? Usually records are all-time)
    // Let's use ALL-TIME records for cards, but chart uses filtered.
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedEjercicio,
              hint: const Text('Seleccionar Ejercicio'),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
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
        const SizedBox(height: 24),

        // Summary Cards
        if (_historyData.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  '1RM ESTIMADO',
                  '${max1RM.toStringAsFixed(1)} kg',
                  Icons.emoji_events_rounded,
                  const Color(0xFFFFB800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'PESO MÁX',
                  '${maxWeight.toStringAsFixed(1)} kg',
                  Icons.fitness_center_rounded,
                  const Color(0xFF007AFF),
                ),
              ),
            ],
          ),
        if (_historyData.isNotEmpty) ...[
          const SizedBox(height: 12),
          // Volume Card full width or third card
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'VOLUMEN RÉCORD',
                  '${(maxVolume / 1000).toStringAsFixed(1)} tons',
                  Icons.bar_chart_rounded,
                  const Color(0xFFAF52DE),
                ),
              ),
            ],
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
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    children: [
                      _buildMetricBtn('Fuerza', 'strength'),
                      _buildMetricBtn('Volumen', 'volume'),
                      _buildMetricBtn('Reps', 'reps'),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Time Filter
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(2),
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
                color: Colors.white,
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

  Widget _buildMetricBtn(String label, String val) {
    final isSelected = _metric == val;
    return GestureDetector(
      onTap: () => setState(() => _metric = val),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ), // Compact padding
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
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
            color: isSelected ? Colors.black : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeBtn(String label, String val) {
    final isSelected = _timeFilter == val;
    return GestureDetector(
      onTap: () => setState(() => _timeFilter = val),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ), // Compact padding
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
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
            color: isSelected ? const Color(0xFF007AFF) : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced from 16
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: color,
                ), // Reduced size slightly
              ),
              const SizedBox(width: 8),
              Expanded(
                // Ensure title truncates if needed
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8E8E93),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            // Auto-scale large numbers
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18, // Slightly adjusted base size
                fontWeight: FontWeight.w800,
                color: Color(0xFF1C1C1E),
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvolutionChart(List<ExerciseHistoryRecord> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    List<FlSpot> spots = [];
    List<FlSpot> spots2 = [];

    // Map timestamps to X axis (index-based for simplicity in this prototype,
    // but equidistant points are fine if we just want to show "sessions")
    // If we want accurate time axis: spots.add(FlSpot(rec.fecha.millisecondsSinceEpoch.toDouble(), ...))
    // Let's stick to index 0..N for clean categorical spacing logic.

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
        ? const Color(0xFF007AFF)
        : (_metric == 'volume'
              ? const Color(0xFFAF52DE)
              : const Color(0xFF30D158));

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (val) =>
              FlLine(color: Colors.grey.shade100, strokeWidth: 1),
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
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF8E8E93),
                    ),
                  );
                }
                return Text(
                  val.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8E8E93),
                  ),
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
                  if (data.length > 5 && idx % (data.length ~/ 4) != 0)
                    return const SizedBox.shrink();

                  final date = data[idx].fecha;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${date.day}/${date.month}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF8E8E93),
                      ),
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
              color: const Color(0xFFFFB800), // Amber for 1RM
              barWidth: 2,
              dashArray: [5, 5],
              dotData: FlDotData(show: false),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bar_chart_rounded,
                size: 32,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              msg,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF8E8E93),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
