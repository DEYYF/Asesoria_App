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
  final String? tiempoTarifa; // Added
  final List<dynamic>? extras; // Added, list of Strings or Objects
  final int? sesionesCounter;
  final String? sesionesLastMonth;
  final String? sexo; // Added
  final double? altura; // Added
  final List<dynamic>? historialProgreso; // Added missing field
  String? estado; // Added (Mutable for optimistic updates)
  final String? avatarUrl; // Added
  final List<String>? objetivos; // Added

  Cliente({
    required this.id,
    required this.nombre,
    required this.email,
    this.telefono,
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
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['_id'] ?? '',
      nombre: json['nombre'] ?? '',
      email: json['email'] ?? '',
      telefono: json['telefono'],
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'nombre': nombre,
      'email': email,
      'telefono': telefono,
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
    };
  }

  Cliente copyWith({
    String? id,
    String? nombre,
    String? email,
    String? telefono,
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
  }) {
    return Cliente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
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
    );
  }
}
