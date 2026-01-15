class Tarifa {
  final String id;
  final String nombre;
  final double precio;
  final int duracionDias;
  final String tipoServicio;

  final String? descripcion;

  Tarifa({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.duracionDias,
    required this.tipoServicio,
    this.descripcion,
  });

  factory Tarifa.fromJson(Map<String, dynamic> json) {
    return Tarifa(
      id: json['_id'] ?? '',
      nombre: json['nombre'] ?? '',
      precio: (json['precio'] as num?)?.toDouble() ?? 0.0,
      duracionDias: json['duracionDias'] ?? 30,
      tipoServicio: json['tipoServicio'] ?? 'Mensual',
      descripcion: json['descripcion'],
    );
  }
}
