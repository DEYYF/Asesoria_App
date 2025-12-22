import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/ejercicio_model.dart';
import '../../models/entrenamiento_model.dart';

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
        final dynamic decoded = jsonDecode(res.body);
        List list = [];
        if (decoded is List)
          list = decoded;
        else if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('items'))
            list = decoded['items'];
          else if (decoded.containsKey('ejercicios'))
            list = decoded['ejercicios'];
        }
        _allEjercicios = list.map((e) => Ejercicio.fromJson(e)).toList();
      }
    } catch (e) {
      // Silent fail on init, showing later? Or SnackBar
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
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error cargando plan: $e')));
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
    final s = item.esquema ?? EsquemaSerie();
    return ItemEntrenamiento(
      orden: item.orden,
      ejercicio: item.ejercicio,
      ejercicioId: item.ejercicioId,
      ejercicioNombre: item.ejercicioNombre,
      grupoId: item.grupoId,
      esquema: EsquemaSerie(
        series: s.series,
        repsMin: s.repsMin,
        repsMax: s.repsMax,
        rir: s.rir,
        descanso: s.descanso,
        notas: s.notas,
      ),
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Falta ID del Cliente')),
        );
      setState(() => _isSaving = false);
      return;
    }

    try {
      final ent = Entrenamiento(
        id: widget.entrenamientoId, // Include ID if editing
        clienteId: _loadedClienteId!, // Use loaded or passed ID
        asesorId: asesorId,
        titulo: _tituloController.text.trim(),
        objetivo: _objetivoController.text.trim(),
        semanas: _semanas,
      );

      // Add ToJson payload
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
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${res.body}')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error excepción: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- Widgets ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.entrenamientoId != null
              ? 'Editar Entrenamiento'
              : 'Crear Entrenamiento',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: theme.textTheme.titleLarge?.color,
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _handleSave,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Guardar'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _tituloController,
                      decoration: const InputDecoration(
                        labelText: 'Título del Plan',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _objetivoController,
                      decoration: const InputDecoration(
                        labelText: 'Objetivo Principal',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flag),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Weeks
            ..._semanas.asMap().entries.map(
              (entry) => _buildSemanaCard(entry.key, entry.value),
            ),

            const SizedBox(height: 24),

            // Add Week Button
            Center(
              child: OutlinedButton.icon(
                onPressed: _addSemana,
                icon: const Icon(Icons.add),
                label: const Text('Añadir Semana'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSemanaCard(int weekIdx, SemanaEntrenamiento semana) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Week Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Semana ${semana.numero}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        size: 20,
                        color: Colors.blue,
                      ),
                      onPressed: () => _copySemana(weekIdx),
                      tooltip: 'Duplicar Semana',
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 20,
                        color: Colors.red,
                      ),
                      onPressed: () {
                        setState(() {
                          _semanas.removeAt(weekIdx);
                        });
                      },
                      tooltip: 'Eliminar Semana',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Days
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ...semana.dias.asMap().entries.map(
                  (dEntry) => _buildDiaCard(weekIdx, dEntry.key, dEntry.value),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _addDia(weekIdx),
                  icon: const Icon(Icons.add_circle, size: 16),
                  label: const Text('Añadir Día'),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    foregroundColor: theme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaCard(int weekIdx, int dayIdx, DiaEntrenamiento dia) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Day Title Row
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: theme.hintColor),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: dia.nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleSmall?.color,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Nombre del día (ej. Pecho/Tríceps)',
                      hintStyle: TextStyle(color: theme.hintColor),
                    ),
                    onChanged: (v) {
                      setState(() {
                        // In-place update of mutable object
                        // Actually need to replace object in list to trigger update if immutable
                        // Assuming mutable list in Semana but Dia fields might be final?
                        // Re-constructing Dia to be safe:
                        final items = dia.items;
                        _semanas[weekIdx].dias[dayIdx] = DiaEntrenamiento(
                          nombre: v,
                          items: items,
                        );
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.copy,
                    size: 18,
                    color: Colors.blueGrey,
                  ),
                  onPressed: () => _copyDia(weekIdx, dayIdx),
                  tooltip: 'Duplicar Día',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _semanas[weekIdx].dias.removeAt(dayIdx);
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Reorderable List of Exercises
          // Using ReorderableListView inside a column needs physics limit and shrinkwrap
          if (dia.items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Sin ejercicios',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.hintColor),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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
                  // Update orden property
                  for (var i = 0; i < dia.items.length; i++) {
                    // Again, need to reconstruct ItemEntrenamiento if fields are final
                    final it = dia.items[i];
                    dia.items[i] = ItemEntrenamiento(
                      orden: i,
                      ejercicio: it.ejercicio,
                      ejercicioId: it.ejercicioId,
                      ejercicioNombre: it.ejercicioNombre,
                      grupoId: it.grupoId,
                      esquema: it.esquema,
                    );
                  }
                  // Re-assign dia to refresh state deeply check
                  _semanas[weekIdx].dias[dayIdx] = DiaEntrenamiento(
                    nombre: dia.nombre,
                    items: dia.items,
                  );
                });
              },
              itemBuilder: (context, itemIdx) {
                final item = dia.items[itemIdx];
                return Container(
                  key: ValueKey('${item.ejercicioId}_$itemIdx'),
                  child: _buildExerciseRow(weekIdx, dayIdx, itemIdx, item),
                );
              },
            ),

          // Add Exercise Button
          Container(
            padding: const EdgeInsets.all(8),
            color: isDark
                ? Colors.white.withOpacity(0.02)
                : Colors.grey.shade50,
            child: TextButton.icon(
              onPressed: () => _showExercisePicker(context, weekIdx, dayIdx),
              icon: const Icon(Icons.add),
              label: const Text('Añadir Ejercicio'),
              style: TextButton.styleFrom(foregroundColor: theme.primaryColor),
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: theme.cardColor, // Required for dragging visuals
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: Icon(Icons.drag_indicator, color: theme.hintColor),
            title: Text(
              item.ejercicioNombre ?? 'Ejercicio',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            subtitle: Text(
              item.ejercicio?.grupo ?? 'General',
              style: TextStyle(color: theme.hintColor),
            ),
            trailing: IconButton(
              icon: Icon(Icons.close, size: 18, color: theme.hintColor),
              onPressed: () {
                setState(() {
                  _semanas[wIdx].dias[dIdx].items.removeAt(iIdx);
                });
              },
            ),
          ),
          // Schema Inputs Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                _miniInput(
                  'Series',
                  item.esquema?.series,
                  (v) => _updateSchema(wIdx, dIdx, iIdx, 'series', v),
                ),
                const SizedBox(width: 8),
                _miniInput(
                  'Reps',
                  item.esquema?.repsMin,
                  (v) => _updateSchema(wIdx, dIdx, iIdx, 'repsMin', v),
                ), // Simplify to just repsMin/target for now? Or Range
                const Text(' - ', style: TextStyle(color: Colors.grey)),
                _miniInput(
                  'Max',
                  item.esquema?.repsMax,
                  (v) => _updateSchema(wIdx, dIdx, iIdx, 'repsMax', v),
                ),
                const SizedBox(width: 8),
                _miniInput(
                  'RIR',
                  item.esquema?.rir,
                  (v) => _updateSchema(wIdx, dIdx, iIdx, 'rir', v),
                ),
                const SizedBox(width: 8),
                _miniInput(
                  'Desc (s)',
                  item.esquema?.descanso,
                  (v) => _updateSchema(wIdx, dIdx, iIdx, 'descanso', v),
                  flex: 2,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _miniInput(
    String label,
    num? val,
    Function(String) onChange, {
    int flex = 1,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: theme.hintColor)),
          SizedBox(
            height: 32,
            child: TextFormField(
              initialValue: val?.toString() ?? '',
              keyboardType: TextInputType.number,
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
              ),
              onChanged: onChange,
            ),
          ),
        ],
      ),
    );
  }

  // Logic to show dialog
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
              ),
            );
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _updateSchema(int wIdx, int dIdx, int iIdx, String field, String val) {
    setState(() {
      final dia = _semanas[wIdx].dias[dIdx];
      final item = dia.items[iIdx];
      final old = item.esquema ?? EsquemaSerie();
      num? n = num.tryParse(val);

      dia.items[iIdx] = ItemEntrenamiento(
        orden: item.orden,
        ejercicio: item.ejercicio,
        ejercicioId: item.ejercicioId,
        ejercicioNombre: item.ejercicioNombre,
        grupoId: item.grupoId,
        esquema: EsquemaSerie(
          series: field == 'series' ? (n?.toInt() ?? old.series) : old.series,
          repsMin: field == 'repsMin'
              ? (n?.toInt() ?? old.repsMin)
              : old.repsMin,
          repsMax: field == 'repsMax'
              ? (n?.toInt() ?? old.repsMax)
              : old.repsMax,
          rir: field == 'rir' ? (n ?? old.rir) : old.rir,
          descanso: field == 'descanso'
              ? (n?.toInt() ?? old.descanso)
              : old.descanso,
          notas: old.notas,
        ),
      );
    });
  }
}

// Helper Dialog
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
  String _query = '';
  String? _filterGroup;

  @override
  Widget build(BuildContext context) {
    // Unique groups
    final groups = widget.ejercicios
        .map((e) => e.grupo)
        .where((g) => g != null)
        .toSet()
        .toList();

    final filtered = widget.ejercicios.where((e) {
      final matchesSearch = e.nombre.toLowerCase().contains(
        _query.toLowerCase(),
      );
      final matchesGroup = _filterGroup == null || e.grupo == _filterGroup;
      return matchesSearch && matchesGroup;
    }).toList();

    return AlertDialog(
      title: const Text('Seleccionar Ejercicio'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _filterGroup == null,
                    onSelected: (b) => setState(() => _filterGroup = null),
                  ),
                  const SizedBox(width: 8),
                  ...groups.map(
                    (g) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(g!),
                        selected: _filterGroup == g,
                        onSelected: (b) =>
                            setState(() => _filterGroup = b ? g : null),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No se encontraron ejercicios',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final e = filtered[index];
                        return ListTile(
                          title: Text(e.nombre),
                          subtitle: Text(
                            '${e.grupo ?? '-'} | ${e.equipo ?? '-'}',
                          ),
                          onTap: () => widget.onSelected(e),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
