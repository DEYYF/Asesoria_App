import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ingrediente_model.dart';
import '../../models/receta_model.dart';
import '../../models/macros_model.dart';
import '../../services/api_service.dart';
import '../../services/food_catalog_cache_service.dart';
import '../../utils/notification_helper.dart';

class AddEditRecetaDialog extends StatefulWidget {
  final Receta? receta;
  final List<Ingrediente> ingredientesDisponibles;
  final VoidCallback onSuccess;

  const AddEditRecetaDialog({
    super.key,
    this.receta,
    required this.ingredientesDisponibles,
    required this.onSuccess,
  });

  @override
  State<AddEditRecetaDialog> createState() => _AddEditRecetaDialogState();
}

class _AddEditRecetaDialogState extends State<AddEditRecetaDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _linkController;

  List<RecetaIngrediente> _ingredientes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(
      text: widget.receta?.nombre ?? '',
    );
    _linkController = TextEditingController(
      text: widget.receta?.linkPreparacion ?? '',
    );
    if (widget.receta != null) {
      _ingredientes = List.from(widget.receta!.ingredientes);
    } else {
      _ingredientes = [RecetaIngrediente(gramos: 100)];
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Macros get _totales {
    double k = 0, p = 0, c = 0, g = 0;
    for (var ri in _ingredientes) {
      if (ri.ingredienteId != null) {
        final ing = widget.ingredientesDisponibles.firstWhere(
          (i) => i.id == ri.ingredienteId,
          orElse: () => Ingrediente(id: '', nombre: ''),
        );
        if (ing.id.isNotEmpty) {
          final factor = ri.gramos / 100.0;
          k += ing.kcal * factor;
          p += ing.proteinas * factor;
          c += ing.carbohidratos * factor;
          g += ing.grasas * factor;
        }
      }
    }
    return Macros(kcal: k, proteinas: p, carbohidratos: c, grasas: g);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);

    final payload = {
      'nombre': _nombreController.text.trim(),
      'link': _linkController.text.trim(),
      'ingredientes': _ingredientes.map((i) => i.toJson()).toList(),
      'caloriasTotales': _totales.kcal,
      'macrosTotales': _totales.toJson(),
    };

    try {
      if (widget.receta != null) {
        await api.put('/comidas/recetas/${widget.receta!.id}', payload);
      } else {
        await api.post('/comidas/recetas', payload);
      }
      FoodCatalogCacheService.invalidate();
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        NotificationHelper.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totales = _totales;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      widget.receta == null
                          ? Icons.menu_book_rounded
                          : Icons.edit_note_rounded,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.receta == null
                              ? 'Nueva Receta'
                              : 'Editar Receta',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Combina ingredientes para crear platos',
                          style: TextStyle(
                            color: theme.hintColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildHeaderField(
                        controller: _nombreController,
                        label: 'Nombre de la receta',
                        icon: Icons.restaurant_rounded,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildHeaderField(
                        controller: _linkController,
                        label: 'Link de preparación / Youtube',
                        icon: Icons.link_rounded,
                      ),

                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'INGREDIENTES',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1.2,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => setState(
                              () => _ingredientes.add(
                                RecetaIngrediente(gramos: 100),
                              ),
                            ),
                            icon: const Icon(
                              Icons.add_circle_outline_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Añadir',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      ..._ingredientes.asMap().entries.map(
                        (entry) => _buildIngredientRow(entry.key, entry.value),
                      ),

                      const SizedBox(height: 24),
                      _buildSummaryCard(totales),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.receta == null
                              ? 'Crear Receta'
                              : 'Guardar Cambios',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: theme.primaryColor),
        filled: true,
        fillColor: theme.primaryColor.withOpacity(0.02),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
        ),
      ),
    );
  }

  Widget _buildIngredientRow(int idx, RecetaIngrediente ing) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Autocomplete<Ingrediente>(
              displayStringForOption: (i) => i.nombre,
              optionsBuilder: (textEdit) {
                if (textEdit.text.isEmpty)
                  return const Iterable<Ingrediente>.empty();
                return widget.ingredientesDisponibles.where(
                  (i) => i.nombre.toLowerCase().contains(
                    textEdit.text.toLowerCase(),
                  ),
                );
              },
              onSelected: (selected) {
                setState(() {
                  _ingredientes[idx] = RecetaIngrediente(
                    ingredienteId: selected.id,
                    nombre: selected.nombre,
                    gramos: _ingredientes[idx].gramos,
                  );
                });
              },
              fieldViewBuilder: (ctx, ctrl, focus, onFieldSubmitted) {
                if (ctrl.text.isEmpty && ing.nombre != null)
                  ctrl.text = ing.nombre!;
                return TextField(
                  controller: ctrl,
                  focusNode: focus,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Buscar o nombre libre',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (val) {
                    // Only clear the ingredient ID if the user manually changes the text
                    // and it no longer matches the selected ingredient's name.
                    final currentIng = _ingredientes[idx];
                    if (currentIng.ingredienteId != null &&
                        val != currentIng.nombre) {
                      setState(() {
                        _ingredientes[idx] = RecetaIngrediente(
                          nombreLibre: val,
                          gramos: currentIng.gramos,
                        );
                      });
                    } else if (currentIng.ingredienteId == null) {
                      setState(() {
                        _ingredientes[idx] = RecetaIngrediente(
                          nombreLibre: val,
                          gramos: currentIng.gramos,
                        );
                      });
                    }
                  },
                );
              },
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: theme.dividerColor.withOpacity(0.1),
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: ing.gramos.round().toString(),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              decoration: const InputDecoration(
                suffixText: 'g',
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (val) {
                setState(() {
                  _ingredientes[idx] = RecetaIngrediente(
                    ingredienteId: _ingredientes[idx].ingredienteId,
                    nombre: _ingredientes[idx].nombre,
                    nombreLibre: _ingredientes[idx].nombreLibre,
                    gramos: double.tryParse(val) ?? 0,
                  );
                });
              },
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _ingredientes.removeAt(idx)),
            icon: const Icon(
              Icons.remove_circle_outline_rounded,
              color: Colors.grey,
              size: 20,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Macros totales) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.analytics_rounded,
                size: 16,
                color: theme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'TOTAL ESTIMADO',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroBadge(
                'Kcal',
                totales.kcal.round().toDouble(),
                Colors.orange,
              ),
              _buildMacroBadge('Prot', totales.proteinas, Colors.redAccent),
              _buildMacroBadge(
                'Carbs',
                totales.carbohidratos,
                Colors.blueAccent,
              ),
              _buildMacroBadge('Grasas', totales.grasas, Colors.orangeAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBadge(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          value.toStringAsFixed(1),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
