class Cliente {
  final String id;
  final String nombre;
  final String email;
  final String? telefono;
  final String? direccion;
  final String? ciudad;
  final String? provincia;
  final String? codigoPostal;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final String? tipoServicio;
  final String? tiempoTarifa;
  final DateTime? fechaNacimiento; // Added
  final List<dynamic>? extras;
  final int? sesionesCounter;
  final String? sesionesLastMonth;
  final String? sexo;
  final double? altura;
  final List<dynamic>? historialProgreso;
  final String? nif;
  String? estado;
  final String? avatarUrl;
  final List<String>? objetivos;
  final String? asesorId;
  final List<String>? etiquetas;
  final Map<String, dynamic>? gamification;

  Cliente({
    required this.id,
    required this.nombre,
    required this.email,
    this.telefono,
    this.fechaNacimiento,
    this.direccion,
    this.ciudad,
    this.provincia,
    this.codigoPostal,
    this.fechaInicio,
    this.fechaFin,
    this.tipoServicio,
    this.tiempoTarifa,
    this.extras,
    this.sesionesCounter,
    this.sesionesLastMonth,
    this.historialProgreso,
    this.sexo,
    this.altura,
    this.estado,
    this.avatarUrl,
    this.objetivos,
    this.asesorId,
    this.etiquetas,
    this.nif,
    this.gamification,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['_id'] ?? '',
      nombre: json['nombre'] ?? '',
      email: json['email'] ?? '',
      telefono: json['telefono'],
      fechaNacimiento: json['fechaNacimiento'] != null
          ? DateTime.parse(json['fechaNacimiento'])
          : null,
      direccion: json['direccion'],
      ciudad: json['ciudad'],
      provincia: json['provincia'],
      codigoPostal: json['codigoPostal'],
      fechaInicio: json['fechaInicio'] != null
          ? DateTime.parse(json['fechaInicio'])
          : null,
      fechaFin: json['fechaFin'] != null
          ? DateTime.parse(json['fechaFin'])
          : null,
      tipoServicio: json['tipoServicio'],
      tiempoTarifa: json['Tiempo_Tarifa'],
      extras: json['extras'] as List<dynamic>?,
      sesionesCounter: json['sesionesCounter'],
      sesionesLastMonth: json['sesionesLastMonth']?.toString(),
      historialProgreso: json['historialProgreso'] as List<dynamic>?,
      sexo: json['sexo'],
      altura: (json['altura'] as num?)?.toDouble(),
      estado: json['estado'] ?? 'Activo',
      avatarUrl: json['avatarUrl'],
      objetivos: (json['objetivos'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      asesorId: json['asesorId']?.toString(),
      etiquetas: (json['etiquetas'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      nif: json['nif'],
      gamification: json['gamification'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'nombre': nombre,
      'email': email,
      'telefono': telefono,
      'fechaNacimiento': fechaNacimiento?.toIso8601String(),
      'direccion': direccion,
      'ciudad': ciudad,
      'provincia': provincia,
      'codigoPostal': codigoPostal,
      'fechaInicio': fechaInicio?.toIso8601String(),
      'fechaFin': fechaFin?.toIso8601String(),
      'tipoServicio': tipoServicio,
      'Tiempo_Tarifa': tiempoTarifa,
      'extras': extras,
      'sesionesCounter': sesionesCounter,
      'sesionesLastMonth': sesionesLastMonth,
      'historialProgreso': historialProgreso,
      'asesorId': asesorId,
      'nif': nif,
      'etiquetas': etiquetas,
    };
  }

  Cliente copyWith({
    String? id,
    String? nombre,
    String? email,
    String? telefono,
    DateTime? fechaNacimiento,
    String? direccion,
    String? ciudad,
    String? provincia,
    String? codigoPostal,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? tipoServicio,
    String? tiempoTarifa,
    List<dynamic>? extras,
    int? sesionesCounter,
    String? sesionesLastMonth,
    List<dynamic>? historialProgreso,
    String? sexo,
    double? altura,
    String? estado,
    String? avatarUrl,
    List<String>? objetivos,
    List<String>? etiquetas,
    String? nif,
    Map<String, dynamic>? gamification,
  }) {
    return Cliente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      direccion: direccion ?? this.direccion,
      ciudad: ciudad ?? this.ciudad,
      provincia: provincia ?? this.provincia,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      tipoServicio: tipoServicio ?? this.tipoServicio,
      tiempoTarifa: tiempoTarifa ?? this.tiempoTarifa,
      extras: extras ?? this.extras,
      sesionesCounter: sesionesCounter ?? this.sesionesCounter,
      sesionesLastMonth: sesionesLastMonth ?? this.sesionesLastMonth,
      historialProgreso: historialProgreso ?? this.historialProgreso,
      sexo: sexo ?? this.sexo,
      altura: altura ?? this.altura,
      estado: estado ?? this.estado,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      objetivos: objetivos ?? this.objetivos,
      asesorId: asesorId ?? asesorId,
      etiquetas: etiquetas ?? this.etiquetas,
      nif: nif ?? this.nif,
      gamification: gamification ?? this.gamification,
    );
  }
}
