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
          'Mensajes',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: -1,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              // TODO: Implement search
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
          ? _buildEmptyState(theme)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _conversations.length,
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
    final isDark = theme.brightness == Brightness.dark;

    // Safety check for lastMessage
    final lastMsg = conv.lastMessage ?? 'Sin mensajes aún';
    final isLastMessage = conv.lastMessage != null;

    final dateStr = isLastMessage ? _formatDate(conv.lastMessageAt) : '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasUnread
              ? theme.primaryColor.withOpacity(0.3)
              : (isDark ? Colors.white10 : Colors.grey.shade100),
          width: 1.5,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(hasUnread ? 0.05 : 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Stack(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: hasUnread
                    ? Border.all(color: theme.primaryColor, width: 2)
                    : null,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            if (hasUnread)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.scaffoldBackgroundColor,
                      width: 2,
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
                  fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 16,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
            if (dateStr.isNotEmpty)
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 11,
                  color: hasUnread
                      ? theme.primaryColor
                      : theme.hintColor.withOpacity(0.5),
                  fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              if (conv.type == 'advisor-advisor')
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'ASESOR',
                    style: TextStyle(
                      fontSize: 8,
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  lastMsg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: hasUnread
                        ? theme.textTheme.bodyLarge?.color?.withOpacity(0.8)
                        : theme.hintColor,
                    fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              if (hasUnread)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ),
        onTap: () async {
          await context.push('/chat/${conv.id}');
          _loadConversations();
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return DateFormat('HH:mm').format(date);
    }
    if (date.day == now.day - 1 &&
        date.month == now.month &&
        date.year == now.year) {
      return 'Ayer';
    }
    return DateFormat('dd/MM/yy').format(date);
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
