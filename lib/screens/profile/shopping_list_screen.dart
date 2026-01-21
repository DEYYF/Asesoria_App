import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/api_service.dart';

class ShoppingListScreen extends StatefulWidget {
  final String dietaId;
  final String dietaNombre;
  final String clienteId;

  const ShoppingListScreen({
    super.key,
    required this.dietaId,
    required this.dietaNombre,
    required this.clienteId,
  });

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  List<dynamic> _ingredients = [];
  bool _isLoading = true;
  String? _error;
  String _selectedPeriod = 'diario';
  String? _currentDietaId;
  String? _currentDietaNombre;
  List<dynamic> _availableDiets = [];
  final Set<String> _checkedItems = {};

  @override
  void initState() {
    super.initState();
    _currentDietaId = widget.dietaId;
    _currentDietaNombre = widget.dietaNombre;
    _loadAllDiets();
    _loadShoppingList();
  }

  Future<void> _loadAllDiets() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get(
        '/dietas?clienteId=${widget.clienteId}&isCurrent=true',
      );
      if (res.statusCode == 200) {
        setState(() {
          _availableDiets = jsonDecode(res.body);
        });
      }
    } catch (e) {
      debugPrint('Error loading diets: $e');
    }
  }

  Future<void> _loadShoppingList() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get(
        '/dietas/$_currentDietaId/shopping-list?periodo=$_selectedPeriod',
      );
      if (res.statusCode == 200) {
        setState(() {
          _ingredients = jsonDecode(res.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Error ${res.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, List<dynamic>> _groupByCategory() {
    final grouped = <String, List<dynamic>>{};
    for (var item in _ingredients) {
      final cat = item['category'] ?? 'General';
      if (!grouped.containsKey(cat)) grouped[cat] = [];
      grouped[cat]!.add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lista de Compra'),
            Text(
              _currentDietaNombre ?? '',
              style: TextStyle(
                fontSize: 12,
                color: theme.hintColor.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (_availableDiets.length > 1)
            PopupMenuButton<dynamic>(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip: 'Cambiar Dieta',
              onSelected: (diet) {
                setState(() {
                  _currentDietaId = diet['_id'];
                  _currentDietaNombre = diet['nombre'];
                  _isLoading = true;
                  _checkedItems.clear();
                });
                _loadShoppingList();
              },
              itemBuilder: (context) => _availableDiets.map((diet) {
                return PopupMenuItem<dynamic>(
                  value: diet,
                  child: Row(
                    children: [
                      Icon(
                        Icons.restaurant_menu_rounded,
                        size: 18,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(diet['nombre'] ?? 'Sin nombre')),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(width: 8),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          _buildPeriodSelector(theme),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : _ingredients.isEmpty
                ? _buildEmptyState()
                : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildPeriodOption('diario', 'DIARIO'),
          _buildPeriodOption('semanal', 'SEMANAL'),
          _buildPeriodOption('mensual', 'MENSUAL'),
        ],
      ),
    );
  }

  Widget _buildPeriodOption(String value, String label) {
    final theme = Theme.of(context);
    final isSelected = _selectedPeriod == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = value;
            _isLoading = true;
          });
          _loadShoppingList();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : theme.hintColor,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_basket_outlined,
            size: 64,
            color: Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No se encontraron ingredientes',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final groups = _groupByCategory();
    final categories = groups.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final items = groups[cat]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 32, bottom: 12, left: 4),
              child: Text(
                cat.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).primaryColor,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ...items.map((item) => _buildIngredientItem(item)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildIngredientItem(dynamic item) {
    final name = item['name'];
    final grams = item['grams'] as num;
    final isChecked = _checkedItems.contains(name);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isChecked) {
              _checkedItems.remove(name);
            } else {
              _checkedItems.add(name);
            }
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isChecked ? theme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isChecked
                        ? theme.primaryColor
                        : Colors.grey.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: isChecked
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: isChecked
                            ? TextDecoration.lineThrough
                            : null,
                        color: isChecked ? theme.hintColor : null,
                      ),
                    ),
                    if (grams > 0)
                      Text(
                        _formatQuantity(grams),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.hintColor.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatQuantity(num grams) {
    if (grams >= 1000) {
      final kg = grams / 1000;
      return '${kg.toStringAsFixed(kg.truncateToDouble() == kg ? 0 : 1)} kg';
    }
    return '${grams.round()} g';
  }
}
