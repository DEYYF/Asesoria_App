import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'dart:async';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/ejercicio_model.dart';
import '../../models/entrenamiento_model.dart';
import '../../utils/isolate_utils.dart';

class CreateTrainingScreen extends StatefulWidget {
  final String? clienteId;
  final String? entrenamientoId;

  const CreateTrainingScreen({super.key, this.clienteId, this.entrenamientoId});

  @override
  State<CreateTrainingScreen> createState() => _CreateTrainingScreenState();
}

class _CreateTrainingScreenState extends State<CreateTrainingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Basic Info
  final _tituloController = TextEditingController();
  final _objetivoController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  // Data
  List<Ejercicio> _allEjercicios = [];

  // Training Structure
  List<SemanaEntrenamiento> _semanas = [];
  String? _loadedClienteId;

  // UI State
  int _selectedWeekIdx = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = Provider.of<ApiService>(context, listen: false);

    // 1. Load Exercises
    try {
      final res = await api.get(
        '/ejercicios',
        params: {'t': DateTime.now().millisecondsSinceEpoch.toString()},
      );
      if (res.statusCode == 200) {
        final ejercicios = await parseEjerciciosInIsolate(res.body);
        _allEjercicios = ejercicios;
      }
    } catch (e) {
      // Silent fail on init
    }

    // 2. Load Training if Editing
    if (widget.entrenamientoId != null) {
      try {
        final res = await api.get('/entrenamientos/${widget.entrenamientoId}');
        if (res.statusCode == 200) {
          final ent = Entrenamiento.fromJson(jsonDecode(res.body));
          _tituloController.text = ent.titulo;
          _objetivoController.text = ent.objetivo ?? '';
          _semanas = ent.semanas;
          _loadedClienteId = ent.clienteId;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error cargando plan: $e')));
        }
      }
    } else {
      // New Plan
      _loadedClienteId = widget.clienteId;
      _addSemana();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // --- Logic Helpers ---

  void _addSemana() {
    setState(() {
      _semanas.add(
        SemanaEntrenamiento(
          numero: _semanas.length + 1,
          dias: [DiaEntrenamiento(nombre: 'Día 1', items: [])],
        ),
      );
      // Switch to new week
      _selectedWeekIdx = _semanas.length - 1;
    });
  }

  void _copySemana(int idx) {
    setState(() {
      final original = _semanas[idx];
      // Deep copy logic
      final newDias = original.dias.map((d) {
        final newItems = d.items.map((i) => _cloneItem(i)).toList();
        return DiaEntrenamiento(nombre: d.nombre, items: newItems);
      }).toList();

      _semanas.add(
        SemanaEntrenamiento(numero: _semanas.length + 1, dias: newDias),
      );
      _selectedWeekIdx = _semanas.length - 1;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Semana duplicada')));
  }

  void _addDia(int weekIdx) {
    setState(() {
      final week = _semanas[weekIdx];
      week.dias.add(
        DiaEntrenamiento(nombre: 'Día ${week.dias.length + 1}', items: []),
      );
    });
  }

  void _copyDia(int weekIdx, int dayIdx) {
    setState(() {
      final original = _semanas[weekIdx].dias[dayIdx];
      final newItems = original.items.map((i) => _cloneItem(i)).toList();

      _semanas[weekIdx].dias.add(
        DiaEntrenamiento(nombre: '${original.nombre} (Copia)', items: newItems),
      );
    });
  }

  ItemEntrenamiento _cloneItem(ItemEntrenamiento item) {
    return item.copyWith(
      uniqueKey: DateTime.now().microsecondsSinceEpoch.toString() + '_copy',
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_semanas.isEmpty) return;

    setState(() => _isSaving = true);
    final auth = Provider.of<AuthService>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);
    final asesorId = auth.user?['_id'] ?? auth.user?['id'];

    if (asesorId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No se identificó al asesor')),
        );
      }
      setState(() => _isSaving = false);
      return;
    }

    // Validate loaded client ID
    if (_loadedClienteId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Falta ID del Cliente')),
        );
      }
      setState(() => _isSaving = false);
      return;
    }

    try {
      final ent = Entrenamiento(
        id: widget.entrenamientoId,
        clienteId: _loadedClienteId!,
        asesorId: asesorId,
        titulo: _tituloController.text.trim(),
        objetivo: _objetivoController.text.trim(),
        semanas: _semanas,
      );

      final payload = ent.toJson();

      final res = widget.entrenamientoId != null
          ? await api.put('/entrenamientos/${widget.entrenamientoId}', payload)
          : await api.post('/entrenamientos', payload);

      if (res.statusCode == 201 || res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entrenamiento guardado')),
          );
          context.pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${res.body}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error excepción: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- Widgets ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Cargando...'),
          backgroundColor: theme.scaffoldBackgroundColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_selectedWeekIdx >= _semanas.length) {
      _selectedWeekIdx = 0;
    }
    if (_semanas.isEmpty) {
      return const Scaffold(body: Center(child: Text("Sin semanas")));
    }

    final currentSemana = _semanas[_selectedWeekIdx];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.entrenamientoId != null
              ? 'Editar Entrenamiento'
              : 'Crear Entrenamiento',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: theme.textTheme.bodyLarge?.color),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _isSaving ? null : _handleSave,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
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
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildMetaHeader(theme),
            _buildWeekSelector(theme),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  ...currentSemana.dias.asMap().entries.map((entry) {
                    return _buildDiaCard(
                      _selectedWeekIdx,
                      entry.key,
                      entry.value,
                    );
                  }),

                  const SizedBox(height: 16),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () => _addDia(_selectedWeekIdx),
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir Día'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          TextFormField(
            controller: _tituloController,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Título del Plan (ej. Hipertrofia Fase 1)',
              hintStyle: TextStyle(color: theme.disabledColor),
              isDense: true,
              border: InputBorder.none,
            ),
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
          const Divider(height: 1),
          TextFormField(
            controller: _objetivoController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Objetivo y notas generales...',
              hintStyle: TextStyle(color: theme.disabledColor, fontSize: 13),
              isDense: true,
              border: InputBorder.none,
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildWeekSelector(ThemeData theme) {
    return Container(
      height: 60,
      width: double.infinity,
      color: theme.scaffoldBackgroundColor,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: _semanas.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, idx) {
          if (idx == _semanas.length) {
            return IconButton.filledTonal(
              onPressed: _addSemana,
              icon: const Icon(Icons.add),
              tooltip: 'Añadir Semana',
            );
          }
          final sem = _semanas[idx];
          final isSelected = idx == _selectedWeekIdx;
          return _buildCapsuleTab(
            theme,
            label: 'Semana ${sem.numero}',
            isSelected: isSelected,
            onTap: () => setState(() => _selectedWeekIdx = idx),
            onLongPress: () => _copySemana(idx),
          );
        },
      ),
    );
  }

  Widget _buildCapsuleTab(
    ThemeData theme, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : theme.dividerColor.withOpacity(0.1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildDiaCard(int weekIdx, int dayIdx, DiaEntrenamiento dia) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: theme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: dia.nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: theme.primaryColor,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Nombre del día',
                    ),
                    onChanged: (v) {
                      setState(() {
                        dia.nombre = v;
                      });
                    },
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 20, color: theme.hintColor),
                  onSelected: (val) {
                    if (val == 'dup') _copyDia(weekIdx, dayIdx);
                    if (val == 'del') {
                      setState(() {
                        _semanas[weekIdx].dias.removeAt(dayIdx);
                      });
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'dup',
                      child: Row(
                        children: [
                          Icon(Icons.copy, size: 16),
                          SizedBox(width: 8),
                          Text('Duplicar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'del',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (dia.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Añade ejercicios a este día',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              proxyDecorator: (child, _, __) => Material(
                elevation: 4,
                color: Colors.transparent,
                child: child,
              ),
              itemCount: dia.items.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = dia.items.removeAt(oldIndex);
                  dia.items.insert(newIndex, item);
                  for (var i = 0; i < dia.items.length; i++) {
                    dia.items[i] = dia.items[i].copyWith(orden: i);
                  }
                });
              },
              itemBuilder: (context, itemIdx) {
                final item = dia.items[itemIdx];
                return _buildExerciseRow(weekIdx, dayIdx, itemIdx, item);
              },
            ),

          InkWell(
            onTap: () => _showExercisePicker(context, weekIdx, dayIdx),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.dividerColor.withOpacity(0.05)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 18,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Añadir Ejercicio',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseRow(
    int wIdx,
    int dIdx,
    int iIdx,
    ItemEntrenamiento item,
  ) {
    final theme = Theme.of(context);
    final key = ValueKey(item.uniqueKey);

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      color: theme.cardColor,
      child: Column(
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: iIdx,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.drag_indicator,
                    color: theme.disabledColor,
                    size: 20,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.ejercicioNombre ?? 'Ejercicio',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (item.ejercicio?.grupo != null)
                      Text(
                        item.ejercicio!.grupo!,
                        style: TextStyle(color: theme.hintColor, fontSize: 10),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: theme.disabledColor),
                onPressed: () {
                  setState(() {
                    _semanas[wIdx].dias[dIdx].items.removeAt(iIdx);
                  });
                },
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.only(left: 36, right: 12, bottom: 8),
            child: Row(
              children: [
                _OptimizedMiniInput(
                  label: 'Series',
                  val: item.esquema?.series,
                  onChange: (v) => _updateSchema(wIdx, dIdx, iIdx, 'series', v),
                ),
                const SizedBox(width: 6),
                _OptimizedMiniInput(
                  label: 'Reps',
                  val: item.esquema?.repsMin,
                  onChange: (v) =>
                      _updateSchema(wIdx, dIdx, iIdx, 'repsMin', v),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '-',
                    style: TextStyle(color: theme.disabledColor),
                  ),
                ),
                _OptimizedMiniInput(
                  label: 'Max',
                  val: item.esquema?.repsMax,
                  onChange: (v) =>
                      _updateSchema(wIdx, dIdx, iIdx, 'repsMax', v),
                ),
                const SizedBox(width: 6),
                _OptimizedMiniInput(
                  label: 'RIR',
                  val: item.esquema?.rir,
                  onChange: (v) => _updateSchema(wIdx, dIdx, iIdx, 'rir', v),
                ),
                const SizedBox(width: 6),
                _OptimizedMiniInput(
                  label: 'Desc (s)',
                  val: item.esquema?.descanso,
                  onChange: (v) =>
                      _updateSchema(wIdx, dIdx, iIdx, 'descanso', v),
                  flex: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Timer? _debounceTimer;
  void _updateSchema(int wIdx, int dIdx, int iIdx, String field, String val) {
    final dia = _semanas[wIdx].dias[dIdx];
    final item = dia.items[iIdx];
    final currentE = item.esquema ?? EsquemaSerie();

    EsquemaSerie nextE;
    switch (field) {
      case 'series':
        nextE = currentE.copyWith(series: int.tryParse(val));
        break;
      case 'repsMin':
        nextE = currentE.copyWith(repsMin: int.tryParse(val));
        break;
      case 'repsMax':
        nextE = currentE.copyWith(repsMax: int.tryParse(val));
        break;
      case 'rir':
        nextE = currentE.copyWith(rir: num.tryParse(val));
        break;
      case 'descanso':
        nextE = currentE.copyWith(descanso: int.tryParse(val));
        break;
      default:
        nextE = currentE;
    }

    dia.items[iIdx] = item.copyWith(esquema: nextE);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() {});
    });
  }

  void _showExercisePicker(BuildContext mainCtx, int wIdx, int dIdx) {
    showDialog(
      context: mainCtx,
      builder: (ctx) => _ExerciseSearchDialog(
        ejercicios: _allEjercicios,
        onSelected: (ej) {
          setState(() {
            final dia = _semanas[wIdx].dias[dIdx];
            dia.items.add(
              ItemEntrenamiento(
                orden: dia.items.length,
                ejercicio: ej,
                ejercicioId: ej.id,
                ejercicioNombre: ej.nombre,
                esquema: EsquemaSerie(
                  series: 3,
                  repsMin: 8,
                  repsMax: 12,
                  rir: 2,
                  descanso: 90,
                ),
                uniqueKey:
                    DateTime.now().microsecondsSinceEpoch.toString() +
                    '_' +
                    (ej.id ?? 'none'),
              ),
            );
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _OptimizedMiniInput extends StatefulWidget {
  final String label;
  final num? val;
  final Function(String) onChange;
  final int flex;

  const _OptimizedMiniInput({
    required this.label,
    required this.val,
    required this.onChange,
    this.flex = 1,
  });

  @override
  State<_OptimizedMiniInput> createState() => _OptimizedMiniInputState();
}

class _OptimizedMiniInputState extends State<_OptimizedMiniInput> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.val?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _OptimizedMiniInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.val != oldWidget.val) {
      if (_ctrl.text != widget.val?.toString()) {
        _ctrl.text = widget.val?.toString() ?? '';
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      flex: widget.flex,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          controller: _ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: widget.label,
            hintStyle: TextStyle(fontSize: 10, color: theme.disabledColor),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onChanged: widget.onChange,
        ),
      ),
    );
  }
}

class _ExerciseSearchDialog extends StatefulWidget {
  final List<Ejercicio> ejercicios;
  final Function(Ejercicio) onSelected;

  const _ExerciseSearchDialog({
    required this.ejercicios,
    required this.onSelected,
  });

  @override
  State<_ExerciseSearchDialog> createState() => _ExerciseSearchDialogState();
}

class _ExerciseSearchDialogState extends State<_ExerciseSearchDialog> {
  List<Ejercicio> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.ejercicios;
  }

  void _filter(String q) {
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.ejercicios;
      } else {
        _filtered = widget.ejercicios
            .where((e) => e.nombre.toLowerCase().contains(q.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 500,
        child: Column(
          children: [
            Text('Seleccionar Ejercicio', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                filled: true,
                fillColor: theme.scaffoldBackgroundColor,
              ),
              onChanged: _filter,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final e = _filtered[i];
                  return ListTile(
                    title: Text(e.nombre),
                    subtitle: Text(e.grupo ?? ''),
                    onTap: () => widget.onSelected(e),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
