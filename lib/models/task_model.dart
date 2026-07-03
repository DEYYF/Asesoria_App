class SubTask {
  final String title;
  final bool isCompleted;

  SubTask({required this.title, this.isCompleted = false});

  factory SubTask.fromJson(Map<String, dynamic> json) => SubTask(
    title: json['title'] ?? '',
    isCompleted: json['isCompleted'] ?? false,
  );

  Map<String, dynamic> toJson() => {'title': title, 'isCompleted': isCompleted};

  SubTask copyWith({String? title, bool? isCompleted}) {
    return SubTask(
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class TaskTag {
  final String label;
  final String color;

  const TaskTag({required this.label, this.color = 'blue'});

  factory TaskTag.fromJson(Map<String, dynamic> json) =>
      TaskTag(label: json['label'] ?? '', color: json['color'] ?? 'blue');

  Map<String, dynamic> toJson() => {'label': label, 'color': color};
}


class TaskComment {
  final String text;
  final String authorName;
  final DateTime createdAt;

  TaskComment({
    required this.text,
    this.authorName = 'Usuario',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TaskComment.fromJson(Map<String, dynamic> json) => TaskComment(
    text: json['text'] ?? '',
    authorName: json['authorName'] ?? json['author'] ?? 'Usuario',
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'authorName': authorName,
    'createdAt': createdAt.toIso8601String(),
  };
}

class TaskAttachment {
  final String name;
  final String url;
  final String type;

  TaskAttachment({required this.name, required this.url, this.type = 'link'});

  factory TaskAttachment.fromJson(Map<String, dynamic> json) => TaskAttachment(
    name: json['name'] ?? json['nombre'] ?? 'Adjunto',
    url: json['url'] ?? '',
    type: json['type'] ?? 'link',
  );

  Map<String, dynamic> toJson() => {'name': name, 'url': url, 'type': type};
}

class Tarea {
  final String id;
  final String title;
  final String notes;
  final String status; // 'todo', 'doing', 'done', 'pending'
  final String priority; // 'low', 'medium', 'high', 'urgent'
  final DateTime? dueAt;
  final String? clientId;
  final String? clientName;
  final String? assigneeId;
  final String origin;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime statusChangedAt;
  final String? createdByName;
  final String? assigneeName;
  final List<SubTask> subtasks;
  final List<TaskTag> tags;
  final List<TaskAttachment> attachments;
  final List<TaskComment> comments;

  Tarea({
    required this.id,
    required this.title,
    this.notes = '',
    required this.status,
    this.priority = 'medium',
    this.dueAt,
    this.clientId,
    this.clientName,
    this.assigneeId,
    this.origin = 'manual',
    required this.createdAt,
    required this.updatedAt,
    required this.statusChangedAt,
    this.createdByName,
    this.assigneeName,
    this.subtasks = const [],
    this.tags = const [],
    this.attachments = const [],
    this.comments = const [],
  });

  factory Tarea.fromJson(Map<String, dynamic> json) {
    return Tarea(
      id: json['_id'] ?? '',
      title: json['title'] ?? '',
      notes: json['notes'] ?? '',
      status: json['status'] ?? 'todo',
      priority: json['priority'] ?? 'medium',
      dueAt: json['dueAt'] != null ? DateTime.parse(json['dueAt']) : null,
      statusChangedAt: json['statusChangedAt'] != null
          ? DateTime.parse(json['statusChangedAt'])
          : (json['createdAt'] != null
                ? DateTime.parse(json['createdAt'])
                : DateTime.now()),
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
      subtasks:
          (json['subtasks'] as List?)
              ?.map((e) => SubTask.fromJson(e))
              .toList() ??
          [],
      tags:
          (json['tags'] as List?)?.map((e) => TaskTag.fromJson(e)).toList() ??
          [],
      attachments:
          (json['attachments'] as List?)
              ?.map((e) => TaskAttachment.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      comments:
          (json['comments'] as List?)
              ?.map((e) => TaskComment.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'notes': notes,
      'status': status,
      'priority': priority,
      if (dueAt != null) 'dueAt': dueAt!.toIso8601String(),
      if (clientId != null) 'clientId': clientId,
      if (clientName != null) 'clientName': clientName,
      if (assigneeId != null) 'assigneeId': assigneeId,
      'origin': origin,
      'subtasks': subtasks.map((e) => e.toJson()).toList(),
      'tags': tags.map((e) => e.toJson()).toList(),
      'attachments': attachments.map((e) => e.toJson()).toList(),
      'comments': comments.map((e) => e.toJson()).toList(),
      'statusChangedAt': statusChangedAt.toIso8601String(),
    };
  }

  Tarea copyWith({
    String? title,
    String? notes,
    String? status,
    String? priority,
    DateTime? dueAt,
    DateTime? statusChangedAt,
    String? clientId,
    String? clientName,
    String? assigneeId,
    List<SubTask>? subtasks,
    List<TaskTag>? tags,
    List<TaskAttachment>? attachments,
    List<TaskComment>? comments,
  }) {
    return Tarea(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueAt: dueAt ?? this.dueAt,
      statusChangedAt: statusChangedAt ?? this.statusChangedAt,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      assigneeId: assigneeId ?? this.assigneeId,
      origin: origin,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      subtasks: subtasks ?? this.subtasks,
      tags: tags ?? this.tags,
      attachments: attachments ?? this.attachments,
      comments: comments ?? this.comments,
    );
  }
}
