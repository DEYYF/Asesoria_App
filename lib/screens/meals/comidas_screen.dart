import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ingrediente_model.dart';
import '../../models/receta_model.dart';
import '../../models/macros_model.dart';
import '../../services/api_service.dart';
import '../../widgets/dialogs/add_edit_ingrediente_dialog.dart';
import '../../widgets/dialogs/add_edit_receta_dialog.dart';
import '../../services/settings_service.dart';
import '../../services/food_catalog_cache_service.dart';
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
  bool _isSearchExpanded = false;
  bool _showFilters = false;
  final Set<String> _selectedCategories = {};
  String? _macroFilter; // 'highProt', 'lowKcal', 'lowCarb'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    final settingsService = SettingsService(api);

    try {
      final results = await Future.wait([
        FoodCatalogCacheService.getCatalog(api, forceRefresh: forceRefresh),
        settingsService.getSettings(),
      ]);
      final catalog = results[0] as FoodCatalogData;
      final settings = results[1] as UserSettings;

      if (!mounted) return;
      setState(() {
        _ingredientes = catalog.ingredientes;
        _recetas = catalog.recetas;
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading comidas: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  List<Ingrediente> get _filteredIngredientes {
    return _ingredientes.where((i) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          i.nombre.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategories.isEmpty ||
          (_selectedCategories.contains(i.tipo ?? 'Sin tipo'));

      bool matchesMacros = true;
      if (_macroFilter == 'highProt') matchesMacros = i.proteinas >= 20;
      if (_macroFilter == 'lowKcal') matchesMacros = i.kcal <= 100;
      if (_macroFilter == 'lowCarb') matchesMacros = i.carbohidratos <= 5;

      return matchesSearch && matchesCategory && matchesMacros;
    }).toList();
  }

  List<Receta> get _filteredRecetas {
    return _recetas.where((r) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          r.nombre.toLowerCase().contains(_searchQuery.toLowerCase());

      // Recipes don't have types in the model but we could filter by high protein recipes
      bool matchesMacros = true;
      if (_macroFilter == 'highProt')
        matchesMacros = r.macrosTotales.proteinas >= 40;
      if (_macroFilter == 'lowKcal') matchesMacros = r.caloriasTotales <= 400;
      if (_macroFilter == 'lowCarb')
        matchesMacros = r.macrosTotales.carbohidratos <= 20;

      return matchesSearch && matchesMacros;
    }).toList();
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
          AddEditIngredienteDialog(ingrediente: ing, onSuccess: () => _loadData(forceRefresh: true)),
    );
  }

  void _showAddEditReceta([Receta? receta]) {
    showDialog(
      context: context,
      builder: (context) => AddEditRecetaDialog(
        receta: receta,
        ingredientesDisponibles: _ingredientes,
        onSuccess: () => _loadData(forceRefresh: true),
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
        FoodCatalogCacheService.invalidate();
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
        FoodCatalogCacheService.invalidate();
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    theme.scaffoldBackgroundColor,
                    theme.scaffoldBackgroundColor.withBlue(40),
                  ]
                : [Colors.white, theme.primaryColor.withOpacity(0.05)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Panel de',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.hintColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Comidas',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                              ),
                            ],
                          ),
                          _buildTabToggle(theme, isDark),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSearchBar(theme, isDark),
                    ],
                  ),
                ),
              ),
            ],
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _tabController.index == 0
                  ? _buildIngredientesList(theme, isDark)
                  : _buildRecetasList(theme, isDark),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(_tabController.index == 0 ? 'Ingrediente' : 'Receta'),
        elevation: 4,
      ),
    );
  }

  Widget _buildTabToggle(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabItem(
            label: 'Ing',
            icon: Icons.kitchen_rounded,
            isSelected: _tabController.index == 0,
            onTap: () => setState(() => _tabController.index = 0),
          ),
          _TabItem(
            label: 'Rec',
            icon: Icons.menu_book_rounded,
            isSelected: _tabController.index == 1,
            onTap: () => setState(() => _tabController.index = 1),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: Row(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0.1, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      ),
                    );
                  },
                  child: _isSearchExpanded
                      ? Container(
                          key: const ValueKey('search_active'),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_rounded),
                                color: theme.primaryColor,
                                onPressed: () => setState(() {
                                  _isSearchExpanded = false;
                                  _searchController.clear();
                                  _searchQuery = '';
                                }),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  autofocus: true,
                                  onChanged: (val) =>
                                      setState(() => _searchQuery = val),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '¿Qué buscas hoy?',
                                    hintStyle: TextStyle(
                                      color: theme.hintColor.withOpacity(0.4),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                ),
                              ),
                              if (_searchQuery.isNotEmpty)
                                IconButton(
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                ),
                            ],
                          ),
                        )
                      : Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _isSearchExpanded = true),
                            child: Container(
                              key: const ValueKey('search_inactive'),
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  if (!isDark)
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: Icon(
                                Icons.search_rounded,
                                color: theme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              _buildFilterButton(theme, isDark),
            ],
          ),
        ),
        if (_showFilters) _buildAdvancedFilters(theme, isDark),
      ],
    );
  }

  Widget _buildFilterButton(ThemeData theme, bool isDark) {
    final hasActiveFilters =
        _selectedCategories.isNotEmpty || _macroFilter != null;
    return GestureDetector(
      onTap: () => setState(() => _showFilters = !_showFilters),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          color: _showFilters
              ? theme.primaryColor
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.tune_rounded,
              color: _showFilters ? Colors.white : theme.primaryColor,
              size: 24,
            ),
            if (hasActiveFilters && !_showFilters)
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedFilters(ThemeData theme, bool isDark) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: theme.primaryColor.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.category_rounded,
                  size: 14,
                  color: theme.primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'CATEGORÍAS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children:
                    [
                      'Carne',
                      'Pescado',
                      'Verdura',
                      'Fruta',
                      'Lácteo',
                      'Cereal',
                      'Sin tipo',
                    ].map((cat) {
                      final isSelected = _selectedCategories.contains(cat);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedCategories.add(cat);
                              } else {
                                _selectedCategories.remove(cat);
                              }
                            });
                          },
                          selectedColor: theme.primaryColor.withOpacity(0.15),
                          checkmarkColor: theme.primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? theme.primaryColor
                                : theme.hintColor,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                          backgroundColor: Colors.transparent,
                          side: BorderSide(
                            color: isSelected
                                ? theme.primaryColor
                                : theme.dividerColor.withOpacity(0.1),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.bolt_rounded, size: 14, color: theme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'METAS NUTRICIONALES',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildMacroFilterChip(
                  'Alta Prot',
                  'highProt',
                  Colors.redAccent,
                ),
                const SizedBox(width: 12),
                _buildMacroFilterChip('Baja Kcal', 'lowKcal', Colors.orange),
                const SizedBox(width: 12),
                _buildMacroFilterChip('Keto', 'lowCarb', Colors.blueAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroFilterChip(String label, String value, Color color) {
    final theme = Theme.of(context);
    final isSelected = _macroFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_macroFilter == value) {
              _macroFilter = null;
            } else {
              _macroFilter = value;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : theme.dividerColor.withOpacity(0.1),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? color : theme.hintColor.withOpacity(0.6),
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientesList(ThemeData theme, bool isDark) {
    final groups = _groupedIngredientes;
    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.no_food_rounded,
              size: 64,
              color: theme.hintColor.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay ingredientes',
              style: TextStyle(color: theme.hintColor),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      children: groups.entries.map((group) {
        return _CategorySection(
          title: group.key,
          count: group.value.length,
          children: group.value.map((ing) {
            return _IngredientCard(
              ing: ing,
              onEdit: () => _showAddEditIngrediente(ing),
              onDelete: () => _deleteIngrediente(ing),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildRecetasList(ThemeData theme, bool isDark) {
    final filtered = _filteredRecetas;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 64,
              color: theme.hintColor.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text('No hay recetas', style: TextStyle(color: theme.hintColor)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final receta = filtered[index];
        return _RecipeCard(
          receta: receta,
          onEdit: () => _showAddEditReceta(receta),
          onDelete: () => _deleteReceta(receta),
        );
      },
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : theme.hintColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : theme.hintColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatefulWidget {
  final String title;
  final int count;
  final List<Widget> children;

  const _CategorySection({
    required this.title,
    required this.count,
    required this.children,
  });

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoryIcon(widget.title),
                      color: theme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${widget.count} elementos',
                          style: TextStyle(
                            color: theme.hintColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: theme.hintColor,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(children: widget.children),
            ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String type) {
    switch (type.toLowerCase()) {
      case 'carne':
        return Icons.kebab_dining_rounded;
      case 'pescado':
        return Icons.set_meal_rounded;
      case 'verdura':
        return Icons.eco_rounded;
      case 'fruta':
        return Icons.apple_rounded;
      case 'lácteo':
        return Icons.egg_alt_rounded;
      case 'cereal':
        return Icons.grass_rounded;
      default:
        return Icons.fastfood_rounded;
    }
  }
}

class _IngredientCard extends StatelessWidget {
  final Ingrediente ing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _IngredientCard({
    required this.ing,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          ing.nombre,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              _MiniMacro(
                label: '${ing.kcal.round()} kcal',
                color: Colors.orange,
              ),
              const SizedBox(width: 4),
              _MiniMacro(label: 'P ${ing.proteinas}', color: Colors.redAccent),
              const SizedBox(width: 4),
              _MiniMacro(
                label: 'C ${ing.carbohidratos}',
                color: Colors.blueAccent,
              ),
            ],
          ),
        ),
        trailing: _MoreMenu(onEdit: onEdit, onDelete: onDelete),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Receta receta;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecipeCard({
    required this.receta,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            title: Text(
              receta.nombre,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            subtitle: Text(
              '${receta.caloriasTotales.round()} total kcal',
              style: TextStyle(
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: _MoreMenu(onEdit: onEdit, onDelete: onDelete),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMacroBar(receta.macrosTotales),
                const SizedBox(height: 12),
                if (receta.ingredientes.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: receta.ingredientes.map((i) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.primaryColor.withOpacity(0.1),
                          ),
                        ),
                        child: Text(
                          '${i.nombre ?? i.nombreLibre ?? "???"} · ${i.gramos.round()}g',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBar(Macros macros) {
    final total = (macros.proteinas + macros.carbohidratos + macros.grasas)
        .clamp(1.0, 10000.0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Row(
              children: [
                Expanded(
                  flex: (macros.proteinas / total * 100).round(),
                  child: Container(color: Colors.redAccent),
                ),
                const SizedBox(width: 1),
                Expanded(
                  flex: (macros.carbohidratos / total * 100).round(),
                  child: Container(color: Colors.blueAccent),
                ),
                const SizedBox(width: 1),
                Expanded(
                  flex: (macros.grasas / total * 100).round(),
                  child: Container(color: Colors.orangeAccent),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _MacroLegend(
              label: 'P ${macros.proteinas.round()}g',
              color: Colors.redAccent,
            ),
            _MacroLegend(
              label: 'C ${macros.carbohidratos.round()}g',
              color: Colors.blueAccent,
            ),
            _MacroLegend(
              label: 'G ${macros.grasas.round()}g',
              color: Colors.orangeAccent,
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniMacro extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniMacro({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MacroLegend extends StatelessWidget {
  final String label;
  final Color color;
  const _MacroLegend({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _MoreMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _MoreMenu({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded, size: 20),
      onSelected: (val) {
        if (val == 'edit') onEdit();
        if (val == 'delete') onDelete();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 18),
              SizedBox(width: 8),
              Text('Editar'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_rounded, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('Eliminar', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }
}
