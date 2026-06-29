import 'dart:math';
import 'macros_model.dart';

class Dieta {
  final String? id;
  final String clienteId;
  final String asesorId;
  final String nombre;
  final String? objetivo;
  final String estado;
  final String? notas;
  final String tipo; // 'opciones' | 'calendario'
  final Macros macros;
  final List<Comida> comidas;
  final List<DiaCalendario> diasSemana;
  final DateTime? createdAt;

  Dieta({
    this.id,
    required this.clienteId,
    required this.asesorId,
    required this.nombre,
    this.objetivo,
    this.estado = 'borrador',
    this.notas,
    this.tipo = 'opciones',
    required this.macros,
    required this.comidas,
    this.diasSemana = const [],
    this.createdAt,
  });

  Dieta copyWith({
    String? id,
    String? clienteId,
    String? asesorId,
    String? nombre,
    String? objetivo,
    String? estado,
    String? notas,
    String? tipo,
    Macros? macros,
    List<Comida>? comidas,
    List<DiaCalendario>? diasSemana,
    DateTime? createdAt,
  }) {
    return Dieta(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      asesorId: asesorId ?? this.asesorId,
      nombre: nombre ?? this.nombre,
      objetivo: objetivo ?? this.objetivo,
      estado: estado ?? this.estado,
      notas: notas ?? this.notas,
      tipo: tipo ?? this.tipo,
      macros: macros ?? this.macros,
      comidas: comidas ?? this.comidas,
      diasSemana: diasSemana ?? this.diasSemana,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Dieta.fromJson(Map<String, dynamic> json) {
    String cId = '';
    String? cName;

    if (json['clienteId'] is Map) {
      cId = json['clienteId']['_id'] ?? '';
      cName = json['clienteId']['nombre'];
    } else {
      cId = json['clienteId'] ?? '';
    }

    return Dieta(
      id: json['_id'],
      clienteId: cId,
      asesorId: json['asesorId'] ?? '',
      nombre: json['nombre'] ?? '',
      objetivo: json['objetivo'],
      estado: json['estado'] ?? 'borrador',
      notas: json['notas'],
      tipo: json['tipo'] ?? 'opciones',
      macros: json['macros'] != null ? Macros.fromJson(json['macros']) : Macros(),
      comidas: (json['comidas'] as List<dynamic>?)
              ?.map((e) => Comida.fromJson(e))
              .toList() ??
          [],
      diasSemana: (json['diasSemana'] as List<dynamic>?)
              ?.map((e) => DiaCalendario.fromJson(e))
              .toList() ??
          [],
      createdAt:
          json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    )..clienteNombre = cName;
  }

  String? clienteNombre;

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'clienteId': clienteId,
      'asesorId': asesorId,
      'nombre': nombre,
      'objetivo': objetivo,
      'estado': estado,
      'notas': notas,
      'tipo': tipo,
      'macros': macros.toJson(),
      'comidas': comidas.map((e) => e.toJson()).toList(),
      'diasSemana': diasSemana.map((e) => e.toJson()).toList(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}

class DiaCalendario {
  final String dia;
  final List<Comida> comidas;
  final String? notas;

  const DiaCalendario({
    required this.dia,
    this.comidas = const [],
    this.notas,
  });

  factory DiaCalendario.fromJson(Map<String, dynamic> json) {
    return DiaCalendario(
      dia: json['dia'] ?? '',
      comidas: (json['comidas'] as List<dynamic>?)
              ?.map((e) => Comida.fromJson(e))
              .toList() ??
          [],
      notas: json['notas'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dia': dia,
      'comidas': comidas.map((e) => e.toJson()).toList(),
      if (notas != null) 'notas': notas,
    };
  }
}

class Comida {
  final String titulo;
  final String? hora;
  final String? notas;
  final List<OpcionDieta> opciones;
  final Macros totales;
  final String? uniqueKey;

  Comida({
    required this.titulo,
    this.hora,
    this.notas,
    required this.opciones,
    required this.totales,
    this.uniqueKey,
  });

  Comida copyWith({
    String? titulo,
    String? hora,
    String? notas,
    List<OpcionDieta>? opciones,
    Macros? totales,
    String? uniqueKey,
  }) {
    return Comida(
      titulo: titulo ?? this.titulo,
      hora: hora ?? this.hora,
      notas: notas ?? this.notas,
      opciones: opciones ?? this.opciones,
      totales: totales ?? this.totales,
      uniqueKey: uniqueKey ?? this.uniqueKey,
    );
  }

  factory Comida.fromJson(Map<String, dynamic> json) {
    return Comida(
      titulo: json['titulo'] ?? 'Comida',
      hora: json['hora'],
      notas: json['notas'],
      opciones: (json['opciones'] as List<dynamic>?)
              ?.map((e) => OpcionDieta.fromJson(e))
              .toList() ??
          [],
      totales: json['totales'] != null ? Macros.fromJson(json['totales']) : Macros(),
      uniqueKey:
          '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(10000)}_${json['titulo'] ?? 'meal'}',
    );
  }

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
  final String tipo;
  final String? recetaId;
  final String? ingredienteId;
  final String? nombre;
  final double? gramos;
  final int? unidades;
  final List<CombinacionItem>? items;
  final Macros? macrosTotales;
  final String? uniqueKey;
  final String? notas;

  OpcionDieta({
    required this.tipo,
    this.recetaId,
    this.ingredienteId,
    this.nombre,
    this.gramos,
    this.unidades,
    this.items,
    this.macrosTotales,
    this.uniqueKey,
    this.notas,
  });

  OpcionDieta copyWith({
    String? tipo,
    String? recetaId,
    String? ingredienteId,
    String? nombre,
    double? gramos,
    int? unidades,
    List<CombinacionItem>? items,
    Macros? macrosTotales,
    String? uniqueKey,
    String? notas,
    bool clearNotas = false,
  }) {
    return OpcionDieta(
      tipo: tipo ?? this.tipo,
      recetaId: recetaId ?? this.recetaId,
      ingredienteId: ingredienteId ?? this.ingredienteId,
      nombre: nombre ?? this.nombre,
      gramos: gramos ?? this.gramos,
      unidades: unidades ?? this.unidades,
      items: items ?? this.items,
      macrosTotales: macrosTotales ?? this.macrosTotales,
      uniqueKey: uniqueKey ?? this.uniqueKey,
      notas: clearNotas ? null : (notas ?? this.notas),
    );
  }

  factory OpcionDieta.fromJson(Map<String, dynamic> json) {
    String? rId;
    List<CombinacionItem>? extractedItems;

    if (json['recetaId'] is Map) {
      rId = json['recetaId']['_id'];
      if (json['recetaId']['ingredientes'] is List) {
        extractedItems = (json['recetaId']['ingredientes'] as List).map((i) {
          final ingObj = i['ingrediente'] is Map ? i['ingrediente'] : {};
          final ingId =
              ingObj['_id'] ?? (i['ingrediente'] is String ? i['ingrediente'] : '');
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
      uniqueKey:
          '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(10000)}_${iId ?? rId ?? 'opt'}',
      notas: json['notas'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {'tipo': tipo};

    if (recetaId != null) data['recetaId'] = recetaId;
    if (ingredienteId != null) data['ingredienteId'] = ingredienteId;
    if (nombre != null) data['nombre'] = nombre;
    if (gramos != null) data['gramos'] = gramos;
    if (unidades != null) data['unidades'] = unidades;
    if (items != null) data['items'] = items!.map((e) => e.toJson()).toList();
    if (macrosTotales != null) data['totales'] = macrosTotales!.toJson();
    if (notas != null && notas!.isNotEmpty) data['notas'] = notas;

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

  CombinacionItem copyWith({
    String? ingredienteId,
    String? nombre,
    double? gramos,
  }) {
    return CombinacionItem(
      ingredienteId: ingredienteId ?? this.ingredienteId,
      nombre: nombre ?? this.nombre,
      gramos: gramos ?? this.gramos,
    );
  }

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
    return {
      'ingredienteId': ingredienteId,
      'nombre': nombre,
      'gramos': gramos,
    };
  }
}