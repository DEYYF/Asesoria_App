class Progreso {
  final String id;
  final String clienteId;
  final DateTime fecha;
  final double? peso;
  final double? grasaCorporal;
  final double? masaMusculoEsqueletica;
  final List<MedidaMusculo>? musculo;

  Progreso({
    required this.id,
    required this.clienteId,
    required this.fecha,
    this.peso,
    this.grasaCorporal,
    this.masaMusculoEsqueletica,
    this.musculo,
  });

  factory Progreso.fromJson(Map<String, dynamic> json) {
    return Progreso(
      id: json['_id'] ?? '',
      clienteId: json['clienteId'] ?? '',
      fecha: json['fecha'] != null
          ? DateTime.parse(json['fecha'])
          : DateTime.now(),
      peso: json['peso'] != null ? (json['peso'] as num).toDouble() : null,
      grasaCorporal: json['grasaCorporal'] != null
          ? (json['grasaCorporal'] as num).toDouble()
          : null,
      masaMusculoEsqueletica: json['MasaMusculoEsqueletica'] != null
          ? (json['MasaMusculoEsqueletica'] as num).toDouble()
          : null,
      musculo: json['musculo'] != null
          ? (json['musculo'] as List)
                .map((i) => MedidaMusculo.fromJson(i))
                .toList()
          : null,
    );
  }
}

class MedidaMusculo {
  final String nombre;
  final double medida;

  MedidaMusculo({required this.nombre, required this.medida});

  factory MedidaMusculo.fromJson(Map<String, dynamic> json) {
    return MedidaMusculo(
      nombre: json['nombre'] ?? '',
      medida: (json['medida'] as num).toDouble(),
    );
  }
}
