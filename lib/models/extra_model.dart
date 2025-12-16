class Extra {
  final String id;
  final String nombre;
  final double precio;
  final String? tipo; // "mensual" or "unico"

  Extra({
    required this.id,
    required this.nombre,
    required this.precio,
    this.tipo,
  });

  factory Extra.fromJson(Map<String, dynamic> json) {
    return Extra(
      id: json['_id'] ?? '',
      nombre: json['nombre'] ?? '',
      precio: (json['precio'] as num?)?.toDouble() ?? 0.0,
      tipo: json['type'] ?? 'mensual',
    );
  }
}
