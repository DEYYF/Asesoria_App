import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../services/task_service.dart';
import 'package:intl/intl.dart';
import '../../models/settings_model.dart';
import '../../widgets/advisor_selector.dart';
import '../../providers/super_admin_provider.dart';
import '../../services/auth_service.dart';
import '../../providers/settings_provider.dart';

class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      final saProvider = Provider.of<SuperAdminProvider>(
        context,
        listen: false,
      );
      saProvider.addListener(_onAdvisorChanged);
    });
  }

  void _onAdvisorChanged() {
    if (mounted) _loadData();
  }

  void _loadData() {
    final saProvider = Provider.of<SuperAdminProvider>(context, listen: false);
    Provider.of<TaskService>(
      context,
      listen: false,
    ).loadTasks(assigneeId: saProvider.selectedAdvisorId);
  }

  @override
  void dispose() {
    try {
      final saProvider = Provider.of<SuperAdminProvider>(
        context,
        listen: false,
      );
      saProvider.removeListener(_onAdvisorChanged);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskService = Provider.of<TaskService>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Tablero de Tareas',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest_rounded),
            onPressed: _showKanbanSettings,
            tooltip: 'Configurar columnas',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (Provider.of<AuthService>(context, listen: false).isSuperAdmin)
            const AdvisorSelector(),
          Expanded(
            child: taskService.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Consumer<SettingsProvider>(
                    builder: (context, settingsProv, _) {
                      final columns =
                          settingsProv.settings?.kanbanColumns ?? [];

                      // Fallback to default columns if empty
                      final activeColumns = columns.isEmpty
                          ? [
                              KanbanColumn(
                                id: 'todo',
                                title: 'PENDIENTE',
                                color: 'orange',
                                order: 0,
                              ),
                              KanbanColumn(
                                id: 'doing',
                                title: 'EN PROGRESO',
                                color: 'blue',
                                order: 1,
                              ),
                              KanbanColumn(
                                id: 'done',
                                title: 'COMPLETADO',
                                color: 'green',
                                order: 2,
                              ),
                            ]
                          : columns;

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: activeColumns.map((col) {
                            return _buildKanbanColumn(
                              col.id,
                              col.title,
                              _getIconForStatus(col.id),
                              _getColorFromString(col.color),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTaskDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nueva Tarea',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildKanbanColumn(
    String status,
    String title,
    IconData icon,
    Color color,
  ) {
    final taskService = Provider.of<TaskService>(context);
    final tasks = taskService.tasks
        .where(
          (t) =>
              t.status == status || (status == 'todo' && t.status == 'pending'),
        )
        .toList();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DragTarget<Tarea>(
      onWillAccept: (data) => data?.status != status,
      onAccept: (data) {
        taskService.updateStatus(data.id, status);
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 320,
          margin: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty
                ? color.withOpacity(0.05)
                : (isDark ? Colors.white.withOpacity(0.02) : Colors.grey[50]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: candidateData.isNotEmpty
                  ? color.withOpacity(0.3)
                  : (isDark ? Colors.white10 : Colors.grey.shade200),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: color,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        tasks.length.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    return _buildTaskCard(tasks[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskCard(Tarea task) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Draggable<Tarea>(
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 296,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Text(
            task.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildStaticCard(task)),
      child: _buildStaticCard(task),
    );
  }

  Widget _buildStaticCard(Tarea task) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _showEditTaskDialog(task),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.clientName != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task.clientName!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: theme.primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  task.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                ),
                if (task.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    task.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.hintColor.withOpacity(0.7),
                      height: 1.4,
                    ),
                  ),
                ],
                if (task.dueAt != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: _isOverdue(task.dueAt!)
                            ? Colors.red
                            : theme.hintColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM').format(task.dueAt!),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _isOverdue(task.dueAt!)
                              ? Colors.red
                              : theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isOverdue(DateTime date) {
    return date.isBefore(DateTime.now()) && date.day != DateTime.now().day;
  }

  void _showCreateTaskDialog() {
    // Show a bottom sheet or dialog to create a task
    _showTaskForm();
  }

  void _showEditTaskDialog(Tarea task) {
    _showTaskForm(task: task);
  }

  void _showTaskForm({Tarea? task}) {
    final isEdit = task != null;
    final titleController = TextEditingController(text: task?.title);
    final notesController = TextEditingController(text: task?.notes);
    DateTime? selectedDate = task?.dueAt;
    String selectedStatus = task?.status ?? 'todo';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Editar Tarea' : 'Nueva Tarea',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                autofocus: !isEdit,
                decoration: InputDecoration(
                  labelText: '¿Qué hay que hacer?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  prefixIcon: const Icon(Icons.edit_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notas adicionales',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365 * 2),
                          ),
                        );
                        if (date != null) {
                          setModalState(() => selectedDate = date);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              selectedDate == null
                                  ? 'Sin fecha'
                                  : DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(selectedDate!),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Estado',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Consumer<SettingsProvider>(
                builder: (context, settingsProv, _) {
                  var columns = settingsProv.settings?.kanbanColumns ?? [];
                  if (columns.isEmpty) {
                    columns = [
                      KanbanColumn(
                        id: 'todo',
                        title: 'PENDIENTE',
                        color: 'orange',
                        order: 0,
                      ),
                      KanbanColumn(
                        id: 'doing',
                        title: 'EN PROGRESO',
                        color: 'blue',
                        order: 1,
                      ),
                      KanbanColumn(
                        id: 'done',
                        title: 'COMPLETADO',
                        color: 'green',
                        order: 2,
                      ),
                    ];
                  }

                  // Ensure selectedStatus is valid
                  if (!columns.any((c) => c.id == selectedStatus)) {
                    selectedStatus = columns.first.id;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedStatus,
                        isExpanded: true,
                        items: columns
                            .map(
                              (col) => DropdownMenuItem(
                                value: col.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: _getColorFromString(col.color),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(col.title),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null)
                            setModalState(() => selectedStatus = val);
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;

                    final taskService = Provider.of<TaskService>(
                      this.context,
                      listen: false,
                    );
                    final data = {
                      'title': title,
                      'notes': notesController.text.trim(),
                      'dueAt': selectedDate?.toIso8601String(),
                      'status': selectedStatus,
                    };

                    if (isEdit) {
                      taskService.updateTask(task.id, data);
                    } else {
                      taskService.createTask(data);
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(isEdit ? 'Guardar Cambios' : 'Crear Tarea'),
                ),
              ),
              if (isEdit) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Provider.of<TaskService>(
                        this.context,
                        listen: false,
                      ).deleteTask(task.id);
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Eliminar Tarea',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForStatus(String status) {
    switch (status) {
      case 'todo':
        return Icons.list_rounded;
      case 'doing':
        return Icons.play_arrow_rounded;
      case 'done':
        return Icons.check_circle_rounded;
      default:
        return Icons.label_outline_rounded;
    }
  }

  Color _getColorFromString(String colorStr) {
    switch (colorStr.toLowerCase()) {
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
      case 'amber':
        return Colors.amber;
      case 'pink':
        return Colors.pink;
      case 'indigo':
        return Colors.indigo;
      default:
        return Colors.blueGrey;
    }
  }

  void _showKanbanSettings() {
    _showKanbanSettingsDialog();
  }

  void _showKanbanSettingsDialog() {
    final settingsProv = Provider.of<SettingsProvider>(context, listen: false);
    final currentColumns = List<KanbanColumn>.from(
      settingsProv.settings?.kanbanColumns ?? [],
    );

    // Initial default if empty
    if (currentColumns.isEmpty) {
      currentColumns.addAll([
        KanbanColumn(id: 'todo', title: 'PENDIENTE', color: 'orange', order: 0),
        KanbanColumn(
          id: 'doing',
          title: 'EN PROGRESO',
          color: 'blue',
          order: 1,
        ),
        KanbanColumn(id: 'done', title: 'COMPLETADO', color: 'green', order: 2),
      ]);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Configurar Tablero',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Text(
                'Personaliza las columnas de tu tablero Kanban.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: currentColumns.length,
                  onReorder: (oldIndex, newIndex) {
                    setModalState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = currentColumns.removeAt(oldIndex);
                      currentColumns.insert(newIndex, item);
                      // Update orders
                      for (int i = 0; i < currentColumns.length; i++) {
                        currentColumns[i] = currentColumns[i].copyWith(
                          order: i,
                        );
                      }
                    });
                  },
                  itemBuilder: (context, index) {
                    final col = currentColumns[index];
                    return Container(
                      key: ValueKey(col.id),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getColorFromString(col.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          col.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          col.id,
                          style: const TextStyle(fontSize: 10),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (col.id != 'todo') ...[
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 18),
                                onPressed: () => _editColumn(col, (updated) {
                                  setModalState(() {
                                    currentColumns[index] = updated;
                                  });
                                }),
                              ),
                              if (currentColumns.length > 1)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    setModalState(() {
                                      currentColumns.removeAt(index);
                                    });
                                  },
                                ),
                            ] else
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Icon(
                                  Icons.lock_outline_rounded,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            const Icon(
                              Icons.drag_handle_rounded,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _addColumn((newCol) {
                        setModalState(() {
                          currentColumns.add(
                            newCol.copyWith(order: currentColumns.length),
                          );
                        });
                      }),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Añadir Columna'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final updatedSettings = settingsProv.settings?.copyWith(
                          kanbanColumns: currentColumns,
                        );
                        if (updatedSettings != null) {
                          await settingsProv.updateSettings(updatedSettings);
                        }
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editColumn(KanbanColumn col, Function(KanbanColumn) onUpdated) {
    _showColumnForm(column: col, onSaved: onUpdated);
  }

  void _addColumn(Function(KanbanColumn) onAdded) {
    _showColumnForm(onSaved: onAdded);
  }

  void _showColumnForm({
    KanbanColumn? column,
    required Function(KanbanColumn) onSaved,
  }) {
    final isEdit = column != null;
    final titleController = TextEditingController(text: column?.title);
    final idController = TextEditingController(text: column?.id);
    String selectedColor = column?.color ?? 'blue';

    final colors = [
      'orange',
      'blue',
      'green',
      'purple',
      'red',
      'teal',
      'amber',
      'pink',
      'indigo',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Editar Columna' : 'Nueva Columna'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            if (!isEdit) ...[
              const SizedBox(height: 12),
              TextField(
                controller: idController,
                decoration: const InputDecoration(
                  labelText: 'ID (ej: backlog, review)',
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text('Color', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: colors
                  .map(
                    (c) => GestureDetector(
                      onTap: () => selectedColor = c,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _getColorFromString(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == c
                                ? Colors.black
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              final id = idController.text.trim().toLowerCase().replaceAll(
                ' ',
                '_',
              );
              if (title.isEmpty || (!isEdit && id.isEmpty)) return;

              onSaved(
                KanbanColumn(
                  id: isEdit ? column.id : id,
                  title: title,
                  color: selectedColor,
                  order: column?.order ?? 0,
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
