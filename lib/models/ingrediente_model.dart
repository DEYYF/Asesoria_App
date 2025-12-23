class Ingrediente {
  final String id;
  final String nombre;
  final double kcal;
  final double proteinas;
  final double carbohidratos;
  final double grasas;
  final String? tipo;

  Ingrediente({
    required this.id,
    required this.nombre,
    this.kcal = 0,
    this.proteinas = 0,
    this.carbohidratos = 0,
    this.grasas = 0,
    this.tipo,
  });

  factory Ingrediente.fromJson(Map<String, dynamic> json) {
    return Ingrediente(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      nombre: json['nombre'] ?? '',
      kcal: (json['kcal'] as num?)?.toDouble() ?? 0,
      proteinas: (json['proteinas'] as num?)?.toDouble() ?? 0,
      carbohidratos: (json['carbohidratos'] as num?)?.toDouble() ?? 0,
      grasas: (json['grasas'] as num?)?.toDouble() ?? 0,
      tipo: json['tipo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'nombre': nombre,
      'kcal': kcal,
      'proteinas': proteinas,
      'carbohidratos': carbohidratos,
      'grasas': grasas,
      'tipo': tipo,
    };
  }
}
