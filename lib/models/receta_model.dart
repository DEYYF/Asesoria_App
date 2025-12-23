import 'macros_model.dart';

class Receta {
  final String id;
  final String nombre;
  final double caloriasTotales;
  final Macros macrosTotales;
  final String? linkPreparacion;
  final List<RecetaIngrediente> ingredientes;

  Receta({
    required this.id,
    required this.nombre,
    this.caloriasTotales = 0,
    required this.macrosTotales,
    this.linkPreparacion,
    this.ingredientes = const [],
  });

  factory Receta.fromJson(Map<String, dynamic> json) {
    var ingList = json['ingredientes'] as List? ?? [];
    return Receta(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      nombre: json['nombre'] ?? '',
      caloriasTotales: (json['caloriasTotales'] as num?)?.toDouble() ?? 0,
      macrosTotales: json['macrosTotales'] != null
          ? Macros.fromJson(json['macrosTotales'])
          : Macros(),
      linkPreparacion: json['linkPreparacion'],
      ingredientes: ingList.map((i) => RecetaIngrediente.fromJson(i)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'nombre': nombre,
      'caloriasTotales': caloriasTotales,
      'macrosTotales': macrosTotales.toJson(),
      'linkPreparacion': linkPreparacion,
      'ingredientes': ingredientes.map((i) => i.toJson()).toList(),
    };
  }
}

class RecetaIngrediente {
  final String? ingredienteId;
  final String? nombre; // Derived or libre
  final String? nombreLibre;
  final double gramos;

  RecetaIngrediente({
    this.ingredienteId,
    this.nombre,
    this.nombreLibre,
    this.gramos = 0,
  });

  factory RecetaIngrediente.fromJson(Map<String, dynamic> json) {
    return RecetaIngrediente(
      ingredienteId: (json['ingrediente'] is Map)
          ? json['ingrediente']['_id']?.toString()
          : json['ingrediente']?.toString(),
      nombre: (json['ingrediente'] is Map)
          ? json['ingrediente']['nombre']?.toString()
          : json['nombre']?.toString(),
      nombreLibre: json['nombreLibre']?.toString(),
      gramos: (json['gramos'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (ingredienteId != null) 'ingrediente': ingredienteId,
      if (nombreLibre != null) 'nombreLibre': nombreLibre,
      'gramos': gramos,
    };
  }
}
