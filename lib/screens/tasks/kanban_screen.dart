import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/task_model.dart';
import '../../models/settings_model.dart';
import '../../services/task_service.dart';
import '../../services/auth_service.dart';
import '../../providers/super_admin_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/advisor_selector.dart';
import '../../widgets/kanban/kanban_column_widget.dart';

enum _GroupMode { status, priority, client, type, date }

class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _quickFilter = 'all';
  String _selectedPriority = 'all';
  _GroupMode _groupMode = _GroupMode.status;
  final Set<String> _selectedTags = {};
  final Set<String> _collapsedColumns = {};

  final List<TaskTag> _availableTags = const [
    TaskTag(label: 'Dieta', color: 'orange'),
    TaskTag(label: 'Entreno', color: 'blue'),
    TaskTag(label: 'Consulta', color: 'purple'),
    TaskTag(label: 'Pago', color: 'green'),
    TaskTag(label: 'Revisión', color: 'teal'),
    TaskTag(label: 'Urgente', color: 'red'),
    TaskTag(label: 'Cita', color: 'amber'),
    TaskTag(label: 'Online', color: 'blue'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      Provider.of<SuperAdminProvider>(context, listen: false).addListener(_onAdvisorChanged);
    });
  }

  void _onAdvisorChanged() {
    if (mounted) _loadData();
  }

  void _loadData() {
    final saProvider = Provider.of<SuperAdminProvider>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final assigneeId = auth.isSuperAdmin ? saProvider.selectedAdvisorId : auth.userId;
    Provider.of<TaskService>(context, listen: false).loadTasks(assigneeId: assigneeId);
    Provider.of<SettingsProvider>(context, listen: false).loadSettings(userId: assigneeId);
  }

  @override
  void dispose() {
    try {
      Provider.of<SuperAdminProvider>(context, listen: false).removeListener(_onAdvisorChanged);
    } catch (_) {}
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskService = Provider.of<TaskService>(context);
    final filtered = _filteredTasks(taskService.tasks);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Tareas', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(icon: const Icon(Icons.settings_suggest_rounded), onPressed: _showKanbanSettings, tooltip: 'Configurar columnas'),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData, tooltip: 'Actualizar'),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (Provider.of<AuthService>(context, listen: false).isSuperAdmin) const AdvisorSelector(),
          _buildStats(filtered),
          _buildSearchAndGroup(theme),
          _buildQuickFilters(theme),
          Expanded(
            child: taskService.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Consumer<SettingsProvider>(
                    builder: (context, settingsProv, _) => _buildBoard(filtered, settingsProv),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva tarea', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStats(List<Tarea> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pending = tasks.where((t) => t.status == 'todo' || t.status == 'pending').length;
    final doing = tasks.where((t) => t.status == 'doing').length;
    final done = tasks.where((t) => t.status == 'done').length;
    final overdue = tasks.where((t) => t.dueAt != null && DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day).isBefore(today) && t.status != 'done').length;
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        children: [
          _StatCard(label: 'Pendientes', value: pending.toString(), icon: Icons.radio_button_unchecked_rounded, color: Colors.orange),
          _StatCard(label: 'En proceso', value: doing.toString(), icon: Icons.timelapse_rounded, color: Colors.blue),
          _StatCard(label: 'Hechas', value: done.toString(), icon: Icons.check_circle_rounded, color: Colors.green),
          _StatCard(label: 'Vencidas', value: overdue.toString(), icon: Icons.warning_amber_rounded, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildSearchAndGroup(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar por título, cliente, notas o etiqueta...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); }) : null,
                filled: true,
                fillColor: theme.cardColor.withOpacity(.65),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: theme.cardColor.withOpacity(.65), borderRadius: BorderRadius.circular(18)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<_GroupMode>(
                value: _groupMode,
                icon: const Icon(Icons.view_column_rounded),
                items: const [
                  DropdownMenuItem(value: _GroupMode.status, child: Text('Estado')),
                  DropdownMenuItem(value: _GroupMode.priority, child: Text('Prioridad')),
                  DropdownMenuItem(value: _GroupMode.client, child: Text('Cliente')),
                  DropdownMenuItem(value: _GroupMode.type, child: Text('Tipo')),
                  DropdownMenuItem(value: _GroupMode.date, child: Text('Fecha')),
                ],
                onChanged: (value) => setState(() => _groupMode = value ?? _GroupMode.status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilters(ThemeData theme) {
    final filters = [
      ['all', 'Todos', Icons.all_inclusive_rounded],
      ['today', 'Hoy', Icons.today_rounded],
      ['week', 'Semana', Icons.date_range_rounded],
      ['overdue', 'Vencidas', Icons.warning_amber_rounded],
      ['high', 'Altas', Icons.priority_high_rounded],
      ['diet', 'Dietas', Icons.restaurant_menu_rounded],
      ['training', 'Entrenos', Icons.fitness_center_rounded],
      ['invoice', 'Facturas', Icons.payments_rounded],
    ];
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...filters.map((f) {
            final selected = _quickFilter == f[0];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: selected,
                avatar: Icon(f[2] as IconData, size: 16, color: selected ? Colors.white : theme.primaryColor),
                label: Text(f[1] as String, style: TextStyle(fontWeight: FontWeight.w800, color: selected ? Colors.white : null)),
                selectedColor: theme.primaryColor,
                onSelected: (_) => setState(() => _quickFilter = f[0] as String),
              ),
            );
          }),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Filtrar prioridad',
            onSelected: (v) => setState(() => _selectedPriority = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'all', child: Text('Todas las prioridades')),
              PopupMenuItem(value: 'urgent', child: Text('Urgente')),
              PopupMenuItem(value: 'high', child: Text('Alta')),
              PopupMenuItem(value: 'medium', child: Text('Media')),
              PopupMenuItem(value: 'low', child: Text('Baja')),
            ],
            child: Chip(avatar: const Icon(Icons.filter_list_rounded, size: 16), label: Text(_selectedPriority == 'all' ? 'Prioridad' : _priorityLabel(_selectedPriority))),
          ),
          const SizedBox(width: 8),
          ..._availableTags.map((tag) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: _selectedTags.contains(tag.label),
                  selectedColor: _getColorFromString(tag.color),
                  label: Text(tag.label, style: TextStyle(fontWeight: FontWeight.w800, color: _selectedTags.contains(tag.label) ? Colors.white : null)),
                  onSelected: (v) => setState(() => v ? _selectedTags.add(tag.label) : _selectedTags.remove(tag.label)),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildBoard(List<Tarea> tasks, SettingsProvider settingsProv) {
    final groups = _buildGroups(tasks, settingsProv);
    if (groups.isEmpty) return const Center(child: Text('No hay tareas con estos filtros'));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: groups.map((g) {
          return KanbanColumnWidget(
            id: g.id,
            title: g.title,
            icon: g.icon,
            color: g.color,
            tasks: g.tasks,
            collapsed: _collapsedColumns.contains(g.id),
            canDrop: _groupMode == _GroupMode.status,
            onToggleCollapsed: () => setState(() => _collapsedColumns.contains(g.id) ? _collapsedColumns.remove(g.id) : _collapsedColumns.add(g.id)),
            onTaskDropped: (task) => Provider.of<TaskService>(context, listen: false).updateStatus(task.id, g.id),
            onTaskTap: _showTaskDetails,
            onEdit: (task) => _showTaskForm(task: task),
            onDone: _markDone,
            onDuplicate: _duplicateTask,
            onDelete: _deleteTask,
            onQuickAdd: () => _showTaskForm(status: _groupMode == _GroupMode.status ? g.id : null),
          );
        }).toList(),
      ),
    );
  }

  List<Tarea> _filteredTasks(List<Tarea> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return tasks.where((t) {
      final haystack = '${t.title} ${t.notes} ${t.clientName ?? ''} ${t.tags.map((e) => e.label).join(' ')}'.toLowerCase();
      if (_searchQuery.isNotEmpty && !haystack.contains(_searchQuery)) return false;
      if (_selectedPriority != 'all' && t.priority != _selectedPriority) return false;
      if (_selectedTags.isNotEmpty) {
        final labels = t.tags.map((e) => e.label).toSet();
        if (!_selectedTags.any(labels.contains)) return false;
      }
      final due = t.dueAt == null ? null : DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day);
      switch (_quickFilter) {
        case 'today': return due != null && due == today;
        case 'week': return due != null && !due.isBefore(today) && due.difference(today).inDays <= 7;
        case 'overdue': return due != null && due.isBefore(today) && t.status != 'done';
        case 'high': return t.priority == 'high' || t.priority == 'urgent';
        case 'diet': return _typeOf(t) == 'Dieta';
        case 'training': return _typeOf(t) == 'Entreno';
        case 'invoice': return _typeOf(t) == 'Factura';
      }
      return true;
    }).toList();
  }

  List<_TaskGroup> _buildGroups(List<Tarea> tasks, SettingsProvider settingsProv) {
    switch (_groupMode) {
      case _GroupMode.status:
        var columns = settingsProv.settings?.kanbanColumns ?? [];
        if (columns.isEmpty) {
          columns = [
            KanbanColumn(id: 'todo', title: 'Pendiente', color: 'orange', order: 0),
            KanbanColumn(id: 'doing', title: 'En proceso', color: 'blue', order: 1),
            KanbanColumn(id: 'done', title: 'Hecho', color: 'green', order: 2),
          ];
        }
        return columns.map((c) => _TaskGroup(c.id, c.title, _getIconForStatus(c.id), _getColorFromString(c.color), tasks.where((t) => t.status == c.id || (c.id == 'todo' && t.status == 'pending')).toList())).toList();
      case _GroupMode.priority:
        return [
          _TaskGroup('urgent', 'Urgente', Icons.local_fire_department_rounded, Colors.deepPurple, tasks.where((t) => t.priority == 'urgent').toList()),
          _TaskGroup('high', 'Alta', Icons.priority_high_rounded, Colors.red, tasks.where((t) => t.priority == 'high').toList()),
          _TaskGroup('medium', 'Media', Icons.flag_rounded, Colors.orange, tasks.where((t) => t.priority == 'medium').toList()),
          _TaskGroup('low', 'Baja', Icons.low_priority_rounded, Colors.blue, tasks.where((t) => t.priority == 'low').toList()),
        ];
      case _GroupMode.client:
        final names = tasks.map((t) => t.clientName?.isNotEmpty == true ? t.clientName! : 'Sin cliente').toSet().toList()..sort();
        return names.map((n) => _TaskGroup(n, n, Icons.person_rounded, Colors.indigo, tasks.where((t) => (t.clientName?.isNotEmpty == true ? t.clientName! : 'Sin cliente') == n).toList())).toList();
      case _GroupMode.type:
        final types = ['Dieta', 'Entreno', 'Factura', 'Presupuesto', 'Cita', 'Revisión', 'Manual'];
        return types.map((type) => _TaskGroup(type, type, _iconForType(type), _colorForType(type), tasks.where((t) => _typeOf(t) == type).toList())).where((g) => g.tasks.isNotEmpty).toList();
      case _GroupMode.date:
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        return [
          _TaskGroup('overdue', 'Vencidas', Icons.warning_amber_rounded, Colors.red, tasks.where((t) => t.dueAt != null && DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day).isBefore(today) && t.status != 'done').toList()),
          _TaskGroup('today', 'Hoy', Icons.today_rounded, Colors.orange, tasks.where((t) => t.dueAt != null && DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day) == today).toList()),
          _TaskGroup('week', 'Esta semana', Icons.date_range_rounded, Colors.blue, tasks.where((t) => t.dueAt != null && !DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day).isBefore(today) && DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day).difference(today).inDays <= 7).toList()),
          _TaskGroup('later', 'Más adelante', Icons.event_available_rounded, Colors.green, tasks.where((t) => t.dueAt != null && DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day).difference(today).inDays > 7).toList()),
          _TaskGroup('nodate', 'Sin fecha', Icons.event_busy_rounded, Colors.blueGrey, tasks.where((t) => t.dueAt == null).toList()),
        ];
    }
  }

  void _showTaskDetails(Tarea task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskDetailsSheet(
        task: task,
        availableTags: _availableTags,
        onEdit: () { Navigator.pop(context); _showTaskForm(task: task); },
        onDelete: () { Navigator.pop(context); _deleteTask(task); },
        onDuplicate: () { Navigator.pop(context); _duplicateTask(task); },
        onChanged: (updated) => Provider.of<TaskService>(context, listen: false).updateTask(task.id, updated.toJson()),
        onGoClient: task.clientId == null ? null : () { Navigator.pop(context); context.push('/clientes/${task.clientId}'); },
      ),
    );
  }

  void _showTaskForm({Tarea? task, String? status}) {
    final titleController = TextEditingController(text: task?.title ?? '');
    final notesController = TextEditingController(text: task?.notes ?? '');
    DateTime? selectedDate = task?.dueAt;
    String selectedPriority = task?.priority ?? 'medium';
    String selectedStatus = status ?? task?.status ?? 'todo';
    final tempTags = [...?task?.tags];
    final tempSubtasks = [...?task?.subtasks];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(.35), borderRadius: BorderRadius.circular(99)))),
                const SizedBox(height: 18),
                Text(task == null ? 'Nueva tarea' : 'Editar tarea', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                TextField(controller: titleController, decoration: _inputDecoration('Título', Icons.title_rounded)),
                const SizedBox(height: 12),
                TextField(controller: notesController, minLines: 3, maxLines: 5, decoration: _inputDecoration('Notas', Icons.notes_rounded)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _DropdownBox(label: 'Prioridad', value: selectedPriority, items: const {'low':'Baja','medium':'Media','high':'Alta','urgent':'Urgente'}, onChanged: (v) => setModalState(() => selectedPriority = v))),
                  const SizedBox(width: 10),
                  Expanded(child: _DateBox(date: selectedDate, onTap: () async { final picked = await showDatePicker(context: ctx, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: selectedDate ?? DateTime.now()); if (picked != null) setModalState(() => selectedDate = picked); })),
                ]),
                const SizedBox(height: 12),
                Consumer<SettingsProvider>(builder: (_, settingsProv, __) {
                  var columns = settingsProv.settings?.kanbanColumns ?? [];
                  if (columns.isEmpty) columns = [KanbanColumn(id: 'todo', title: 'Pendiente', color: 'orange', order: 0), KanbanColumn(id: 'doing', title: 'En proceso', color: 'blue', order: 1), KanbanColumn(id: 'done', title: 'Hecho', color: 'green', order: 2)];
                  if (!columns.any((c) => c.id == selectedStatus)) selectedStatus = columns.first.id;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(.35)), borderRadius: BorderRadius.circular(14)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedStatus,
                        isExpanded: true,
                        items: columns.map((c) => DropdownMenuItem(value: c.id, child: Text(c.title))).toList(),
                        onChanged: (v) => setModalState(() => selectedStatus = v ?? selectedStatus),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                const Text('Etiquetas', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: _availableTags.map((tag) {
                  final selected = tempTags.any((e) => e.label == tag.label);
                  return FilterChip(
                    selected: selected,
                    selectedColor: _getColorFromString(tag.color),
                    label: Text(tag.label, style: TextStyle(color: selected ? Colors.white : null, fontWeight: FontWeight.w800)),
                    onSelected: (v) => setModalState(() => v ? tempTags.add(tag) : tempTags.removeWhere((e) => e.label == tag.label)),
                  );
                }).toList()),
                const SizedBox(height: 16),
                Row(children: [
                  const Expanded(child: Text('Checklist', style: TextStyle(fontWeight: FontWeight.w900))),
                  TextButton.icon(onPressed: () => _addSubtaskDialog(ctx, tempSubtasks, setModalState), icon: const Icon(Icons.add_rounded), label: const Text('Añadir')),
                ]),
                ...tempSubtasks.asMap().entries.map((entry) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: entry.value.isCompleted,
                  title: Text(entry.value.title),
                  onChanged: (v) => setModalState(() => tempSubtasks[entry.key] = entry.value.copyWith(isCompleted: v ?? false)),
                  secondary: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setModalState(() => tempSubtasks.removeAt(entry.key))),
                )),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;
                      final data = {
                        'title': title,
                        'notes': notesController.text.trim(),
                        'dueAt': selectedDate?.toIso8601String(),
                        'status': selectedStatus,
                        'priority': selectedPriority,
                        'subtasks': tempSubtasks.map((e) => e.toJson()).toList(),
                        'tags': tempTags.map((e) => e.toJson()).toList(),
                      };
                      final service = Provider.of<TaskService>(context, listen: false);
                      if (task == null) { await service.createTask(data); } else { await service.updateTask(task.id, data); }
                      if (mounted) Navigator.pop(ctx);
                    },
                    child: Text(task == null ? 'Crear tarea' : 'Guardar cambios'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addSubtaskDialog(BuildContext ctx, List<SubTask> list, void Function(void Function()) setModalState) {
    final c = TextEditingController();
    showDialog(context: ctx, builder: (dialogContext) => AlertDialog(
      title: const Text('Nueva subtarea'),
      content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'Ej. Enviar PDF')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (c.text.trim().isNotEmpty) {
              setModalState(() => list.add(SubTask(title: c.text.trim())));
            }
            Navigator.of(dialogContext).pop();
          },
          child: const Text('Añadir'),
        ),
      ],
    ));
  }

  Future<void> _markDone(Tarea task) async {
    await Provider.of<TaskService>(context, listen: false).updateTask(task.id, {'status': 'done'});
  }

  Future<void> _duplicateTask(Tarea task) async {
    final data = task.toJson();
    data['title'] = '${task.title} (copia)';
    data['status'] = task.status == 'done' ? 'todo' : task.status;
    await Provider.of<TaskService>(context, listen: false).createTask(data);
  }

  Future<void> _deleteTask(Tarea task) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Eliminar tarea'),
      content: Text('¿Eliminar "${task.title}"?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar'))],
    ));
    if (ok == true) await Provider.of<TaskService>(context, listen: false).deleteTask(task.id);
  }

  void _showKanbanSettings() => context.push('/settings');

  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(labelText: label, prefixIcon: Icon(icon), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)));

  String _priorityLabel(String priority) => {'urgent':'Urgente','high':'Alta','medium':'Media','low':'Baja'}[priority] ?? priority;

  String _typeOf(Tarea t) {
    final text = '${t.origin} ${t.title} ${t.notes} ${t.tags.map((e) => e.label).join(' ')}'.toLowerCase();
    if (text.contains('dieta') || text.contains('nutric')) return 'Dieta';
    if (text.contains('entreno') || text.contains('ejercicio')) return 'Entreno';
    if (text.contains('factura') || text.contains('pago')) return 'Factura';
    if (text.contains('presupuesto')) return 'Presupuesto';
    if (text.contains('cita')) return 'Cita';
    if (text.contains('revision') || text.contains('revisión')) return 'Revisión';
    return 'Manual';
  }

  IconData _iconForType(String type) => {
    'Dieta': Icons.restaurant_menu_rounded,
    'Entreno': Icons.fitness_center_rounded,
    'Factura': Icons.payments_rounded,
    'Presupuesto': Icons.request_quote_rounded,
    'Cita': Icons.event_rounded,
    'Revisión': Icons.fact_check_rounded,
  }[type] ?? Icons.task_alt_rounded;

  Color _colorForType(String type) => {
    'Dieta': Colors.orange,
    'Entreno': Colors.blue,
    'Factura': Colors.green,
    'Presupuesto': Colors.purple,
    'Cita': Colors.amber.shade700,
    'Revisión': Colors.teal,
  }[type] ?? Colors.blueGrey;

  IconData _getIconForStatus(String status) {
    switch (status) {
      case 'doing': return Icons.timelapse_rounded;
      case 'done': return Icons.check_circle_rounded;
      case 'blocked': return Icons.lock_rounded;
      default: return Icons.radio_button_unchecked_rounded;
    }
  }

  Color _getColorFromString(String colorStr) {
    switch (colorStr) {
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

class _TaskGroup {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final List<Tarea> tasks;
  _TaskGroup(this.id, this.title, this.icon, this.color, this.tasks);
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 146,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withOpacity(.15))),
      child: Row(children: [Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.hintColor))]))]),
    );
  }
}

class _DropdownBox extends StatelessWidget {
  final String label;
  final String value;
  final Map<String,String> items;
  final ValueChanged<String> onChanged;
  const _DropdownBox({required this.label, required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(.35)), borderRadius: BorderRadius.circular(14)),
    child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, isExpanded: true, items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (v) { if (v != null) onChanged(v); })),
  );
}

class _DateBox extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onTap;
  const _DateBox({this.date, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(.35)), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [const Icon(Icons.calendar_today_rounded, size: 18), const SizedBox(width: 8), Expanded(child: Text(date == null ? 'Sin fecha' : DateFormat('dd/MM/yyyy').format(date!)))]),
    ),
  );
}

class _TaskDetailsSheet extends StatefulWidget {
  final Tarea task;
  final List<TaskTag> availableTags;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback? onGoClient;
  final ValueChanged<Tarea> onChanged;
  const _TaskDetailsSheet({required this.task, required this.availableTags, required this.onEdit, required this.onDelete, required this.onDuplicate, this.onGoClient, required this.onChanged});

  @override
  State<_TaskDetailsSheet> createState() => _TaskDetailsSheetState();
}

class _TaskDetailsSheetState extends State<_TaskDetailsSheet> {
  late Tarea task;
  final _commentController = TextEditingController();
  final _attachmentNameController = TextEditingController();
  final _attachmentUrlController = TextEditingController();

  @override
  void initState() { super.initState(); task = widget.task; }
  @override
  void dispose() { _commentController.dispose(); _attachmentNameController.dispose(); _attachmentUrlController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * .90,
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
          child: Row(children: [
            Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(.35), borderRadius: BorderRadius.circular(99))),
            const Spacer(),
            IconButton(onPressed: widget.onDuplicate, icon: const Icon(Icons.copy_rounded), tooltip: 'Duplicar'),
            IconButton(onPressed: widget.onEdit, icon: const Icon(Icons.edit_rounded), tooltip: 'Editar'),
            IconButton(onPressed: widget.onDelete, icon: const Icon(Icons.delete_outline_rounded), tooltip: 'Eliminar'),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(task.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _Pill(text: task.priority.toUpperCase(), color: _priorityColor(task.priority)),
                if (task.clientName != null) _Pill(text: task.clientName!, color: theme.primaryColor),
                if (task.dueAt != null) _Pill(text: DateFormat('dd/MM/yyyy').format(task.dueAt!), color: Colors.blueGrey),
              ]),
              if (task.notes.isNotEmpty) ...[const SizedBox(height: 18), _SectionTitle('Notas'), Text(task.notes, style: TextStyle(color: theme.hintColor, height: 1.35))],
              const SizedBox(height: 18),
              _SectionTitle('Checklist'),
              if (task.subtasks.isEmpty) Text('Sin subtareas', style: TextStyle(color: theme.hintColor)) else ...task.subtasks.asMap().entries.map((entry) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: entry.value.isCompleted,
                title: Text(entry.value.title),
                onChanged: (v) => _updateTask(task.copyWith(subtasks: [...task.subtasks]..[entry.key] = entry.value.copyWith(isCompleted: v ?? false))),
              )),
              const SizedBox(height: 18),
              _SectionTitle('Etiquetas'),
              Wrap(spacing: 8, runSpacing: 6, children: widget.availableTags.map((tag) {
                final selected = task.tags.any((e) => e.label == tag.label);
                return FilterChip(
                  selected: selected,
                  selectedColor: _tagColor(tag.color),
                  label: Text(tag.label, style: TextStyle(color: selected ? Colors.white : null, fontWeight: FontWeight.w800)),
                  onSelected: (v) {
                    final next = [...task.tags];
                    if (v) { next.add(tag); } else { next.removeWhere((e) => e.label == tag.label); }
                    _updateTask(task.copyWith(tags: next));
                  },
                );
              }).toList()),
              const SizedBox(height: 18),
              _SectionTitle('Comentarios'),
              ...task.comments.map((c) => ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(child: Text(c.authorName.substring(0,1).toUpperCase())), title: Text(c.text), subtitle: Text('${c.authorName} · ${DateFormat('dd/MM HH:mm').format(c.createdAt)}'))),
              Row(children: [Expanded(child: TextField(controller: _commentController, decoration: const InputDecoration(hintText: 'Añadir comentario'))), IconButton(onPressed: _addComment, icon: const Icon(Icons.send_rounded))]),
              const SizedBox(height: 18),
              _SectionTitle('Archivos / enlaces'),
              ...task.attachments.map((a) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.attach_file_rounded), title: Text(a.name), subtitle: Text(a.url, maxLines: 1, overflow: TextOverflow.ellipsis))),
              Row(children: [Expanded(child: TextField(controller: _attachmentNameController, decoration: const InputDecoration(hintText: 'Nombre'))), const SizedBox(width: 8), Expanded(child: TextField(controller: _attachmentUrlController, decoration: const InputDecoration(hintText: 'URL'))), IconButton(onPressed: _addAttachment, icon: const Icon(Icons.add_link_rounded))]),
              const SizedBox(height: 18),
              _SectionTitle('Acciones rápidas'),
              Wrap(spacing: 10, runSpacing: 10, children: [
                ElevatedButton.icon(onPressed: () => _updateTask(task.copyWith(status: 'done')), icon: const Icon(Icons.check_rounded), label: const Text('Marcar hecha')),
                OutlinedButton.icon(onPressed: widget.onEdit, icon: const Icon(Icons.edit_rounded), label: const Text('Editar')),
                OutlinedButton.icon(onPressed: widget.onGoClient, icon: const Icon(Icons.person_rounded), label: const Text('Ir al cliente')),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  void _updateTask(Tarea updated) { setState(() => task = updated); widget.onChanged(updated); }
  void _addComment() { final text = _commentController.text.trim(); if (text.isEmpty) return; _commentController.clear(); _updateTask(task.copyWith(comments: [...task.comments, TaskComment(text: text)])); }
  void _addAttachment() { final url = _attachmentUrlController.text.trim(); final name = _attachmentNameController.text.trim(); if (url.isEmpty) return; _attachmentUrlController.clear(); _attachmentNameController.clear(); _updateTask(task.copyWith(attachments: [...task.attachments, TaskAttachment(name: name.isEmpty ? 'Adjunto' : name, url: url)])); }
  Color _priorityColor(String priority) => {'urgent': Colors.deepPurple, 'high': Colors.red, 'medium': Colors.orange, 'low': Colors.blue}[priority] ?? Colors.grey;
  Color _tagColor(String color) => {'orange': Colors.orange, 'blue': Colors.blue, 'green': Colors.green, 'purple': Colors.purple, 'red': Colors.red, 'teal': Colors.teal, 'pink': Colors.pink, 'amber': Colors.amber.shade700}[color] ?? Colors.blueGrey;
}

class _SectionTitle extends StatelessWidget { final String text; const _SectionTitle(this.text); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))); }
class _Pill extends StatelessWidget { final String text; final Color color; const _Pill({required this.text, required this.color}); @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(99)), child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color))); }
