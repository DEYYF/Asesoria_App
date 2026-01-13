import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ingrediente_model.dart';
import '../../models/receta_model.dart';
import '../../services/api_service.dart';
import '../../widgets/dialogs/add_edit_ingrediente_dialog.dart';
import '../../widgets/dialogs/add_edit_receta_dialog.dart';
import '../../utils/isolate_utils.dart';
import '../../services/settings_service.dart';
import '../../models/settings_model.dart';
import 'widgets/add_food_options_sheet.dart';
import 'widgets/barcode_scanner_screen.dart';

class ComidasScreen extends StatefulWidget {
  const ComidasScreen({super.key});

  @override
  State<ComidasScreen> createState() => _ComidasScreenState();
}

class _ComidasScreenState extends State<ComidasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<Ingrediente> _ingredientes = [];
  List<Receta> _recetas = [];
  UserSettings? _settings;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    final settingsService = SettingsService(api);

    try {
      final ingsRes = await api.get('/comidas/ingredientes');
      final recsRes = await api.get('/comidas/recetas');
      final settings = await settingsService.getSettings();

      if (ingsRes.statusCode == 200 && recsRes.statusCode == 200) {
        final ingredientes = await parseIngredientesInIsolate(ingsRes.body);
        final recetas = await parseRecetasInIsolate(recsRes.body);

        setState(() {
          _ingredientes = ingredientes;
          _recetas = recetas;
          _settings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading comidas: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  List<Ingrediente> get _filteredIngredientes {
    if (_searchQuery.isEmpty) return _ingredientes;
    return _ingredientes
        .where(
          (i) => i.nombre.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  List<Receta> get _filteredRecetas {
    if (_searchQuery.isEmpty) return _recetas;
    return _recetas
        .where(
          (r) => r.nombre.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  Map<String, List<Ingrediente>> get _groupedIngredientes {
    final Map<String, List<Ingrediente>> groups = {};
    for (var ing in _filteredIngredientes) {
      final key = ing.tipo ?? 'Sin tipo';
      if (!groups.containsKey(key)) groups[key] = [];
      groups[key]!.add(ing);
    }
    return groups;
  }

  void _showAddEditIngrediente([Ingrediente? ing]) {
    showDialog(
      context: context,
      builder: (context) =>
          AddEditIngredienteDialog(ingrediente: ing, onSuccess: _loadData),
    );
  }

  void _showAddEditReceta([Receta? receta]) {
    showDialog(
      context: context,
      builder: (context) => AddEditRecetaDialog(
        receta: receta,
        ingredientesDisponibles: _ingredientes,
        onSuccess: _loadData,
      ),
    );
  }

  Future<void> _deleteIngrediente(Ingrediente ing) async {
    final confirmed = await _showConfirmDialog(
      'Eliminar Ingrediente',
      '¿Estás seguro de que deseas eliminar "${ing.nombre}"?',
    );
    if (confirmed == true) {
      final api = Provider.of<ApiService>(context, listen: false);
      try {
        await api.delete('/comidas/ingredientes/${ing.id}');
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _deleteReceta(Receta receta) async {
    final confirmed = await _showConfirmDialog(
      'Eliminar Receta',
      '¿Estás seguro de que deseas eliminar "${receta.nombre}"?',
    );
    if (confirmed == true) {
      final api = Provider.of<ApiService>(context, listen: false);
      try {
        await api.delete('/comidas/recetas/${receta.id}');
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AddFoodOptionsSheet(
        currentTabIndex: _tabController.index,
        showScan: _settings?.enabledFoodScanner ?? false,
        onAddManual: () {
          Navigator.pop(context);
          _tabController.index == 0
              ? _showAddEditIngrediente()
              : _showAddEditReceta();
        },
        onScanProduct: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BarcodeScannerScreen(onSuccess: _loadData),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Comidas'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ingredientes', icon: Icon(Icons.fastfood)),
            Tab(text: 'Recetas', icon: Icon(Icons.restaurant_menu)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildIngredientesList(theme),
                      _buildRecetasList(theme),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOptions,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildIngredientesList(ThemeData theme) {
    final groups = _groupedIngredientes;
    if (groups.isEmpty) return const Center(child: Text('No hay ingredientes'));

    return ListView(
      children: groups.entries.map((group) {
        return ExpansionTile(
          initiallyExpanded: groups.length < 5,
          title: Text(
            '${group.key} · ${group.value.length}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          children: group.value.map((ing) {
            return ListTile(
              title: Text(ing.nombre),
              subtitle: Text(
                '${ing.kcal.round()} kcal · P ${ing.proteinas} · C ${ing.carbohidratos} · G ${ing.grasas}',
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'edit') _showAddEditIngrediente(ing);
                  if (val == 'delete') _deleteIngrediente(ing);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildRecetasList(ThemeData theme) {
    final filtered = _filteredRecetas;
    if (filtered.isEmpty) return const Center(child: Text('No hay recetas'));

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final receta = filtered[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text(
                  receta.nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${receta.caloriasTotales.round()} kcal — P ${receta.macrosTotales.proteinas} · C ${receta.macrosTotales.carbohidratos} · G ${receta.macrosTotales.grasas}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit') _showAddEditReceta(receta);
                    if (val == 'delete') _deleteReceta(receta);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar'),
                    ),
                  ],
                ),
              ),
              if (receta.ingredientes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: receta.ingredientes.map((ing) {
                      return Chip(
                        label: Text(
                          '${ing.nombre ?? ing.nombreLibre ?? "???"} (${ing.gramos.round()} g)',
                        ),
                        labelStyle: const TextStyle(fontSize: 10),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
