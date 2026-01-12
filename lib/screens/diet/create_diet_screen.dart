import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/dieta_model.dart';
import '../../models/receta_model.dart';
import '../../models/ingrediente_model.dart';
import '../../models/macros_model.dart';
import '../../utils/isolate_utils.dart';
import 'diet_detail_screen.dart';

class CreateDietScreen extends StatefulWidget {
  final String clienteId;
  final String? dietaId;
  const CreateDietScreen({super.key, required this.clienteId, this.dietaId});

  @override
  State<CreateDietScreen> createState() => _CreateDietScreenState();
}

class _CreateDietScreenState extends State<CreateDietScreen>
    with TickerProviderStateMixin {
  // State
  late TabController _foodTabController;
  final TextEditingController _nameCtrl = TextEditingController(
    text: 'Nueva Dieta',
  );
  final TextEditingController _goalCtrl = TextEditingController();
  final TextEditingController _comboNameCtrl = TextEditingController();

  int _mealCount = 3;
  List<Comida> _comidas = [];
  int _activeComidaIndex = 0;
  String _selectedObjetivo = 'salud';
  List<String> _tags = [];

  // Data for selectors
  List<Receta> _recetas = [];
  List<Ingrediente> _ingredientes = [];
  bool _isLoading = false;

  // Temporary combo items
  List<CombinacionItem> _currentComboItems = [];

  final List<String> _validObjetivos = [
    'ganancia',
    'perdida',
    'definicion',
    'salud',
    'rendimiento',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.dietaId != null) {
      _loadDietToEdit();
    } else {
      _initComidas(3);
    }
    _foodTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _goalCtrl.dispose();
    _comboNameCtrl.dispose();
    _foodTabController.dispose();
    super.dispose();
  }

  Future<void> _loadDietToEdit() async {
    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get('/dietas/${widget.dietaId}');
      if (res.statusCode == 200) {
        final d = Dieta.fromJson(jsonDecode(res.body));
        if (mounted) {
          setState(() {
            _nameCtrl.text = d.nombre;
            _selectedObjetivo = d.objetivo ?? 'salud';
            _tags =
                d.notas?.split(', ').where((s) => s.isNotEmpty).toList() ?? [];
            _comidas = d.comidas;
            _mealCount = d.comidas.length;
            if (_activeComidaIndex >= _mealCount) _activeComidaIndex = 0;
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading diet: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final results = await Future.wait([
        api.get('/comidas/recetas'),
        api.get('/comidas/ingredientes'),
      ]);

      if (mounted) {
        if (results[0].statusCode == 200) {
          final recetas = await parseRecetasInIsolate(results[0].body);
          setState(() => _recetas = recetas);
        }
        if (results[1].statusCode == 200) {
          final ingredientes = await parseIngredientesInIsolate(
            results[1].body,
          );
          setState(() => _ingredientes = ingredientes);
        }
      }
    } catch (e) {
      debugPrint('Error loading food data: $e');
    }
  }

  void _initComidas(int n) {
    // Non-destructive update
    List<String> defaultNames = [
      "Desayuno",
      "Almuerzo",
      "Comida",
      "Merienda",
      "Cena",
    ];

    setState(() {
      if (_comidas.length < n) {
        // Add meals
        for (int i = _comidas.length; i < n; i++) {
          String title = i < defaultNames.length
              ? defaultNames[i]
              : "Comida ${i + 1}";
          _comidas.add(Comida(titulo: title, opciones: [], totales: Macros()));
        }
      } else if (_comidas.length > n) {
        // Remove meals (only if empty, or just pop)
        _comidas = _comidas.sublist(0, n);
      }
      _mealCount = n;
      if (_activeComidaIndex >= n) _activeComidaIndex = n - 1;
    });
  }

  // --- Calculations ---

  Map<String, double> _calculateItemMacros(OpcionDieta op) {
    double k = 0, p = 0, c = 0, g = 0;
    if (op.tipo == 'receta' && op.recetaId != null) {
      final r = _recetas.firstWhere(
        (e) => e.id == op.recetaId,
        orElse: () => Receta(id: '', nombre: '?', macrosTotales: Macros()),
      );
      k = r.caloriasTotales;
      p = r.macrosTotales.proteinas;
      c = r.macrosTotales.carbohidratos;
      g = r.macrosTotales.grasas;
    } else if (op.tipo == 'ingrediente' && op.ingredienteId != null) {
      final i = _ingredientes.firstWhere(
        (e) => e.id == op.ingredienteId,
        orElse: () => Ingrediente(id: '', nombre: '?'),
      );
      final factor = (op.gramos ?? 0) / 100.0;
      k = i.kcal * factor;
      p = i.proteinas * factor;
      c = i.carbohidratos * factor;
      g = i.grasas * factor;
    } else if (op.tipo == 'combinacion' && op.items != null) {
      for (final item in op.items!) {
        final i = _ingredientes.firstWhere(
          (e) => e.id == item.ingredienteId,
          orElse: () => Ingrediente(id: '', nombre: '?'),
        );
        final factor = item.gramos / 100.0;
        k += i.kcal * factor;
        p += i.proteinas * factor;
        c += i.carbohidratos * factor;
        g += i.grasas * factor;
      }
    }
    return {'k': k, 'p': p, 'c': c, 'g': g};
  }

  Macros _calculateMealMacros(Comida m) {
    if (m.opciones.isEmpty) return Macros();

    double k = 0, p = 0, c = 0, g = 0;
    for (final op in m.opciones) {
      final mac = _calculateItemMacros(op);
      k += mac['k']!;
      p += mac['p']!;
      c += mac['c']!;
      g += mac['g']!;
    }

    final count = m.opciones.length;
    return Macros(
      kcal: k / count,
      proteinas: p / count,
      carbohidratos: c / count,
      grasas: g / count,
    );
  }

  Macros _calculateTotalMacros() {
    double k = 0, p = 0, c = 0, g = 0;
    for (final m in _comidas) {
      final mac = _calculateMealMacros(m);
      k += mac.kcal;
      p += mac.proteinas;
      c += mac.carbohidratos;
      g += mac.grasas;
    }
    return Macros(kcal: k, proteinas: p, carbohidratos: c, grasas: g);
  }

  // --- Handlers ---

  Future<void> _handleSave() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);
    final user = auth.user;

    if (user == null || user['_id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Usuario no identificado')),
      );
      return;
    }

    final totalMacros = _calculateTotalMacros();

    final payload = {
      'clienteId': widget.clienteId,
      'asesorId': user['_id'],
      'nombre': _nameCtrl.text.isEmpty ? 'Dieta sin nombre' : _nameCtrl.text,
      'objetivo': _selectedObjetivo,
      'estado': 'borrador',
      'notas': _tags.join(', '),
      'macros': totalMacros.toJson(),
      'comidas': _comidas.map((c) {
        final mMacros = _calculateMealMacros(c);
        return {
          'titulo': c.titulo,
          'hora': c.hora ?? "",
          'notas': c.notas ?? '',
          'totales': mMacros.toJson(),
          'opciones': c.opciones.map((op) {
            Map<String, dynamic> opData = {
              'tipo': op.tipo,
              'nombre': op.nombre,
              'totales': _calculateItemMacros(op), // Optional but helpful
            };
            if (op.tipo == 'receta') {
              opData['recetaId'] = op.recetaId;
            } else if (op.tipo == 'ingrediente') {
              opData['gramos'] = op.gramos ?? 0;
              opData['ingredienteId'] = op.ingredienteId;
            } else if (op.tipo == 'combinacion') {
              opData['items'] = op.items?.map((it) => it.toJson()).toList();
            }
            return opData;
          }).toList(),
        };
      }).toList(),
    };

    setState(() => _isLoading = true);
    try {
      final res = widget.dietaId != null
          ? await api.put('/dietas/${widget.dietaId}', payload)
          : await api.post('/dietas', payload);

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          final body = jsonDecode(res.body);
          final newId = body is Map ? body['_id'] : null;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dieta guardada con éxito')),
          );
          if (newId != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DietDetailScreen(dietaId: newId),
              ),
            );
          } else {
            Navigator.pop(context);
          }
        }
      } else {
        throw Exception('Error del servidor: ${res.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addOption(OpcionDieta op) {
    setState(() => _comidas[_activeComidaIndex].opciones.add(op));
  }

  void _removeOption(int index) {
    setState(() => _comidas[_activeComidaIndex].opciones.removeAt(index));
  }

  void _showRenameMealDialog() {
    final active = _comidas[_activeComidaIndex];
    final ctrl = TextEditingController(text: active.titulo);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renombrar Comida'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nombre'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() {
                  _comidas[_activeComidaIndex] = Comida(
                    titulo: ctrl.text.trim(),
                    hora: active.hora,
                    notas: active.notas,
                    opciones: active.opciones,
                    totales: active.totales,
                  );
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showEditOptionDialog(int idx) {
    final op = _comidas[_activeComidaIndex].opciones[idx];

    if (op.tipo == 'ingrediente') {
      final ctrl = TextEditingController(text: op.gramos?.round().toString());
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Editar ${op.nombre}'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Gramos',
              suffix: Text('g'),
            ),
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final g = double.tryParse(ctrl.text) ?? 100;
                setState(() {
                  _comidas[_activeComidaIndex].opciones[idx] = OpcionDieta(
                    tipo: op.tipo,
                    ingredienteId: op.ingredienteId,
                    nombre: op.nombre,
                    gramos: g,
                  );
                });
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
    } else if (op.tipo == 'combinacion') {
      // Re-use combination logic but pre-filled
      setState(() {
        _currentComboItems = List.from(op.items ?? []);
        _comboNameCtrl.text = op.nombre ?? '';
        // Remove from list so it can be "re-added" after editing
        _comidas[_activeComidaIndex].opciones.removeAt(idx);
        // Switch to Combo tab to edit using our state managed controller
        _foodTabController.animateTo(2);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Editando combo en la pestaña correspondiente'),
        ),
      );
    }
  }

  // --- UI Components ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.dietaId != null ? 'Editar Dieta' : 'Crear Dieta'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                  ),
                  onPressed: _handleSave,
                ),
        ],
      ),
      body: _isLoading && _comidas.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMainInfo(theme, isDark),
                  const SizedBox(height: 16),
                  _buildMacroSummary(theme, isDark),
                  const SizedBox(height: 24),
                  _buildMealCountSelector(theme),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  _buildMealSelector(theme),
                  const SizedBox(height: 20),
                  _buildFoodEditor(theme, isDark),
                  const SizedBox(height: 24),
                  _buildAddedList(theme, isDark),
                  const SizedBox(height: 60),
                ],
              ),
            ),
    );
  }

  Widget _buildMainInfo(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre de la Dieta',
              hintText: 'Ej. Dieta Volumen Invernal',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),
          _buildObjectivesDropdown(theme),
          const SizedBox(height: 16),
          _buildTagInput(theme),
        ],
      ),
    );
  }

  Widget _buildObjectivesDropdown(ThemeData theme) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedObjetivo,
      decoration: const InputDecoration(
        labelText: 'Objetivo',
        prefixIcon: Icon(Icons.flag_rounded),
      ),
      items: _validObjetivos
          .map((o) => DropdownMenuItem(value: o, child: Text(o.toUpperCase())))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _selectedObjetivo = v);
      },
    );
  }

  Widget _buildTagInput(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _goalCtrl,
                decoration: const InputDecoration(
                  labelText: 'Etiquetas / Notas rápidas',
                  hintText: 'Ej. Vegana, Ayuno...',
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    setState(() {
                      _tags.add(val.trim());
                      _goalCtrl.clear();
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              icon: const Icon(Icons.add),
              onPressed: () {
                if (_goalCtrl.text.trim().isNotEmpty) {
                  setState(() {
                    _tags.add(_goalCtrl.text.trim());
                    _goalCtrl.clear();
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _tags
              .map(
                (t) => Chip(
                  label: Text(t, style: const TextStyle(fontSize: 12)),
                  onDeleted: () => setState(() => _tags.remove(t)),
                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildMacroSummary(ThemeData theme, bool isDark) {
    final macs = _calculateTotalMacros();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(isDark ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'TOTAL DIARIO ESTIMADO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _macroItem('Kcal', macs.kcal.round(), theme),
              _macroItem('Prot', '${macs.proteinas.round()}g', theme),
              _macroItem('Carb', '${macs.carbohidratos.round()}g', theme),
              _macroItem('Gras', '${macs.grasas.round()}g', theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroItem(String label, dynamic val, ThemeData theme) {
    return Column(
      children: [
        Text(
          val.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.hintColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMealCountSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'DISTRIBUCIÓN DE COMIDAS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 2, label: Text('2')),
              ButtonSegment(value: 3, label: Text('3')),
              ButtonSegment(value: 4, label: Text('4')),
              ButtonSegment(value: 5, label: Text('5')),
              ButtonSegment(value: 6, label: Text('6')),
            ],
            selected: {_mealCount},
            onSelectionChanged: (Set<int> newSelection) {
              _initComidas(newSelection.first);
            },
            style: SegmentedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 4),
              selectedBackgroundColor: theme.primaryColor,
              selectedForegroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMealSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'GESTIONAR ALIMENTOS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _activeComidaIndex,
                items: _comidas
                    .asMap()
                    .entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value.titulo),
                      ),
                    )
                    .toList(),
                onChanged: (idx) {
                  if (idx != null) setState(() => _activeComidaIndex = idx);
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              icon: const Icon(Icons.edit_rounded, size: 20),
              onPressed: _showRenameMealDialog,
              tooltip: 'Renombrar comida',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFoodEditor(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _foodTabController,
            labelColor: theme.primaryColor,
            unselectedLabelColor: theme.hintColor,
            indicatorColor: theme.primaryColor,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Alimento'),
              Tab(text: 'Receta'),
              Tab(text: 'Combo'),
            ],
          ),
          SizedBox(
            height: 380, // Increased height for better visibility
            child: TabBarView(
              controller: _foodTabController,
              children: [
                _IngredientSelector(
                  ingredientes: _ingredientes,
                  onAdd: (ing, grams) {
                    _addOption(
                      OpcionDieta(
                        tipo: 'ingrediente',
                        ingredienteId: ing.id,
                        nombre: ing.nombre,
                        gramos: grams,
                      ),
                    );
                  },
                ),
                _RecipeSelector(
                  recetas: _recetas,
                  onAdd: (rec) {
                    _addOption(
                      OpcionDieta(
                        tipo: 'receta',
                        recetaId: rec.id,
                        nombre: rec.nombre,
                      ),
                    );
                  },
                ),
                _CombinationSelector(
                  ingredientes: _ingredientes,
                  currentItems: _currentComboItems,
                  comboNameCtrl: _comboNameCtrl,
                  onAddItem: (item) {
                    setState(() {
                      _currentComboItems.add(item);
                    });
                  },
                  onRemoveItem: (index) {
                    setState(() {
                      _currentComboItems.removeAt(index);
                    });
                  },
                  onSave: () {
                    if (_currentComboItems.isEmpty) return;
                    final name = _comboNameCtrl.text.isNotEmpty
                        ? _comboNameCtrl.text
                        : _currentComboItems.map((e) => e.nombre).join(' + ');
                    _addOption(
                      OpcionDieta(
                        tipo: 'combinacion',
                        nombre: name,
                        items: List.from(_currentComboItems),
                      ),
                    );
                    setState(() {
                      _currentComboItems.clear();
                      _comboNameCtrl.clear();
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddedList(ThemeData theme, bool isDark) {
    if (_comidas.isEmpty || _activeComidaIndex >= _comidas.length) {
      return const SizedBox.shrink();
    }

    final active = _comidas[_activeComidaIndex];
    final mealMacros = _calculateMealMacros(active);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Opciones en ${active.titulo}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${mealMacros.kcal.round()} kcal',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (active.opciones.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.02)
                  : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
            ),
            child: Center(
              child: Text(
                'Vacío. Añade alimentos arriba.',
                style: TextStyle(
                  color: theme.hintColor,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: active.opciones.length,
            itemBuilder: (context, idx) {
              final op = active.opciones[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.05),
                  ),
                ),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.restaurant_rounded, size: 20),
                  title: Text(
                    op.nombre ?? op.tipo,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    op.gramos != null
                        ? '${op.gramos!.round()} g'
                        : (op.tipo == 'receta' ? 'Receta completa' : 'Combo'),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (op.tipo !=
                          'receta') // Recipes are usually fixed, or handled differently
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: Colors.blueAccent,
                          ),
                          onPressed: () => _showEditOptionDialog(idx),
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () => _removeOption(idx),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// --- Sub-Widgets ---

class _IngredientSelector extends StatefulWidget {
  final List<Ingrediente> ingredientes;
  final Function(Ingrediente, double) onAdd;
  const _IngredientSelector({required this.ingredientes, required this.onAdd});

  @override
  State<_IngredientSelector> createState() => _IngredientSelectorState();
}

class _IngredientSelectorState extends State<_IngredientSelector> {
  Ingrediente? _selected;
  final _gramsCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Autocomplete<Ingrediente>(
            optionsBuilder: (text) {
              if (text.text.isEmpty) return widget.ingredientes.take(10);
              final q = text.text.toLowerCase();
              return widget.ingredientes
                  .where((x) => x.nombre.toLowerCase().contains(q))
                  .take(20);
            },
            displayStringForOption: (x) => x.nombre,
            onSelected: (x) => setState(() => _selected = x),
            fieldViewBuilder: (ctx, ctrl, focus, onFieldSubmitted) {
              return TextField(
                controller: ctrl,
                focusNode: focus,
                decoration: const InputDecoration(
                  labelText: 'Buscar Alimento',
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Ej. Pechuga de Pollo',
                ),
                onChanged: (_) => setState(() => _selected = null),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 8,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  child: Container(
                    width: MediaQuery.of(context).size.width - 64,
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          title: Text(option.nombre),
                          subtitle: Text('${option.kcal.round()} kcal/100g'),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _gramsCtrl,
            decoration: const InputDecoration(
              labelText: 'Cantidad (gramos)',
              prefixIcon: Icon(Icons.scale_rounded),
              suffixText: 'g',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_selected == null) return;
                final g = double.tryParse(_gramsCtrl.text) ?? 0;
                if (g <= 0) return;
                widget.onAdd(_selected!, g);
                setState(() {
                  _selected = null;
                  _gramsCtrl.clear();
                });
                FocusScope.of(context).unfocus();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Añadir a la comida'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeSelector extends StatefulWidget {
  final List<Receta> recetas;
  final Function(Receta) onAdd;
  const _RecipeSelector({required this.recetas, required this.onAdd});

  @override
  State<_RecipeSelector> createState() => _RecipeSelectorState();
}

class _RecipeSelectorState extends State<_RecipeSelector> {
  Receta? _selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Autocomplete<Receta>(
            optionsBuilder: (text) {
              if (text.text.isEmpty) return widget.recetas.take(10);
              final q = text.text.toLowerCase();
              return widget.recetas
                  .where((x) => x.nombre.toLowerCase().contains(q))
                  .take(20);
            },
            displayStringForOption: (x) => x.nombre,
            onSelected: (x) => setState(() => _selected = x),
            fieldViewBuilder: (ctx, ctrl, focus, onFieldSubmitted) {
              return TextField(
                controller: ctrl,
                focusNode: focus,
                decoration: const InputDecoration(
                  labelText: 'Buscar Receta',
                  prefixIcon: Icon(Icons.restaurant_rounded),
                ),
                onChanged: (_) => setState(() => _selected = null),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 8,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  child: Container(
                    width: MediaQuery.of(context).size.width - 64,
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          title: Text(option.nombre),
                          subtitle: Text(
                            '${option.caloriasTotales.round()} kcal',
                          ),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                if (_selected == null) return;
                widget.onAdd(_selected!);
                setState(() => _selected = null);
                FocusScope.of(context).unfocus();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Añadir Receta'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CombinationSelector extends StatefulWidget {
  final List<Ingrediente> ingredientes;
  final List<CombinacionItem> currentItems;
  final TextEditingController comboNameCtrl;
  final Function(CombinacionItem) onAddItem;
  final Function(int) onRemoveItem;
  final VoidCallback onSave;

  const _CombinationSelector({
    required this.ingredientes,
    required this.currentItems,
    required this.comboNameCtrl,
    required this.onAddItem,
    required this.onRemoveItem,
    required this.onSave,
  });

  @override
  State<_CombinationSelector> createState() => _CombinationSelectorState();
}

class _CombinationSelectorState extends State<_CombinationSelector> {
  Ingrediente? _selected;
  final _gramsCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: widget.comboNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre del Combo',
              hintText: 'Ej. Ensalada Completa',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Autocomplete<Ingrediente>(
                  optionsBuilder: (text) {
                    if (text.text.isEmpty) return widget.ingredientes.take(5);
                    final q = text.text.toLowerCase();
                    return widget.ingredientes
                        .where((x) => x.nombre.toLowerCase().contains(q))
                        .take(10);
                  },
                  displayStringForOption: (x) => x.nombre,
                  onSelected: (x) => setState(() => _selected = x),
                  fieldViewBuilder: (ctx, ctrl, focus, onFieldSubmitted) {
                    return TextField(
                      controller: ctrl,
                      focusNode: focus,
                      decoration: const InputDecoration(
                        labelText: 'Ingrediente',
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() => _selected = null),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _gramsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'g',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.add_rounded, size: 20),
                onPressed: () {
                  if (_selected == null) return;
                  final g = double.tryParse(_gramsCtrl.text) ?? 0;
                  if (g <= 0) return;
                  widget.onAddItem(
                    CombinacionItem(
                      ingredienteId: _selected!.id,
                      nombre: _selected!.nombre,
                      gramos: g,
                    ),
                  );
                  setState(() {
                    _selected = null;
                    _gramsCtrl.clear();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
              ),
              child: widget.currentItems.isEmpty
                  ? const Center(
                      child: Text(
                        'Añade ingredientes al combo',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: widget.currentItems.length,
                      itemBuilder: (ctx, i) => ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          widget.currentItems[i].nombre ?? '?',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${widget.currentItems[i].gramos.round()}g',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => widget.onRemoveItem(i),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirmar Combo'),
            ),
          ),
        ],
      ),
    );
  }
}
