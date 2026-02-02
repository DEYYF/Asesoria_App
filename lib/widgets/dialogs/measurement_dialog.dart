import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/client_service.dart';
import '../../../services/api_service.dart';
import '../../../utils/notification_helper.dart';

class MeasurementDialog extends StatefulWidget {
  final String clientId;

  const MeasurementDialog({super.key, required this.clientId});

  @override
  State<MeasurementDialog> createState() => _MeasurementDialogState();
}

class _MeasurementDialogState extends State<MeasurementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pesoController = TextEditingController();
  final _grasaController = TextEditingController();
  final _musculoController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _pesoController.dispose();
    _grasaController.dispose();
    _musculoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final clientService = ClientService(
        Provider.of<ApiService>(context, listen: false),
      );

      final data = {
        'fecha': DateTime.now().toIso8601String(),
        'peso': double.parse(_pesoController.text),
        'grasaCorporal': double.tryParse(_grasaController.text),
        'MasaMusculoEsqueletica': double.tryParse(_musculoController.text),
      };

      await clientService.addProgress(widget.clientId, data);

      if (!mounted) return;
      Navigator.pop(context, true);
      NotificationHelper.showSuccess(
        context,
        '¡Progreso registrado con éxito!',
      );
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.monitor_weight_rounded,
                    color: theme.primaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Registro de Progreso',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Introduce tus medidas actuales',
                  style: TextStyle(color: theme.hintColor),
                ),
                const SizedBox(height: 24),
                _buildField(
                  controller: _pesoController,
                  label: 'Peso (kg)',
                  icon: Icons.scale_rounded,
                  hint: 'Ej: 75.5',
                  required: true,
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _grasaController,
                  label: '% Grasa Corporal',
                  icon: Icons.percent_rounded,
                  hint: 'Ej: 15.2',
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _musculoController,
                  label: '% Masa Muscular',
                  icon: Icons.fitness_center_rounded,
                  hint: 'Ej: 42.1',
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Registrar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (val) {
        if (required && (val == null || val.isEmpty)) {
          return 'Campo obligatorio';
        }
        if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
          return 'Número inválido';
        }
        return null;
      },
    );
  }
}
