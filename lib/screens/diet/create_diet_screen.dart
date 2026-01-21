import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
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

class _CreateDietScreenState extends State<CreateDietScreen> {
  // --- Controllers & State ---
  final _nameCtrl = TextEditingController(text: 'Nueva Dieta');
  final _goalCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  List<Comida> _comidas = [];
  String _selectedObjetivo = 'salud';
  List<String> _tags = [];

  // Data for selectors
  List<Receta> _recetas = [];
  List<Ingrediente> _ingredientes = [];

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
    _loadAll();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  // --- Data Loading ---

  Future<void> _loadAll() async {
    final api = Provider.of<ApiService>(context, listen: false);

    // 1. Data for selectors
    try {
      final results = await Future.wait([
        api.get('/comidas/recetas'),
        api.get('/comidas/ingredientes'),
      ]);

      if (mounted) {
        if (results[0].statusCode == 200) {
          _recetas = await parseRecetasInIsolate(results[0].body);
        }
        if (results[1].statusCode == 200) {
          _ingredientes = await parseIngredientesInIsolate(results[1].body);
        }
      }
    } catch (e) {
      debugPrint('Error loading food data: $e');
    }

    // 2. Load Diet if editing
    if (widget.dietaId != null) {
      try {
        final res = await api.get('/dietas/${widget.dietaId}');
        if (res.statusCode == 200 && mounted) {
          final d = Dieta.fromJson(jsonDecode(res.body));
          setState(() {
            _nameCtrl.text = d.nombre;
            _selectedObjetivo = d.objetivo ?? 'salud';
            _tags =
                d.notas?.split(', ').where((s) => s.isNotEmpty).toList() ?? [];
            _comidas = d.comidas;
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        debugPrint('Error loading diet: $e');
      }
    } else {
      // New Diet Initialization
      _initComidas(3);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _initComidas(int n) {
    List<String> defaultNames = [
      "Desayuno",
      "Almuerzo",
      "Comida",
      "Merienda",
      "Cena",
    ];
    setState(() {
      _comidas = List.generate(
        n,
        (i) => Comida(
          titulo: i < defaultNames.length ? defaultNames[i] : "Comida ${i + 1}",
          opciones: [],
          totales: Macros(),
          uniqueKey: DateTime.now().microsecondsSinceEpoch.toString() + '_m$i',
        ),
      );
    });
  }

  // --- Logic ---

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

  // --- Actions ---

  Future<void> _handleSave() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);
    final user = auth.user;

    if (user == null) return;
    setState(() => _isSaving = true);

    final totalMacros = _calculateTotalMacros();
    final payload = {
      'clienteId': widget.clienteId,
      'asesorId': user['_id'] ?? user['id'],
      'nombre': _nameCtrl.text.isEmpty ? 'Nueva Dieta' : _nameCtrl.text,
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
              'totales': _calculateItemMacros(op),
            };
            if (op.tipo == 'receta')
              opData['recetaId'] = op.recetaId;
            else if (op.tipo == 'ingrediente') {
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

    try {
      final res = widget.dietaId != null
          ? await api.put('/dietas/${widget.dietaId}', payload)
          : await api.post('/dietas', payload);

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          final body = jsonDecode(res.body);
          final newId = body is Map
              ? (body['_id'] ?? body['id'])
              : widget.dietaId;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Dieta guardada')));
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
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
        ),
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
        title: Text(
          widget.dietaId != null ? 'Editar Dieta' : 'Crear Dieta',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
      body: Column(
        children: [
          _buildMetaHeader(theme),
          _buildMacroSummaryBanner(theme),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _comidas.length + 1,
              itemBuilder: (ctx, idx) {
                if (idx == _comidas.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _comidas.add(
                              Comida(
                                titulo: "Nueva Comida",
                                opciones: [],
                                totales: Macros(),
                                uniqueKey: DateTime.now().microsecondsSinceEpoch
                                    .toString(),
                              ),
                            );
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Añadir Comida'),
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
                  );
                }
                return _buildMealCard(idx, _comidas[idx], theme);
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
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          TextFormField(
            controller: _nameCtrl,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Nombre de la Dieta (ej. Volumen 2024)',
              hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.5)),
              isDense: true,
              border: InputBorder.none,
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildGoalChip(theme),
                const SizedBox(width: 8),
                ..._tags.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Chip(
                      label: Text(t, style: const TextStyle(fontSize: 11)),
                      onDeleted: () => setState(() => _tags.remove(t)),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
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
        ],
      ),
    );
  }

  Widget _buildGoalChip(ThemeData theme) {
    return PopupMenuButton<String>(
      onSelected: (v) => setState(() => _selectedObjetivo = v),
      itemBuilder: (ctx) => _validObjetivos
          .map((o) => PopupMenuItem(value: o, child: Text(o.toUpperCase())))
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
            Text(
              _selectedObjetivo.toUpperCase(),
              style: TextStyle(
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroSummaryBanner(ThemeData theme) {
    final macs = _calculateTotalMacros();
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
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _macroHeaderItem('Kcal', macs.kcal.round().toString()),
          _macroHeaderItem('Prot', '${macs.proteinas.round()}g'),
          _macroHeaderItem('Carb', '${macs.carbohidratos.round()}g'),
          _macroHeaderItem('Gras', '${macs.grasas.round()}g'),
        ],
      ),
    );
  }

  Widget _macroHeaderItem(String label, String val) {
    return Column(
      children: [
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // --- Meal Card ---

  Widget _buildMealCard(int mealIdx, Comida meal, ThemeData theme) {
    final mealMacros = _calculateMealMacros(meal);

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
          _buildMealHeader(mealIdx, meal, theme, mealMacros),
          if (meal.opciones.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Sin alimentos. Pulsa "+" para añadir.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else
            Column(
              children: meal.opciones
                  .asMap()
                  .entries
                  .map((e) => _buildFoodRow(mealIdx, e.key, e.value, theme))
                  .toList(),
            ),

          _buildAddFoodButton(mealIdx, theme),
        ],
      ),
    );
  }

  Widget _buildMealHeader(
    int mealIdx,
    Comida meal,
    ThemeData theme,
    Macros macros,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.04),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(Icons.restaurant_rounded, size: 16, color: theme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: meal.titulo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
              ),
              onChanged: (v) => _comidas[mealIdx] = meal.copyWith(titulo: v),
            ),
          ),
          Text(
            '${macros.kcal.round()} kcal',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(width: 8),
          _buildMealActions(mealIdx),
        ],
      ),
    );
  }

  Widget _buildMealActions(int idx) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (v) {
        if (v == 'del') setState(() => _comidas.removeAt(idx));
        if (v == 'dup')
          setState(() {
            final m = _comidas[idx];
            _comidas.add(
              m.copyWith(
                uniqueKey: DateTime.now().microsecondsSinceEpoch.toString(),
                titulo: "${m.titulo} (Copy)",
              ),
            );
          });
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'dup', child: Text('Duplicar')),
        const PopupMenuItem(
          value: 'del',
          child: Text('Eliminar', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  Widget _buildFoodRow(int mIdx, int oIdx, OpcionDieta op, ThemeData theme) {
    final key = ValueKey(op.uniqueKey);
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          _getIconForType(op.tipo, theme),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  op.nombre ?? "Alimento",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (op.gramos != null)
                  Text(
                    '${op.gramos!.round()} g',
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                if (op.tipo == 'combinacion' && op.items != null)
                  Text(
                    '${op.items!.length} ingredientes',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.hintColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.edit_note_rounded,
              size: 20,
              color: theme.primaryColor.withOpacity(0.6),
            ),
            onPressed: () => _showEditFoodDialog(mIdx, oIdx),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: () =>
                setState(() => _comidas[mIdx].opciones.removeAt(oIdx)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddFoodButton(int mealIdx, ThemeData theme) {
    return InkWell(
      onTap: () => _showFoodPicker(mealIdx),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline, size: 18, color: theme.primaryColor),
            const SizedBox(width: 8),
            Text(
              'Añadir Alimento',
              style: TextStyle(
                color: theme.primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getIconForType(String tipo, ThemeData theme) {
    IconData icon;
    Color color;
    switch (tipo) {
      case 'receta':
        icon = Icons.restaurant_menu_rounded;
        color = Colors.orange;
        break;
      case 'combinacion':
        icon = Icons.auto_awesome_rounded;
        color = Colors.blue;
        break;
      default:
        icon = Icons.local_dining_rounded;
        color = Colors.green;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  // --- Dialogs ---

  void _showAddTagDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Añadir Etiqueta'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Ej. Vegana, Ayuno...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty)
                setState(() => _tags.add(ctrl.text.trim()));
              Navigator.pop(ctx);
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  void _showFoodPicker(int mIdx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FoodPickerSheet(
        ingredientes: _ingredientes,
        recetas: _recetas,
        onSelected: (op) {
          setState(() => _comidas[mIdx].opciones.add(op));
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showEditFoodDialog(int mIdx, int oIdx) {
    final op = _comidas[mIdx].opciones[oIdx];
    if (op.tipo != 'ingrediente') {
      // For now, only ingredients have quick gram editing in a simple dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Las recetas y combos se editan eliminando y añadiendo.',
          ),
        ),
      );
      return;
    }

    final ctrl = TextEditingController(text: op.gramos?.round().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar ${op.nombre}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Gramos',
            suffixText: 'g',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final g = double.tryParse(ctrl.text) ?? op.gramos;
              setState(() {
                _comidas[mIdx].opciones[oIdx] = op.copyWith(gramos: g);
              });
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// --- Specialized Components ---

class _FoodPickerSheet extends StatefulWidget {
  final List<Ingrediente> ingredientes;
  final List<Receta> recetas;
  final Function(OpcionDieta) onSelected;

  const _FoodPickerSheet({
    required this.ingredientes,
    required this.recetas,
    required this.onSelected,
  });

  @override
  State<_FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<_FoodPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: theme.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Alimentos'),
              Tab(text: 'Recetas'),
              Tab(text: 'Combo'),
            ],
            indicatorColor: theme.primaryColor,
            labelColor: theme.primaryColor,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildIngredientList(theme),
                _buildRecipeList(theme),
                _buildComboCreator(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientList(ThemeData theme) {
    final filtered = widget.ingredientes
        .where((e) => e.nombre.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final ing = filtered[i];
        return ListTile(
          title: Text(ing.nombre),
          subtitle: Text('${ing.kcal.round()} kcal/100g'),
          trailing: const Icon(Icons.add, size: 20),
          onTap: () => _showGramSelector(ing),
        );
      },
    );
  }

  void _showGramSelector(Ingrediente ing) {
    final ctrl = TextEditingController(text: '100');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cantidad de ${ing.nombre}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'g'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final g = double.tryParse(ctrl.text) ?? 100;
              widget.onSelected(
                OpcionDieta(
                  tipo: 'ingrediente',
                  ingredienteId: ing.id,
                  nombre: ing.nombre,
                  gramos: g,
                  uniqueKey:
                      '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(10000)}_${ing.id}',
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeList(ThemeData theme) {
    final filtered = widget.recetas
        .where((e) => e.nombre.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final rec = filtered[i];
        return ListTile(
          title: Text(rec.nombre),
          subtitle: Text('${rec.caloriasTotales.round()} kcal'),
          trailing: const Icon(Icons.add, size: 20),
          onTap: () => widget.onSelected(
            OpcionDieta(
              tipo: 'receta',
              recetaId: rec.id,
              nombre: rec.nombre,
              macrosTotales: rec.macrosTotales,
              uniqueKey:
                  '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(10000)}_${rec.id ?? 'r'}',
            ),
          ),
        );
      },
    );
  }

  Widget _buildComboCreator(ThemeData theme) {
    return _ActiveComboCreator(
      ingredientes: widget.ingredientes,
      onSave: (name, items) {
        widget.onSelected(
          OpcionDieta(
            tipo: 'combinacion',
            nombre: name,
            items: items,
            uniqueKey:
                '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(10000)}_combo',
          ),
        );
      },
    );
  }
}

class _ActiveComboCreator extends StatefulWidget {
  final List<Ingrediente> ingredientes;
  final Function(String, List<CombinacionItem>) onSave;
  const _ActiveComboCreator({required this.ingredientes, required this.onSave});

  @override
  State<_ActiveComboCreator> createState() => _ActiveComboCreatorState();
}

class _ActiveComboCreatorState extends State<_ActiveComboCreator> {
  final _nameCtrl = TextEditingController();
  final List<CombinacionItem> _items = [];
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const SizedBox(height: 12),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre del Combo',
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Añadir ingrediente al combo...',
                  prefixIcon: Icon(Icons.add_circle_outline),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              Expanded(
                child: _query.isEmpty
                    ? _buildSelectedList(theme)
                    : _buildSearchResults(theme),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              if (_items.isEmpty) return;
              final name = _nameCtrl.text.isNotEmpty
                  ? _nameCtrl.text
                  : _items.map((e) => e.nombre).join(' + ');
              widget.onSave(name, _items);
            },
            child: const Text('Guardar Combo'),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    final filtered = widget.ingredientes
        .where((e) => e.nombre.toLowerCase().contains(_query.toLowerCase()))
        .take(10)
        .toList();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final ing = filtered[i];
        return ListTile(
          title: Text(ing.nombre),
          onTap: () => _addIngredient(ing),
        );
      },
    );
  }

  void _addIngredient(Ingrediente ing) {
    final ctrl = TextEditingController(text: '100');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Gramos de ${ing.nombre}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final g = double.tryParse(ctrl.text) ?? 100;
              setState(() {
                _items.add(
                  CombinacionItem(
                    ingredienteId: ing.id,
                    nombre: ing.nombre,
                    gramos: g,
                  ),
                );
                _query = '';
              });
              Navigator.pop(ctx);
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedList(ThemeData theme) {
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (ctx, i) {
        final it = _items[i];
        return ListTile(
          dense: true,
          title: Text(it.nombre ?? '?'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${it.gramos.round()}g',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => setState(() => _items.removeAt(i)),
              ),
            ],
          ),
        );
      },
    );
  }
}
