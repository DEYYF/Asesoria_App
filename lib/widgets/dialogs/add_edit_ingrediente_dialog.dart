import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ingrediente_model.dart';
import '../../services/api_service.dart';

class AddEditIngredienteDialog extends StatefulWidget {
  final Ingrediente? ingrediente;
  final VoidCallback onSuccess;

  const AddEditIngredienteDialog({
    super.key,
    this.ingrediente,
    required this.onSuccess,
  });

  @override
  State<AddEditIngredienteDialog> createState() =>
      _AddEditIngredienteDialogState();
}

class _AddEditIngredienteDialogState extends State<AddEditIngredienteDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _kcalController;
  late TextEditingController _pController;
  late TextEditingController _cController;
  late TextEditingController _gController;
  late TextEditingController _tipoController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(
      text: widget.ingrediente?.nombre ?? '',
    );
    _kcalController = TextEditingController(
      text: widget.ingrediente?.kcal.toString() ?? '',
    );
    _pController = TextEditingController(
      text: widget.ingrediente?.proteinas.toString() ?? '',
    );
    _cController = TextEditingController(
      text: widget.ingrediente?.carbohidratos.toString() ?? '',
    );
    _gController = TextEditingController(
      text: widget.ingrediente?.grasas.toString() ?? '',
    );
    _tipoController = TextEditingController(
      text: widget.ingrediente?.tipo ?? '',
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _kcalController.dispose();
    _pController.dispose();
    _cController.dispose();
    _gController.dispose();
    _tipoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);

    final payload = {
      'nombre': _nombreController.text.trim(),
      'kcal': double.tryParse(_kcalController.text) ?? 0,
      'proteinas': double.tryParse(_pController.text) ?? 0,
      'carbohidratos': double.tryParse(_cController.text) ?? 0,
      'grasas': double.tryParse(_gController.text) ?? 0,
      'tipo': _tipoController.text.trim().isEmpty
          ? null
          : _tipoController.text.trim(),
    };

    try {
      if (widget.ingrediente != null) {
        await api.put(
          '/comidas/ingredientes/${widget.ingrediente!.id}',
          payload,
        );
      } else {
        await api.post('/comidas/ingredientes', payload);
      }
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.ingrediente == null ? 'Nuevo Ingrediente' : 'Editar Ingrediente',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _kcalController,
                      decoration: const InputDecoration(labelText: 'Kcal'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _pController,
                      decoration: const InputDecoration(labelText: 'Prot (g)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cController,
                      decoration: const InputDecoration(labelText: 'Carb (g)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _gController,
                      decoration: const InputDecoration(labelText: 'Grasa (g)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _tipoController,
                decoration: const InputDecoration(
                  labelText: 'Tipo / Categoría',
                  hintText: 'Ej: Proteínas, Verduras...',
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'Macros calculados por cada 100g',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
