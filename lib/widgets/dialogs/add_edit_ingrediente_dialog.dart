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
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 24,
                ),
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
                        widget.ingrediente == null
                            ? Icons.add_circle_outline_rounded
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
                            widget.ingrediente == null
                                ? 'Nuevo Ingrediente'
                                : 'Editar Ingrediente',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'Define los macros por cada 100g',
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

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _nombreController,
                        label: 'Nombre del alimento',
                        icon: Icons.title_rounded,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _tipoController,
                        label: 'Categoría (Ej: Proteínas, Fruta...)',
                        icon: Icons.category_rounded,
                      ),
                      const SizedBox(height: 24),

                      // Macros Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildMacroField(
                              controller: _kcalController,
                              label: 'Calorías',
                              suffix: 'kcal',
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMacroField(
                              controller: _pController,
                              label: 'Proteínas',
                              suffix: 'g',
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMacroField(
                              controller: _cController,
                              label: 'Carbos',
                              suffix: 'g',
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMacroField(
                              controller: _gController,
                              label: 'Grasas',
                              suffix: 'g',
                              color: Colors.orangeAccent,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Actions
                      SizedBox(
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
                                  widget.ingrediente == null
                                      ? 'Crear Ingrediente'
                                      : 'Guardar Cambios',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
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
        prefixIcon: Icon(icon, size: 20),
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

  Widget _buildMacroField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: '0',
              suffixText: suffix,
              suffixStyle: TextStyle(
                color: theme.hintColor.withOpacity(0.5),
                fontSize: 12,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}
