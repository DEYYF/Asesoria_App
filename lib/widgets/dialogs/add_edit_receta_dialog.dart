import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ingrediente_model.dart';
import '../../models/receta_model.dart';
import '../../models/macros_model.dart';
import '../../services/api_service.dart';

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
    };

    try {
      if (widget.receta != null) {
        await api.put('/comidas/recetas/${widget.receta!.id}', payload);
      } else {
        await api.post('/comidas/recetas', payload);
      }
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totales = _totales;

    return AlertDialog(
      title: Text(widget.receta == null ? 'Nueva Receta' : 'Editar Receta'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la receta *',
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
                TextFormField(
                  controller: _linkController,
                  decoration: const InputDecoration(
                    labelText: 'Link de preparación',
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Ingredientes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Divider(),
                ..._ingredientes.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final ing = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 3,
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
                            fieldViewBuilder:
                                (ctx, ctrl, focus, onFieldSubmitted) {
                                  if (ctrl.text.isEmpty && ing.nombre != null) {
                                    ctrl.text = ing.nombre!;
                                  }
                                  return TextFormField(
                                    controller: ctrl,
                                    focusNode: focus,
                                    decoration: const InputDecoration(
                                      labelText: 'Buscar o libre',
                                    ),
                                    onChanged: (val) {
                                      // If not matches any, treat as nombreLibre
                                      setState(() {
                                        _ingredientes[idx] = RecetaIngrediente(
                                          nombreLibre: val,
                                          gramos: _ingredientes[idx].gramos,
                                        );
                                      });
                                    },
                                  );
                                },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            initialValue: ing.gramos.round().toString(),
                            decoration: const InputDecoration(labelText: 'g'),
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              setState(() {
                                _ingredientes[idx] = RecetaIngrediente(
                                  ingredienteId:
                                      _ingredientes[idx].ingredienteId,
                                  nombre: _ingredientes[idx].nombre,
                                  nombreLibre: _ingredientes[idx].nombreLibre,
                                  gramos: double.tryParse(val) ?? 0,
                                );
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle,
                            color: Colors.grey,
                          ),
                          onPressed: () =>
                              setState(() => _ingredientes.removeAt(idx)),
                        ),
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () => setState(
                    () => _ingredientes.add(RecetaIngrediente(gramos: 100)),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir ingrediente'),
                ),
                const Divider(),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Totales Estimados (Ingredientes con ID)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMacroInfo('Kcal', totales.kcal),
                          _buildMacroInfo('P', totales.proteinas),
                          _buildMacroInfo('C', totales.carbohidratos),
                          _buildMacroInfo('G', totales.grasas),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _buildMacroInfo(String label, double value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          value.toStringAsFixed(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
