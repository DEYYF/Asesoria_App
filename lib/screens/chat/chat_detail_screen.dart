import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../models/chat_models.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import 'package:intl/intl.dart';
import '../../models/template_model.dart';
import '../../widgets/dialogs/template_selector_dialog.dart';
import '../../widgets/dialogs/measurement_dialog.dart';
import '../../widgets/dialogs/habit_dialog.dart';
import '../../services/api_service.dart';
import '../../services/transcription_service.dart';
import 'components/voice_recorder_widget.dart';

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
  int? _unreadIndex;
  bool _hasScrolledToUnread = false;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _deleteSubscription;
  bool _showRecorder = false;
  void initState() {
    super.initState();
    _loadData();
    // Connect and listen to real-time messages
    final chatService = Provider.of<ChatService>(context, listen: false);
    chatService.connect();
    chatService.setActiveConversation(widget.conversationId);
    _messageSubscription = chatService.messages.listen(_handleNewMessage);
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

      // Mark as read AFTER unread detection in _loadHistory (managed there now)

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
      final auth = Provider.of<AuthService>(context, listen: false);
      final chatService = Provider.of<ChatService>(context, listen: false);

      // Load history
      final history = await chatService.getMessageHistory(
        widget.conversationId,
      );

      // Detect unread index
      int? unreadIdx;
      if (_conversation != null) {
        final count = _conversation!.getUnreadCount(auth.userId!);
        if (count > 0 && history.isNotEmpty) {
          // Unread messages are the last 'count' messages
          unreadIdx = history.length - count;
        }
      }

      setState(() {
        _messages = history;
        _unreadIndex = unreadIdx;
        _isLoading = false;
      });

      // Mark as read now that we captured the index
      chatService.markAsRead(widget.conversationId);

      _smartScroll();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _smartScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      if (_unreadIndex != null && !_hasScrolledToUnread) {
        // Calculate an approximate position for the unread marker
        // Each message is roughly 80-120px depending on content.
        // A simple max scroll will go to bottom anyway.
        // For a more precise scroll, we'd need ItemScrollController, but we can jump to bottom
        // and let them see the divider.
        // OR: If unreadIndex is near the end, bottom is fine.
        _scrollToBottom();
        _hasScrolledToUnread = true;
      } else {
        _scrollToBottom();
      }
    });
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

  Future<void> _sendVoiceNote(String audioPath) async {
    // 1. Ocultar grabador y mostrar carga (opcional)
    setState(() => _showRecorder = false);

    // 2. Transcribir (Subir al endpoint /transcribe)
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final transcriptionService = TranscriptionService(api);

      // Mostrar feedback visual
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transcribiendo y enviando...'),
          duration: Duration(seconds: 1),
        ),
      );

      final text = await transcriptionService.transcribe(audioPath);

      // 3. Enviar mensaje
      // Como /transcribe no guarda el audio persistentemente para el chat (solo temp para whisper),
      // y nuestro endpoint de chat no soporta audioFile aun,
      // enviaremos el texto transcrito como mensaje, y simularemos que es una nota de voz.
      // TODO: Implementar subida real de archivos al chat.

      final chatService = Provider.of<ChatService>(context, listen: false);

      // Enviamos el mensaje con metadata simulada
      // En una implementación real, enviariamos el URL del audio subido.
      // Aquí enviamos el texto y un flag o url ficticia si queremos probar la UI

      // HACK: Por ahora enviamos el texto transcrito.
      // Para probar la UI de audio, necesitaríamos subir el archivo a un bucket real.
      // Dado que el usuario pidió "Simulación", podemos enviar un mensaje con
      // transcription: text y audioUrl: 'placeholder'

      // PERO: El backend espera solo texto en sendMessage.
      // Necesitamos modificar el backend sendMessage para aceptar audioUrl/transcription
      // O usar un nuevo endpoint.

      // POR AHORA: Enviamos el texto transcrito directo.
      if (text.isNotEmpty) {
        chatService.sendMessage(
          widget.conversationId,
          text,
        ); // Se envía como texto normal
        // Opcional: Agregar prefijo "[Nota de Voz]: $text"
      }
    } catch (e) {
      debugPrint('Error sending voice note: $e');
      String errorMsg = 'Error al enviar nota de voz';
      if (e.toString().contains('429') ||
          e.toString().contains('QUOTA_EXCEEDED')) {
        errorMsg =
            'Límite de transcripción alcanzado. No se puede procesar el audio en este momento.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red.shade800),
      );
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _deleteSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    // Ensure active conversation is cleared when leaving the screen
    Provider.of<ChatService>(
      context,
      listen: false,
    ).setActiveConversation(null);
    super.dispose();
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
                          if (index == _unreadIndex) _buildUnreadMarker(theme),
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

  Widget _buildUnreadMarker(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Expanded(child: Divider(color: theme.primaryColor.withOpacity(0.3))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
            ),
            child: Text(
              'NUEVOS MENSAJES',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: theme.primaryColor,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(child: Divider(color: theme.primaryColor.withOpacity(0.3))),
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
              if (msg.audioUrl != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white.withOpacity(0.2)
                        : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.play_circle_fill_rounded,
                        color: isMe ? Colors.white : theme.primaryColor,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nota de voz',
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : theme.textTheme.bodyLarge?.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '0:00 / --:--', // Placeholder duration
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white.withOpacity(0.8)
                                    : theme.hintColor,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (msg.transcription != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.black.withOpacity(0.1)
                          : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.subtitles_rounded,
                              size: 12,
                              color: isMe
                                  ? Colors.white.withOpacity(0.7)
                                  : theme.hintColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'TRANSCRIPCIÓN',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isMe
                                    ? Colors.white.withOpacity(0.7)
                                    : theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg.transcription!,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            color: isMe
                                ? Colors.white.withOpacity(0.95)
                                : theme.textTheme.bodyLarge?.color,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              if (msg.buttons.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: msg.buttons.map((button) {
                    return OutlinedButton(
                      onPressed: () => _handleButtonTap(msg, button),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isMe
                            ? Colors.white
                            : theme.primaryColor,
                        side: BorderSide(
                          color: isMe ? Colors.white70 : theme.primaryColor,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: isMe ? Colors.white12 : null,
                      ),
                      child: Text(
                        button.text,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleButtonTap(ChatMessage message, ChatButton button) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    String? clientId;
    if (auth.isClient) {
      clientId = auth.userId;
    } else if (_conversation != null) {
      clientId = _conversation!.clienteId;
    }

    switch (button.action) {
      case 'OPEN_MEASUREMENTS_DIALOG':
        if (clientId != null) {
          final String id = clientId;
          await showDialog(
            context: context,
            builder: (ctx) => MeasurementDialog(clientId: id),
          );
        }
        break;

      case 'OPEN_HABITS_DIALOG':
        if (clientId != null) {
          final String id = clientId;
          await showDialog(
            context: context,
            builder: (ctx) => HabitDialog(clientId: id),
          );
        }
        break;

      case 'NAVIGATE_TO_DIET':
        if (!widget.isEmbedded && mounted) {
          Navigator.of(context).pushNamed('/diet');
        }
        break;

      case 'NAVIGATE_TO_WORKOUT':
        if (!widget.isEmbedded && mounted) {
          Navigator.of(context).pushNamed('/workout');
        }
        break;

      case 'SHOW_INFO':
        final infoText = button.payload?['message'] ?? 'Información';
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.blue),
                SizedBox(width: 8),
                Text('Información'),
              ],
            ),
            content: Text(infoText),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
        break;

      default:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Acción: ${button.action}')));
    }
  }

  Widget _buildInputArea(ThemeData theme) {
    if (_showRecorder) {
      return VoiceRecorderWidget(
        onSend: (path) => _sendVoiceNote(path),
        onCancel: () => setState(() => _showRecorder = false),
      );
    }

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
                  onTap: hasText
                      ? _sendMessage
                      : () => setState(() => _showRecorder = true),
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
                    child: Icon(
                      hasText ? Icons.send_rounded : Icons.mic_rounded,
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
}
