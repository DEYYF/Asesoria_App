import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/habito_service.dart';

class AnalyticsTab extends StatefulWidget {
  final String clienteId;
  const AnalyticsTab({super.key, required this.clienteId});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  bool _isLoading = true;
  List<FlSpot> _weightSpots = [];
  List<FlSpot> _kcalSpots = [];
  List<DateTime> _dates = [];
  double? _minYWeight;
  double? _maxYWeight;
  double? _minYKcal;
  double? _maxYKcal;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final habitoService = Provider.of<HabitoService>(context, listen: false);
    final data = await habitoService.fetchWeightKcalAnalytics(widget.clienteId);

    final List<dynamic> weightData = data['weight'] ?? [];
    final List<dynamic> kcalData = data['kcal'] ?? [];

    if (!mounted) return;

    // 1. Process and Group Data by Day to avoid duplicates and ensure vertical sorting
    Map<DateTime, List<double>> weightByDay = {};
    for (var e in weightData) {
      final date = DateTime.parse(e['date']);
      final midnight = DateTime(date.year, date.month, date.day);
      weightByDay
          .putIfAbsent(midnight, () => [])
          .add((e['weight'] as num).toDouble());
    }

    Map<DateTime, List<double>> kcalByDay = {};
    for (var e in kcalData) {
      final date = DateTime.parse(e['date']);
      final midnight = DateTime(date.year, date.month, date.day);
      kcalByDay
          .putIfAbsent(midnight, () => [])
          .add((e['kcal'] as num).toDouble());
    }

    // Average values if multiple entries exist per day
    final weightProcessed =
        weightByDay.entries
            .map(
              (e) => _DataPoint(
                date: e.key,
                value: e.value.reduce((a, b) => a + b) / e.value.length,
              ),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    final kcalProcessed =
        kcalByDay.entries
            .map(
              (e) => _DataPoint(
                date: e.key,
                value: e.value.reduce((a, b) => a + b) / e.value.length,
              ),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    // 2. Merge dates for X-axis synchronization
    Set<DateTime> allDatesSet = {};
    for (var p in weightProcessed) allDatesSet.add(p.dateAtMidnight);
    for (var p in kcalProcessed) allDatesSet.add(p.dateAtMidnight);

    _dates = allDatesSet.toList()..sort();

    if (_dates.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    // 3. Generate Spots (now strictly sorted by X)
    final List<FlSpot> rawWeightSpots = weightProcessed.map((p) {
      final x = _dates.indexOf(p.dateAtMidnight).toDouble();
      return FlSpot(x, p.value);
    }).toList();

    final List<FlSpot> rawKcalSpots = kcalProcessed.map((p) {
      final x = _dates.indexOf(p.dateAtMidnight).toDouble();
      return FlSpot(x, p.value);
    }).toList();

    // 4. Calculate Ranges for Y-axis scaling
    if (rawWeightSpots.isNotEmpty) {
      _minYWeight =
          rawWeightSpots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 1;
      _maxYWeight =
          rawWeightSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 1;
    } else {
      _minYWeight = 0;
      _maxYWeight = 100;
    }

    if (rawKcalSpots.isNotEmpty) {
      _minYKcal =
          rawKcalSpots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 100;
      _maxYKcal =
          rawKcalSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 100;
    } else {
      _minYKcal = 0;
      _maxYKcal = 3000;
    }

    // 5. Apply Normalization to Calories to fit Weight scale visually
    _weightSpots = rawWeightSpots;

    final weightRange = _maxYWeight! - _minYWeight!;
    final kcalRange = _maxYKcal! - _minYKcal!;

    if (kcalRange != 0 && weightRange != 0) {
      _kcalSpots = rawKcalSpots.map((s) {
        final normalizedY =
            _minYWeight! + ((s.y - _minYKcal!) / kcalRange) * weightRange;
        return FlSpot(s.x, normalizedY);
      }).toList();
    } else if (weightRange != 0) {
      _kcalSpots = rawKcalSpots.map((s) {
        return FlSpot(s.x, _minYWeight! + weightRange / 2);
      }).toList();
    } else {
      _kcalSpots = rawKcalSpots;
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_dates.isEmpty) {
      return _buildEmptyState();
    }

    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(theme),
          const SizedBox(height: 24),
          Text(
            'Peso vs Calorías',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Compara cómo tu ingesta calórica influye en tu peso.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 24),
          _buildChartContainer(theme),
          const SizedBox(height: 16),
          _buildLegend(theme),
          const SizedBox(height: 32),
          _buildPRPlaceholder(theme),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard de Progreso',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Usa la gráfica para ver la relación entre dieta y resultados.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartContainer(ThemeData theme) {
    return Container(
      height: 350,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 32, 24, 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => theme.cardColor.withOpacity(0.95),
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  if (isSelectedWeight(spot)) {
                    return LineTooltipItem(
                      '${spot.y.toStringAsFixed(1)} kg',
                      TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  } else {
                    double originalKcal = 0;
                    final weightRange = _maxYWeight! - _minYWeight!;
                    final kcalRange = _maxYKcal! - _minYKcal!;
                    if (weightRange != 0) {
                      originalKcal =
                          _minYKcal! +
                          ((spot.y - _minYWeight!) / weightRange) * kcalRange;
                    }
                    return LineTooltipItem(
                      '${originalKcal.toInt()} kcal',
                      const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: theme.dividerColor.withOpacity(0.1),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}kg',
                  style: const TextStyle(fontSize: 10),
                ),
                reservedSize: 35,
              ),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final weightRange = _maxYWeight! - _minYWeight!;
                  final kcalRange = _maxYKcal! - _minYKcal!;
                  if (weightRange == 0) return const SizedBox();
                  final originalKcal =
                      _minYKcal! +
                      ((value - _minYWeight!) / weightRange) * kcalRange;
                  return Text(
                    '${originalKcal.toInt()}',
                    style: const TextStyle(color: Colors.orange, fontSize: 10),
                  );
                },
                reservedSize: 35,
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= _dates.length)
                    return const SizedBox();

                  // Dynamically control density based on data length
                  int skip = (_dates.length / 5).ceil();
                  if (skip < 1) skip = 1;

                  if (index % skip != 0 && index != _dates.length - 1)
                    return const SizedBox();

                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('dd/MM').format(_dates[index]),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minY: _minYWeight,
          maxY: _maxYWeight,
          lineBarsData: [
            // kcal (orange, back)
            LineChartBarData(
              spots: _kcalSpots,
              isCurved: true,
              color: Colors.orange.withOpacity(0.4),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.orange.withOpacity(0.05),
              ),
            ),
            // weight (primary, front)
            LineChartBarData(
              spots: _weightSpots,
              isCurved: true,
              color: theme.primaryColor,
              barWidth: 4,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                      color: Colors.white,
                      strokeColor: theme.primaryColor,
                      strokeWidth: 2,
                      radius: 4,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool isSelectedWeight(LineBarSpot spot) {
    // If we have multiple lines, weight is the one with index 1
    return spot.barIndex == 1;
  }

  Widget _buildLegend(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendChip(color: theme.primaryColor, label: 'Peso (kg)'),
        const SizedBox(width: 20),
        _LegendChip(color: Colors.orange, label: 'Calorías (kcal)'),
      ],
    );
  }

  Widget _buildPRPlaceholder(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.fitness_center_rounded,
            color: theme.primaryColor.withOpacity(0.2),
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'Próximamente: Récords Personales',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            'Pronto podrás visualizar tu progresión de fuerza aquí.',
            style: TextStyle(color: theme.hintColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text('No hay datos suficientes para mostrar analíticas.'),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _DataPoint {
  final DateTime date;
  final double value;
  _DataPoint({required this.date, required this.value});
  DateTime get dateAtMidnight => DateTime(date.year, date.month, date.day);
}
