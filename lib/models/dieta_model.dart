import 'macros_model.dart';

class Dieta {
  final String? id;
  final String clienteId;
  final String asesorId;
  final String nombre;
  final String? objetivo;
  final String estado; // 'borrador', 'activa', etc.
  final String? notas;
  final Macros macros;
  final List<Comida> comidas;
  final DateTime? createdAt;

  Dieta({
    this.id,
    required this.clienteId,
    required this.asesorId,
    required this.nombre,
    this.objetivo,
    this.estado = 'borrador',
    this.notas,
    required this.macros,
    required this.comidas,
    this.createdAt,
  });

  factory Dieta.fromJson(Map<String, dynamic> json) {
    return Dieta(
      id: json['_id'],
      clienteId: json['clienteId'] ?? '',
      asesorId: json['asesorId'] ?? '',
      nombre: json['nombre'] ?? '',
      objetivo: json['objetivo'],
      estado: json['estado'] ?? 'borrador',
      notas: json['notas'],
      macros: json['macros'] != null
          ? Macros.fromJson(json['macros'])
          : Macros(),
      comidas:
          (json['comidas'] as List<dynamic>?)
              ?.map((e) => Comida.fromJson(e))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
    );
  }
  // ... toJson ...
  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'clienteId': clienteId,
      'asesorId': asesorId,
      'nombre': nombre,
      'objetivo': objetivo,
      'estado': estado,
      'notas': notas,
      'macros': macros.toJson(),
      'comidas': comidas.map((e) => e.toJson()).toList(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}

class Comida {
  final String titulo;
  final String? hora;
  final String? notas;
  final List<OpcionDieta> opciones;
  final Macros totales;

  Comida({
    required this.titulo,
    this.hora,
    this.notas,
    required this.opciones,
    required this.totales,
  });

  factory Comida.fromJson(Map<String, dynamic> json) {
    return Comida(
      titulo: json['titulo'] ?? 'Comida',
      hora: json['hora'],
      notas: json['notas'],
      opciones:
          (json['opciones'] as List<dynamic>?)
              ?.map((e) => OpcionDieta.fromJson(e))
              .toList() ??
          [],
      totales: json['totales'] != null
          ? Macros.fromJson(json['totales'])
          : Macros(),
    );
  }
  // ... toJson ...
  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'hora': hora,
      'notas': notas,
      'opciones': opciones.map((e) => e.toJson()).toList(),
      'totales': totales.toJson(),
    };
  }
}

class OpcionDieta {
  final String tipo; // 'receta', 'ingrediente', 'combinacion'
  final String? recetaId;
  final String? ingredienteId;
  final String? nombre;
  final double? gramos;
  final int? unidades;
  final List<CombinacionItem>? items;
  final Macros? macrosTotales; // or just macros

  OpcionDieta({
    required this.tipo,
    this.recetaId,
    this.ingredienteId,
    this.nombre,
    this.gramos,
    this.unidades,
    this.items,
    this.macrosTotales,
  });

  factory OpcionDieta.fromJson(Map<String, dynamic> json) {
    String? rId;
    List<CombinacionItem>? extractedItems;

    if (json['recetaId'] is Map) {
      rId = json['recetaId']['_id'];
      // Always extract ingredients if present in the populated object
      if (json['recetaId']['ingredientes'] is List) {
        extractedItems = (json['recetaId']['ingredientes'] as List).map((i) {
          // Recipe ingredient structure: { ingrediente: { _id, nombre }, gramos }
          final ingObj = i['ingrediente'] is Map ? i['ingrediente'] : {};
          final ingId =
              ingObj['_id'] ??
              (i['ingrediente'] is String ? i['ingrediente'] : '');
          final ingName = ingObj['nombre'];
          final g = (i['gramos'] as num?)?.toDouble() ?? 0;
          return CombinacionItem(
            ingredienteId: ingId,
            nombre: ingName,
            gramos: g,
          );
        }).toList();
      }
    } else {
      rId = json['recetaId'];
    }

    String? iId;
    String? iName = json['nombre'];
    if (json['ingredienteId'] is Map) {
      iId = json['ingredienteId']['_id'];
      iName ??= json['ingredienteId']['nombre'];
    } else {
      iId = json['ingredienteId'];
    }

    final jsonItems = (json['items'] as List<dynamic>?)
        ?.map((e) => CombinacionItem.fromJson(e))
        .toList();

    return OpcionDieta(
      tipo: json['tipo'] ?? 'ingrediente',
      recetaId: rId,
      ingredienteId: iId,
      nombre: iName,
      gramos: (json['gramos'] as num?)?.toDouble(),
      unidades: json['unidades'],
      items: extractedItems ?? jsonItems,
      macrosTotales: json['totales'] != null
          ? Macros.fromJson(json['totales'])
          : (json['macros'] != null ? Macros.fromJson(json['macros']) : null),
    );
  }
  // ... toJson ...
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {'tipo': tipo};
    if (recetaId != null) data['recetaId'] = recetaId;
    if (ingredienteId != null) data['ingredienteId'] = ingredienteId;
    if (nombre != null) data['nombre'] = nombre;
    if (gramos != null) data['gramos'] = gramos;
    if (unidades != null) data['unidades'] = unidades;
    if (items != null) data['items'] = items!.map((e) => e.toJson()).toList();
    if (macrosTotales != null) data['totales'] = macrosTotales!.toJson();
    return data;
  }
}

class CombinacionItem {
  final String ingredienteId;
  final String? nombre;
  final double gramos;

  CombinacionItem({
    required this.ingredienteId,
    this.nombre,
    required this.gramos,
  });

  factory CombinacionItem.fromJson(Map<String, dynamic> json) {
    String iId;
    String? iName = json['nombre'];

    if (json['ingredienteId'] is Map) {
      iId = json['ingredienteId']['_id'] ?? '';
      iName ??= json['ingredienteId']['nombre'];
    } else {
      iId = json['ingredienteId'] ?? '';
    }

    return CombinacionItem(
      ingredienteId: iId,
      nombre: iName,
      gramos: (json['gramos'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'ingredienteId': ingredienteId, 'nombre': nombre, 'gramos': gramos};
  }
}
