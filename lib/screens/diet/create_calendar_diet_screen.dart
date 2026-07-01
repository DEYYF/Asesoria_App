import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/dieta_model.dart';
import '../../models/ingrediente_model.dart';
import '../../models/macros_model.dart';
import '../../models/receta_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/offline_sync_service.dart';
import '../../utils/isolate_utils.dart';
import 'diet_detail_screen.dart';

class CreateCalendarDietScreen extends StatefulWidget {
  final String clienteId;
  final String? dietaId;
  final Dieta? initialDieta;

  const CreateCalendarDietScreen({
    super.key,
    required this.clienteId,
    this.dietaId,
    this.initialDieta,
  });

  @override
  State<CreateCalendarDietScreen> createState() => _CreateCalendarDietScreenState();
}

class _CreateCalendarDietScreenState extends State<CreateCalendarDietScreen> {
  final _nameCtrl = TextEditingController(text: 'Nueva Dieta por Calendario');
  final List<String> _validObjetivos = const [
    'ganancia',
    'perdida',
    'definicion',
    'salud',
    'rendimiento',
  ];
  final List<String> _dayNames = const [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  bool _isLoading = true;
  bool _isSaving = false;
  int _selectedDay = 0;
  String _selectedObjetivo = 'salud';
  List<String> _tags = [];
  late List<List<Comida>> _calendarMeals;

  List<Receta> _recetas = [];
  List<Ingrediente> _ingredientes = [];
  List<_MealTemplateEntry> _mealTemplates = [];

  @override
  void initState() {
    super.initState();
    _calendarMeals = List.generate(7, (_) => _defaultMeals());
    _loadMealTemplates();
    _loadAll();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  List<Comida> _defaultMeals() {
    return ['Desayuno', 'Comida', 'Cena']
        .map(
          (title) => Comida(
            titulo: title,
            opciones: [],
            totales: Macros(),
            uniqueKey: _newKey(title),
          ),
        )
        .toList();
  }

  String _newKey(String prefix) =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(10000)}_$prefix';


  Comida _cloneMeal(Comida meal, {String? titleSuffix}) {
    return Comida(
      titulo: titleSuffix == null ? meal.titulo : '${meal.titulo}$titleSuffix',
      hora: meal.hora,
      notas: meal.notas,
      opciones: meal.opciones.map(_cloneOption).toList(),
      totales: meal.totales,
      uniqueKey: _newKey(meal.titulo),
    );
  }

  OpcionDieta _cloneOption(OpcionDieta option) {
    return option.copyWith(
      items: option.items?.map((item) => item.copyWith()).toList(),
      uniqueKey: _newKey(option.nombre ?? option.tipo),
    );
  }

  Future<void> _loadMealTemplates() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.get('/meal-templates', params: {'scope': 'global'});
      if (res.statusCode != 200) return;

      final decoded = jsonDecode(res.body);
      if (decoded is! List || !mounted) return;

      setState(() {
        _mealTemplates = decoded
            .whereType<Map>()
            .map((item) => _MealTemplateEntry.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading calendar meal templates: $e');
    }
  }

  Map<String, dynamic> _mealTemplatePayload(String name, Comida meal) {
    final cloned = _cloneMeal(meal).copyWith(titulo: name);
    return {
      'nombre': name,
      'categoria': 'Dieta',
      'comida': cloned.toJson(),
    };
  }

  Future<void> _loadAll() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final results = await Future.wait([
        api.get('/comidas/recetas'),
        api.get('/comidas/ingredientes'),
      ]);

      if (!mounted) return;
      if (results[0].statusCode == 200) {
        _recetas = await parseRecetasInIsolate(results[0].body);
      }
      if (results[1].statusCode == 200) {
        _ingredientes = await parseIngredientesInIsolate(results[1].body);
      }
    } catch (e) {
      debugPrint('Error loading food data: $e');
    }

    await _loadDietForEditionIfNeeded(api);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadDietForEditionIfNeeded(ApiService api) async {
    Dieta? dieta = widget.initialDieta;

    if (dieta == null && widget.dietaId != null) {
      try {
        final res = await api.get('/dietas/${widget.dietaId}');
        if (res.statusCode == 200) {
          dieta = Dieta.fromJson(jsonDecode(res.body));
        }
      } catch (e) {
        debugPrint('Error loading calendar diet: $e');
      }
    }

    if (dieta == null || !mounted) return;

    _nameCtrl.text = dieta.nombre.isEmpty ? 'Dieta por Calendario' : dieta.nombre;
    _selectedObjetivo = dieta.objetivo ?? 'salud';
    _tags = dieta.notas?.split(', ').where((tag) => tag.trim().isNotEmpty).toList() ?? [];

    final days = List.generate(7, (_) => _defaultMeals());
    for (final dia in dieta.diasSemana) {
      final index = _dayIndexFromName(dia.dia);
      if (index != -1) {
        days[index] = dia.comidas
            .map((meal) => meal.copyWith(uniqueKey: meal.uniqueKey ?? _newKey(meal.titulo)))
            .toList();
      }
    }
    _calendarMeals = days;
  }

  int _dayIndexFromName(String dayName) {
    final normalized = _normalizeDay(dayName);
    const days = ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'];
    return days.indexOf(normalized);
  }

  String _normalizeDay(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .trim();
  }

  List<Comida> get _currentMeals => _calendarMeals[_selectedDay];

  Macros _calculateMealMacros(Comida meal) {
    if (meal.opciones.isEmpty) return Macros();

    double kcal = 0;
    double proteinas = 0;
    double carbohidratos = 0;
    double grasas = 0;

    for (final option in meal.opciones) {
      final macros = _calculateOptionMacros(option);
      kcal += macros.kcal;
      proteinas += macros.proteinas;
      carbohidratos += macros.carbohidratos;
      grasas += macros.grasas;
    }

    return Macros(
      kcal: kcal,
      proteinas: proteinas,
      carbohidratos: carbohidratos,
      grasas: grasas,
    );
  }

  Macros _calculateDayMacros(int dayIndex) {
    double kcal = 0;
    double proteinas = 0;
    double carbohidratos = 0;
    double grasas = 0;

    for (final meal in _calendarMeals[dayIndex]) {
      final macros = _calculateMealMacros(meal);
      kcal += macros.kcal;
      proteinas += macros.proteinas;
      carbohidratos += macros.carbohidratos;
      grasas += macros.grasas;
    }

    return Macros(
      kcal: kcal,
      proteinas: proteinas,
      carbohidratos: carbohidratos,
      grasas: grasas,
    );
  }

  Macros _calculateWeeklyAverageMacros() {
    double kcal = 0;
    double proteinas = 0;
    double carbohidratos = 0;
    double grasas = 0;

    for (var i = 0; i < 7; i++) {
      final macros = _calculateDayMacros(i);
      kcal += macros.kcal;
      proteinas += macros.proteinas;
      carbohidratos += macros.carbohidratos;
      grasas += macros.grasas;
    }

    return Macros(
      kcal: kcal / 7,
      proteinas: proteinas / 7,
      carbohidratos: carbohidratos / 7,
      grasas: grasas / 7,
    );
  }

  Macros _calculateOptionMacros(OpcionDieta option) {
    if (option.tipo == 'receta' && option.recetaId != null) {
      final receta = _recetas.firstWhere(
        (item) => item.id == option.recetaId,
        orElse: () => Receta(id: '', nombre: '?', macrosTotales: Macros()),
      );
      return Macros(
        kcal: receta.caloriasTotales,
        proteinas: receta.macrosTotales.proteinas,
        carbohidratos: receta.macrosTotales.carbohidratos,
        grasas: receta.macrosTotales.grasas,
      );
    }

    if (option.tipo == 'ingrediente' && option.ingredienteId != null) {
      final ingrediente = _ingredientes.firstWhere(
        (item) => item.id == option.ingredienteId,
        orElse: () => Ingrediente(id: '', nombre: '?'),
      );
      final factor = (option.gramos ?? 0) / 100;
      return Macros(
        kcal: ingrediente.kcal * factor,
        proteinas: ingrediente.proteinas * factor,
        carbohidratos: ingrediente.carbohidratos * factor,
        grasas: ingrediente.grasas * factor,
      );
    }

    if (option.tipo == 'combinacion' && option.items != null) {
      double kcal = 0;
      double proteinas = 0;
      double carbohidratos = 0;
      double grasas = 0;

      for (final item in option.items!) {
        final ingrediente = _ingredientes.firstWhere(
          (ing) => ing.id == item.ingredienteId,
          orElse: () => Ingrediente(id: '', nombre: item.nombre ?? '?'),
        );
        final factor = item.gramos / 100;
        kcal += ingrediente.kcal * factor;
        proteinas += ingrediente.proteinas * factor;
        carbohidratos += ingrediente.carbohidratos * factor;
        grasas += ingrediente.grasas * factor;
      }

      return Macros(kcal: kcal, proteinas: proteinas, carbohidratos: carbohidratos, grasas: grasas);
    }

    return Macros();
  }

  Future<void> _handleSave() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);
    final syncService = Provider.of<OfflineSyncService>(context, listen: false);
    final user = auth.user;

    if (user == null) return;

    setState(() => _isSaving = true);

    final payload = {
      'clienteId': widget.clienteId,
      'asesorId': user['_id'] ?? user['id'],
      'nombre': _nameCtrl.text.trim().isEmpty
          ? 'Nueva Dieta por Calendario'
          : _nameCtrl.text.trim(),
      'objetivo': _selectedObjetivo,
      'estado': 'borrador',
      'notas': _tags.join(', '),
      'tipo': 'calendario',
      'macros': _calculateWeeklyAverageMacros().toJson(),
      'comidas': [],
      'diasSemana': List.generate(7, (index) {
        return {
          'dia': _dayNames[index].toLowerCase(),
          'comidas': _calendarMeals[index].map((meal) {
            final mealMacros = _calculateMealMacros(meal);
            return {
              'titulo': meal.titulo,
              'hora': meal.hora ?? '',
              'notas': meal.notas ?? '',
              'totales': mealMacros.toJson(),
              'opciones': meal.opciones.map((option) {
                final optionMacros = _calculateOptionMacros(option);
                final data = <String, dynamic>{
                  'tipo': option.tipo,
                  'nombre': option.nombre,
                  'totales': optionMacros.toJson(),
                  'macros': optionMacros.toJson(),
                };
                if (option.tipo == 'receta') data['recetaId'] = option.recetaId;
                if (option.tipo == 'ingrediente') {
                  data['ingredienteId'] = option.ingredienteId;
                  data['gramos'] = option.gramos ?? 0;
                }
                if (option.tipo == 'combinacion') {
                  data['items'] = option.items?.map((item) => item.toJson()).toList() ?? [];
                }
                if (option.notas != null && option.notas!.isNotEmpty) {
                  data['notas'] = option.notas;
                }
                return data;
              }).toList(),
            };
          }).toList(),
        };
      }),
    };

    try {
      if (await syncService.isOffline()) {
        await syncService.queueUpdate(
          payload,
          endpoint: widget.dietaId != null ? '/dietas/${widget.dietaId}' : '/dietas',
          method: widget.dietaId != null ? 'PUT' : 'POST',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Guardado offline. Se sincronizará al conectar.')),
          );
          Navigator.pop(context);
        }
        return;
      }

      final response = widget.dietaId != null
          ? await api.put('/dietas/${widget.dietaId}', payload)
          : await api.post('/dietas', payload);
      if ((response.statusCode == 200 || response.statusCode == 201) && mounted) {
        final body = jsonDecode(response.body);
        final newId = body is Map ? (body['_id'] ?? body['id'] ?? (body['dieta'] is Map ? (body['dieta']['_id'] ?? body['dieta']['id']) : null)) : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.dietaId != null ? 'Dieta por calendario actualizada' : 'Dieta por calendario guardada')),
        );
        if (newId != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => DietDetailScreen(dietaId: newId)),
          );
        } else {
          Navigator.pop(context);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }


  void _reorderCurrentMeals(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final meal = _currentMeals.removeAt(oldIndex);
      _currentMeals.insert(newIndex, meal);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(backgroundColor: theme.scaffoldBackgroundColor, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(widget.dietaId != null ? 'Editar dieta por calendario' : 'Crear dieta por calendario', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _handleSave,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_rounded),
              label: const Text('Guardar'),
              style: TextButton.styleFrom(
                backgroundColor: theme.primaryColor.withOpacity(0.1),
                foregroundColor: theme.primaryColor,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMetaHeader(theme),
          _buildDaySelector(theme),
          _buildMacroSummary(theme),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              buildDefaultDragHandles: false,
              itemCount: _currentMeals.length,
              onReorder: _reorderCurrentMeals,
              footer: _buildAddMealButton(theme),
              itemBuilder: (context, index) {
                final meal = _currentMeals[index];
                return KeyedSubtree(
                  key: ValueKey(meal.uniqueKey ?? '${meal.titulo}_$index'),
                  child: _buildMealCard(index, meal, theme),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          TextFormField(
            controller: _nameCtrl,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Nombre de la dieta',
              hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.5)),
              isDense: true,
              border: InputBorder.none,
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildGoalChip(theme),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ..._tags.map(
                        (tag) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Chip(
                            label: Text(tag, style: const TextStyle(fontSize: 11)),
                            onDeleted: () => setState(() => _tags.remove(tag)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: _showAddTagDialog,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalChip(ThemeData theme) {
    return PopupMenuButton<String>(
      onSelected: (value) => setState(() => _selectedObjetivo = value),
      itemBuilder: (_) => _validObjetivos
          .map((goal) => PopupMenuItem(value: goal, child: Text(goal.toUpperCase())))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_rounded, size: 14, color: theme.primaryColor),
            const SizedBox(width: 6),
            Text(_selectedObjetivo.toUpperCase(), style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 11)),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector(ThemeData theme) {
    return SizedBox(
      height: 76,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _dayNames.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, index) {
            final selected = index == _selectedDay;
            final hasMeals = _calendarMeals[index].any((meal) => meal.opciones.isNotEmpty);
            final totalMeals = _calendarMeals[index].length;
            final dayMacros = _calculateDayMacros(index);
            final Color borderColor = selected
                ? theme.primaryColor
                : hasMeals
                    ? Colors.green.withOpacity(0.45)
                    : theme.dividerColor.withOpacity(0.14);
            final Color backgroundColor = selected
                ? theme.primaryColor.withOpacity(0.13)
                : hasMeals
                    ? Colors.green.withOpacity(0.08)
                    : theme.cardColor;

            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => _selectedDay = index),
              onLongPress: () => _showCopyDayDialog(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 132,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor, width: selected ? 1.4 : 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Icon(
                                hasMeals ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                size: 14,
                                color: hasMeals ? Colors.green : theme.hintColor.withOpacity(0.5),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _dayNames[index],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    color: selected ? theme.primaryColor : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalMeals comidas · ${dayMacros.kcal.round()} kcal',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.hintColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 160),
                      icon: Icon(Icons.more_vert_rounded, size: 17, color: theme.hintColor),
                      onSelected: (value) {
                        if (value == 'copy') _showCopyDayDialog(index);
                        if (value == 'clear') {
                          setState(() => _calendarMeals[index] = []);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'copy', child: Text('Copiar día a...')),
                        PopupMenuItem(value: 'clear', child: Text('Vaciar día')),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMacroSummary(ThemeData theme) {
    final dayMacros = _calculateDayMacros(_selectedDay);
    final weeklyAverage = _calculateWeeklyAverageMacros();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _macroItem('Día', '${dayMacros.kcal.round()} kcal'),
          _macroItem('Prot', '${dayMacros.proteinas.round()}g'),
          _macroItem('Media', '${weeklyAverage.kcal.round()} kcal'),
          _macroItem('Días', '7'),
        ],
      ),
    );
  }

  Widget _macroItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildMealCard(int mealIndex, Comida meal, ThemeData theme) {
    final mealMacros = _calculateMealMacros(meal);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: mealIndex,
                  child: Icon(Icons.drag_indicator_rounded, size: 20, color: theme.hintColor),
                ),
                const SizedBox(width: 6),
                Icon(Icons.restaurant_rounded, size: 16, color: theme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: meal.titulo,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                    onChanged: (value) => _currentMeals[mealIndex] = meal.copyWith(titulo: value),
                  ),
                ),
                Text('${mealMacros.kcal.round()} kcal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.hintColor)),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (value) {
                    if (value == 'delete') setState(() => _currentMeals.removeAt(mealIndex));
                    if (value == 'duplicate') {
                      setState(() => _currentMeals.insert(mealIndex + 1, _cloneMeal(meal, titleSuffix: ' (copia)')));
                    }
                    if (value == 'copy_to_day') _showCopyMealToDayDialog(meal);
                    if (value == 'template') _saveMealAsTemplate(meal);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'duplicate', child: Text('Duplicar comida')),
                    PopupMenuItem(value: 'copy_to_day', child: Text('Copiar a otro día')),
                    PopupMenuItem(value: 'template', child: Text('Guardar como plantilla')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
          ),
          if (meal.opciones.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Text('Sin alimentos. Pulsa "+" para añadir.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            )
          else
            ...meal.opciones.asMap().entries.map((entry) => _buildFoodRow(mealIndex, entry.key, entry.value, theme)),
          InkWell(
            onTap: () => _showFoodPicker(mealIndex),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline, size: 18, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Text('Añadir alimento', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodRow(int mealIndex, int optionIndex, OpcionDieta option, ThemeData theme) {
    final macros = _calculateOptionMacros(option);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Icon(_iconForOption(option.tipo), color: theme.primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(option.nombre ?? 'Alimento', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  option.tipo == 'ingrediente'
                      ? '${option.gramos?.round() ?? 0} g · ${macros.kcal.round()} kcal'
                      : option.tipo == 'combinacion'
                          ? '${option.items?.length ?? 0} ingredientes · ${macros.kcal.round()} kcal'
                          : '${macros.kcal.round()} kcal',
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: () => setState(() => _currentMeals[mealIndex].opciones.removeAt(optionIndex)),
          ),
        ],
      ),
    );
  }

  IconData _iconForOption(String tipo) {
    switch (tipo) {
      case 'receta':
        return Icons.restaurant_menu_rounded;
      case 'combinacion':
        return Icons.dashboard_customize_rounded;
      default:
        return Icons.local_dining_rounded;
    }
  }

  Widget _buildAddMealButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _currentMeals.add(
                  Comida(
                    titulo: 'Nueva Comida',
                    opciones: [],
                    totales: Macros(),
                    uniqueKey: _newKey('meal'),
                  ),
                );
              });
            },
            icon: const Icon(Icons.add),
            label: Text('Añadir comida a ${_dayNames[_selectedDay]}'),
          ),
          OutlinedButton.icon(
            onPressed: _mealTemplates.isEmpty ? null : _showTemplatePicker,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text(_mealTemplates.isEmpty ? 'Sin plantillas' : 'Usar plantilla'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCopyDayDialog(int sourceIndex) async {
    final selectedTargets = <int>{};
    final sourceName = _dayNames[sourceIndex];

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Copiar $sourceName a...'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_dayNames.length, (index) {
                if (index == sourceIndex) return const SizedBox.shrink();
                return CheckboxListTile(
                  value: selectedTargets.contains(index),
                  title: Text(_dayNames[index]),
                  subtitle: Text('${_calendarMeals[index].length} comidas actuales'),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        selectedTargets.add(index);
                      } else {
                        selectedTargets.remove(index);
                      }
                    });
                  },
                );
              }),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: selectedTargets.isEmpty
                  ? null
                  : () {
                      setState(() {
                        for (final target in selectedTargets) {
                          _calendarMeals[target] = _calendarMeals[sourceIndex]
                              .map((meal) => _cloneMeal(meal))
                              .toList();
                        }
                        _selectedDay = selectedTargets.first;
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$sourceName copiado a ${selectedTargets.length} día(s).')),
                      );
                    },
              child: const Text('Copiar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCopyMealToDayDialog(Comida meal) async {
    final selectedTargets = <int>{};

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Copiar "${meal.titulo}" a...'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_dayNames.length, (index) {
                return CheckboxListTile(
                  value: selectedTargets.contains(index),
                  title: Text(_dayNames[index]),
                  subtitle: index == _selectedDay ? const Text('Día actual') : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (checked) {
                    setDialogState(() {
                      if (checked == true) {
                        selectedTargets.add(index);
                      } else {
                        selectedTargets.remove(index);
                      }
                    });
                  },
                );
              }),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: selectedTargets.isEmpty
                  ? null
                  : () {
                      setState(() {
                        for (final target in selectedTargets) {
                          _calendarMeals[target].add(_cloneMeal(meal, titleSuffix: target == _selectedDay ? ' (copia)' : null));
                        }
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Comida copiada a ${selectedTargets.length} día(s).')),
                      );
                    },
              child: const Text('Copiar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMealAsTemplate(Comida meal) async {
    final controller = TextEditingController(text: meal.titulo);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Guardar plantilla'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nombre de la plantilla'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.post('/meal-templates', _mealTemplatePayload(name, meal));

      if ((res.statusCode == 200 || res.statusCode == 201) && mounted) {
        final saved = _MealTemplateEntry.fromJson(jsonDecode(res.body));
        setState(() => _mealTemplates.insert(0, saved));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plantilla guardada.')));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar plantilla: ${res.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar plantilla: $e')));
    }
  }

  Future<void> _showTemplatePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: _mealTemplates.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final template = _mealTemplates[index];
            final meal = template.comida;
            final macros = _calculateMealMacros(meal);
            return ListTile(
              leading: const Icon(Icons.bookmark_rounded),
              title: Text(template.nombre),
              subtitle: Text('${meal.opciones.length} alimentos · ${macros.kcal.round()} kcal'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'delete') {
                    final api = Provider.of<ApiService>(context, listen: false);
                    final templateId = template.id;
                    if (templateId != null && templateId.isNotEmpty) {
                      await api.delete('/meal-templates/$templateId');
                    }
                    if (!mounted) return;
                    setState(() => _mealTemplates.removeAt(index));
                    Navigator.pop(ctx);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Eliminar plantilla')),
                ],
              ),
              onTap: () {
                setState(() => _currentMeals.add(_cloneMeal(template.comida)));
                Navigator.pop(ctx);
              },
            );
          },
        ),
      ),
    );
  }

  void _showAddTagDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Añadir etiqueta'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Ej. Vegana, Ayuno...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) setState(() => _tags.add(controller.text.trim()));
              Navigator.pop(ctx);
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  void _showFoodPicker(int mealIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CalendarFoodPickerSheet(
        ingredientes: _ingredientes,
        recetas: _recetas,
        onSelected: (option) {
          setState(() => _currentMeals[mealIndex].opciones.add(option));
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _CalendarFoodPickerSheet extends StatefulWidget {
  final List<Ingrediente> ingredientes;
  final List<Receta> recetas;
  final ValueChanged<OpcionDieta> onSelected;

  const _CalendarFoodPickerSheet({
    required this.ingredientes,
    required this.recetas,
    required this.onSelected,
  });

  @override
  State<_CalendarFoodPickerSheet> createState() => _CalendarFoodPickerSheetState();
}

class _CalendarFoodPickerSheetState extends State<_CalendarFoodPickerSheet> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: theme.cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [Tab(text: 'Alimentos'), Tab(text: 'Recetas'), Tab(text: 'Combos')],
            indicatorColor: theme.primaryColor,
            labelColor: theme.primaryColor,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildIngredientList(), _buildRecipeList(), _buildComboCreator()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientList() {
    final filtered = widget.ingredientes
        .where((item) => item.nombre.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, index) {
        final ingrediente = filtered[index];
        return ListTile(
          title: Text(ingrediente.nombre),
          subtitle: Text('${ingrediente.kcal.round()} kcal/100g'),
          trailing: const Icon(Icons.add),
          onTap: () => _showGramDialog(ingrediente),
        );
      },
    );
  }

  Widget _buildRecipeList() {
    final filtered = widget.recetas
        .where((item) => item.nombre.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, index) {
        final receta = filtered[index];
        return ListTile(
          title: Text(receta.nombre),
          subtitle: Text('${receta.caloriasTotales.round()} kcal'),
          trailing: const Icon(Icons.add),
          onTap: () {
            widget.onSelected(
              OpcionDieta(
                tipo: 'receta',
                recetaId: receta.id,
                nombre: receta.nombre,
                uniqueKey: '${DateTime.now().microsecondsSinceEpoch}_receta',
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildComboCreator() {
    return _ActiveCalendarComboCreator(
      ingredientes: widget.ingredientes,
      onSave: (name, items) {
        widget.onSelected(
          OpcionDieta(
            tipo: 'combinacion',
            nombre: name,
            items: items,
            uniqueKey: '${DateTime.now().microsecondsSinceEpoch}_combo',
          ),
        );
      },
    );
  }

  void _showGramDialog(Ingrediente ingrediente) {
    final controller = TextEditingController(text: '100');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ingrediente.nombre),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Gramos', suffixText: 'g'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final grams = double.tryParse(controller.text.replaceAll(',', '.')) ?? 100;
              Navigator.pop(ctx);
              widget.onSelected(
                OpcionDieta(
                  tipo: 'ingrediente',
                  ingredienteId: ingrediente.id,
                  nombre: ingrediente.nombre,
                  gramos: grams,
                  uniqueKey: '${DateTime.now().microsecondsSinceEpoch}_ingrediente',
                ),
              );
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }
}


class _ActiveCalendarComboCreator extends StatefulWidget {
  final List<Ingrediente> ingredientes;
  final void Function(String name, List<CombinacionItem> items) onSave;

  const _ActiveCalendarComboCreator({required this.ingredientes, required this.onSave});

  @override
  State<_ActiveCalendarComboCreator> createState() => _ActiveCalendarComboCreatorState();
}

class _ActiveCalendarComboCreatorState extends State<_ActiveCalendarComboCreator> {
  final _nameCtrl = TextEditingController();
  final List<CombinacionItem> _items = [];
  String _query = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Nombre del combo', isDense: true),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Añadir ingrediente al combo...',
            prefixIcon: Icon(Icons.add_circle_outline),
            isDense: true,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        Expanded(child: _query.isEmpty ? _buildSelectedList(theme) : _buildSearchResults()),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _items.isEmpty
                ? null
                : () {
                    final name = _nameCtrl.text.trim().isNotEmpty
                        ? _nameCtrl.text.trim()
                        : _items.map((item) => item.nombre).whereType<String>().join(' + ');
                    widget.onSave(name.isEmpty ? 'Combo' : name, List<CombinacionItem>.from(_items));
                  },
            icon: const Icon(Icons.check_rounded),
            label: const Text('Guardar combo'),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    final filtered = widget.ingredientes
        .where((item) => item.nombre.toLowerCase().contains(_query.toLowerCase()))
        .take(20)
        .toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (_, index) {
        final ingrediente = filtered[index];
        return ListTile(
          title: Text(ingrediente.nombre),
          subtitle: Text('${ingrediente.kcal.round()} kcal/100g'),
          trailing: const Icon(Icons.add),
          onTap: () => _addIngredient(ingrediente),
        );
      },
    );
  }

  Future<void> _addIngredient(Ingrediente ingrediente) async {
    final controller = TextEditingController(text: '100');
    final grams = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Gramos de ${ingrediente.nombre}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Gramos', suffixText: 'g'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text.replaceAll(',', '.')) ?? 100),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );

    if (grams == null) return;
    setState(() {
      _items.add(CombinacionItem(ingredienteId: ingrediente.id, nombre: ingrediente.nombre, gramos: grams));
      _query = '';
    });
  }

  Widget _buildSelectedList(ThemeData theme) {
    if (_items.isEmpty) {
      return Center(
        child: Text('Busca ingredientes y añádelos al combo.', style: TextStyle(color: theme.hintColor)),
      );
    }

    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, index) {
        final item = _items[index];
        return ListTile(
          dense: true,
          title: Text(item.nombre ?? 'Ingrediente'),
          subtitle: Text('${item.gramos.toStringAsFixed(item.gramos % 1 == 0 ? 0 : 1)} g'),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _items.removeAt(index)),
          ),
        );
      },
    );
  }
}


class _MealTemplateEntry {
  final String? id;
  final String nombre;
  final String categoria;
  final Comida comida;

  const _MealTemplateEntry({
    this.id,
    required this.nombre,
    required this.categoria,
    required this.comida,
  });

  factory _MealTemplateEntry.fromJson(Map<String, dynamic> json) {
    final comidaJson = json['comida'];
    return _MealTemplateEntry(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      nombre: json['nombre']?.toString() ?? 'Plantilla',
      categoria: json['categoria']?.toString() ?? 'General',
      comida: comidaJson is Map
          ? Comida.fromJson(Map<String, dynamic>.from(comidaJson))
          : Comida(titulo: 'Plantilla', opciones: const [], totales: Macros()),
    );
  }
}
