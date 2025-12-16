class Macros {
  final double kcal;
  final double proteinas;
  final double carbohidratos;
  final double grasas;

  Macros({
    this.kcal = 0,
    this.proteinas = 0,
    this.carbohidratos = 0,
    this.grasas = 0,
  });

  factory Macros.fromJson(Map<String, dynamic> json) {
    return Macros(
      kcal:
          (json['kcal'] as num?)?.toDouble() ??
          (json['calorias'] as num?)?.toDouble() ??
          0,
      proteinas:
          (json['p'] as num?)?.toDouble() ??
          (json['proteinas'] as num?)?.toDouble() ??
          0,
      carbohidratos:
          (json['c'] as num?)?.toDouble() ??
          (json['carbohidratos'] as num?)?.toDouble() ??
          0,
      grasas:
          (json['g'] as num?)?.toDouble() ??
          (json['grasas'] as num?)?.toDouble() ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kcal': kcal,
      'proteinas': proteinas,
      'carbohidratos': carbohidratos,
      'grasas': grasas,
    };
  }
}
