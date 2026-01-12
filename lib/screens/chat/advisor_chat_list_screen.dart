import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import 'package:intl/intl.dart';

class AdvisorChatListScreen extends StatefulWidget {
  const AdvisorChatListScreen({super.key});

  @override
  State<AdvisorChatListScreen> createState() => _AdvisorChatListScreenState();
}

class _AdvisorChatListScreenState extends State<AdvisorChatListScreen> {
  bool _isLoading = true;
  List<Conversation> _conversations = [];

  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _setupMessageListener();
  }

  void _setupMessageListener() {
    final chatService = Provider.of<ChatService>(context, listen: false);
    chatService.connect(); // Ensure socket is connected
    _messageSubscription = chatService.messages.listen(_handleNewMessage);
  }

  void _handleNewMessage(ChatMessage msg) {
    setState(() {
      final index = _conversations.indexWhere(
        (c) => c.id == msg.conversationId,
      );
      if (index != -1) {
        final conv = _conversations.removeAt(index);
        final auth = Provider.of<AuthService>(context, listen: false);
        final isMe = msg.senderId == auth.userId;

        // Update fields
        final updatedConv = Conversation(
          id: conv.id,
          type: conv.type,
          asesorId: conv.asesorId,
          clienteId: conv.clienteId,
          recipientAsesorId: conv.recipientAsesorId,
          asesorNombre: conv.asesorNombre,
          clienteNombre: conv.clienteNombre,
          recipientAsesorNombre: conv.recipientAsesorNombre,
          lastMessageAt: msg.createdAt,
          lastMessage: msg.text,
          unreadCounts: Map.from(conv.unreadCounts),
        );

        // Increment unread if not sent by me
        if (!isMe && auth.userId != null) {
          final count = updatedConv.getUnreadCount(auth.userId!);
          updatedConv.unreadCounts[auth.userId!] = count + 1;
        }

        // Move to top
        _conversations.insert(0, updatedConv);
      } else {
        // New conversation? Reload to be safe
        _loadConversations();
      }
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      final list = await chatService.getConversations();
      if (mounted) {
        setState(() {
          _conversations = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis Mensajes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
          ? _buildEmptyState(theme)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _conversations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final conv = _conversations[index];
                return _buildConversationTile(conv, theme, auth.userId!);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/chat/new'),
        child: const Icon(Icons.add_comment_rounded),
      ),
    );
  }

  Widget _buildConversationTile(
    Conversation conv,
    ThemeData theme,
    String currentUserId,
  ) {
    final name = conv.getDisplayName(currentUserId);
    final initial = conv.getDisplayInitial(currentUserId);
    final unreadCount = conv.getUnreadCount(currentUserId);
    final hasUnread = unreadCount > 0;

    // Safety check for lastMessage
    final lastMsg = conv.lastMessage ?? 'Inicia una conversación';
    final isLastMessage = conv.lastMessage != null;

    final dateStr = isLastMessage
        ? DateFormat('dd MMM, HH:mm').format(conv.lastMessageAt)
        : '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasUnread
              ? theme.primaryColor.withOpacity(0.5)
              : theme.dividerColor.withOpacity(0.1),
          width: hasUnread ? 1.5 : 1,
        ),
      ),
      color: hasUnread ? theme.primaryColor.withOpacity(0.05) : theme.cardColor,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              child: Text(
                initial,
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (hasUnread)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (conv.type == 'advisor-advisor')
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Asesor',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                lastMsg,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: hasUnread
                      ? theme.textTheme.bodyLarge?.color
                      : theme.hintColor,
                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (dateStr.isNotEmpty)
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 10,
                  color: hasUnread ? theme.primaryColor : theme.hintColor,
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () async {
          await context.push('/chat/${conv.id}');
          _loadConversations(); // Refresh list to update unread counts
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 80,
            color: theme.hintColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Aún no tienes conversaciones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tus chats con clientes aparecerán aquí.',
            style: TextStyle(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}
