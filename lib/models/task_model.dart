class Tarea {
  final String id;
  final String title;
  final String notes;
  final String status; // 'todo', 'doing', 'done', 'pending'
  final DateTime? dueAt;
  final String? clientId;
  final String? clientName;
  final String? assigneeId;
  final String origin;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdByName;
  final String? assigneeName;

  Tarea({
    required this.id,
    required this.title,
    this.notes = '',
    required this.status,
    this.dueAt,
    this.clientId,
    this.clientName,
    this.assigneeId,
    this.origin = 'manual',
    required this.createdAt,
    required this.updatedAt,
    this.createdByName,
    this.assigneeName,
  });

  factory Tarea.fromJson(Map<String, dynamic> json) {
    return Tarea(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      notes: json['notes'] ?? '',
      status: json['status'] ?? 'todo',
      dueAt: json['dueAt'] != null ? DateTime.parse(json['dueAt']) : null,
      clientId: json['clientId'] is Map
          ? json['clientId']['_id']
          : json['clientId'],
      clientName: json['clientName'],
      assigneeId: json['assigneeId'] is Map
          ? json['assigneeId']['_id']
          : json['assigneeId'],
      assigneeName: json['assigneeId'] is Map
          ? json['assigneeId']['nombre']
          : null,
      origin: json['origin'] ?? 'manual',
      createdByName: json['createdBy'] is Map
          ? json['createdBy']['nombre']
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'notes': notes,
      'status': status,
      if (dueAt != null) 'dueAt': dueAt!.toIso8601String(),
      if (clientId != null) 'clientId': clientId,
      if (clientName != null) 'clientName': clientName,
      if (assigneeId != null) 'assigneeId': assigneeId,
      'origin': origin,
    };
  }

  Tarea copyWith({
    String? title,
    String? notes,
    String? status,
    DateTime? dueAt,
    String? clientId,
    String? clientName,
    String? assigneeId,
  }) {
    return Tarea(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      dueAt: dueAt ?? this.dueAt,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      assigneeId: assigneeId ?? this.assigneeId,
      origin: origin,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
