import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/cliente_model.dart';
import '../../utils/notification_helper.dart';

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
      errors['telefono'] = "Teléfono no válido";
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
        'altura': _heightController.text,
      };

      await api.put('/clientes/${widget.cliente.id}', body);
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        NotificationHelper.showError(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        // Use constraints instead of fixed width
        constraints: BoxConstraints(
          maxWidth: 450,
          maxHeight: size.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Editar Información',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: theme.hintColor,
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Actualiza los datos básicos del cliente.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _emailController,
              label: "Email",
              icon: Icons.email_outlined,
              theme: theme,
              isDark: isDark,
              error: _errors['email'],
              inputType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: "Teléfono",
              icon: Icons.phone_outlined,
              theme: theme,
              isDark: isDark,
              error: _errors['telefono'],
              inputType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _heightController,
              label: "Altura (cm)",
              icon: Icons.height_rounded,
              theme: theme,
              isDark: isDark,
              error: _errors['altura'],
              inputType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    "Sexo",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.hintColor,
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: 'Hombre',
                        label: Text('Hombre'),
                        icon: Icon(Icons.male_rounded),
                      ),
                      ButtonSegment(
                        value: 'Mujer',
                        label: Text('Mujer'),
                        icon: Icon(Icons.female_rounded),
                      ),
                      ButtonSegment(
                        value: 'Otro',
                        label: Text('Otro'),
                        icon: Icon(Icons.transgender_rounded),
                      ),
                    ],
                    selected: {_selectedSex ?? 'Hombre'},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedSex = newSelection.first;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.comfortable,
                      side: BorderSide(
                        color: _errors['sexo'] != null
                            ? Colors.red
                            : theme.dividerColor.withOpacity(0.2),
                      ),
                      selectedBackgroundColor: theme.primaryColor.withOpacity(
                        0.1,
                      ),
                      selectedForegroundColor: theme.primaryColor,
                    ),
                  ),
                ),
                if (_errors['sexo'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 12),
                    child: Text(
                      _errors['sexo']!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: theme.hintColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                      : const Text(
                          'Guardar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ThemeData theme,
    required bool isDark,
    String? error,
    TextInputType inputType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: inputType,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: theme.textTheme.bodyMedium?.color,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: theme.hintColor),
            prefixIcon: Icon(
              icon,
              color: theme.primaryColor.withOpacity(0.7),
              size: 20,
            ),
            errorText: error,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.dividerColor.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.primaryColor),
            ),
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }
}
