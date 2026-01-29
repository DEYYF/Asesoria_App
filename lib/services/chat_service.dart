import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/chat_models.dart';
import 'api_service.dart';
import 'auth_service.dart';

class ChatService {
  final ApiService _api;
  final AuthService _auth;
  IO.Socket? _socket;

  final _messageController = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get messages => _messageController.stream;

  final _messageDeletedController = StreamController<String>.broadcast();
  Stream<String> get messageDeleted => _messageDeletedController.stream;

  final _unreadCountController = StreamController<int>.broadcast();
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  int _unreadCount = 0;
  String? _activeConversationId;

  ChatService(this._api, this._auth);

  void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId;
  }

  void connect() {
    if (_socket != null && _socket!.connected) return;

    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:4000';

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': _auth.token})
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      print('Connected to Chat Socket');
      loadUnreadCount(); // Refresh count on reconnect
    });
    _socket!.onDisconnect((_) => print('Disconnected from Chat Socket'));

    _socket!.on('receiveMessage', (data) {
      if (_messageController.isClosed) return;

      final msg = ChatMessage.fromJson(data);
      _messageController.add(msg);

      // Increment unread count if message is not from me
      if (msg.senderId != _auth.userId) {
        if (_activeConversationId == msg.conversationId) {
          markAsRead(msg.conversationId);
        } else {
          _unreadCount++;
          if (!_unreadCountController.isClosed) {
            _unreadCountController.add(_unreadCount);
          }
        }
      }
    });

    _socket!.on('messageDeleted', (data) {
      if (_messageDeletedController.isClosed) return;
      final messageId = data['messageId'];
      if (messageId != null) {
        _messageDeletedController.add(messageId);
      }
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  Future<void> loadUnreadCount() async {
    print('Loading unread count...');
    try {
      final res = await _api.get('/chat/unread-count');
      print('Unread count response status: ${res.statusCode}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _unreadCount = data['count'] ?? 0;
        print('Unread count loaded: $_unreadCount');
        if (!_unreadCountController.isClosed) {
          _unreadCountController.add(_unreadCount);
        }
      } else {
        print('Unread count failed body: ${res.body}');
      }
    } catch (e) {
      print('Failed to load unread count: $e');
    }
  }

  Future<List<Conversation>> getConversations() async {
    final res = await _api.get('/chat/conversations');
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.map((json) => Conversation.fromJson(json)).toList();
    }
    throw Exception('Failed to load conversations');
  }

  Future<Conversation> getConversation(String conversationId) async {
    final res = await _api.get('/chat/conversations/$conversationId');
    if (res.statusCode == 200) {
      return Conversation.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load conversation');
  }

  Future<Map<String, dynamic>> getContacts() async {
    final res = await _api.get('/chat/contacts');
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load contacts');
  }

  Future<Conversation> findOrCreateConversation({
    required String type,
    required String asesorId,
    String? clienteId,
    String? recipientAsesorId,
  }) async {
    final res = await _api.post('/chat/conversations', {
      'type': type,
      'asesorId': asesorId,
      'clienteId': clienteId,
      'recipientAsesorId': recipientAsesorId,
    });

    if (res.statusCode == 200 || res.statusCode == 201) {
      return Conversation.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to find or create conversation');
  }

  Future<List<ChatMessage>> getMessageHistory(String conversationId) async {
    final res = await _api.get('/chat/messages/$conversationId');
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.map((json) => ChatMessage.fromJson(json)).toList();
    }
    throw Exception('Failed to load message history');
  }

  void sendMessage(String conversationId, String text) {
    print(
      'Attempting to send message. Socket exists: ${_socket != null}, Connected: ${_socket?.connected}',
    );
    if (_socket == null || !_socket!.connected) {
      print('Socket not connected. Cannot send message.');
      return;
    }
    _socket!.emit('sendMessage', {
      'conversationId': conversationId,
      'text': text,
    });
    print('Message emitted to socket');
  }

  Future<void> markAsRead(String conversationId) async {
    await _api.put('/chat/conversations/$conversationId/read', {});
    loadUnreadCount(); // Refresh total count
  }

  Future<String?> getOrCreateConversation(String clienteId) async {
    try {
      final res = await _api.post('/chat/conversations', {
        'participantId': clienteId,
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return data['_id'];
      }
    } catch (e) {
      print('Error getting conversation: $e');
    }
    return null;
  }

  Future<void> deleteMessage(String messageId) async {
    final res = await _api.delete('/chat/messages/$messageId');
    if (res.statusCode != 200) {
      throw Exception('Failed to delete message');
    }
  }

  void dispose() {
    _messageController.close();
    _unreadCountController.close();
    _messageDeletedController.close();
    disconnect();
  }
}
