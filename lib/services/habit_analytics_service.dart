import 'dart:math';
import '../models/habito_model.dart';

class HabitInsight {
  final String type; // 'correlation' or 'prediction'
  final String title;
  final String description;
  final double? confidence;
  final DateTime? estimatedDate;
  final String? habitId1;
  final String? habitId2;

  HabitInsight({
    required this.type,
    required this.title,
    required this.description,
    this.confidence,
    this.estimatedDate,
    this.habitId1,
    this.habitId2,
  });
}

class HabitAnalyticsService {
  /// Calculate Pearson correlation coefficient between two numeric habits
  double calculateCorrelation(
    List<HabitoRegistro> logs1,
    List<HabitoRegistro> logs2,
  ) {
    if (logs1.length < 7 || logs2.length < 7) {
      return 0.0; // Need at least 7 data points
    }

    // Create a map of date -> value for both habits
    final map1 = <DateTime, double>{};
    final map2 = <DateTime, double>{};

    for (var log in logs1) {
      if (log.valor != null) {
        final normalizedDate = DateTime(
          log.fecha.year,
          log.fecha.month,
          log.fecha.day,
        );
        map1[normalizedDate] = log.valor!;
      }
    }

    for (var log in logs2) {
      if (log.valor != null) {
        final normalizedDate = DateTime(
          log.fecha.year,
          log.fecha.month,
          log.fecha.day,
        );
        map2[normalizedDate] = log.valor!;
      }
    }

    // Find overlapping dates
    final commonDates = map1.keys.toSet().intersection(map2.keys.toSet());
    if (commonDates.length < 7) return 0.0;

    final values1 = commonDates.map((d) => map1[d]!).toList();
    final values2 = commonDates.map((d) => map2[d]!).toList();

    // Calculate means
    final mean1 = values1.reduce((a, b) => a + b) / values1.length;
    final mean2 = values2.reduce((a, b) => a + b) / values2.length;

    // Calculate correlation
    double numerator = 0;
    double denominator1 = 0;
    double denominator2 = 0;

    for (int i = 0; i < values1.length; i++) {
      final diff1 = values1[i] - mean1;
      final diff2 = values2[i] - mean2;
      numerator += diff1 * diff2;
      denominator1 += diff1 * diff1;
      denominator2 += diff2 * diff2;
    }

    if (denominator1 == 0 || denominator2 == 0) return 0.0;

    return numerator / sqrt(denominator1 * denominator2);
  }

  /// Generate correlation insights between pairs of numeric habits
  List<HabitInsight> generateCorrelationInsights(
    List<Habito> habits,
    Map<String, List<HabitoRegistro>> logsMap,
  ) {
    final insights = <HabitInsight>[];
    final numericHabits = habits.where((h) => h.tipo == 'numeric').toList();

    // Check all pairs
    for (int i = 0; i < numericHabits.length; i++) {
      for (int j = i + 1; j < numericHabits.length; j++) {
        final habit1 = numericHabits[i];
        final habit2 = numericHabits[j];

        final logs1 = logsMap[habit1.id] ?? [];
        final logs2 = logsMap[habit2.id] ?? [];

        final correlation = calculateCorrelation(logs1, logs2);

        // Only generate insights for strong correlations
        if (correlation.abs() >= 0.6) {
          final isPositive = correlation > 0;
          final strength = correlation.abs();

          String description;
          if (isPositive) {
            description =
                'He notado que cuando ${habit1.nombre.toLowerCase()} aumenta, ${habit2.nombre.toLowerCase()} también tiende a aumentar (correlación: ${(strength * 100).toStringAsFixed(0)}%).';
          } else {
            description =
                'He notado que cuando ${habit1.nombre.toLowerCase()} aumenta, ${habit2.nombre.toLowerCase()} tiende a disminuir (correlación: ${(strength * 100).toStringAsFixed(0)}%).';
          }

          insights.add(
            HabitInsight(
              type: 'correlation',
              title: '${habit1.nombre} ↔ ${habit2.nombre}',
              description: description,
              confidence: strength,
              habitId1: habit1.id,
              habitId2: habit2.id,
            ),
          );
        }
      }
    }

    return insights;
  }

  /// Predict when a user will reach their goal based on linear regression
  HabitInsight? generatePrediction(Habito habit, List<HabitoRegistro> logs) {
    if (habit.tipo != 'numeric' || habit.target == null) return null;
    if (logs.length < 7) return null;

    // Sort logs by date
    final sortedLogs = logs.where((l) => l.valor != null).toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    if (sortedLogs.length < 7) return null;

    // Convert to x (days since first log) and y (values)
    final firstDate = sortedLogs.first.fecha;
    final xValues = <double>[];
    final yValues = <double>[];

    for (var log in sortedLogs) {
      final daysSinceStart = log.fecha.difference(firstDate).inDays.toDouble();
      xValues.add(daysSinceStart);
      yValues.add(log.valor!);
    }

    // Calculate linear regression: y = mx + b
    final n = xValues.length;
    final sumX = xValues.reduce((a, b) => a + b);
    final sumY = yValues.reduce((a, b) => a + b);
    final sumXY = List.generate(
      n,
      (i) => xValues[i] * yValues[i],
    ).reduce((a, b) => a + b);
    final sumX2 = xValues.map((x) => x * x).reduce((a, b) => a + b);

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    // Check if we're making progress toward the goal
    final currentValue = yValues.last;
    final target = habit.target!;

    if (slope.abs() < 0.01) {
      return HabitInsight(
        type: 'prediction',
        title: 'Progreso estancado',
        description:
            'Tu progreso en ${habit.nombre} se ha estancado. Considera ajustar tu estrategia.',
        confidence: 0.5,
      );
    }

    final isIncreasing = slope > 0;
    final needsIncrease = currentValue < target;

    // Check if we're moving in the right direction
    if ((isIncreasing && !needsIncrease) || (!isIncreasing && needsIncrease)) {
      return HabitInsight(
        type: 'prediction',
        title: 'Dirección incorrecta',
        description:
            'Tu progreso en ${habit.nombre} se está alejando del objetivo.',
        confidence: 0.7,
      );
    }

    // Calculate days to reach goal
    final daysToGoal = ((target - currentValue) / slope).round();

    if (daysToGoal < 0) {
      return null; // Already at or past goal
    }

    final estimatedDate = DateTime.now().add(Duration(days: daysToGoal));

    // Calculate R² for confidence
    final meanY = sumY / n;
    final ssTotal = yValues
        .map((y) => pow(y - meanY, 2))
        .reduce((a, b) => a + b);
    final ssResidual = List.generate(
      n,
      (i) => pow(yValues[i] - (slope * xValues[i] + intercept), 2),
    ).reduce((a, b) => a + b);
    final rSquared = 1 - (ssResidual / ssTotal);

    return HabitInsight(
      type: 'prediction',
      title: 'Predicción de objetivo',
      description:
          'A tu ritmo actual, alcanzarás tu objetivo de ${habit.nombre} (${target} ${habit.unidad}) en aproximadamente $daysToGoal días (${_formatDate(estimatedDate)}).',
      confidence: rSquared.clamp(0.0, 1.0),
      estimatedDate: estimatedDate,
      habitId1: habit.id,
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${date.day} de ${months[date.month - 1]}';
  }

  /// Generate all insights for a client's habits
  List<HabitInsight> generateAllInsights(
    List<Habito> habits,
    Map<String, List<HabitoRegistro>> logsMap,
  ) {
    final insights = <HabitInsight>[];

    // Add correlation insights
    insights.addAll(generateCorrelationInsights(habits, logsMap));

    // Add prediction insights
    for (var habit in habits) {
      final logs = logsMap[habit.id] ?? [];
      final prediction = generatePrediction(habit, logs);
      if (prediction != null) {
        insights.add(prediction);
      }
    }

    // Sort by confidence (highest first)
    insights.sort((a, b) => (b.confidence ?? 0).compareTo(a.confidence ?? 0));

    return insights;
  }
}
