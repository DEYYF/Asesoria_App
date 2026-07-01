class MessageTemplate {
  final String id;
  final String title;
  final String type; // 'email', 'chat', 'both'
  final String? subject;
  final String content;
  final List<String> categories;

  MessageTemplate({
    required this.id,
    required this.title,
    required this.type,
    this.subject,
    required this.content,
    this.categories = const ['General'],
  });

  static String normalizeType(dynamic value) {
    final raw = (value ?? '').toString().trim().toLowerCase();

    if (raw == 'email' ||
        raw == 'correo' ||
        raw == 'mail' ||
        raw == 'e-mail') {
      return 'email';
    }

    if (raw == 'chat' ||
        raw == 'mensaje' ||
        raw == 'message' ||
        raw == 'mensajes' ||
        raw == 'whatsapp') {
      return 'chat';
    }

    if (raw == 'both' ||
        raw == 'ambos' ||
        raw == 'todo' ||
        raw == 'todos') {
      return 'both';
    }

    // Compatibilidad con plantillas antiguas sin tipo.
    return 'both';
  }

  bool supports(String requestedType) {
    final normalizedRequestedType = normalizeType(requestedType);
    return type == 'both' || type == normalizedRequestedType;
  }

  factory MessageTemplate.fromJson(Map<String, dynamic> json) {
    final dynamic rawCategories = json['categories'] ?? json['categorias'];

    List<String> parsedCategories;
    if (rawCategories is List) {
      parsedCategories = rawCategories
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (rawCategories is String && rawCategories.trim().isNotEmpty) {
      parsedCategories = [rawCategories.trim()];
    } else {
      parsedCategories = ['General'];
    }

    if (parsedCategories.isEmpty) parsedCategories = ['General'];

    return MessageTemplate(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? json['titulo'] ?? 'Plantilla sin título').toString(),
      type: normalizeType(json['type'] ?? json['tipo']),
      subject: json['subject'] ?? json['asunto'],
      content: (json['content'] ?? json['contenido'] ?? json['mensaje'] ?? '').toString(),
      categories: parsedCategories,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'type': normalizeType(type),
      'subject': subject,
      'content': content,
      'categories': categories.isEmpty ? ['General'] : categories,
    };
  }
}
