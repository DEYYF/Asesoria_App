class Ejercicio {
  final String id;
  final String nombre;
  final String? grupo;
  final String? equipo;
  final String? nivel; // 'principiante', 'intermedio', 'avanzado'
  final String? urlVideo;
  final String? instrucciones;

  Ejercicio({
    required this.id,
    required this.nombre,
    this.grupo,
    this.equipo,
    this.nivel,
    this.urlVideo,
    this.instrucciones,
  });

  factory Ejercicio.fromJson(Map<String, dynamic> json) {
    return Ejercicio(
      id: json['_id'] ?? '',
      nombre: json['nombre'] ?? 'Sin nombre',
      grupo: json['grupo'],
      equipo: json['equipo'],
      nivel: json['nivel'],
      urlVideo: json['urlVideo'],
      instrucciones: json['instrucciones'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'nombre': nombre,
      'grupo': grupo,
      'equipo': equipo,
      'nivel': nivel,
      'urlVideo': urlVideo,
      'instrucciones': instrucciones,
    };
  }
}
