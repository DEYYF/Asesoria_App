import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/ejercicio_model.dart';

class AddEditEjercicioDialog extends StatefulWidget {
  final Ejercicio? ejercicio;
  final VoidCallback onSuccess;

  const AddEditEjercicioDialog({
    super.key,
    this.ejercicio,
    required this.onSuccess,
  });

  @override
  State<AddEditEjercicioDialog> createState() => _AddEditEjercicioDialogState();
}

class _AddEditEjercicioDialogState extends State<AddEditEjercicioDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _urlVideoController = TextEditingController();
  final _instruccionesController = TextEditingController();

  String? _selectedGrupo;
  String? _selectedEquipo;
  String? _selectedNivel;
  bool _isLoading = false;

  final List<String> _grupos = [
    "Pecho Superior",
    "Pecho Inferior",
    "Pecho Medio",
    "Trapecio",
    "Dorsal",
    "Espalda Baja",
    "Cuello",
    "Cuadriceps",
    "Isquiotibiales",
    "Gluteos",
    "Gemelos",
    "Hombros",
    "Bíceps",
    "Tríceps",
    "Abdominales",
    "Cardio",
    "Otro",
  ];

  final List<String> _equipos = [
    "Mancuernas",
    "Barra",
    "Máquinas",
    "Cuerpo libre",
    "Bandas elásticas",
    "TRX",
    "Balón medicinal",
    "Rueda abdominal",
    "Comba",
    "Peso corporal",
    "Poleas",
  ];

  final List<String> _niveles = ["Principiante", "Intermedio", "Avanzado"];

  @override
  void initState() {
    super.initState();
    if (widget.ejercicio != null) {
      _nombreController.text = widget.ejercicio!.nombre;
      _urlVideoController.text = widget.ejercicio!.urlVideo ?? '';
      _instruccionesController.text = widget.ejercicio!.instrucciones ?? '';
      _selectedGrupo = widget.ejercicio!.grupo;
      _selectedEquipo = widget.ejercicio!.equipo;
      _selectedNivel = widget.ejercicio!.nivel;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _urlVideoController.dispose();
    _instruccionesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final api = Provider.of<ApiService>(context, listen: false);
    final payload = {
      "nombre": _nombreController.text.trim(),
      "grupo": _selectedGrupo,
      "equipo": _selectedEquipo,
      "nivel": _selectedNivel,
      "urlVideo": _urlVideoController.text.trim(),
      "instrucciones": _instruccionesController.text.trim(),
    };

    try {
      if (widget.ejercicio == null) {
        await api.post('/ejercicios', payload);
      } else {
        await api.put('/ejercicios/${widget.ejercicio!.id}', payload);
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
    final isDark = theme.brightness == Brightness.dark;
    final isEdit = widget.ejercicio != null;

    return Dialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEdit ? 'Editar Ejercicio' : 'Nuevo Ejercicio',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel(theme, "NOMBRE"),
                      _buildTextField(
                        controller: _nombreController,
                        hint: "Ej: Sentadillas con barra",
                        theme: theme,
                        isDark: isDark,
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Obligatorio' : null,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(theme, "GRUPO MUSCULAR"),
                                DropdownButtonFormField<String>(
                                  value: _selectedGrupo,
                                  dropdownColor: theme.cardColor,
                                  decoration: _inputDecoration(
                                    theme,
                                    isDark,
                                    "Seleccionar",
                                  ),
                                  items: _grupos
                                      .map(
                                        (g) => DropdownMenuItem(
                                          value: g,
                                          child: Text(
                                            g,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: theme
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) =>
                                      setState(() => _selectedGrupo = val),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(theme, "EQUIPO"),
                                DropdownButtonFormField<String>(
                                  value: _selectedEquipo,
                                  dropdownColor: theme.cardColor,
                                  decoration: _inputDecoration(
                                    theme,
                                    isDark,
                                    "Seleccionar",
                                  ),
                                  items: _equipos
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(
                                            e,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: theme
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) =>
                                      setState(() => _selectedEquipo = val),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildLabel(theme, "NIVEL"),
                      DropdownButtonFormField<String>(
                        value: _selectedNivel,
                        dropdownColor: theme.cardColor,
                        decoration: _inputDecoration(
                          theme,
                          isDark,
                          "Seleccionar",
                        ),
                        items: _niveles
                            .map(
                              (n) => DropdownMenuItem(
                                value: n,
                                child: Text(
                                  n,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedNivel = val),
                      ),

                      const SizedBox(height: 16),
                      _buildLabel(theme, "URL VIDEO (YOUTUBE)"),
                      _buildTextField(
                        controller: _urlVideoController,
                        hint: "https://youtu.be/...",
                        theme: theme,
                        isDark: isDark,
                      ),

                      const SizedBox(height: 16),
                      _buildLabel(theme, "INSTRUCCIONES"),
                      _buildTextField(
                        controller: _instruccionesController,
                        hint: "Pasos detallados para realizar el ejercicio...",
                        theme: theme,
                        isDark: isDark,
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: theme.hintColor),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
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
                      : Text(isEdit ? 'Guardar Cambios' : 'Crear Ejercicio'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: theme.hintColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required ThemeData theme,
    required bool isDark,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: theme.textTheme.bodyMedium?.color),
      validator: validator,
      decoration: _inputDecoration(theme, isDark, hint),
    );
  }

  InputDecoration _inputDecoration(ThemeData theme, bool isDark, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.4)),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.primaryColor),
      ),
    );
  }
}
