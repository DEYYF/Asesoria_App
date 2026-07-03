import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import 'kanban_card.dart';

class KanbanColumnWidget extends StatelessWidget {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final List<Tarea> tasks;
  final bool collapsed;
  final bool canDrop;
  final Function(Tarea) onTaskDropped;
  final Function(Tarea) onTaskTap;
  final Function(Tarea) onEdit;
  final Function(Tarea) onDone;
  final Function(Tarea) onDuplicate;
  final Function(Tarea) onDelete;
  final VoidCallback onQuickAdd;
  final VoidCallback onToggleCollapsed;

  const KanbanColumnWidget({
    super.key,
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.tasks,
    required this.onTaskDropped,
    required this.onTaskTap,
    required this.onEdit,
    required this.onDone,
    required this.onDuplicate,
    required this.onDelete,
    required this.onQuickAdd,
    required this.onToggleCollapsed,
    this.collapsed = false,
    this.canDrop = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final content = Container(
      width: collapsed ? 86 : 326,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(.025) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: collapsed ? _CollapsedHeader(title: title, color: color, count: tasks.length, onTap: onToggleCollapsed) : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 10, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color, letterSpacing: .6)),
                      Text('${tasks.length} tareas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.hintColor)),
                    ],
                  ),
                ),
                IconButton(onPressed: onToggleCollapsed, icon: const Icon(Icons.keyboard_arrow_left_rounded), tooltip: 'Plegar'),
                IconButton(onPressed: onQuickAdd, icon: const Icon(Icons.add_circle_outline_rounded), tooltip: 'Añadir'),
              ],
            ),
          ),
          Expanded(
            child: tasks.isEmpty ? _buildEmptyState(theme) : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              physics: const BouncingScrollPhysics(),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                final card = KanbanCard(
                  task: task,
                  onTap: () => onTaskTap(task),
                  onEdit: () => onEdit(task),
                  onDone: () => onDone(task),
                  onDuplicate: () => onDuplicate(task),
                  onDelete: () => onDelete(task),
                );
                return canDrop ? Draggable<Tarea>(
                  data: task,
                  feedback: Material(color: Colors.transparent, child: SizedBox(width: 292, child: card)),
                  childWhenDragging: Opacity(opacity: .35, child: card),
                  child: card,
                ) : card;
              },
            ),
          ),
        ],
      ),
    );

    if (!canDrop || collapsed) return content;
    return DragTarget<Tarea>(
      onWillAccept: (data) => data != null && data.status != id,
      onAccept: onTaskDropped,
      builder: (context, candidateData, rejectedData) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: candidateData.isEmpty ? null : BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: color.withOpacity(.15), blurRadius: 18)],
        ),
        child: content,
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 44, color: theme.hintColor.withOpacity(.16)),
          const SizedBox(height: 10),
          Text('Sin tareas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.hintColor.withOpacity(.45))),
        ],
      ),
    );
  }
}

class _CollapsedHeader extends StatelessWidget {
  final String title;
  final Color color;
  final int count;
  final VoidCallback onTap;
  const _CollapsedHeader({required this.title, required this.color, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Column(
          children: [
            Icon(Icons.keyboard_arrow_right_rounded, color: color),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(99)), child: Text('$count', style: TextStyle(fontWeight: FontWeight.w900, color: color))),
            const SizedBox(height: 12),
            Expanded(child: RotatedBox(quarterTurns: 3, child: Center(child: Text(title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color, letterSpacing: .8))))),
          ],
        ),
      ),
    );
  }
}
