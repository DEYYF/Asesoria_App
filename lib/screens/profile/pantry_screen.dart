import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/api_service.dart';

class PantryScreen extends StatefulWidget {
  final String clienteId;

  const PantryScreen({super.key, required this.clienteId});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  List<dynamic> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPantry();
  }

  Future<void> _loadPantry() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get('/despensa/${widget.clienteId}');
      if (res.statusCode == 200) {
        setState(() {
          _items = jsonDecode(res.body);
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

  Future<void> _removeItem(String id) async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.delete('/despensa/$id');
      if (res.statusCode == 200) {
        _loadPantry();
      }
    } catch (e) {
      debugPrint('Error removing item: $e');
    }
  }

  Map<String, List<dynamic>> _groupByCategory() {
    final grouped = <String, List<dynamic>>{};
    for (var item in _items) {
      final cat = item['categoria'] ?? 'General';
      if (!grouped.containsKey(cat)) grouped[cat] = [];
      grouped[cat]!.add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Mi Nevera',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF2C2C2E), const Color(0xFF1C1C1E)]
                : [const Color(0xFFF2F2F7), Colors.white],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : _items.isEmpty
            ? _buildEmptyState()
            : _buildFridgeContent(isDark, theme),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.kitchen_outlined,
            size: 80,
            color: Colors.blue.withOpacity(0.2),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tu nevera está vacía',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '¡Añade algo desde tu lista de compra!',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFridgeContent(bool isDark, ThemeData theme) {
    final groups = _groupByCategory();
    final categories = groups.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 120, 20, 40),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final items = groups[cat]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text(
                cat.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Colors.blue.withOpacity(0.7),
                ),
              ),
            ),
            // Shelf Container
            Container(
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: items.asMap().entries.map((entry) {
                  final itemIndex = entry.key;
                  final item = entry.value;
                  return _buildShelfItem(
                    item,
                    isDark,
                    theme,
                    isLast: itemIndex == items.length - 1,
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildShelfItem(
    dynamic item,
    bool isDark,
    ThemeData theme, {
    required bool isLast,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.blue.withOpacity(0.05),
                ),
              ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            _getIconForCategory(item['categoria']),
            color: Colors.blue,
            size: 22,
          ),
        ),
        title: Text(
          item['nombreIngrediente'],
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: -0.2,
          ),
        ),
        subtitle: const Text(
          'Disponible',
          style: TextStyle(color: Colors.green, fontSize: 12),
        ),
        trailing: IconButton(
          icon: Icon(Icons.close_rounded, color: Colors.red.withOpacity(0.5)),
          onPressed: () => _removeItem(item['_id']),
        ),
      ),
    );
  }

  IconData _getIconForCategory(String? category) {
    final cat = category?.toLowerCase() ?? '';
    if (cat.contains('proteina') ||
        cat.contains('carne') ||
        cat.contains('pollo')) {
      return Icons.restaurant_rounded;
    }
    if (cat.contains('frut') || cat.contains('verd')) {
      return Icons.eco_rounded;
    }
    if (cat.contains('lact') || cat.contains('leche')) {
      return Icons.water_drop_rounded;
    }
    if (cat.contains('bebida')) {
      return Icons.local_drink_rounded;
    }
    return Icons.kitchen_rounded;
  }
}
