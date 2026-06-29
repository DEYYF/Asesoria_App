import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class PointsGraphWidget extends StatelessWidget {
  final List<dynamic>? history;

  const PointsGraphWidget({super.key, this.history});

  List<FlSpot> get dataPoints {
    if (history == null || history!.isEmpty) {
      return [const FlSpot(0, 0)];
    }

    // Get last 30 days of data
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final recentHistory = history!.where((entry) {
      final date = DateTime.parse(entry['date'].toString());
      return date.isAfter(thirtyDaysAgo);
    }).toList();

    if (recentHistory.isEmpty) {
      return [const FlSpot(0, 0)];
    }

    // Sort by date
    recentHistory.sort((a, b) {
      final dateA = DateTime.parse(a['date'].toString());
      final dateB = DateTime.parse(b['date'].toString());
      return dateA.compareTo(dateB);
    });

    // Create cumulative points data
    double cumulativePoints = 0;
    final spots = <FlSpot>[];

    for (int i = 0; i < recentHistory.length; i++) {
      cumulativePoints += (recentHistory[i]['points'] ?? 0).toDouble();
      spots.add(FlSpot(i.toDouble(), cumulativePoints));
    }

    return spots.isEmpty ? [const FlSpot(0, 0)] : spots;
  }

  int get totalPoints {
    if (history == null || history!.isEmpty) return 0;
    return history!.fold<int>(
      0,
      (sum, entry) => sum + ((entry['points'] ?? 0) as int),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spots = dataPoints;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PUNTOS TOTALES',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalPoints',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Últimos 30 días',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: spots.length == 1 && spots[0].y == 0
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.show_chart,
                          size: 48,
                          color: theme.hintColor.withOpacity(0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Sin datos de puntos',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: spots.last.y / 4,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: theme.dividerColor.withOpacity(0.3),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: spots.length > 10 ? spots.length / 5 : 1,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= spots.length)
                                return const SizedBox();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${value.toInt() + 1}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.hintColor,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: spots.last.y / 4,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.hintColor,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: spots.length > 1 ? spots.length - 1 : 1,
                      minY: 0,
                      maxY: spots.last.y * 1.2,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          gradient: LinearGradient(
                            colors: [
                              theme.primaryColor,
                              theme.primaryColor.withOpacity(0.7),
                            ],
                          ),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: theme.primaryColor,
                                strokeWidth: 2,
                                strokeColor:
                                    theme.cardTheme.color ?? Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                theme.primaryColor.withOpacity(0.2),
                                theme.primaryColor.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => theme.primaryColor,
                          tooltipRoundedRadius: 8,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              return LineTooltipItem(
                                '${spot.y.toInt()} pts',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
