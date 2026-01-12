class MessageTemplate {
  final String id;
  final String title;
  final String type; // 'email', 'chat'
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

  factory MessageTemplate.fromJson(Map<String, dynamic> json) {
    return MessageTemplate(
      id: json['_id'],
      title: json['title'],
      type: json['type'],
      subject: json['subject'],
      content: json['content'],
      categories: List<String>.from(json['categories'] ?? ['General']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'type': type,
      'subject': subject,
      'content': content,
      'categories': categories,
    };
  }
}
