import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/habito_service.dart';
import '../../services/habito_preset_service.dart';
import '../../services/habit_analytics_service.dart';
import '../../services/auth_service.dart';
import '../../models/habito_model.dart';
import '../../models/gamification_models.dart';
import '../../services/gamification_service.dart';
import '../../widgets/gamification/streak_widget.dart';
import '../../widgets/gamification/badge_card.dart';
import '../../widgets/gamification/challenge_card.dart';
import '../../widgets/gamification/level_progress_widget.dart';
import 'package:fl_chart/fl_chart.dart';

class HabitTrackerScreen extends StatefulWidget {
  final String clienteId;
  const HabitTrackerScreen({super.key, required this.clienteId});

  @override
  State<HabitTrackerScreen> createState() => _HabitTrackerScreenState();
}

class _HabitTrackerScreenState extends State<HabitTrackerScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _filterHabitId;
  int? _filterMonth;
  int _filterYear = DateTime.now().year;
  bool _showCharts = false;

  late GamificationService _gamificationService;
  GamificationStats? _gamStats;
  List<BadgeModel> _badges = [];
  List<ChallengeModel> _challenges = [];
  bool _isLoadingGamification = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _gamificationService = GamificationService(auth);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
      _loadGamification();
    });
  }

  Future<void> _loadGamification() async {
    if (_isLoadingGamification) return;
    setState(() => _isLoadingGamification = true);

    try {
      final stats = await _gamificationService.fetchStats(widget.clienteId);
      final badges = await _gamificationService.fetchBadges(widget.clienteId);
      final challenges = await _gamificationService.fetchChallenges(
        widget.clienteId,
        active: false,
      );

      if (mounted) {
        setState(() {
          _gamStats = stats;
          _badges = badges;
          _challenges = challenges;
          _isLoadingGamification = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingGamification = false);
    }
  }

  Future<void> _refresh() async {
    final service = Provider.of<HabitoService>(context, listen: false);
    await Future.wait([
      service.fetchHabitos(widget.clienteId),
      service.fetchLogs(
        widget.clienteId,
        start: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        ),
        end: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          23,
          59,
          59,
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = Provider.of<HabitoService>(context);
    final auth = Provider.of<AuthService>(context, listen: false);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            onTap: (index) {
              if (index == 1) {
                service.fetchHistoryLogs(
                  widget.clienteId,
                  habitoId: _filterHabitId,
                  month: _filterMonth,
                  year: _filterYear,
                );
              } else if (index == 3) {
                _loadGamification();
              } else {
                _refresh();
              }
            },
            tabs: const [
              Tab(text: 'Diario'),
              Tab(text: 'Registro'),
              Tab(text: 'Insights'),
              Tab(text: 'Retos'),
            ],
            indicatorColor: theme.primaryColor,
            labelColor: theme.primaryColor,
            unselectedLabelColor: theme.hintColor,
            indicatorSize: TabBarIndicatorSize.label,
          ),
        ),
        body: TabBarView(
          children: [
            // Daily View
            Column(
              children: [
                _buildDatePicker(theme),
                Expanded(
                  child: service.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : service.habitos.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildHabitsList(service, theme),
                ),
              ],
            ),
            // History View
            Column(
              children: [
                _buildFilterBar(service, theme),
                Expanded(
                  child: _showCharts
                      ? _buildHistoryCharts(service, theme)
                      : _buildHistoryList(service, theme),
                ),
              ],
            ),
            // Insights View
            _buildInsightsView(service, theme),
            // Gamification View
            _buildGamificationView(theme),
          ],
        ),
        floatingActionButton: !auth.isClient ? _buildFAB(context, theme) : null,
      ),
    );
  }

  Widget _buildFAB(BuildContext context, ThemeData theme) {
    return FloatingActionButton.extended(
      onPressed: () => _showHabitOptions(context),
      backgroundColor: theme.primaryColor,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: const Text(
        'Nuevo Hábito',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showHabitOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.library_books_rounded,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              title: const Text(
                'Biblioteca de Hábitos',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Elige de nuestra colección'),
              onTap: () {
                Navigator.pop(ctx);
                _showHabitLibrary(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.edit_rounded,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              title: const Text(
                'Crear Personalizado',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Define tu propio hábito'),
              onTap: () {
                Navigator.pop(ctx);
                _showHabitFormDialog(context, null);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showHabitLibrary(BuildContext context) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final presetService = HabitoPresetService(auth);
    final presets = await presetService.fetchPresets();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Icon(
                      Icons.library_books_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Biblioteca de Hábitos',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: presets.isEmpty
                    ? const Center(
                        child: Text('No hay hábitos predeterminados'),
                      )
                    : ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: presets.length,
                        itemBuilder: (context, index) {
                          final preset = presets[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getIconFromName(preset.icono),
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              title: Text(
                                preset.nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (preset.descripcion != null)
                                    Text(preset.descripcion!),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          preset.categoria.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                          ),
                                        ),
                                      ),
                                      if (preset.tipo == 'numeric') ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '${preset.target} ${preset.unidad}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).hintColor,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: Theme.of(context).hintColor,
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                _showHabitFormDialog(
                                  context,
                                  null,
                                  preset: preset,
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconFromName(String? iconName) {
    if (iconName == null) return Icons.auto_awesome_rounded;
    switch (iconName) {
      case 'water_drop':
        return Icons.water_drop_rounded;
      case 'directions_walk':
        return Icons.directions_walk_rounded;
      case 'self_improvement':
        return Icons.self_improvement_rounded;
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'ac_unit':
        return Icons.ac_unit_rounded;
      case 'bedtime':
        return Icons.bedtime_rounded;
      case 'eco':
        return Icons.eco_rounded;
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'phone_disabled':
        return Icons.phone_disabled_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  void _showHabitFormDialog(
    BuildContext context,
    Habito? habito, {
    HabitoPreset? preset,
  }) {
    final isEditing = habito != null;
    final nameController = TextEditingController(
      text: habito?.nombre ?? preset?.nombre ?? '',
    );
    final descController = TextEditingController(
      text: habito?.descripcion ?? preset?.descripcion ?? '',
    );
    final unitController = TextEditingController(
      text: habito?.unidad ?? preset?.unidad ?? '',
    );
    final targetController = TextEditingController(
      text: habito?.target?.toString() ?? preset?.target?.toString() ?? '',
    );
    final parentValueController = TextEditingController(
      text: habito?.parentValue?.toString() ?? '',
    );
    String type = habito?.tipo ?? 'checklist';
    String chartType =
        habito?.chartType ?? (type == 'checklist' ? 'pie' : 'line');
    String? parentId = habito?.parentId;
    String? parentCondition = habito?.parentCondition;

    final habitsService = Provider.of<HabitoService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final theme = Theme.of(context);

    // Helper to check if parent is numeric
    bool isParentNumeric() {
      if (parentId == null) return false;
      try {
        final parent = habitsService.habitos.firstWhere(
          (h) => h.id == parentId,
        );
        return parent.tipo == 'numeric';
      } catch (_) {
        return false;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isEditing ? Icons.edit_rounded : Icons.add_rounded,
                          color: theme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          isEditing ? 'Editar Hábito' : 'Nuevo Hábito',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildModernField(
                    controller: nameController,
                    label: 'Nombre',
                    hint: 'Ej: Beber Agua, Pasos diarios...',
                    icon: Icons.title_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildModernField(
                    controller: descController,
                    label: 'Descripción (Opcional)',
                    hint: 'Añade una pequeña explicación...',
                    icon: Icons.description_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  _buildModernDropdown<String>(
                    value: type,
                    label: 'Tipo de Tracking',
                    icon: Icons.track_changes_rounded,
                    items: const [
                      DropdownMenuItem(
                        value: 'checklist',
                        child: Text('Checklist (Si/No)'),
                      ),
                      DropdownMenuItem(
                        value: 'numeric',
                        child: Text('Numérico (Valor)'),
                      ),
                    ],
                    onChanged: (val) => setDialogState(() {
                      type = val!;
                      chartType = type == 'checklist' ? 'pie' : 'line';
                    }),
                  ),
                  const SizedBox(height: 16),
                  _buildModernDropdown<String>(
                    value: chartType,
                    label: 'Gráfica Preferida',
                    icon: Icons.bar_chart_rounded,
                    items: type == 'checklist'
                        ? const [
                            DropdownMenuItem(
                              value: 'pie',
                              child: Text('Gráfico Circular'),
                            ),
                            DropdownMenuItem(
                              value: 'bar_count',
                              child: Text('Barras de Frecuencia'),
                            ),
                            DropdownMenuItem(
                              value: 'heatmap',
                              child: Text('Mapa de Calor'),
                            ),
                          ]
                        : const [
                            DropdownMenuItem(
                              value: 'line',
                              child: Text('Línea de Evolución'),
                            ),
                            DropdownMenuItem(
                              value: 'bar',
                              child: Text('Barras Diarias'),
                            ),
                          ],
                    onChanged: (val) => setDialogState(() => chartType = val!),
                  ),
                  if (type == 'numeric') ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernDropdown<String>(
                            value:
                                [
                                  'g',
                                  'kg',
                                  'L',
                                  'ml',
                                  'horas',
                                  'min',
                                  'pasos',
                                  'cantidad',
                                  'kcal',
                                ].contains(unitController.text)
                                ? unitController.text
                                : null,
                            label: 'Unidad',
                            icon: Icons.straighten_rounded,
                            items: const [
                              DropdownMenuItem(
                                value: 'g',
                                child: Text('Gramos (g)'),
                              ),
                              DropdownMenuItem(value: 'kg', child: Text('Kg')),
                              DropdownMenuItem(
                                value: 'L',
                                child: Text('Litros (L)'),
                              ),
                              DropdownMenuItem(value: 'ml', child: Text('ml')),
                              DropdownMenuItem(
                                value: 'horas',
                                child: Text('Horas'),
                              ),
                              DropdownMenuItem(
                                value: 'min',
                                child: Text('Minutos'),
                              ),
                              DropdownMenuItem(
                                value: 'pasos',
                                child: Text('Pasos'),
                              ),
                              DropdownMenuItem(
                                value: 'cantidad',
                                child: Text('Cant.'),
                              ),
                              DropdownMenuItem(
                                value: 'kcal',
                                child: Text('kcal'),
                              ),
                            ],
                            onChanged: (val) => setDialogState(
                              () => unitController.text = val!,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModernField(
                            controller: targetController,
                            label: 'Objetivo',
                            hint: 'Ej: 2000',
                            icon: Icons.flag_rounded,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildModernField(
                      controller: unitController,
                      label: 'Unidad Personalizada',
                      hint: 'Ej: vasos, repeticiones...',
                      icon: Icons.edit_note_rounded,
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Hábito Desencadenante (Opcional)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildModernDropdown<String?>(
                    value: parentId,
                    label: 'Depende de...',
                    icon: Icons.account_tree_rounded,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Ninguno'),
                      ),
                      ...habitsService.habitos
                          .where((h) => h.id != habito?.id)
                          .map(
                            (h) => DropdownMenuItem(
                              value: h.id,
                              child: Text(h.nombre),
                            ),
                          ),
                    ],
                    onChanged: (val) => setDialogState(() => parentId = val),
                  ),
                  if (parentId != null) ...[
                    const SizedBox(height: 16),
                    _buildModernDropdown<String>(
                      value:
                          parentCondition ?? (isParentNumeric() ? '>' : 'si'),
                      label: 'Se muestra si la respuesta es:',
                      icon: Icons.rule_rounded,
                      items: isParentNumeric()
                          ? const [
                              DropdownMenuItem(
                                value: '>',
                                child: Text('Mayor que (>)'),
                              ),
                              DropdownMenuItem(
                                value: '<',
                                child: Text('Menor que (<)'),
                              ),
                              DropdownMenuItem(
                                value: '>=',
                                child: Text('Mayor o igual (>=)'),
                              ),
                              DropdownMenuItem(
                                value: '<=',
                                child: Text('Menor o igual (<=)'),
                              ),
                              DropdownMenuItem(
                                value: '==',
                                child: Text('Igual a (==)'),
                              ),
                            ]
                          : const [
                              DropdownMenuItem(
                                value: 'si',
                                child: Text('Si (Completado)'),
                              ),
                              DropdownMenuItem(
                                value: 'no',
                                child: Text('No (No realizado)'),
                              ),
                            ],
                      onChanged: (val) =>
                          setDialogState(() => parentCondition = val),
                    ),
                    if (isParentNumeric()) ...[
                      const SizedBox(height: 16),
                      _buildModernField(
                        controller: parentValueController,
                        label: 'Valor de umbral',
                        hint: 'Ej: 8',
                        icon: Icons.numbers_rounded,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ],
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      if (isEditing)
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () =>
                                _handleDelete(ctx, habito, habitsService),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red,
                            ),
                            label: const Text(
                              'Eliminar',
                              style: TextStyle(color: Colors.red),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(color: theme.hintColor),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (nameController.text.isNotEmpty) {
                              final newHabito = Habito(
                                id: habito?.id ?? '',
                                nombre: nameController.text,
                                descripcion: descController.text.isEmpty
                                    ? null
                                    : descController.text,
                                tipo: type,
                                unidad: type == 'numeric'
                                    ? unitController.text
                                    : null,
                                target: type == 'numeric'
                                    ? double.tryParse(targetController.text)
                                    : null,
                                frecuencia: 'diario',
                                clienteId: widget.clienteId,
                                asesorId: auth.userId!,
                                chartType: chartType,
                                parentId: parentId,
                                parentCondition: parentId != null
                                    ? (parentCondition ??
                                          (isParentNumeric() ? '>' : 'si'))
                                    : null,
                                parentValue:
                                    parentId != null && isParentNumeric()
                                    ? double.tryParse(
                                        parentValueController.text,
                                      )
                                    : null,
                              );

                              bool success;
                              if (isEditing) {
                                success = await habitsService.updateHabito(
                                  newHabito,
                                );
                              } else {
                                success = await habitsService.createHabito(
                                  newHabito,
                                );
                              }

                              if (success && mounted) {
                                Navigator.pop(ctx);
                                _refresh();
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            isEditing ? 'Guardar Cambios' : 'Crear Hábito',
                            style: const TextStyle(fontWeight: FontWeight.bold),
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

  Future<void> _handleDelete(
    BuildContext dialogCtx,
    Habito habito,
    HabitoService service,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Eliminar hábito?'),
        content: const Text(
          'Esto no borrará el registro histórico pero el hábito ya no aparecerá en el día a día.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text(
              'Sí, eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await service.deleteHabito(habito.id);
      if (success) {
        Navigator.pop(dialogCtx);
        _refresh();
      }
    }
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null
                ? Icon(
                    icon,
                    size: 20,
                    color: theme.primaryColor.withOpacity(0.5),
                  )
                : null,
            filled: true,
            fillColor: theme.dividerColor.withOpacity(0.05),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernDropdown<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
        ),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              size: 20,
              color: theme.primaryColor.withOpacity(0.5),
            ),
            filled: true,
            fillColor: theme.dividerColor.withOpacity(0.05),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: theme.cardColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat(
                    'MMMM yyyy',
                    'es',
                  ).format(_selectedDate).toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontSize: 14,
                    color: theme.primaryColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_month_rounded, size: 20),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now().add(const Duration(days: 7)),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                      _refresh();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: 15, // Show 7 days before and 7 days after
              itemBuilder: (context, index) {
                final date = DateTime.now()
                    .subtract(const Duration(days: 7))
                    .add(Duration(days: index));
                final isSelected = DateUtils.isSameDay(date, _selectedDate);
                final isToday = DateUtils.isSameDay(date, DateTime.now());

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedDate = date);
                      _refresh();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 60,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.primaryColor
                            : isToday
                            ? theme.primaryColor.withOpacity(0.1)
                            : theme.dividerColor.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? theme.primaryColor
                              : isToday
                              ? theme.primaryColor.withOpacity(0.3)
                              : Colors.transparent,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: theme.primaryColor.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('EEE', 'es').format(date).toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white70
                                  : theme.hintColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            date.day.toString(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: isSelected
                                  ? Colors.white
                                  : theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          if (isToday && !isSelected)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: theme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitsList(HabitoService service, ThemeData theme) {
    final auth = Provider.of<AuthService>(context, listen: false);

    // Filter habits based on triggers
    final visibleHabitos = service.habitos.where((habito) {
      if (habito.parentId == null) return true;

      // Find parent's status
      final parentLog = service.logs.firstWhere(
        (l) => l.habitoId == habito.parentId,
        orElse: () => HabitoRegistro(
          id: '',
          habitoId: habito.parentId!,
          clienteId: widget.clienteId,
          fecha: _selectedDate,
          completado: false,
        ),
      );

      final parentValue = parentLog.valor ?? 0;
      final threshold = habito.parentValue ?? 0;

      switch (habito.parentCondition) {
        case 'si':
          return parentLog.completado;
        case 'no':
          return !parentLog.completado;
        case '>':
          return parentValue > threshold;
        case '<':
          return parentValue < threshold;
        case '>=':
          return parentValue >= threshold;
        case '<=':
          return parentValue <= threshold;
        case '==':
          return parentValue == threshold;
        default:
          return true;
      }
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visibleHabitos.length,
      itemBuilder: (context, index) {
        final habito = visibleHabitos[index];
        final registro = service.logs.firstWhere(
          (l) => l.habitoId == habito.id,
          orElse: () => HabitoRegistro(
            id: '',
            habitoId: habito.id,
            clienteId: widget.clienteId,
            fecha: _selectedDate,
            completado: false,
          ),
        );

        return _HabitCard(
          habito: habito,
          registro: registro,
          onToggle: (val) {
            service.logHabit(
              habitoId: habito.id,
              clienteId: widget.clienteId,
              fecha: _selectedDate,
              completado: val,
            );
          },
          onUpdateValue: (val) {
            service.logHabit(
              habitoId: habito.id,
              clienteId: widget.clienteId,
              fecha: _selectedDate,
              valor: val,
              completado: true,
            );
          },
          onEdit: !auth.isClient
              ? () => _showHabitFormDialog(context, habito)
              : null,
        );
      },
    );
  }

  Widget _buildFilterBar(HabitoService service, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStyledDropdown<String?>(
                  value: _filterHabitId,
                  label: 'Hábito',
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    ...service.habitos.map(
                      (h) =>
                          DropdownMenuItem(value: h.id, child: Text(h.nombre)),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() => _filterHabitId = val);
                    service.fetchHistoryLogs(
                      widget.clienteId,
                      habitoId: _filterHabitId,
                      month: _filterMonth,
                      year: _filterYear,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStyledDropdown<int?>(
                  value: _filterMonth,
                  label: 'Mes',
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    ...List.generate(
                      12,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(
                          DateFormat(
                            'MMMM',
                            'es',
                          ).format(DateTime(2024, i + 1)),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() => _filterMonth = val);
                    service.fetchHistoryLogs(
                      widget.clienteId,
                      habitoId: _filterHabitId,
                      month: _filterMonth,
                      year: _filterYear,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildViewTypeToggle(theme),
        ],
      ),
    );
  }

  Widget _buildStyledDropdown<T>({
    required T value,
    required String label,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T> onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: theme.primaryColor,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButton<T>(
          value: value,
          isExpanded: true,
          underline: const SizedBox(),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: theme.primaryColor,
          ),
          items: items,
          onChanged: (val) => onChanged(val as T),
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildViewTypeToggle(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.dividerColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleItem(Icons.list_rounded, 'LISTA', !_showCharts),
          ),
          Expanded(
            child: _buildToggleItem(
              Icons.bar_chart_rounded,
              'GRÁFICAS',
              _showCharts,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem(IconData icon, String label, bool active) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => setState(() => _showCharts = label == 'GRÁFICAS'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? theme.cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: active ? theme.primaryColor : theme.hintColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: active ? theme.primaryColor : theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.checklist_rounded,
            size: 80,
            color: theme.hintColor.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          const Text('No hay hábitos configurados'),
          const SizedBox(height: 8),
          Text(
            'Tu asesor definirá tus hábitos diarios aquí.',
            style: TextStyle(color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(HabitoService service, ThemeData theme) {
    if (service.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (service.historyLogs.isEmpty) {
      return Center(
        child: Text(
          'No hay registros históricos aún',
          style: TextStyle(color: theme.hintColor),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: service.historyLogs.length,
      itemBuilder: (context, index) {
        final log = service.historyLogs[index];
        final habito = service.habitos.firstWhere(
          (h) => h.id == log.habitoId,
          orElse: () => Habito(
            id: '',
            nombre: 'Hábito eliminado',
            tipo: '',
            frecuencia: '',
            clienteId: '',
            asesorId: '',
          ),
        );

        return _HistoryItem(log: log, habito: habito);
      },
    );
  }

  Widget _buildHistoryCharts(HabitoService service, ThemeData theme) {
    if (service.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (service.historyLogs.isEmpty) {
      return Center(
        child: Text(
          'No hay datos para graficar',
          style: TextStyle(color: theme.hintColor),
        ),
      );
    }

    if (_filterHabitId == null) {
      return _buildGlobalSummaryChart(service, theme);
    }

    final habito = service.habitos.firstWhere((h) => h.id == _filterHabitId);
    final logs = service.historyLogs
        .where((l) => l.habitoId == _filterHabitId)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            habito.nombre,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: _buildSpecificChart(habito, logs, theme),
          ),
          const SizedBox(height: 24),
          _buildChartLegend(habito, theme),
        ],
      ),
    );
  }

  Widget _buildGlobalSummaryChart(HabitoService service, ThemeData theme) {
    Map<String, int> total = {};
    Map<String, int> completed = {};

    for (var habito in service.habitos) {
      total[habito.id] = 0;
      completed[habito.id] = 0;
    }

    for (var log in service.historyLogs) {
      if (total.containsKey(log.habitoId)) {
        total[log.habitoId] = total[log.habitoId]! + 1;
        if (log.completado) {
          completed[log.habitoId] = completed[log.habitoId]! + 1;
        }
      }
    }

    final barGroups = service.habitos.asMap().entries.map((entry) {
      final i = entry.key;
      final h = entry.value;
      final t = total[h.id] ?? 0;
      final c = completed[h.id] ?? 0;
      final percent = t > 0 ? (c / t) * 100 : 0.0;

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: percent,
            gradient: LinearGradient(
              colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.7)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 100,
              color: theme.dividerColor.withOpacity(0.05),
            ),
          ),
        ],
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'RENDIMIENTO GENERAL',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: theme.primaryColor,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cumplimiento de Hábitos',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: BarChart(
              BarChartData(
                barGroups: barGroups,
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: theme.cardColor,
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${service.habitos[groupIndex].nombre}\n',
                        TextStyle(
                          color: theme.textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.bold,
                        ),
                        children: [
                          TextSpan(
                            text: '${rod.toY.toInt()}%',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (val, meta) {
                        final i = val.toInt();
                        if (i >= 0 && i < service.habitos.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Transform.rotate(
                              angle: -0.5,
                              child: Text(
                                service.habitos[i].nombre.length > 5
                                    ? '${service.habitos[i].nombre.substring(0, 5)}...'
                                    : service.habitos[i].nombre,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: theme.hintColor,
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (val, meta) => Text(
                        '${val.toInt()}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.hintColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (val) => FlLine(
                    color: theme.dividerColor.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecificChart(
    Habito habito,
    List<HabitoRegistro> logs,
    ThemeData theme,
  ) {
    final type =
        habito.chartType ?? (habito.tipo == 'checklist' ? 'pie' : 'line');

    // Important: fl_chart requires x-values to be in increasing order.
    // Since service.historyLogs comes sorted newest-first, we reverse it here.
    final sortedLogs = logs.reversed.toList();

    switch (type) {
      case 'pie':
        final done = sortedLogs.where((l) => l.completado).length;
        final missed = sortedLogs.length - done;
        if (sortedLogs.isEmpty) return const Center(child: Text('Sin datos'));
        return PieChart(
          PieChartData(
            sectionsSpace: 4,
            centerSpaceRadius: 40,
            sections: [
              PieChartSectionData(
                value: done.toDouble(),
                title: '${(done / sortedLogs.length * 100).toInt()}%',
                color: theme.primaryColor,
                radius: 60,
                titleStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              PieChartSectionData(
                value: missed.toDouble(),
                title: '',
                color: theme.primaryColor.withOpacity(0.1),
                radius: 50,
              ),
            ],
          ),
        );
      case 'line':
        final spots = sortedLogs
            .asMap()
            .entries
            .map(
              (e) => FlSpot(
                e.key.toDouble(),
                e.value.valor ?? (e.value.completado ? 1 : 0),
              ),
            )
            .toList();
        if (spots.isEmpty) return const Center(child: Text('Sin datos'));
        return LineChart(
          LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: theme.primaryColor,
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 3,
                        strokeColor: theme.primaryColor,
                      ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      theme.primaryColor.withOpacity(0.3),
                      theme.primaryColor.withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 35,
                  getTitlesWidget: (val, meta) => Text(
                    val.toInt().toString(),
                    style: TextStyle(fontSize: 10, color: theme.hintColor),
                  ),
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (val) => FlLine(
                color: theme.dividerColor.withOpacity(0.05),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
          ),
        );
      case 'bar':
      case 'bar_count':
        final barGroups = sortedLogs.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.valor ?? (e.value.completado ? 1 : 0),
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor,
                    theme.primaryColor.withOpacity(0.7),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 14,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList();
        if (barGroups.isEmpty) return const Center(child: Text('Sin datos'));
        return BarChart(
          BarChartData(
            barGroups: barGroups,
            titlesData: const FlTitlesData(
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (val) => FlLine(
                color: theme.dividerColor.withOpacity(0.05),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
          ),
        );
      default:
        return const Center(child: Text('Gráfico apoyado próximamente'));
    }
  }

  Widget _buildChartLegend(Habito habito, ThemeData theme) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _buildLegendItem(Colors.green, 'Completado'),
        _buildLegendItem(Colors.red, 'No completado'),
        if (habito.tipo == 'numeric')
          _buildLegendItem(
            theme.primaryColor,
            'Valor (${habito.unidad ?? ""})',
          ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildInsightsView(HabitoService service, ThemeData theme) {
    if (service.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Generate insights
    final analyticsService = HabitAnalyticsService();
    final logsMap = <String, List<HabitoRegistro>>{};

    for (var habit in service.habitos) {
      logsMap[habit.id] = service.historyLogs
          .where((log) => log.habitoId == habit.id)
          .toList();
    }

    final insights = analyticsService.generateAllInsights(
      service.habitos,
      logsMap,
    );

    if (insights.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              size: 80,
              color: theme.hintColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay suficientes datos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra más hábitos para ver insights',
              style: TextStyle(color: theme.hintColor),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await service.fetchHistoryLogs(
          widget.clienteId,
          habitoId: _filterHabitId,
          month: _filterMonth,
          year: _filterYear,
        );
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: insights.length,
        itemBuilder: (context, index) {
          final insight = insights[index];
          return _buildInsightCard(insight, theme);
        },
      ),
    );
  }

  Widget _buildInsightCard(HabitInsight insight, ThemeData theme) {
    IconData icon;
    Color iconColor;

    if (insight.type == 'correlation') {
      icon = Icons.insights_rounded;
      iconColor = Colors.purple;
    } else {
      icon = Icons.trending_up_rounded;
      iconColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [iconColor.withOpacity(0.05), theme.cardColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (insight.confidence != null)
                        Row(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 14,
                              color: theme.hintColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Confianza: ${(insight.confidence! * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              insight.description,
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color,
                height: 1.5,
              ),
            ),
            if (insight.estimatedDate != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: iconColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat(
                        'dd MMM yyyy',
                        'es',
                      ).format(insight.estimatedDate!),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGamificationView(ThemeData theme) {
    if (_isLoadingGamification && _gamStats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadGamification,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_gamStats != null) ...[
              LevelProgressWidget(
                level: _gamStats!.level,
                xpInCurrentLevel: _gamStats!.xpInCurrentLevel,
                xpNeededForLevel: _gamStats!.xpNeededForLevel,
              ),
              const SizedBox(height: 20),
              StreakWidget(
                streak: _gamStats!.currentStreak,
                longestStreak: _gamStats!.longestStreak,
              ),
              const SizedBox(height: 20),
              _buildTrendCard(theme, _gamStats!.trend),
            ],
            const SizedBox(height: 32),
            _buildSectionTitle(theme, 'Desafíos Activos', Icons.flag_rounded),
            const SizedBox(height: 16),
            if (_challenges.where((c) => !c.completed).isEmpty)
              _buildEmptyChallenges(theme)
            else
              ..._challenges
                  .where((c) => !c.completed)
                  .map((c) => ChallengeCard(challenge: c)),
            const SizedBox(height: 32),
            _buildSectionTitle(
              theme,
              'Mis Medallas',
              Icons.emoji_events_rounded,
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: _badges.length,
              itemBuilder: (context, index) => BadgeCard(badge: _badges[index]),
            ),
            const SizedBox(height: 32),
            if (_challenges.where((c) => c.completed).isNotEmpty) ...[
              _buildSectionTitle(
                theme,
                'Desafíos Completados',
                Icons.check_circle_rounded,
              ),
              const SizedBox(height: 16),
              ..._challenges
                  .where((c) => c.completed)
                  .map((c) => ChallengeCard(challenge: c)),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard(ThemeData theme, TrendAnalysis trend) {
    final isImprovement = trend.percentageChange > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isImprovement ? Colors.green.withOpacity(0.05) : theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isImprovement
              ? Colors.green.withOpacity(0.2)
              : theme.dividerColor.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isImprovement
                  ? Colors.green.withOpacity(0.1)
                  : theme.dividerColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isImprovement
                  ? Icons.trending_up_rounded
                  : Icons.info_outline_rounded,
              color: isImprovement ? Colors.green : theme.hintColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              trend.message.isEmpty
                  ? 'Sigue registrando tus hábitos para ver tendencias.'
                  : trend.message,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isImprovement ? Colors.green : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildEmptyChallenges(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.flag_outlined,
            size: 48,
            color: theme.hintColor.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin desafíos activos',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final HabitoRegistro log;
  final Habito habito;

  const _HistoryItem({required this.log, required this.habito});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('dd MMM', 'es').format(log.fecha);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              dateStr,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: theme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habito.nombre,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  log.completado ? 'Completado' : 'No realizado',
                  style: TextStyle(
                    fontSize: 11,
                    color: log.completado ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (habito.tipo == 'numeric' && log.valor != null)
            Text(
              '${log.valor} ${habito.unidad ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            )
          else
            Icon(
              log.completado
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              color: log.completado ? Colors.green : Colors.red,
              size: 20,
            ),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final Habito habito;
  final HabitoRegistro registro;
  final Function(bool) onToggle;
  final Function(double)? onUpdateValue;
  final VoidCallback? onEdit;

  const _HabitCard({
    required this.habito,
    required this.registro,
    required this.onToggle,
    this.onUpdateValue,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompletado = registro.completado;
    final isNumeric = habito.tipo == 'numeric';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isCompletado
            ? theme.primaryColor.withOpacity(0.05)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCompletado
              ? theme.primaryColor.withOpacity(0.2)
              : theme.dividerColor.withOpacity(0.05),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildLeadingIcon(theme, isCompletado),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            habito.nombre,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              decoration: isCompletado
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isCompletado ? theme.hintColor : null,
                            ),
                          ),
                          if (habito.descripcion != null)
                            Text(
                              habito.descripcion!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.hintColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (onEdit != null)
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, size: 20),
                        onPressed: onEdit,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: theme.hintColor.withOpacity(0.4),
                      ),
                    const SizedBox(width: 8),
                    if (!isNumeric)
                      Transform.scale(
                        scale: 1.2,
                        child: Checkbox(
                          value: isCompletado,
                          onChanged: (val) => onToggle(val ?? false),
                          activeColor: theme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                  ],
                ),
                if (isNumeric) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildNumericInput(context, theme)),
                      const SizedBox(width: 16),
                      if (habito.target != null)
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${((registro.valor ?? 0) / habito.target! * 100).toInt()}% del objetivo',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (registro.valor ?? 0) / habito.target!,
                                  backgroundColor: theme.primaryColor
                                      .withOpacity(0.1),
                                  minHeight: 6,
                                ),
                              ),
                            ],
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

  Widget _buildLeadingIcon(ThemeData theme, bool done) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: done
              ? [theme.primaryColor, theme.primaryColor.withOpacity(0.7)]
              : [
                  theme.dividerColor.withOpacity(0.05),
                  theme.dividerColor.withOpacity(0.1),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: done
            ? [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Icon(
        _getIconForHabit(habito.nombre),
        color: done ? Colors.white : theme.hintColor.withOpacity(0.5),
        size: 22,
      ),
    );
  }

  Widget _buildNumericInput(BuildContext context, ThemeData theme) {
    final controller = TextEditingController(
      text: registro.valor?.toString() ?? '',
    );
    return Container(
      decoration: BoxDecoration(
        color: theme.dividerColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        decoration: InputDecoration(
          hintText: '0',
          suffixText: habito.unidad,
          suffixStyle: TextStyle(fontSize: 12, color: theme.hintColor),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: InputBorder.none,
        ),
        onSubmitted: (val) {
          if (val.trim().isEmpty) return;
          final dVal = double.tryParse(val.replaceAll(',', '.'));
          if (dVal != null) {
            if (onUpdateValue != null) {
              onUpdateValue!(dVal);
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Por favor, introduce un número válido'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  IconData _getIconForHabit(String name) {
    final n = name.toLowerCase();
    if (n.contains('agua')) return Icons.water_drop_rounded;
    if (n.contains('paso')) return Icons.directions_walk_rounded;
    if (n.contains('sueño') || n.contains('dormir'))
      return Icons.bedtime_rounded;
    if (n.contains('comida') || n.contains('dieta'))
      return Icons.restaurant_rounded;
    if (n.contains('meditar')) return Icons.self_improvement_rounded;
    if (n.contains('entren')) return Icons.fitness_center_rounded;
    if (n.contains('frut') || n.contains('verdur')) return Icons.eco_rounded;
    return Icons.auto_awesome_rounded;
  }
}
