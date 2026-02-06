class Habito {
  final String id;
  final String nombre;
  final String? descripcion;
  final String tipo; // 'checklist', 'numeric'
  final String? unidad;
  final double? target;
  final String frecuencia;
  final String clienteId;
  final String asesorId;
  final bool activo;
  final int orden;
  final String? chartType; // 'line', 'bar', 'pie', 'heatmap', etc.
  final String? parentId;
  final String? parentCondition; // 'si', 'no', '>', '<', etc.
  final double? parentValue;

  Habito({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.tipo,
    this.unidad,
    this.target,
    required this.frecuencia,
    required this.clienteId,
    required this.asesorId,
    this.activo = true,
    this.orden = 0,
    this.chartType,
    this.parentId,
    this.parentCondition,
    this.parentValue,
  });

  factory Habito.fromJson(Map<String, dynamic> json) {
    return Habito(
      id: json['_id'] ?? '',
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      tipo: json['tipo'] ?? 'checklist',
      unidad: json['unidad'],
      target: json['target'] != null
          ? (json['target'] as num).toDouble()
          : null,
      frecuencia: json['frecuencia'] ?? 'diario',
      clienteId: json['clienteId'] ?? '',
      asesorId: json['asesorId'] ?? '',
      activo: json['activo'] ?? true,
      orden: json['orden'] ?? 0,
      chartType: json['chartType'],
      parentId: json['parentId'],
      parentCondition: json['parentCondition'],
      parentValue: json['parentValue'] != null
          ? (json['parentValue'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'descripcion': descripcion,
    'tipo': tipo,
    'unidad': unidad,
    'target': target,
    'frecuencia': frecuencia,
    'clienteId': clienteId,
    'asesorId': asesorId,
    'activo': activo,
    'orden': orden,
    'chartType': chartType,
    'parentId': parentId,
    'parentCondition': parentCondition,
    'parentValue': parentValue,
  };
}

class HabitoRegistro {
  final String id;
  final String habitoId;
  final String clienteId;
  final DateTime fecha;
  final bool completado;
  final double? valor;
  final String? notas;

  HabitoRegistro({
    required this.id,
    required this.habitoId,
    required this.clienteId,
    required this.fecha,
    required this.completado,
    this.valor,
    this.notas,
  });

  factory HabitoRegistro.fromJson(Map<String, dynamic> json) {
    return HabitoRegistro(
      id: json['_id'] ?? '',
      habitoId: json['habitoId'] ?? '',
      clienteId: json['clienteId'] ?? '',
      fecha: json['fecha'] != null
          ? DateTime.parse(json['fecha'])
          : DateTime.now(),
      completado: json['completado'] ?? false,
      valor: json['valor'] != null ? (json['valor'] as num).toDouble() : null,
      notas: json['notas'],
    );
  }

  Map<String, dynamic> toJson() => {
    'habitoId': habitoId,
    'clienteId': clienteId,
    'fecha': fecha.toIso8601String(),
    'completado': completado,
    'valor': valor,
    'notas': notas,
  };
}
