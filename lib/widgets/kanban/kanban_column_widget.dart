import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import 'kanban_card.dart';

class KanbanColumnWidget extends StatelessWidget {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final List<Tarea> tasks;
  final Function(Tarea) onTaskDropped;
  final Function(Tarea) onTaskTap;
  final VoidCallback onQuickAdd;

  const KanbanColumnWidget({
    super.key,
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.tasks,
    required this.onTaskDropped,
    required this.onTaskTap,
    required this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DragTarget<Tarea>(
      onWillAccept: (data) => data?.status != id,
      onAccept: onTaskDropped,
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 320,
          margin: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty
                ? color.withOpacity(0.05)
                : (isDark ? Colors.white.withOpacity(0.02) : Colors.grey[50]),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: candidateData.isNotEmpty
                  ? color.withOpacity(0.3)
                  : (isDark ? Colors.white10 : Colors.grey.shade200),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              // Column Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: color,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            '${tasks.length} tareas',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.hintColor.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onQuickAdd,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      color: color.withOpacity(0.5),
                      tooltip: 'Añadir a esta columna',
                    ),
                  ],
                ),
              ),

              // Tasks List
              Expanded(
                child: tasks.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return Draggable<Tarea>(
                            data: task,
                            feedback: Material(
                              color: Colors.transparent,
                              child: SizedBox(
                                width: 288,
                                child: KanbanCard(task: task, onTap: () {}),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: KanbanCard(task: task, onTap: () {}),
                            ),
                            child: KanbanCard(
                              task: task,
                              onTap: () => onTaskTap(task),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 48,
            color: theme.hintColor.withOpacity(0.1),
          ),
          const SizedBox(height: 12),
          Text(
            'Sin tareas',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.hintColor.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}
