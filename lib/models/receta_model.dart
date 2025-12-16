import 'macros_model.dart';

class Receta {
  final String id;
  final String nombre;
  final double caloriasTotales;
  final Macros macrosTotales;

  Receta({
    required this.id,
    required this.nombre,
    this.caloriasTotales = 0,
    required this.macrosTotales,
  });

  factory Receta.fromJson(Map<String, dynamic> json) {
    return Receta(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      nombre: json['nombre'] ?? '',
      caloriasTotales: (json['caloriasTotales'] as num?)?.toDouble() ?? 0,
      macrosTotales: json['macrosTotales'] != null
          ? Macros.fromJson(json['macrosTotales'])
          : Macros(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'nombre': nombre,
      'caloriasTotales': caloriasTotales,
      'macrosTotales': macrosTotales.toJson(),
    };
  }
}
