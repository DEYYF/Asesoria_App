import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import 'package:intl/intl.dart';
import '../../models/template_model.dart';
import '../../widgets/dialogs/template_selector_dialog.dart';

class ChatDetailScreen extends StatefulWidget {
  final String conversationId;
  final bool isEmbedded;
  const ChatDetailScreen({
    super.key,
    required this.conversationId,
    this.isEmbedded = false,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  Conversation? _conversation;
  bool _isLoading = true;

  StreamSubscription? _deleteSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Connect and listen to real-time messages
    final chatService = Provider.of<ChatService>(context, listen: false);
    chatService.connect();
    chatService.setActiveConversation(widget.conversationId);
    chatService.messages.listen(_handleNewMessage);
    _deleteSubscription = chatService.messageDeleted.listen(
      _handleMessageDeleted,
    );
  }

  void _handleMessageDeleted(String messageId) {
    setState(() {
      _messages.removeWhere((msg) => msg.id == messageId);
      // If we removed the last message, we might want to update conversation preview,
      // but that's handled by generic load or socket event elsewhere.
      // For this screen, removing from list is enough.
    });
  }

  Future<void> _showDeleteDialog(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar mensaje'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar este mensaje?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await Provider.of<ChatService>(
          context,
          listen: false,
        ).deleteMessage(messageId);
        // The socket event will trigger the removal from UI,
        // but we can also do it optimistically if we trust the API call success
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
        }
      }
    }
  }

  Future<void> _loadData() async {
    await Future.wait([_loadHistory(), _loadConversationDetails()]);
  }

  Future<void> _loadConversationDetails() async {
    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      final conv = await chatService.getConversation(widget.conversationId);

      // Mark as read immediately
      chatService.markAsRead(widget.conversationId);

      setState(() {
        _conversation = conv;
      });
    } catch (e) {
      debugPrint('Error loading conversation details: $e');
    }
  }

  void _handleNewMessage(ChatMessage msg) {
    if (msg.conversationId == widget.conversationId) {
      setState(() {
        _messages.add(msg);
      });
      _scrollToBottom();
    }
  }

  Future<void> _loadHistory() async {
    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      final history = await chatService.getMessageHistory(
        widget.conversationId,
      );
      setState(() {
        _messages = history;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final chatService = Provider.of<ChatService>(context, listen: false);
    chatService.sendMessage(widget.conversationId, text);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.8),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withOpacity(0.05),
                width: 1,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            if (!widget.isEmbedded && !auth.isClient)
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            if (!widget.isEmbedded && !auth.isClient) const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: theme.primaryColor.withOpacity(0.1),
                child: Text(
                  _conversation?.getDisplayInitial(auth.userId!) ?? '?',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _conversation?.getDisplayName(auth.userId!) ?? 'Chat',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    _conversation?.type == 'advisor-advisor'
                        ? 'Colega Asesor'
                        : 'Cliente',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.hintColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              // Show conversation info or user profile
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.senderId == auth.userId;

                      // Check if we should show date header
                      bool showDate = false;
                      if (index == 0) {
                        showDate = true;
                      } else {
                        final prevMsg = _messages[index - 1];
                        if (msg.createdAt.day != prevMsg.createdAt.day ||
                            msg.createdAt.month != prevMsg.createdAt.month ||
                            msg.createdAt.year != prevMsg.createdAt.year) {
                          showDate = true;
                        }
                      }

                      // Simple grouping: check if next message is from same sender
                      bool isLastInGroup = true;
                      if (index < _messages.length - 1) {
                        final nextMsg = _messages[index + 1];
                        if (nextMsg.senderId == msg.senderId) {
                          isLastInGroup = false;
                        }
                      }

                      return Column(
                        children: [
                          if (showDate)
                            _buildDateSeparator(msg.createdAt, theme),
                          _buildMessageBubble(msg, isMe, theme, isLastInGroup),
                        ],
                      );
                    },
                  ),
          ),
          _buildInputArea(theme),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date, ThemeData theme) {
    final now = DateTime.now();
    String label;
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      label = 'Hoy';
    } else if (date.day == now.day - 1 &&
        date.month == now.month &&
        date.year == now.year) {
      label = 'Ayer';
    } else {
      label = DateFormat('dd MMMM', 'es').format(date).toUpperCase();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: theme.dividerColor.withOpacity(0.05),
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: theme.hintColor.withOpacity(0.5),
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: theme.dividerColor.withOpacity(0.05),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessage msg,
    bool isMe,
    ThemeData theme,
    bool isLastInGroup,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          if (isMe) {
            _showDeleteDialog(msg.id);
          }
        },
        child: Container(
          margin: EdgeInsets.only(bottom: isLastInGroup ? 16 : 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            gradient: isMe
                ? LinearGradient(
                    colors: [
                      theme.primaryColor,
                      theme.primaryColor.withBlue(
                        (theme.primaryColor.blue + 30).clamp(0, 255),
                      ),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isMe
                ? null
                : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7)),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(isMe ? 22 : (isLastInGroup ? 6 : 22)),
              bottomRight: Radius.circular(
                isMe ? (isLastInGroup ? 6 : 22) : 22,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isMe ? 0.08 : 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                msg.text,
                style: TextStyle(
                  color: isMe ? Colors.white : theme.textTheme.bodyLarge?.color,
                  fontSize: 15,
                  height: 1.4,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(msg.createdAt),
                    style: TextStyle(
                      color: isMe
                          ? Colors.white.withOpacity(0.6)
                          : theme.hintColor.withOpacity(0.6),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.done_all_rounded,
                      size: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.add_rounded, color: theme.primaryColor),
              onPressed: () {
                // Show more options (attach, etc)
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.description_outlined, color: theme.hintColor),
            tooltip: 'Usar Plantilla',
            onPressed: () async {
              final template = await showDialog<MessageTemplate>(
                context: context,
                builder: (_) => const TemplateSelectorDialog(type: 'chat'),
              );
              if (template != null) {
                _messageController.text = template.content;
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  width: 1.5,
                ),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Tu mensaje...',
                  hintStyle: TextStyle(
                    color: theme.hintColor.withOpacity(0.4),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                maxLines: 5,
                minLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _messageController,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty;
              return AnimatedScale(
                scale: hasText ? 1.0 : 0.9,
                duration: const Duration(milliseconds: 200),
                child: GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hasText
                          ? theme.primaryColor
                          : theme.primaryColor.withOpacity(0.3),
                      shape: BoxShape.circle,
                      boxShadow: hasText
                          ? [
                              BoxShadow(
                                color: theme.primaryColor.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _deleteSubscription?.cancel();
    Provider.of<ChatService>(
      context,
      listen: false,
    ).setActiveConversation(null);
    super.dispose();
  }
}
