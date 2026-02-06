import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/task_model.dart';
import '../../services/task_service.dart';
import '../../models/settings_model.dart';
import '../../widgets/advisor_selector.dart';
import '../../providers/super_admin_provider.dart';
import '../../services/auth_service.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/kanban/kanban_column_widget.dart';

class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

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
    final auth = Provider.of<AuthService>(context, listen: false);

    String? assigneeId;
    if (auth.isSuperAdmin) {
      assigneeId = saProvider.selectedAdvisorId;
    } else {
      assigneeId = auth.userId;
    }

    Provider.of<TaskService>(
      context,
      listen: false,
    ).loadTasks(assigneeId: assigneeId);
    Provider.of<SettingsProvider>(
      context,
      listen: false,
    ).loadSettings(userId: assigneeId);
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
    _searchController.dispose();
    super.dispose();
  }

  String _selectedPriority = 'all';
  final Set<String> _selectedTags = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskService = Provider.of<TaskService>(context);

    final availableTags = [
      {'label': 'Dieta', 'color': 'orange'},
      {'label': 'Entreno', 'color': 'blue'},
      {'label': 'Consulta', 'color': 'purple'},
      {'label': 'Pago', 'color': 'green'},
      {'label': 'Revisión', 'color': 'teal'},
      {'label': 'Urgente', 'color': 'red'},
      {'label': 'Cita', 'color': 'amber'},
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Tareas',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
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

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 5),
            child: TextField(
              controller: _searchController,
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar por título, notas o cliente...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.cardColor.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ),

          // Filters Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                // Priority Filter
                DropdownButton<String>(
                  value: _selectedPriority,
                  underline: const SizedBox(),
                  icon: Icon(
                    Icons.filter_list_rounded,
                    size: 16,
                    color: theme.primaryColor,
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('TODAS PRIORIDADES'),
                    ),
                    DropdownMenuItem(
                      value: 'urgent',
                      child: Text('🔴 URGENTE'),
                    ),
                    DropdownMenuItem(value: 'high', child: Text('🟠 ALTA')),
                    DropdownMenuItem(value: 'medium', child: Text('🟡 MEDIA')),
                    DropdownMenuItem(value: 'low', child: Text('🔵 BAJA')),
                  ],
                  onChanged: (val) => setState(() => _selectedPriority = val!),
                ),
                const SizedBox(width: 16),
                const VerticalDivider(width: 1, indent: 10, endIndent: 10),
                const SizedBox(width: 16),

                // Tag Filters
                ...availableTags.map((tag) {
                  final label = tag['label'] as String;
                  final color = tag['color'] as String;
                  final isSelected = _selectedTags.contains(label);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : null,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: _getColorFromString(color),
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedTags.add(label);
                          } else {
                            _selectedTags.remove(label);
                          }
                        });
                      },
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

          Expanded(
            child: taskService.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Consumer<SettingsProvider>(
                    builder: (context, settingsProv, _) {
                      final columns =
                          settingsProv.settings?.kanbanColumns ?? [];
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
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: activeColumns.map((col) {
                            final filteredTasks = taskService.tasks.where((t) {
                              // 1. Status Match
                              final matchesStatus =
                                  t.status == col.id ||
                                  (col.id == 'todo' && t.status == 'pending');
                              if (!matchesStatus) return false;

                              // 2. SMART ARCHIVING (Done column > 24h)
                              if (col.id == 'done') {
                                final diff = DateTime.now().difference(
                                  t.statusChangedAt,
                                );
                                if (diff.inHours >= 24) return false;
                              }

                              // 3. Search Match
                              final matchesSearch =
                                  t.title.toLowerCase().contains(
                                    _searchQuery,
                                  ) ||
                                  t.notes.toLowerCase().contains(
                                    _searchQuery,
                                  ) ||
                                  (t.clientName?.toLowerCase().contains(
                                        _searchQuery,
                                      ) ??
                                      false);
                              if (!matchesSearch) return false;

                              // 4. Priority Match
                              if (_selectedPriority != 'all' &&
                                  t.priority.toLowerCase() !=
                                      _selectedPriority) {
                                return false;
                              }

                              // 5. Tags Match
                              if (_selectedTags.isNotEmpty) {
                                final taskTagLabels = t.tags
                                    .map((tag) => tag.label)
                                    .toSet();
                                if (!_selectedTags.any(
                                  (tag) => taskTagLabels.contains(tag),
                                )) {
                                  return false;
                                }
                              }

                              return true;
                            }).toList();

                            return KanbanColumnWidget(
                              id: col.id,
                              title: col.title,
                              icon: _getIconForStatus(col.id),
                              color: _getColorFromString(col.color),
                              tasks: filteredTasks,
                              onTaskDropped: (task) =>
                                  taskService.updateStatus(task.id, col.id),
                              onTaskTap: _showEditTaskDialog,
                              onQuickAdd: () => _showTaskForm(status: col.id),
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
      ),
    );
  }

  void _showCreateTaskDialog() => _showTaskForm();
  void _showEditTaskDialog(Tarea task) => _showTaskForm(task: task);

  void _showTaskForm({Tarea? task, String? status}) {
    final isEdit = task != null;
    final titleController = TextEditingController(text: task?.title);
    final notesController = TextEditingController(text: task?.notes);
    DateTime? selectedDate = task?.dueAt;
    String selectedStatus = status ?? task?.status ?? 'todo';
    String selectedPriority = task?.priority ?? 'medium';

    final auth = Provider.of<AuthService>(context, listen: false);
    final saProv = Provider.of<SuperAdminProvider>(context, listen: false);
    String? selectedAssigneeId =
        task?.assigneeId ??
        (auth.isSuperAdmin ? saProv.selectedAdvisorId : auth.userId);

    List<SubTask> tempSubtasks = List<SubTask>.from(task?.subtasks ?? []);
    List<TaskTag> tempTags = List<TaskTag>.from(task?.tags ?? []);
    final subtaskController = TextEditingController();

    final availableTags = [
      {'label': 'Dieta', 'color': 'orange'},
      {'label': 'Entreno', 'color': 'blue'},
      {'label': 'Consulta', 'color': 'purple'},
      {'label': 'Pago', 'color': 'green'},
      {'label': 'Revisión', 'color': 'teal'},
      {'label': 'Urgente', 'color': 'red'},
      {'label': 'Cita', 'color': 'amber'},
    ];

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
          child: SingleChildScrollView(
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
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notas adicionales',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    prefixIcon: const Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 24),

                // Subtasks Section
                const Text(
                  'Checklist de subtareas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (tempSubtasks.isNotEmpty)
                  ...tempSubtasks.asMap().entries.map((entry) {
                    int idx = entry.key;
                    SubTask st = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Checkbox(
                            value: st.isCompleted,
                            activeColor: Theme.of(context).primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            onChanged: (val) {
                              setModalState(() {
                                tempSubtasks[idx] = st.copyWith(
                                  isCompleted: val,
                                );
                              });
                            },
                          ),
                          Expanded(
                            child: Text(
                              st.title,
                              style: TextStyle(
                                decoration: st.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: st.isCompleted ? Colors.grey : null,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline_rounded,
                              size: 18,
                              color: Colors.red,
                            ),
                            onPressed: () =>
                                setModalState(() => tempSubtasks.removeAt(idx)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: subtaskController,
                        decoration: const InputDecoration(
                          hintText: 'Añadir subtarea...',
                          isDense: true,
                        ),
                        onSubmitted: (val) {
                          if (val.trim().isEmpty) return;
                          setModalState(() {
                            tempSubtasks.add(SubTask(title: val.trim()));
                            subtaskController.clear();
                          });
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_rounded),
                      onPressed: () {
                        final val = subtaskController.text.trim();
                        if (val.isEmpty) return;
                        setModalState(() {
                          tempSubtasks.add(SubTask(title: val));
                          subtaskController.clear();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Tags Section
                const Text(
                  'Categorías',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableTags.map((tagData) {
                    final label = tagData['label'] as String;
                    final color = tagData['color'] as String;
                    final isSelected = tempTags.any((t) => t.label == label);

                    return FilterChip(
                      label: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : null,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: _getColorFromString(color),
                      onSelected: (val) {
                        setModalState(() {
                          if (val) {
                            tempTags.add(TaskTag(label: label, color: color));
                          } else {
                            tempTags.removeWhere((t) => t.label == label);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

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
                          if (date != null)
                            setModalState(() => selectedDate = date);
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
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 20,
                              ),
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
                if (auth.isSuperAdmin) ...[
                  const Text(
                    'Asignar a',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value:
                            saProv.advisors.any(
                              (adv) => adv['_id'] == selectedAssigneeId,
                            )
                            ? selectedAssigneeId
                            : null,
                        isExpanded: true,
                        hint: const Text('Global / Todos'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Sin asignar (Global)'),
                          ),
                          ...saProv.advisors.map(
                            (adv) => DropdownMenuItem<String>(
                              value: adv['_id'],
                              child: Text(adv['nombre'] ?? 'Sin nombre'),
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setModalState(() => selectedAssigneeId = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text(
                  'Prioridad',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedPriority,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Baja')),
                        DropdownMenuItem(value: 'medium', child: Text('Media')),
                        DropdownMenuItem(value: 'high', child: Text('Alta')),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Text('Urgente'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null)
                          setModalState(() => selectedPriority = val);
                      },
                    ),
                  ),
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
                    if (!columns.any((c) => c.id == selectedStatus))
                      selectedStatus = columns.first.id;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                const Text(
                  'Adjuntos (Próximamente)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_upload_outlined, color: Colors.grey),
                      SizedBox(width: 12),
                      Text(
                        'Integración con almacenamiento PDF/Fotos',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
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
                        context,
                        listen: false,
                      );
                      final data = {
                        'title': title,
                        'notes': notesController.text.trim(),
                        'dueAt': selectedDate?.toIso8601String(),
                        'status': selectedStatus,
                        'priority': selectedPriority,
                        'assigneeId': selectedAssigneeId,
                        'subtasks': tempSubtasks
                            .map((e) => e.toJson())
                            .toList(),
                        'tags': tempTags.map((e) => e.toJson()).toList(),
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
                          context,
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

  void _showKanbanSettings() => _showKanbanSettingsDialog();

  void _showKanbanSettingsDialog() {
    final settingsProv = Provider.of<SettingsProvider>(context, listen: false);
    final currentColumns = List<KanbanColumn>.from(
      settingsProv.settings?.kanbanColumns ?? [],
    );
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
                                onPressed: () => _editColumn(
                                  col,
                                  (updated) => setModalState(
                                    () => currentColumns[index] = updated,
                                  ),
                                ),
                              ),
                              if (currentColumns.length > 1)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  onPressed: () => setModalState(
                                    () => currentColumns.removeAt(index),
                                  ),
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
                      onPressed: () => _addColumn(
                        (newCol) => setModalState(
                          () => currentColumns.add(
                            newCol.copyWith(order: currentColumns.length),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Añadir Columna'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final saProvider = Provider.of<SuperAdminProvider>(
                          context,
                          listen: false,
                        );
                        final auth = Provider.of<AuthService>(
                          context,
                          listen: false,
                        );
                        String? assigneeId = auth.isSuperAdmin
                            ? saProvider.selectedAdvisorId
                            : auth.userId;
                        final updatedSettings = settingsProv.settings?.copyWith(
                          kanbanColumns: currentColumns,
                        );
                        if (updatedSettings != null)
                          await settingsProv.updateSettings(
                            updatedSettings,
                            userId: assigneeId,
                          );
                        Navigator.pop(ctx);
                      },
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

  void _editColumn(KanbanColumn col, Function(KanbanColumn) onUpdated) =>
      _showColumnForm(column: col, onSaved: onUpdated);
  void _addColumn(Function(KanbanColumn) onAdded) =>
      _showColumnForm(onSaved: onAdded);

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
                  labelText: 'ID (ej: backlog)',
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
