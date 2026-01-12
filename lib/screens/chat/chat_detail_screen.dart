import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
    // Connect and listen to real-time messages
    final chatService = Provider.of<ChatService>(context, listen: false);
    chatService.connect();
    chatService.setActiveConversation(widget.conversationId);
    chatService.messages.listen(_handleNewMessage);
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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: widget.isEmbedded ? false : !auth.isClient,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _conversation?.getDisplayName(auth.userId!) ?? 'Chat',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (_conversation?.type == 'advisor-advisor')
              Text(
                'Conversación con Asesor',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.isEmbedded
            ? null
            : (!auth.isClient
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => Navigator.pop(context),
                    )
                  : null),
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

                      return Column(
                        children: [
                          if (showDate)
                            _buildDateSeparator(msg.createdAt, theme),
                          _buildMessageBubble(msg, isMe, theme),
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
      label = DateFormat('dd MMMM yyyy', 'es').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.dividerColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: theme.hintColor,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe, ThemeData theme) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? theme.primaryColor
              : (theme.brightness == Brightness.dark
                    ? const Color(0xFF2C2C2E)
                    : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                color: isMe ? Colors.white : theme.textTheme.bodyLarge?.color,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('HH:mm').format(msg.createdAt),
              style: TextStyle(
                color: isMe ? Colors.white.withOpacity(0.7) : theme.hintColor,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        12,
        12,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.description_outlined, color: theme.primaryColor),
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
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                maxLines: 4,
                minLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    Provider.of<ChatService>(
      context,
      listen: false,
    ).setActiveConversation(null);
    super.dispose();
  }
}
