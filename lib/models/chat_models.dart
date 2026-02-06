class Conversation {
  final String id;
  final String type; // 'advisor-client' | 'advisor-advisor'
  final String asesorId;
  final String? clienteId;
  final String? recipientAsesorId;
  final String? asesorNombre;
  final String? clienteNombre;
  final String? recipientAsesorNombre;
  final DateTime lastMessageAt;
  final String? lastMessage;
  final Map<String, dynamic> unreadCounts;

  int getUnreadCount(String userId) {
    if (unreadCounts.containsKey(userId)) {
      return unreadCounts[userId] as int;
    }
    return 0;
  }

  String getDisplayName(String currentUserId) {
    if (type == 'advisor-advisor') {
      return (asesorId == currentUserId)
          ? (recipientAsesorNombre ?? 'Colega')
          : (asesorNombre ?? 'Colega');
    }
    return (asesorId == currentUserId)
        ? (clienteNombre ?? 'Cliente')
        : (asesorNombre ?? 'Asesor');
  }

  String getDisplayInitial(String currentUserId) {
    final name = getDisplayName(currentUserId);
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Conversation({
    required this.id,
    required this.type,
    required this.asesorId,
    this.clienteId,
    this.recipientAsesorId,
    this.asesorNombre,
    this.clienteNombre,
    this.recipientAsesorNombre,
    required this.lastMessageAt,
    this.lastMessage,
    this.unreadCounts = const {},
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['_id'],
      type: json['type'] ?? 'advisor-client',
      asesorId: json['asesorId'] is Map
          ? json['asesorId']['_id']
          : json['asesorId'],
      clienteId: json['clienteId'] != null
          ? (json['clienteId'] is Map
                ? json['clienteId']['_id']
                : json['clienteId'])
          : null,
      recipientAsesorId: json['recipientAsesorId'] != null
          ? (json['recipientAsesorId'] is Map
                ? json['recipientAsesorId']['_id']
                : json['recipientAsesorId'])
          : null,
      asesorNombre: json['asesorId'] is Map ? json['asesorId']['nombre'] : null,
      clienteNombre: json['clienteId'] is Map
          ? json['clienteId']['nombre']
          : null,
      recipientAsesorNombre: json['recipientAsesorId'] is Map
          ? json['recipientAsesorId']['nombre']
          : null,
      lastMessageAt: DateTime.parse(json['lastMessageAt']),
      lastMessage: json['lastMessage'],
      unreadCounts: json['unreadCounts'] ?? {},
    );
  }
}

class ChatButton {
  final String text;
  final String action;
  final Map<String, dynamic>? payload;

  ChatButton({required this.text, required this.action, this.payload});

  factory ChatButton.fromJson(Map<String, dynamic> json) {
    return ChatButton(
      text: json['text'],
      action: json['action'],
      payload: json['payload'],
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'action': action,
    'payload': payload,
  };
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderType; // 'ASESOR' | 'CLIENTE'
  final String senderId;
  final String text;
  final List<ChatButton> buttons;
  final DateTime createdAt;
  final String? audioUrl;
  final String? transcription;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderType,
    required this.senderId,
    required this.text,
    this.buttons = const [],
    required this.createdAt,
    this.audioUrl,
    this.transcription,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['_id'],
      conversationId: json['conversationId'],
      senderType: json['senderType'],
      senderId: json['senderId'],
      text: json['text'],
      buttons:
          (json['buttons'] as List?)
              ?.map((b) => ChatButton.fromJson(b))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt']),
      audioUrl: json['audioUrl'],
      transcription: json['transcription'],
    );
  }

  Map<String, dynamic> toJson() => {
    'conversationId': conversationId,
    'text': text,
    'buttons': buttons.map((b) => b.toJson()).toList(),
    if (audioUrl != null) 'audioUrl': audioUrl,
    if (transcription != null) 'transcription': transcription,
  };
}
