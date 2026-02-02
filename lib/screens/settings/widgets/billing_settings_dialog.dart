import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import 'package:provider/provider.dart';

class BillingSettingsDialog extends StatefulWidget {
  const BillingSettingsDialog({super.key});

  @override
  State<BillingSettingsDialog> createState() => _BillingSettingsDialogState();
}

class _BillingSettingsDialogState extends State<BillingSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _nifController;
  late TextEditingController _direccionController;
  late TextEditingController _cpController;
  late TextEditingController _ciudadController;
  late TextEditingController _provinciaController;
  late TextEditingController _telefonoController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthService>(context, listen: false).user;
    _nombreController = TextEditingController(text: user?['nombre'] ?? '');
    _nifController = TextEditingController(text: user?['nif'] ?? '');
    _direccionController = TextEditingController(
      text: user?['direccion'] ?? '',
    );
    _cpController = TextEditingController(text: user?['codigoPostal'] ?? '');
    _ciudadController = TextEditingController(text: user?['ciudad'] ?? '');
    _provinciaController = TextEditingController(
      text: user?['provincia'] ?? '',
    );
    _telefonoController = TextEditingController(text: user?['telefono'] ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _nifController.dispose();
    _direccionController.dispose();
    _cpController.dispose();
    _ciudadController.dispose();
    _provinciaController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.updateProfile({
        'nombre': _nombreController.text.trim(),
        'nif': _nifController.text.trim(),
        'direccion': _direccionController.text.trim(),
        'codigoPostal': _cpController.text.trim(),
        'ciudad': _ciudadController.text.trim(),
        'provincia': _provinciaController.text.trim(),
        'telefono': _telefonoController.text.trim(),
      });

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Datos fiscales actualizados correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al actualizar datos fiscales'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: const Text('Datos de Facturación'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(
                  label: 'Nombre Fiscal / Empresa',
                  controller: _nombreController,
                  icon: Icons.business_rounded,
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                _buildField(
                  label: 'NIF / DNI / CIF',
                  controller: _nifController,
                  icon: Icons.badge_rounded,
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                _buildField(
                  label: 'Dirección',
                  controller: _direccionController,
                  icon: Icons.location_on_rounded,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildField(
                        label: 'C.P.',
                        controller: _cpController,
                        icon: Icons.map_rounded,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: _buildField(
                        label: 'Ciudad',
                        controller: _ciudadController,
                        icon: Icons.location_city_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildField(
                  label: 'Provincia',
                  controller: _provinciaController,
                  icon: Icons.public_rounded,
                ),
                const SizedBox(height: 12),
                _buildField(
                  label: 'Teléfono de Contacto',
                  controller: _telefonoController,
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                Text(
                  'Estos datos aparecerán en todas las facturas que generes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Guardar Cambios'),
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}
