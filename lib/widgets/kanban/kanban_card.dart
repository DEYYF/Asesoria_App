import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';

class KanbanCard extends StatelessWidget {
  final Tarea task;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDone;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  const KanbanCard({
    super.key,
    required this.task,
    required this.onTap,
    this.onEdit,
    this.onDone,
    this.onDuplicate,
    this.onDelete,
  });

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Colors.deepPurple;
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return 'Urgente';
      case 'high':
        return 'Alta';
      case 'medium':
        return 'Media';
      case 'low':
        return 'Baja';
      default:
        return priority;
    }
  }

  IconData _typeIcon() {
    final origin = task.origin.toLowerCase();
    final tags = task.tags.map((e) => e.label.toLowerCase()).join(' ');
    final text = '$origin ${task.title.toLowerCase()} ${task.notes.toLowerCase()} $tags';
    if (text.contains('dieta') || text.contains('nutric')) return Icons.restaurant_menu_rounded;
    if (text.contains('entreno') || text.contains('ejercicio') || text.contains('training')) return Icons.fitness_center_rounded;
    if (text.contains('factura') || text.contains('pago') || text.contains('cuota')) return Icons.payments_rounded;
    if (text.contains('presupuesto')) return Icons.request_quote_rounded;
    if (text.contains('cita') || origin.contains('cita')) return Icons.event_rounded;
    if (text.contains('revision') || text.contains('revisión')) return Icons.fact_check_rounded;
    return Icons.task_alt_rounded;
  }

  bool _isOverdue(DateTime date) {
    final now = DateTime.now();
    return date.isBefore(DateTime(now.year, now.month, now.day)) && task.status != 'done';
  }

  String _dueText(DateTime? dueAt) {
    if (dueAt == null) return 'Sin fecha';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueAt.year, dueAt.month, dueAt.day);
    final diff = due.difference(today).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    if (diff == -1) return 'Ayer';
    if (diff < 0) return 'Retraso ${diff.abs()} d';
    if (diff <= 7) return 'En $diff d';
    return DateFormat('dd MMM').format(dueAt);
  }

  int get _completed => task.subtasks.where((s) => s.isCompleted).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pColor = _priorityColor(task.priority);
    final overdue = task.dueAt != null && _isOverdue(task.dueAt!);
    final completion = task.subtasks.isEmpty ? 0.0 : _completed / task.subtasks.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2D) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: overdue ? Colors.red.withOpacity(.45) : (isDark ? Colors.white10 : Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? .25 : .06), blurRadius: 14, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(width: 5, color: pColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(color: pColor.withOpacity(.10), borderRadius: BorderRadius.circular(10)),
                                child: Icon(_typeIcon(), color: pColor, size: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  task.clientName?.isNotEmpty == true ? task.clientName! : 'Sin cliente',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: theme.primaryColor),
                                ),
                              ),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.more_horiz_rounded, size: 20, color: theme.hintColor),
                                onSelected: (value) {
                                  if (value == 'edit') onEdit?.call();
                                  if (value == 'done') onDone?.call();
                                  if (value == 'duplicate') onDuplicate?.call();
                                  if (value == 'delete') onDelete?.call();
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                                  PopupMenuItem(value: 'done', child: Text('Marcar hecha')),
                                  PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
                                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, height: 1.15),
                          ),
                          if (task.notes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              task.notes,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, height: 1.25, color: theme.hintColor),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _Badge(label: _priorityLabel(task.priority), color: pColor),
                              _Badge(label: _dueText(task.dueAt), color: overdue ? Colors.red : Colors.blueGrey),
                              if (task.comments.isNotEmpty) _Badge(label: '${task.comments.length} comentarios', color: Colors.indigo),
                              if (task.attachments.isNotEmpty) _Badge(label: '${task.attachments.length} adjuntos', color: Colors.teal),
                              ...task.tags.take(3).map((tag) => _Badge(label: tag.label, color: _tagColor(tag.color))),
                            ],
                          ),
                          if (task.subtasks.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(99),
                                    child: LinearProgressIndicator(
                                      value: completion,
                                      minHeight: 7,
                                      backgroundColor: theme.dividerColor.withOpacity(.25),
                                      valueColor: AlwaysStoppedAnimation<Color>(completion == 1 ? Colors.green : theme.primaryColor),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('$_completed/${task.subtasks.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _tagColor(String color) {
    switch (color) {
      case 'orange': return Colors.orange;
      case 'blue': return Colors.blue;
      case 'green': return Colors.green;
      case 'purple': return Colors.purple;
      case 'red': return Colors.red;
      case 'teal': return Colors.teal;
      case 'pink': return Colors.pink;
      case 'amber': return Colors.amber.shade700;
      default: return Colors.blueGrey;
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
    );
  }
}
