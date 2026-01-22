import 'ejercicio_model.dart';

class Entrenamiento {
  final String? id;
  final String? asesorId;
  final String clienteId;
  final String titulo;
  final String? objetivo;
  final bool activo;
  final List<SemanaEntrenamiento> semanas;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Entrenamiento({
    this.id,
    this.asesorId,
    required this.clienteId,
    required this.titulo,
    this.objetivo,
    this.activo = true,
    required this.semanas,
    this.createdAt,
    this.updatedAt,
  });

  Entrenamiento copyWith({
    String? id,
    String? asesorId,
    String? clienteId,
    String? titulo,
    String? objetivo,
    bool? activo,
    List<SemanaEntrenamiento>? semanas,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Entrenamiento(
      id: id ?? this.id,
      asesorId: asesorId ?? this.asesorId,
      clienteId: clienteId ?? this.clienteId,
      titulo: titulo ?? this.titulo,
      objetivo: objetivo ?? this.objetivo,
      activo: activo ?? this.activo,
      semanas: semanas ?? this.semanas,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Entrenamiento.fromJson(Map<String, dynamic> json) {
    String cId = '';
    String? cName;

    if (json['clienteId'] is Map) {
      cId = json['clienteId']['_id'] ?? '';
      cName = json['clienteId']['nombre'];
    } else {
      cId = json['clienteId'] ?? '';
    }

    return Entrenamiento(
      id: json['_id'],
      asesorId: json['asesorid'] ?? json['asesorId'],
      clienteId: cId,
      titulo: json['titulo'] ?? 'Sin título',
      objetivo: json['objetivo'],
      activo: json['activo'] ?? true,
      semanas: (json['semanas'] as List? ?? [])
          .map((e) => SemanaEntrenamiento.fromJson(e))
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    )..clienteNombre = cName;
  }

  String? clienteNombre;

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'asesorid': asesorId,
      'clienteId': clienteId,
      'titulo': titulo,
      'objetivo': objetivo,
      'activo': activo,
      'semanas': semanas.map((e) => e.toJson()).toList(),
    };
  }
}

class SemanaEntrenamiento {
  final int numero;
  final List<DiaEntrenamiento> dias;

  SemanaEntrenamiento({required this.numero, required this.dias});

  SemanaEntrenamiento copyWith({int? numero, List<DiaEntrenamiento>? dias}) {
    return SemanaEntrenamiento(
      numero: numero ?? this.numero,
      dias: dias ?? this.dias,
    );
  }

  factory SemanaEntrenamiento.fromJson(Map<String, dynamic> json) {
    return SemanaEntrenamiento(
      numero: json['numero'] ?? 1,
      dias: (json['dias'] as List? ?? [])
          .map((e) => DiaEntrenamiento.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'numero': numero, 'dias': dias.map((e) => e.toJson()).toList()};
  }
}

class DiaEntrenamiento {
  String nombre;
  final List<ItemEntrenamiento> items;

  DiaEntrenamiento({required this.nombre, required this.items});

  DiaEntrenamiento copyWith({String? nombre, List<ItemEntrenamiento>? items}) {
    return DiaEntrenamiento(
      nombre: nombre ?? this.nombre,
      items: items ?? this.items,
    );
  }

  factory DiaEntrenamiento.fromJson(Map<String, dynamic> json) {
    return DiaEntrenamiento(
      nombre: json['nombre'] ?? 'Día',
      items: (json['items'] as List? ?? [])
          .map((e) => ItemEntrenamiento.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'nombre': nombre, 'items': items.map((e) => e.toJson()).toList()};
  }
}

class ItemEntrenamiento {
  final String? ejercicioId;
  final Ejercicio? ejercicio;
  final String? ejercicioNombre;
  final int orden;
  final String? grupoId;
  final EsquemaSerie? esquema;
  final String? urlVideo;

  // Stable key for UI reordering/focus
  final String? uniqueKey;

  ItemEntrenamiento({
    this.ejercicioId,
    this.ejercicio,
    this.ejercicioNombre,
    required this.orden,
    this.grupoId,
    this.esquema,
    this.urlVideo,
    this.uniqueKey,
  });

  ItemEntrenamiento copyWith({
    String? ejercicioId,
    Ejercicio? ejercicio,
    String? ejercicioNombre,
    int? orden,
    String? grupoId,
    EsquemaSerie? esquema,
    String? urlVideo,
    String? uniqueKey,
  }) {
    return ItemEntrenamiento(
      ejercicioId: ejercicioId ?? this.ejercicioId,
      ejercicio: ejercicio ?? this.ejercicio,
      ejercicioNombre: ejercicioNombre ?? this.ejercicioNombre,
      orden: orden ?? this.orden,
      grupoId: grupoId ?? this.grupoId,
      esquema: esquema ?? this.esquema,
      urlVideo: urlVideo ?? this.urlVideo,
      uniqueKey: uniqueKey ?? this.uniqueKey,
    );
  }

  factory ItemEntrenamiento.fromJson(Map<String, dynamic> json) {
    String? eId;
    Ejercicio? eObj;
    String? eName;

    if (json['ejercicio'] is String) {
      eId = json['ejercicio'];
    } else if (json['ejercicio'] is Map<String, dynamic>) {
      eObj = Ejercicio.fromJson(json['ejercicio']);
      eId = eObj.id;
      eName = eObj.nombre;
    }

    if (json['ejercicioNombre'] != null) {
      eName = json['ejercicioNombre'];
    }

    return ItemEntrenamiento(
      ejercicioId: eId,
      ejercicio: eObj,
      ejercicioNombre: eName,
      orden: json['orden'] ?? 0,
      grupoId: json['grupoId'],
      esquema: json['esquema'] != null
          ? EsquemaSerie.fromJson(json['esquema'])
          : null,
      urlVideo: json['urlVideo'],
      uniqueKey:
          DateTime.now().microsecondsSinceEpoch.toString() +
          '_' +
          (eId ?? 'none'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ejercicio': ejercicioId,
      'orden': orden,
      'grupoId': grupoId,
      'esquema': esquema?.toJson(),
    };
  }
}

class EsquemaSerie {
  final int series;
  final int? repsMin;
  final int? repsMax;
  final num? rir;
  final int? descanso;
  final String? notas;

  EsquemaSerie({
    this.series = 3,
    this.repsMin,
    this.repsMax,
    this.rir,
    this.descanso,
    this.notas,
  });

  EsquemaSerie copyWith({
    int? series,
    int? repsMin,
    int? repsMax,
    num? rir,
    int? descanso,
    String? notas,
  }) {
    return EsquemaSerie(
      series: series ?? this.series,
      repsMin: repsMin ?? this.repsMin,
      repsMax: repsMax ?? this.repsMax,
      rir: rir ?? this.rir,
      descanso: descanso ?? this.descanso,
      notas: notas ?? this.notas,
    );
  }

  factory EsquemaSerie.fromJson(Map<String, dynamic> json) {
    return EsquemaSerie(
      series: json['series'] != null
          ? int.tryParse(json['series'].toString()) ?? 3
          : 3,
      repsMin: json['repsMin'] != null
          ? int.tryParse(json['repsMin'].toString())
          : null,
      repsMax: json['repsMax'] != null
          ? int.tryParse(json['repsMax'].toString())
          : null,
      rir: json['rir'] != null ? num.tryParse(json['rir'].toString()) : null,
      descanso: json['descanso'] != null
          ? int.tryParse(json['descanso'].toString())
          : null,
      notas: json['notas'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'series': series,
      'repsMin': repsMin,
      'repsMax': repsMax,
      'rir': rir,
      'descanso': descanso,
      'notas': notas,
    };
  }
}
