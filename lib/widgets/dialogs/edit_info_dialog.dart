import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/cliente_model.dart';

class EditInfoDialog extends StatefulWidget {
  final Cliente cliente;
  final VoidCallback onSuccess;

  const EditInfoDialog({
    super.key,
    required this.cliente,
    required this.onSuccess,
  });

  @override
  State<EditInfoDialog> createState() => _EditInfoDialogState();
}

class _EditInfoDialogState extends State<EditInfoDialog> {
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _heightController;
  String? _selectedSex;
  bool _isLoading = false;
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.cliente.email);
    _phoneController = TextEditingController(
      text: widget.cliente.telefono ?? '',
    );
    _heightController = TextEditingController(
      text: widget.cliente.altura?.toString() ?? '',
    );
    _selectedSex = widget.cliente.sexo;
    if (_selectedSex != 'Hombre' &&
        _selectedSex != 'Mujer' &&
        _selectedSex != 'Otro') {
      _selectedSex = null; // Reset if invalid
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  bool _validate() {
    final errors = <String, String>{};

    // Email regex
    final emailRegex = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$");
    if (!emailRegex.hasMatch(_emailController.text)) {
      errors['email'] = "Correo no válido";
    }

    // Phone regex (7-15 digits)
    final phoneRegex = RegExp(r"^\d{7,15}$");
    if (!phoneRegex.hasMatch(_phoneController.text)) {
      errors['telefono'] = "Teléfono no válido (7 a 15 dígitos)";
    }

    if (_selectedSex == null) {
      errors['sexo'] = "Debe seleccionar el sexo";
    }

    final height = double.tryParse(_heightController.text);
    if (height == null || height <= 0) {
      errors['altura'] = "Altura no válida";
    }

    setState(() {
      _errors = errors;
    });

    return errors.isEmpty;
  }

  Future<void> _handleSave() async {
    if (!_validate()) return;
    setState(() {
      _isLoading = true;
    });

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final body = {
        'email': _emailController.text,
        'telefono': _phoneController.text,
        'sexo': _selectedSex,
        'altura': _heightController
            .text, // Backend handles string to number usually or we parse
      };

      await api.put('/clientes/${widget.cliente.id}', body);
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        // Can add general error handling
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      title: Text(
        'Editar información',
        style: TextStyle(color: theme.textTheme.titleLarge?.color),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _emailController,
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: theme.hintColor),
                  errorText: _errors['email'],
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                decoration: InputDecoration(
                  labelText: 'Teléfono',
                  labelStyle: TextStyle(color: theme.hintColor),
                  errorText: _errors['telefono'],
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedSex,
                dropdownColor: theme.colorScheme.surface,
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                items: ['Hombre', 'Mujer', 'Otro']
                    .map(
                      (val) => DropdownMenuItem(
                        value: val,
                        child: Text(
                          val,
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedSex = val),
                decoration: InputDecoration(
                  labelText: 'Sexo',
                  labelStyle: TextStyle(color: theme.hintColor),
                  errorText: _errors['sexo'],
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _heightController,
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                decoration: InputDecoration(
                  labelText: 'Altura (cm)',
                  labelStyle: TextStyle(color: theme.hintColor),
                  errorText: _errors['altura'],
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                ),
                keyboardType: TextInputType.number,
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
          onPressed: _isLoading ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
