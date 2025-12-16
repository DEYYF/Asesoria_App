import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/progreso_model.dart';

class MuscleChart extends StatelessWidget {
  final List<Progreso> historial;

  const MuscleChart({super.key, required this.historial});

  @override
  Widget build(BuildContext context) {
    if (historial.isEmpty)
      return const Center(child: Text('Sin datos musculares'));

    // Extract all diverse muscle measurements
    final Map<String, List<FlSpot>> muscleSpots = {};
    final sortedHistorial = List<Progreso>.from(historial)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    for (int i = 0; i < sortedHistorial.length; i++) {
      final h = sortedHistorial[i];
      if (h.musculo != null) {
        for (var m in h.musculo!) {
          if (!muscleSpots.containsKey(m.nombre)) {
            muscleSpots[m.nombre] = [];
          }
          muscleSpots[m.nombre]!.add(FlSpot(i.toDouble(), m.medida));
        }
      }
    }

    if (muscleSpots.isEmpty)
      return const Center(child: Text('Sin registros musculares'));

    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
      Colors.brown,
      Colors.teal,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Evolución Muscular',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < sortedHistorial.length) {
                            if (index == 0 ||
                                index == sortedHistorial.length - 1 ||
                                index % 3 == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  DateFormat(
                                    'd/M',
                                  ).format(sortedHistorial[index].fecha),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            }
                          }
                          return const SizedBox();
                        },
                        interval: 1,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  lineBarsData: muscleSpots.entries
                      .toList()
                      .asMap()
                      .entries
                      .map((entry) {
                        final index = entry.key;
                        final spots = entry.value.value;
                        return LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: colors[index % colors.length],
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                        );
                      })
                      .toList(),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          final muscleName = muscleSpots.keys.elementAt(
                            touchedSpot.barIndex,
                          );
                          return LineTooltipItem(
                            '$muscleName: ${touchedSpot.y}',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: muscleSpots.keys.toList().asMap().entries.map((e) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      color: colors[e.key % colors.length],
                    ),
                    const SizedBox(width: 4),
                    Text(e.value, style: const TextStyle(fontSize: 12)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
