import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';

import '../../services/chat_service.dart';

class KanbanCard extends StatelessWidget {
  final Tarea task;
  final VoidCallback onTap;

  const KanbanCard({super.key, required this.task, required this.onTap});

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Colors.deepPurple;
      case 'high':
        return Colors.redAccent;
      case 'medium':
        return Colors.orangeAccent;
      case 'low':
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }

  bool _isOverdue(DateTime date) {
    final now = DateTime.now();
    return date.isBefore(DateTime(now.year, now.month, now.day));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final priorityColor = _getPriorityColor(task.priority);
    final isUrgent = task.priority.toLowerCase() == 'urgent';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          if (isUrgent)
            BoxShadow(
              color: priorityColor.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
        border: Border.all(
          color: isUrgent
              ? priorityColor.withOpacity(0.5)
              : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade100),
          width: isUrgent ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Client and Status/Time
                  Row(
                    children: [
                      if (task.clientName != null)
                        Expanded(
                          child: Text(
                            task.clientName!.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: theme.primaryColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      _buildMiniTimeInfo(theme),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Middle Row: Title and Quick Actions
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Priority Indicator
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: priorityColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: -0.3,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      if (task.clientId != null)
                        _buildCompactQuickJump(context, theme),
                    ],
                  ),

                  if (task.notes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      task.notes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.hintColor.withOpacity(0.6),
                      ),
                    ),
                  ],

                  // Tags and Progress
                  if (task.tags.isNotEmpty || task.subtasks.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (task.tags.isNotEmpty)
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: task.tags
                                    .map(
                                      (tag) => Container(
                                        margin: const EdgeInsets.only(right: 4),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getTagColor(
                                            tag.color,
                                          ).withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          tag.label,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: _getTagColor(tag.color),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        if (task.subtasks.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _buildMiniProgress(theme),
                        ],
                      ],
                    ),
                  ],

                  const SizedBox(height: 10),
                  // Footer: Due Date and Assignee
                  Row(
                    children: [
                      if (task.dueAt != null)
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 11,
                              color: _isOverdue(task.dueAt!)
                                  ? Colors.red
                                  : theme.hintColor.withOpacity(0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd MMM').format(task.dueAt!),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _isOverdue(task.dueAt!)
                                    ? Colors.red
                                    : theme.hintColor.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      const Spacer(),
                      if (task.assigneeName != null)
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: theme.primaryColor.withOpacity(0.1),
                          child: Text(
                            task.assigneeName!.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniTimeInfo(ThemeData theme) {
    return Text(
      _getTimeAgo(task.statusChangedAt),
      style: TextStyle(
        fontSize: 9,
        color: theme.hintColor.withOpacity(0.5),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildCompactQuickJump(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniJumpButton(
          icon: Icons.chat_bubble_outline_rounded,
          onTap: () async {
            final chatService = Provider.of<ChatService>(
              context,
              listen: false,
            );
            try {
              final conversationId = await chatService.getOrCreateConversation(
                task.clientId!,
              );
              if (conversationId != null) {
                context.push('/chat/$conversationId');
              }
            } catch (e) {
              debugPrint('Error jumping to chat: $e');
            }
          },
        ),
        const SizedBox(width: 4),
        _MiniJumpButton(
          icon: Icons.account_circle_outlined,
          onTap: () {
            context.push('/clientes/${task.clientId}');
          },
        ),
      ],
    );
  }

  Widget _buildMiniProgress(ThemeData theme) {
    int completed = task.subtasks.where((s) => s.isCompleted).length;
    int total = task.subtasks.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.checklist_rounded, size: 10, color: theme.primaryColor),
          const SizedBox(width: 4),
          Text(
            '$completed/$total',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: theme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0)
      return 'Hace ${diff.inDays} ${diff.inDays == 1 ? 'día' : 'días'}';
    if (diff.inHours > 0)
      return 'Hace ${diff.inHours} ${diff.inHours == 1 ? 'hora' : 'horas'}';
    if (diff.inMinutes > 0)
      return 'Hace ${diff.inMinutes} ${diff.inMinutes == 1 ? 'min' : 'mins'}';
    return 'Recién';
  }

  Color _getTagColor(String colorStr) {
    switch (colorStr) {
      case 'orange':
        return Colors.orange;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'purple':
        return Colors.purple;
      case 'red':
        return Colors.red;
      case 'teal':
        return Colors.teal;
      case 'pink':
        return Colors.pink;
      default:
        return Colors.blueGrey;
    }
  }
}

class _MiniJumpButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MiniJumpButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.primaryColor.withOpacity(0.08)),
          ),
          child: Icon(icon, size: 14, color: theme.primaryColor),
        ),
      ),
    );
  }
}
