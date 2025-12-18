class ExerciseHistoryRecord {
  final DateTime fecha;
  final double maxWeight;
  final double estimated1RM;
  final double totalVolume;
  final int maxReps;
  final String? notes;
  final List<dynamic>? series;

  ExerciseHistoryRecord({
    required this.fecha,
    this.maxWeight = 0,
    this.estimated1RM = 0,
    this.totalVolume = 0,
    this.maxReps = 0,
    this.notes,
    this.series,
  });

  factory ExerciseHistoryRecord.fromJson(Map<String, dynamic> json) {
    return ExerciseHistoryRecord(
      fecha: DateTime.parse(json['fecha']),
      maxWeight: (json['maxWeight'] ?? 0).toDouble(),
      estimated1RM: (json['estimated1RM'] ?? 0).toDouble(),
      totalVolume: (json['totalVolume'] ?? 0).toDouble(),
      maxReps: (json['maxReps'] ?? 0).toInt(),
      // Try to catch session comments if they bubble down, or exercise notes
      notes: json['notas'] ?? json['comentarios'],
      series: json['series'],
    );
  }
}
