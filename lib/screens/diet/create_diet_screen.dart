import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/dieta_model.dart';
import '../../models/receta_model.dart';
import '../../models/ingrediente_model.dart';
import '../../models/macros_model.dart';
import 'diet_detail_screen.dart';

// ...

// Logic Helpers

class CreateDietScreen extends StatefulWidget {
  final String clienteId;
  final String? dietaId;
  const CreateDietScreen({super.key, required this.clienteId, this.dietaId});

  @override
  State<CreateDietScreen> createState() => _CreateDietScreenState();
}

class _CreateDietScreenState extends State<CreateDietScreen> {
  int _mealCount = 3;
  List<Comida> _comidas = [];
  int _activeComidaIndex = 0;

  // Data
  List<Receta> _recetas = [];
  List<Ingrediente> _ingredientes = [];
  bool _isLoading = false; // Match React: render immediately

  @override
  void initState() {
    super.initState();
    _loadData(); // Load catalogs
    if (widget.dietaId != null) {
      _loadDietToEdit();
    } else {
      _initComidas(3);
    }
  }

  Future<void> _loadDietToEdit() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get('/dietas/${widget.dietaId}');
      if (res.statusCode == 200) {
        final d = Dieta.fromJson(jsonDecode(res.body));
        if (mounted) {
          setState(() {
            _selectedObjetivo = d.objetivo ?? 'salud';
            _goals = d.notas?.split(', ') ?? [];
            _comidas = d.comidas; // Direct model reuse
            _mealCount = d.comidas.length;
            if (_activeComidaIndex >= _mealCount) _activeComidaIndex = 0;
            if (_mealCount == 0) _initComidas(3); // Fallback
          });
        }
      } else {
        throw Exception('Failed to load diet');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando dieta: $e')));
      }
    }
  }

  Future<void> _loadData() async {
    final api = Provider.of<ApiService>(context, listen: false);
    // Parallel fetch like React's independent promises
    try {
      final results = await Future.wait([
        api.get('/comidas/recetas'),
        api.get('/comidas/ingredientes'),
      ]);

      final resRecetas = results[0];
      final resIngredientes = results[1];

      if (mounted) {
        setState(() {
          if (resRecetas.statusCode == 200) {
            final List list = jsonDecode(resRecetas.body);
            _recetas = list.map((e) => Receta.fromJson(e)).toList();
          }
          if (resIngredientes.statusCode == 200) {
            final List list = jsonDecode(resIngredientes.body);
            _ingredientes = list.map((e) => Ingrediente.fromJson(e)).toList();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
      }
      print('Error loading food data: $e');
    }
  }

  void _initComidas(int n) {
    List<String> names = [];
    switch (n) {
      case 2:
        names = ["Comida", "Cena"];
        break;
      case 3:
        names = ["Desayuno", "Comida", "Cena"];
        break;
      case 4:
        names = ["Desayuno", "Comida", "Merienda", "Cena"];
        break;
      case 5:
        names = ["Desayuno", "Almuerzo", "Comida", "Merienda", "Cena"];
        break;
      default:
        names = List.generate(n, (i) => "Comida ${i + 1}");
    }

    setState(() {
      _comidas = names
          .map((name) => Comida(titulo: name, opciones: [], totales: Macros()))
          .toList();
      _activeComidaIndex = 0;
      _mealCount = n;
    });
  }

  // State
  String _selectedObjetivo = 'salud';
  final List<String> _validObjetivos = [
    'ganancia',
    'perdida',
    'definicion',
    'salud',
    'rendimiento',
  ];
  List<String> _goals = [];
  final _goalCtrl = TextEditingController();

  // Combination Tab State
  List<CombinacionItem> _currentComboItems = [];
  final _comboNameCtrl = TextEditingController();

  // Logic Helpers
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

  Map<String, double> _calculateMealMacros(Comida m) {
    double k = 0, p = 0, c = 0, g = 0;
    if (m.opciones.isEmpty) return {'k': 0, 'p': 0, 'c': 0, 'g': 0};

    for (final op in m.opciones) {
      final mac = _calculateItemMacros(op);
      k += mac['k']!;
      p += mac['p']!;
      c += mac['c']!;
      g += mac['g']!;
    }

    // React parity: Meal macros are the AVERAGE of the options (Mean)
    // because the user usually selects one of the options to eat.
    final count = m.opciones.length;
    return {'k': k / count, 'p': p / count, 'c': c / count, 'g': g / count};
  }

  Map<String, double> _calculateTotalMacros() {
    double k = 0, p = 0, c = 0, g = 0;
    for (final m in _comidas) {
      final mac = _calculateMealMacros(m);
      k += mac['k']!;
      p += mac['p']!;
      c += mac['c']!;
      g += mac['g']!;
    }
    return {'k': k, 'p': p, 'c': c, 'g': g};
  }

  @override
  void dispose() {
    _goalCtrl.dispose();
    _comboNameCtrl.dispose();
    super.dispose();
  }

  // --- Actions ---

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

    // Calculate Macros
    final macs = _calculateTotalMacros();

    // Construct Body
    final dieta = {
      'clienteId': widget.clienteId,
      'asesorId': user['_id'],
      'nombre': 'Dieta',
      'objetivo': _selectedObjetivo, // Use valid enum
      'estado': 'borrador',
      'notas': _goals.join(
        ', ',
      ), // Put chips in notes or ignore? React ignores them in "objetivo" field.
      'macros': {
        'kcal': macs['k'],
        'p': macs['p'],
        'c': macs['c'],
        'g': macs['g'],
      },
      'comidas': _comidas.map((c) {
        return {
          'titulo': c.titulo,
          'hora':
              c.hora ??
              "", // Send empty string if null, or omit? Backend said "expected string, received null", so string is safe.
          'notas': c.notas ?? '',
          'opciones': c.opciones.map((op) {
            Map<String, dynamic> payload = {};

            if (op.tipo == 'receta') {
              payload = {'tipo': 'receta', 'nombre': op.nombre};
              if (op.recetaId != null && op.recetaId!.isNotEmpty) {
                payload['recetaId'] = op.recetaId;
              }
            } else if (op.tipo == 'ingrediente') {
              payload = {
                'tipo': 'ingrediente',
                'nombre': op.nombre,
                'gramos': op.gramos ?? 0,
                'unidades': op.unidades,
              };
              if (op.ingredienteId != null && op.ingredienteId!.isNotEmpty) {
                payload['ingredienteId'] = op.ingredienteId;
              }
            } else if (op.tipo == 'combinacion') {
              payload = {
                'tipo': 'combinacion',
                'nombre': op.nombre,
                'items': op.items
                    ?.where((it) => it.ingredienteId.isNotEmpty)
                    .map(
                      (it) => {
                        'ingredienteId': it.ingredienteId,
                        'nombre': it.nombre,
                        'gramos': it.gramos,
                      },
                    )
                    .toList(),
                'notas': '',
              };
            }

            // Cleanup nulls
            payload.removeWhere((key, value) => value == null);
            return payload;
          }).toList(),
        };
      }).toList(),
    };

    try {
      final isEdit = widget.dietaId != null;
      final res = isEdit
          ? await api.put('/dietas/${widget.dietaId}', dieta)
          : await api.post('/dietas', dieta);

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          final body = jsonDecode(res.body);
          final newId = body is Map ? body['_id'] : null;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dieta guardada con éxito')),
          );

          if (newId != null && newId is String) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DietDetailScreen(dietaId: newId),
              ),
            );
          } else {
            Navigator.pop(context); // Fallback
          }
        }
      } else {
        throw Exception(res.body);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    }
  }

  void _addOption(OpcionDieta op) {
    setState(() {
      _comidas[_activeComidaIndex].opciones.add(op);
    });
  }

  void _removeOption(int index) {
    setState(() {
      _comidas[_activeComidaIndex].opciones.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dietaId != null ? 'Editar Dieta' : 'Crear Dieta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              if (_comidas.every((c) => c.opciones.isEmpty)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('La dieta está vacía')),
                );
                return;
              }
              _handleSave();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          if (_comidas.every((c) => c.opciones.isEmpty)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('La dieta está vacía'),
                              ),
                            );
                            return;
                          }
                          _handleSave();
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar Dieta'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildMealCountSelector(),
                  const SizedBox(height: 16),
                  _buildObjectives(),
                  const SizedBox(height: 16),
                  if (_comidas.isNotEmpty) ...[
                    _buildSummary(),
                    const Divider(height: 32),
                    _buildMealSelector(),
                    const SizedBox(height: 16),
                    _buildFoodEditor(),
                    const SizedBox(height: 16),
                    _buildAddedList(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildObjectives() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Objetivo Principal',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            DropdownButtonFormField<String>(
              value: _selectedObjetivo,
              items: _validObjetivos
                  .map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Text(o.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedObjetivo = v);
              },
              decoration: const InputDecoration(isDense: true),
            ),
            const SizedBox(height: 16),
            const Text(
              'Etiquetas / Notas',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _goalCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Ej. Ganar masa muscular',
                      isDense: true,
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        setState(() {
                          _goals.add(val.trim());
                          _goalCtrl.clear();
                        });
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_goalCtrl.text.trim().isNotEmpty) {
                      setState(() {
                        _goals.add(_goalCtrl.text.trim());
                        _goalCtrl.clear();
                      });
                    }
                  },
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: _goals
                  .map(
                    (g) => Chip(
                      label: Text(g),
                      onDeleted: () => setState(() => _goals.remove(g)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final macs = _calculateTotalMacros();
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _macroItem('Kcal', macs['k']!.round()),
            _macroItem('Prot', macs['p']!.toStringAsFixed(1)),
            _macroItem('Carb', macs['c']!.toStringAsFixed(1)),
            _macroItem('Gras', macs['g']!.toStringAsFixed(1)),
          ],
        ),
      ),
    );
  }

  Widget _macroItem(String label, dynamic val) {
    return Column(
      children: [
        Text(
          val.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMealCountSelector() {
    return Column(
      children: [
        const Text(
          'Número de comidas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 2, label: Text('2')),
            ButtonSegment(value: 3, label: Text('3')),
            ButtonSegment(value: 4, label: Text('4')),
            ButtonSegment(value: 5, label: Text('5')),
          ],
          selected: {_mealCount},
          onSelectionChanged: (Set<int> newSelection) {
            _initComidas(newSelection.first);
          },
        ),
      ],
    );
  }

  Widget _buildMealSelector() {
    return DropdownButtonFormField<int>(
      initialValue: _activeComidaIndex,
      items: _comidas.asMap().entries.map((e) {
        return DropdownMenuItem(value: e.key, child: Text(e.value.titulo));
      }).toList(),
      onChanged: (idx) {
        if (idx != null) setState(() => _activeComidaIndex = idx);
      },
      decoration: const InputDecoration(
        labelText: 'Comida Activa',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildFoodEditor() {
    return Card(
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Alimento'),
                Tab(text: 'Receta'),
                Tab(text: 'Combinación'),
              ],
            ),
            SizedBox(
              height: 300,
              child: TabBarView(
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
      ),
    );
  }

  Widget _buildAddedList() {
    final active = _comidas[_activeComidaIndex];
    final macs = _calculateMealMacros(active);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Opciones en ${active.titulo}:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${macs['k']!.round()} kcal (P:${macs['p']!.round()} C:${macs['c']!.round()} G:${macs['g']!.round()})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (active.opciones.isEmpty)
          const Text(
            'No hay alimentos añadidos',
            style: TextStyle(color: Colors.grey),
          ),
        ...active.opciones.asMap().entries.map((entry) {
          final idx = entry.key;
          final op = entry.value;
          return ListTile(
            title: Text(op.nombre ?? op.tipo),
            subtitle: op.gramos != null ? Text('${op.gramos} g') : null,
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeOption(idx),
            ),
          );
        }),
      ],
    );
  }
}

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
              if (text.text.isEmpty) return widget.ingredientes;
              return widget.ingredientes.where(
                (x) => x.nombre.toLowerCase().contains(text.text.toLowerCase()),
              );
            },
            displayStringForOption: (x) => x.nombre,
            onSelected: (x) => setState(() => _selected = x),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _gramsCtrl,
            decoration: const InputDecoration(labelText: 'Gramos'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (_selected == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Por favor, selecciona un alimento de la lista',
                    ),
                  ),
                );
                return;
              }
              if (_gramsCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor, introduce los gramos'),
                  ),
                );
                return;
              }
              widget.onAdd(_selected!, double.tryParse(_gramsCtrl.text) ?? 0);
              setState(() {
                _selected = null;
                _gramsCtrl.clear();
              });
            },
            child: const Text('Añadir Alimento'),
          ),
        ],
      ),
    );
  }
}

class _RecipeSelector extends StatelessWidget {
  final List<Receta> recetas;
  final Function(Receta) onAdd;
  const _RecipeSelector({required this.recetas, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Autocomplete<Receta>(
            optionsBuilder: (text) {
              if (text.text.isEmpty) return recetas;
              return recetas.where(
                (x) => x.nombre.toLowerCase().contains(text.text.toLowerCase()),
              );
            },
            displayStringForOption: (x) => x.nombre,
            onSelected: (rec) => onAdd(rec),
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
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Inputs
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Autocomplete<Ingrediente>(
                  optionsBuilder: (text) {
                    if (text.text.isEmpty) return widget.ingredientes;
                    return widget.ingredientes.where(
                      (x) => x.nombre.toLowerCase().contains(
                        text.text.toLowerCase(),
                      ),
                    );
                  },
                  displayStringForOption: (x) => x.nombre,
                  onSelected: (x) => setState(() => _selected = x),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _gramsCtrl,
                  decoration: const InputDecoration(labelText: 'g'),
                  keyboardType: TextInputType.number,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                onPressed: () {
                  if (_selected == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Selecciona un ingrediente'),
                      ),
                    );
                    return;
                  }
                  if (_gramsCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Introduce gramos')),
                    );
                    return;
                  }
                  final g = double.tryParse(_gramsCtrl.text) ?? 0;
                  if (g > 0) {
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
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // List
          Expanded(
            child: ListView.builder(
              itemCount: widget.currentItems.length,
              itemBuilder: (ctx, i) {
                final item = widget.currentItems[i];
                return ListTile(
                  dense: true,
                  title: Text(item.nombre ?? '?'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${item.gramos} g'),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => widget.onRemoveItem(i),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Save
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.comboNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Combinación (Opcional)',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: widget.currentItems.isNotEmpty
                    ? widget.onSave
                    : null,
                child: const Text('Guardar Comb.'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
