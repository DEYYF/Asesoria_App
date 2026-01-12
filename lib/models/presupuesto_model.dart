
class Presupuesto {
  final String id;
  final String clienteId;
  final List<ExtraItem> extras;
  final DateTime createdAt;

  Presupuesto({
    required this.id,
    required this.clienteId,
    required this.extras,
    required this.createdAt,
  });

  factory Presupuesto.fromJson(Map<String, dynamic> json) {
    String cId = '';
    if (json['clienteId'] is Map) {
      cId = json['clienteId']['_id'] ?? '';
    } else if (json['clienteId'] is String) {
      cId = json['clienteId'];
    }

    return Presupuesto(
      id: json['_id'] ?? '',
      clienteId: cId,
      extras: (json['extras'] as List? ?? [])
          .map((i) => ExtraItem.fromJson(i))
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}

class ExtraItem {
  final String extraId; // Just ID for now, or expand if populated
  final String? nombre;
  final double? precio;

  ExtraItem({required this.extraId, this.nombre, this.precio});

  factory ExtraItem.fromJson(Map<String, dynamic> json) {
    // Handle if extraId is populated object or just string
    if (json['extraId'] is Map) {
      final extraObj = json['extraId'];
      return ExtraItem(
        extraId: extraObj['_id'],
        nombre: extraObj['nombre'],
        precio: (extraObj['precio'] as num?)?.toDouble(),
      );
    } else {
      return ExtraItem(extraId: json['extraId'] ?? '');
    }
  }
}
