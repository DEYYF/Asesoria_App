import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../models/dieta_model.dart';
import '../../models/macros_model.dart'; // Ensure Macros is imported
import '../../utils/diet_pdf_generator.dart';
import '../../widgets/revisions_dialog.dart';
import 'create_diet_screen.dart';

class DietDetailScreen extends StatefulWidget {
  final String dietaId;

  const DietDetailScreen({super.key, required this.dietaId});

  @override
  State<DietDetailScreen> createState() => _DietDetailScreenState();
}

class _DietDetailScreenState extends State<DietDetailScreen> {
  late Future<Dieta?> _dietFuture;

  @override
  void initState() {
    super.initState();
    _dietFuture = _fetchDiet();
  }

  Future<Dieta?> _fetchDiet() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      // Fetch diet by ID
      final res = await api.get('/dietas/${widget.dietaId}');
      if (res.statusCode == 200) {
        // Parse directly
        final data = jsonDecode(res.body);
        return Dieta.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error fetching diet: $e');
    }
    return null;
  }

  Future<void> _handleDelete() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.delete('/dietas/${widget.dietaId}');
      if (res.statusCode == 200 && mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.pop(context); // Go back
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dieta eliminada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  Future<void> _handleExportPDF(Dieta dieta) async {
    try {
      await DietPdfGenerator.generateAndPrint(dieta);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al exportar PDF: $e')));
      }
    }
  }

  Future<void> _handleSaveVersion() async {
    // Simple prompt for note
    final noteController = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Guardar Versión'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(labelText: 'Nota de la versión'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, noteController.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (note != null) {
      final api = Provider.of<ApiService>(context, listen: false);
      try {
        final res = await api.post('/dietas/${widget.dietaId}/revision', {
          'note': note.isEmpty ? 'Snapshot manual' : note,
        });
        if (res.statusCode == 201) {
          final data = jsonDecode(res.body);
          final newId = data['dieta']['_id'];
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Versión guardada con éxito')),
            );
            // Navigate to new version
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DietDetailScreen(dietaId: newId),
              ),
            );
          }
        } else {
          throw Exception(res.body);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar versión: $e')),
          );
        }
      }
    }
  }

  void _handleHistory() {
    showDialog(
      context: context,
      builder: (ctx) => RevisionsDialog(
        dietaId: widget.dietaId,
        onRestored: (newId) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => DietDetailScreen(dietaId: newId)),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la Dieta')),
      body: FutureBuilder<Dieta?>(
        future: _dietFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Error al cargar la dieta'));
          }

          final dieta = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(dieta),
                const SizedBox(height: 24),
                _buildInfoAndMacros(dieta),
                const SizedBox(height: 24),
                _buildMealsList(dieta),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(Dieta dieta) {
    final dateStr = dieta.createdAt != null
        ? DateFormat('dd/MM/yyyy').format(dieta.createdAt!)
        : '-';

    return Card(
      color: Colors.blue.shade50.withOpacity(0.3),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalle de la Dieta',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.local_fire_department,
                          size: 16,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${dieta.macros.kcal.round()} kcal objetivo',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                _ActionButton(
                  icon: Icons.picture_as_pdf,
                  label: 'Exportar',
                  onTap: () => _handleExportPDF(dieta),
                  isPrimary: true,
                ),
                _ActionButton(
                  icon: Icons.save_as,
                  label: 'Guardar versión',
                  onTap: _handleSaveVersion,
                ),
                _ActionButton(
                  icon: Icons.history,
                  label: 'Historial',
                  onTap: _handleHistory,
                ),
                _ActionButton(
                  icon: Icons.edit,
                  label: 'Editar',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateDietScreen(
                          clienteId: dieta.clienteId,
                          dietaId: dieta.id,
                        ),
                      ),
                    );
                    if (mounted) {
                      setState(() {
                        _dietFuture = _fetchDiet();
                      });
                    }
                  },
                ),
                _ActionButton(
                  icon: Icons.delete_outline,
                  label: 'Eliminar',
                  color: Colors.red,
                  onTap: () => _showDeleteDialog(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoAndMacros(Dieta dieta) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Flex(
          direction: isWide ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info General
            SizedBox(
              width: isWide ? constraints.maxWidth * 0.4 : double.infinity,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Información general',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 24),
                      _InfoRow(
                        'Fecha de creación:',
                        dieta.createdAt != null
                            ? DateFormat('dd/MM/yyyy').format(dieta.createdAt!)
                            : '-',
                      ),
                      _InfoRow(
                        'Calorías totales:',
                        '${dieta.macros.kcal.round()} kcal',
                      ),
                      _InfoRow(
                        'Objetivo:',
                        dieta.objetivo?.toUpperCase() ?? '-',
                      ),
                      _InfoRow('Estado:', dieta.estado.toUpperCase()),
                    ],
                  ),
                ),
              ),
            ),
            if (isWide)
              const SizedBox(width: 24)
            else
              const SizedBox(height: 16),
            // Macros Cards
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _MacroCard(
                      label: 'Proteínas',
                      val: dieta.macros.proteinas,
                      icon: Icons.egg_alt,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MacroCard(
                      label: 'Carbohidratos',
                      val: dieta.macros.carbohidratos,
                      icon: Icons.breakfast_dining,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MacroCard(
                      label: 'Grasas',
                      val: dieta.macros.grasas,
                      icon: Icons.water_drop,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMealsList(Dieta dieta) {
    if (dieta.comidas.isEmpty) {
      return const Center(child: Text('Sin comidas'));
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Comidas',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            ...dieta.comidas.map((comida) => _MealItem(comida: comida)),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar dieta'),
        content: const Text(
          'Esta acción no se puede deshacer. ¿Seguro que quieres eliminar esta dieta?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: _handleDelete,
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? (isPrimary ? Colors.blue : Colors.grey.shade700);
    return isPrimary
        ? ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18, color: c),
            label: Text(label, style: TextStyle(color: c)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.withOpacity(0.5)),
            ),
          );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final double val;
  final IconData icon;
  final Color color;

  const _MacroCard({
    required this.label,
    required this.val,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${val.round()} g',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _MealItem extends StatelessWidget {
  final Comida comida;
  const _MealItem({required this.comida});

  @override
  Widget build(BuildContext context) {
    // Totals logic
    final k = comida.totales.kcal > 0
        ? comida.totales.kcal
        : 0.0; // Use calculated totals if available
    // OR default to summing/averaging if backend didn't fill it?
    // The backend `calculateComidaMacros` fills `comida.totales`.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: Colors.grey.shade100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                comida.titulo,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (k > 0)
                Text(
                  '${k.round()} kcal',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
        if (comida.opciones.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Sin alimentos',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          )
        else
          ...comida.opciones.map((op) => _OptionRow(op: op)),

        const SizedBox(height: 16),
      ],
    );
  }
}

class _OptionRow extends StatefulWidget {
  final OpcionDieta op;
  const _OptionRow({required this.op});

  @override
  State<_OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<_OptionRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final op = widget.op;
    final hasIngredients = op.items != null && op.items!.isNotEmpty;
    // Note: For 'receta' populated, specific ingredient list logic might be needed if Receta model doesn't nest them in `items`.
    // In `Dieta.js`, Opcion has `items` for Combination.
    // And `recetaId` is populated. `recetaId.ingredientes`.
    // But `OpcionDieta` in Flutter might not have full Receta object nesting yet?
    // Let's check `OpcionDieta` model.

    // NOTE: OpcionDieta model currently has `items` (List<CombinacionItem>).
    // It does NOT appear to have a full `Receta` object populated, just `recetaId` string.
    // If we want detailed ingredients for Recipes, we'd need to fetch them or `OpcionDieta` needs to support populated object.
    // For now, only Combinations use `items`. Recipes show name.

    return Column(
      children: [
        ListTile(
          dense: true,
          leading: _getIcon(op.tipo),
          title: Text(op.nombre ?? op.tipo),
          subtitle: Text(_getSubtitle(op)),
          trailing: hasIngredients
              ? IconButton(
                  icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                )
              : null,
        ),
        if (_expanded)
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: op.items!
                  .map(
                    (it) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('- ${it.nombre ?? "Ingrediente"}'),
                          Text(
                            '${it.gramos} g',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  Icon _getIcon(String tipo) {
    switch (tipo) {
      case 'receta':
        return const Icon(
          Icons.restaurant_menu,
          size: 20,
          color: Colors.orange,
        );
      case 'combinacion':
        return const Icon(
          Icons.emoji_food_beverage,
          size: 20,
          color: Colors.brown,
        );
      default:
        return const Icon(Icons.local_dining, size: 20, color: Colors.green);
    }
  }

  String _getSubtitle(OpcionDieta op) {
    final macs = op.macrosTotales ?? Macros();
    final parts = [
      if (macs.kcal > 0) '${macs.kcal.round()} kcal',
      if (op.gramos != null && op.gramos! > 0) '${op.gramos} g',
    ];
    return parts.join(' · ');
  }
}
