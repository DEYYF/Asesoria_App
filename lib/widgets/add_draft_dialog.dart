import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class AddDraftDialog extends StatefulWidget {
  final List<dynamic> tarifas;
  final List<dynamic> extras;
  final VoidCallback onSuccess;

  const AddDraftDialog({
    super.key,
    required this.tarifas,
    required this.extras,
    required this.onSuccess,
  });

  @override
  State<AddDraftDialog> createState() => _AddDraftDialogState();
}

class _AddDraftDialogState extends State<AddDraftDialog> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  String? _selectedTarifaId;
  final List<String> _selectedExtras = [];
  DateTime _selectedDate = DateTime.now();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio')));
      return;
    }
    if (_selectedTarifaId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona una tarifa')));
      return;
    }

    setState(() => _isLoading = true);

    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);

    try {
      await api.post('/presupuestos', {
        'nombreCliente': _nameCtrl.text.trim(),
        'emailCliente': _emailCtrl.text.trim(),
        'tarifaId': _selectedTarifaId,
        'extras': _selectedExtras,
        'fechaInicio': _selectedDate.toIso8601String().split('T')[0],
        'usuarioId': auth.userId,
      });

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al crear borrador: $e')));
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
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: size.height * 0.9,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nuevo Borrador',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Crea una propuesta inicial para un futuro cliente.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: theme.hintColor,
                ),
              ],
            ),
            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(theme, "DATOS DEL INTERESADO"),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _nameCtrl,
                      label: "Nombre del Interesado",
                      icon: Icons.person_outline_rounded,
                      theme: theme,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailCtrl,
                      label: "Email (Opcional)",
                      icon: Icons.email_outlined,
                      inputType: TextInputType.emailAddress,
                      theme: theme,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 24),
                    _buildSectionTitle(theme, "PLANIFICACIÓN"),
                    const SizedBox(height: 12),

                    // Tarifa Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedTarifaId,
                      isExpanded: true,
                      decoration: _inputDecoration(
                        theme,
                        isDark,
                        "Tarifa",
                        Icons.local_offer_outlined,
                      ),
                      dropdownColor: theme.cardColor,
                      items: widget.tarifas.map<DropdownMenuItem<String>>((t) {
                        return DropdownMenuItem(
                          value: t['_id'] as String,
                          child: Text(
                            '${t['nombre']} (${t['precio']}€)',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedTarifaId = val),
                    ),
                    const SizedBox(height: 16),

                    // Date Picker
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                          builder: (context, child) {
                            return Theme(
                              data: theme.copyWith(
                                colorScheme: isDark
                                    ? ColorScheme.dark(
                                        primary: theme.primaryColor,
                                      )
                                    : ColorScheme.light(
                                        primary: theme.primaryColor,
                                      ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (d != null) setState(() => _selectedDate = d);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: IgnorePointer(
                        child: TextFormField(
                          key: ValueKey(_selectedDate),
                          initialValue: DateFormat(
                            'dd/MM/yyyy',
                          ).format(_selectedDate),
                          decoration: _inputDecoration(
                            theme,
                            isDark,
                            "Fecha Inicio Prevista",
                            Icons.calendar_today_rounded,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    _buildSectionTitle(theme, "EXTRAS"),
                    const SizedBox(height: 12),

                    if (widget.extras.isEmpty)
                      Text(
                        "No hay extras disponibles",
                        style: TextStyle(
                          color: theme.hintColor,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.extras.map((e) {
                          final isSelected = _selectedExtras.contains(e['_id']);
                          return FilterChip(
                            label: Text(
                              "${e['nombre']} (+${e['precio'] ?? 0}€)",
                            ),
                            selected: isSelected,
                            selectedColor: theme.primaryColor,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : theme.textTheme.bodyMedium?.color,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            backgroundColor: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.grey.shade100,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _selectedExtras.add(e['_id']);
                                } else {
                                  _selectedExtras.remove(e['_id']);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                  ],
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
                    style: TextStyle(
                      color: theme.hintColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                          'Crear Borrador',
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

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: theme.hintColor,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ThemeData theme,
    required bool isDark,
    TextInputType inputType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: theme.textTheme.bodyMedium?.color,
      ),
      decoration: _inputDecoration(theme, isDark, label, icon),
    );
  }

  InputDecoration _inputDecoration(
    ThemeData theme,
    bool isDark,
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: theme.hintColor),
      prefixIcon: Icon(
        icon,
        color: theme.primaryColor.withOpacity(0.7),
        size: 20,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.primaryColor),
      ),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
