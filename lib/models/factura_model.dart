class FacturaItem {
  final String descripcion;
  final int cantidad;
  final double precioUnitario;
  final double iva;
  final double descuento;
  final double total;

  FacturaItem({
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
    required this.iva,
    this.descuento = 0,
    required this.total,
  });

  factory FacturaItem.fromJson(Map<String, dynamic> json) {
    return FacturaItem(
      descripcion: json['descripcion'] ?? '',
      cantidad: json['cantidad'] ?? 1,
      precioUnitario: (json['precioUnitario'] ?? 0).toDouble(),
      iva: (json['iva'] ?? 21).toDouble(),
      descuento: (json['descuento'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'descripcion': descripcion,
      'cantidad': cantidad,
      'precioUnitario': precioUnitario,
      'iva': iva,
      'descuento': descuento,
      'total': total,
    };
  }
}

class DatosFacturacion {
  final String nombre;
  final String nif;
  final String direccion;
  final String codigoPostal;
  final String ciudad;
  final String? provincia;
  final String? telefono;
  final String? email;

  DatosFacturacion({
    required this.nombre,
    required this.nif,
    required this.direccion,
    required this.codigoPostal,
    required this.ciudad,
    this.provincia,
    this.telefono,
    this.email,
  });

  factory DatosFacturacion.fromJson(Map<String, dynamic> json) {
    return DatosFacturacion(
      nombre: json['nombre'] ?? '',
      nif: json['nif'] ?? '',
      direccion: json['direccion'] ?? '',
      codigoPostal: json['codigoPostal'] ?? '',
      ciudad: json['ciudad'] ?? '',
      provincia: json['provincia'],
      telefono: json['telefono'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'nif': nif,
      'direccion': direccion,
      'codigoPostal': codigoPostal,
      'ciudad': ciudad,
      if (provincia != null) 'provincia': provincia,
      if (telefono != null) 'telefono': telefono,
      if (email != null) 'email': email,
    };
  }
}

class Factura {
  final String id;
  final String numeroFactura;
  final String serie;
  final String asesorId;
  final String clienteId;
  final DateTime fecha;
  final DateTime vencimiento;
  final String concepto;
  final List<FacturaItem> items;
  final double subtotal;
  final double totalIVA;
  final double descuentoGlobal;
  final double total;
  final String estado; // 'pendiente', 'pagada', 'vencida', 'cancelada'
  final String metodoPago;
  final DateTime? fechaPago;
  final String? notas;
  final String? pdfUrl;
  final String? presupuestoId;
  final DatosFacturacion datosEmisor;
  final DatosFacturacion datosReceptor;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Datos poblados del cliente (opcional)
  final String? clienteNombre;
  final String? clienteEmail;

  Factura({
    required this.id,
    required this.numeroFactura,
    required this.serie,
    required this.asesorId,
    required this.clienteId,
    required this.fecha,
    required this.vencimiento,
    required this.concepto,
    required this.items,
    required this.subtotal,
    required this.totalIVA,
    required this.descuentoGlobal,
    required this.total,
    required this.estado,
    required this.metodoPago,
    this.fechaPago,
    this.notas,
    this.pdfUrl,
    this.presupuestoId,
    required this.datosEmisor,
    required this.datosReceptor,
    required this.createdAt,
    required this.updatedAt,
    this.clienteNombre,
    this.clienteEmail,
  });

  factory Factura.fromJson(Map<String, dynamic> json) {
    return Factura(
      id: json['_id'] ?? '',
      numeroFactura: json['numeroFactura'] ?? '',
      serie: json['serie'] ?? 'A',
      asesorId: json['asesorId'] is String
          ? json['asesorId']
          : json['asesorId']?['_id'] ?? '',
      clienteId: json['clienteId'] is String
          ? json['clienteId']
          : json['clienteId']?['_id'] ?? '',
      fecha: DateTime.parse(json['fecha']),
      vencimiento: DateTime.parse(json['vencimiento']),
      concepto: json['concepto'] ?? '',
      items:
          (json['items'] as List?)
              ?.map((item) => FacturaItem.fromJson(item))
              .toList() ??
          [],
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      totalIVA: (json['totalIVA'] ?? 0).toDouble(),
      descuentoGlobal: (json['descuentoGlobal'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      estado: json['estado'] ?? 'pendiente',
      metodoPago: json['metodoPago'] ?? 'transferencia',
      fechaPago: json['fechaPago'] != null
          ? DateTime.parse(json['fechaPago'])
          : null,
      presupuestoId: json['presupuestoId'],
      datosEmisor: DatosFacturacion.fromJson(json['datosEmisor'] ?? {}),
      datosReceptor: DatosFacturacion.fromJson(json['datosReceptor'] ?? {}),
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
      clienteNombre: json['clienteId'] is Map
          ? json['clienteId']['nombre']
          : null,
      clienteEmail: json['clienteId'] is Map
          ? json['clienteId']['email']
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clienteId': clienteId,
      'concepto': concepto,
      'items': items.map((item) => item.toJson()).toList(),
      'vencimiento': vencimiento.toIso8601String(),
      'metodoPago': metodoPago,
      if (notas != null) 'notas': notas,
      'serie': serie,
      'descuentoGlobal': descuentoGlobal,
      'presupuestoId': presupuestoId,
    };
  }

  bool get isVencida {
    return estado == 'pendiente' && DateTime.now().isAfter(vencimiento);
  }

  bool get isPagada => estado == 'pagada';
  bool get isPendiente => estado == 'pendiente';
  bool get isCancelada => estado == 'cancelada';

  int get diasVencimiento {
    if (isPagada || isCancelada) return 0;
    final diff = vencimiento.difference(DateTime.now());
    return diff.inDays;
  }
}
