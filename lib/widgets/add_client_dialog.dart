import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/tarifa_model.dart';
import '../../models/extra_model.dart';
import '../utils/notification_helper.dart';

class AddClientDialog extends StatefulWidget {
  final ValueChanged<String?> onSuccess;
  final String? initialName;
  final String? initialEmail;
  final String? initialTarifaId;
  final List<String>? initialExtras;

  const AddClientDialog({
    super.key,
    required this.onSuccess,
    this.initialName,
    this.initialEmail,
    this.initialTarifaId,
    this.initialExtras,
  });

  @override
  State<AddClientDialog> createState() => _AddClientDialogState();
}

class _AddClientDialogState extends State<AddClientDialog> {
  final _formKey = GlobalKey<FormState>();

  // Basic Info
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();
  DateTime? _birthDate; // Added for Birthday automation
  String _sexo = 'Hombre';

  // Objectives
  final _objCtrl = TextEditingController();
  final List<String> _objetivos = [];
  final List<String> _sugerencias = [
    "Pérdida de peso",
    "Ganar masa muscular",
    "Mantenimiento",
    "Definición",
    "Aumentar fuerza",
    "Mejorar salud",
  ];

  // Financials
  List<Tarifa> _tarifas = [];
  List<Extra> _extras = [];
  String? _selectedTarifaId;
  final List<String> _selectedExtrasIds = [];

  bool _isLoading = false;
  bool _loadingData = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) _nombreCtrl.text = widget.initialName!;
    if (widget.initialEmail != null) _emailCtrl.text = widget.initialEmail!;
    if (widget.initialTarifaId != null)
      _selectedTarifaId = widget.initialTarifaId;
    if (widget.initialExtras != null)
      _selectedExtrasIds.addAll(widget.initialExtras!);

    _loadData();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _edadCtrl.dispose();
    _objCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final tRes = await api.get('/tarifas');
      final eRes = await api.get('/extras');

      if (tRes.statusCode == 200 && eRes.statusCode == 200) {
        setState(() {
          _tarifas = (jsonDecode(tRes.body) as List)
              .map((i) => Tarifa.fromJson(i))
              .toList();
          _extras = (jsonDecode(eRes.body) as List)
              .map((i) => Extra.fromJson(i))
              .toList();
          _loadingData = false;
        });
      } else {
        throw Exception('Error loading data');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _loadingData = false;
        });
      }
    }
  }

  void _addObjetivo() {
    final val = _objCtrl.text.trim();
    if (val.isNotEmpty && !_objetivos.contains(val)) {
      setState(() {
        _objetivos.add(val);
        _objCtrl.clear();
      });
    }
  }

  // Calculations
  double get _totalBase => _tarifas
      .firstWhere(
        (t) => t.id == _selectedTarifaId,
        orElse: () => Tarifa(
          id: '',
          nombre: '',
          precio: 0,
          duracionDias: 0,
          tipoServicio: '',
        ),
      )
      .precio;
  int get _meses => _selectedTarifaId == null
      ? 0
      : (_tarifas.firstWhere((t) => t.id == _selectedTarifaId).duracionDias /
                30)
            .ceil();

  double get _totalExtras {
    if (_meses == 0) return 0;
    double sum = 0;
    for (var id in _selectedExtrasIds) {
      final e = _extras.firstWhere((x) => x.id == id);
      sum += (e.precio * _meses);
    }
    return sum;
  }

  double get _totalFinal => _totalBase + _totalExtras;

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_objetivos.isEmpty) {
      NotificationHelper.showInfo(context, 'Añade al menos un objetivo');
      return;
    }
    if (_selectedTarifaId == null) {
      NotificationHelper.showInfo(context, 'Selecciona una tarifa');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);
      final asesorId = auth.user?['_id'];

      if (asesorId == null) {
        throw Exception(
          'No se ha podido identificar al asesor. Reinicia sesión.',
        );
      }

      final tarifa = _tarifas.firstWhere((t) => t.id == _selectedTarifaId);

      final clientBody = {
        'nombre': _nombreCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'edad': int.tryParse(_edadCtrl.text),
        'sexo': _sexo,
        'objetivos': _objetivos,
        'fechaNacimiento': _birthDate?.toIso8601String(), // Added
        'fechaInicio': DateTime.now().toIso8601String(),
        'Tarifa': tarifa.nombre,
        'tipoServicio': tarifa.tipoServicio,
        'Tiempo_Tarifa': '$_meses Meses',
        'asesorId': asesorId,
      };

      final resC = await api.post('/clientes', clientBody);
      if (resC.statusCode != 200 && resC.statusCode != 201) {
        throw Exception('Error creando cliente: ${resC.body}');
      }

      final clientId = jsonDecode(resC.body)['_id'];

      // 2. Create Presupuesto
      final budgetBody = {
        'clienteId': clientId,
        'usuarioId': asesorId, // asesorId is user id
        'tarifaId': _selectedTarifaId,
        'extras': _selectedExtrasIds,
        'fechaInicio': DateTime.now().toIso8601String(),
      };

      await api.post('/presupuestos', budgetBody);

      widget.onSuccess(clientId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loadingData) return const Center(child: CircularProgressIndicator());

    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        // Remove fixed width/height, use constraints
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: size.height * 0.9,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Shrink wrap height
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
                        'Nuevo Cliente',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ingresa la información básica y plan financiero',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
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

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(theme, "DATOS BÁSICOS"),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _nombreCtrl,
                        label: "Nombre completo",
                        icon: Icons.person_outline_rounded,
                        theme: theme,
                        isDark: isDark,
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _emailCtrl,
                              label: "Email",
                              icon: Icons.email_outlined,
                              theme: theme,
                              isDark: isDark,
                              inputType: TextInputType.emailAddress,
                              validator: (v) =>
                                  !v!.contains('@') ? 'Inválido' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _telefonoCtrl,
                              label: "Teléfono",
                              icon: Icons.phone_outlined,
                              theme: theme,
                              isDark: isDark,
                              inputType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(height: 24),
                      _buildSectionTitle(
                        theme,
                        "DATOS ANTROPOMÉTRICOS & IDENTIDAD",
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
                              selected: {_sexo},
                              onSelectionChanged: (Set<String> newSelection) {
                                setState(() {
                                  _sexo = newSelection.first;
                                });
                              },
                              style: SegmentedButton.styleFrom(
                                visualDensity: VisualDensity.comfortable,
                                side: BorderSide(
                                  color: theme.dividerColor.withOpacity(0.2),
                                ),
                                selectedBackgroundColor: theme.primaryColor
                                    .withOpacity(0.1),
                                selectedForegroundColor: theme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const SizedBox(height: 32),

                      const SizedBox(height: 16),
                      // BIRTHDAY FIELD
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _birthDate ?? DateTime(2000),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                            locale: const Locale('es', 'ES'),
                            builder: (context, child) {
                              return Theme(
                                data: theme.copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: theme.primaryColor,
                                    onPrimary: Colors.white,
                                    surface: isDark
                                        ? const Color(0xFF1E1E1E)
                                        : Colors.white,
                                    onSurface: isDark
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() {
                              _birthDate = picked;
                              // Optional: auto-calc age
                              final age = DateTime.now().year - picked.year;
                              _edadCtrl.text = age.toString();
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.dividerColor.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                color: theme.hintColor,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _birthDate == null
                                      ? "Fecha de Nacimiento"
                                      : "${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}",
                                  style: TextStyle(
                                    color: _birthDate == null
                                        ? theme.hintColor
                                        : theme.textTheme.bodyMedium?.color,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      _buildSectionTitle(theme, "OBJETIVOS"),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _objCtrl,
                              label: "Nuevo objetivo",
                              icon: Icons.flag_outlined,
                              theme: theme,
                              isDark: isDark,
                              hint: "Escribe y pulsa +",
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.filled(
                            onPressed: _addObjetivo,
                            icon: const Icon(Icons.add_rounded),
                            style: IconButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _objetivos
                            .map(
                              (o) => Chip(
                                label: Text(o),
                                backgroundColor: theme.primaryColor.withOpacity(
                                  0.1,
                                ),
                                labelStyle: TextStyle(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                deleteIcon: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: theme.primaryColor,
                                ),
                                onDeleted: () =>
                                    setState(() => _objetivos.remove(o)),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      if (_objetivos.isNotEmpty) const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _sugerencias
                            .where((s) => !_objetivos.contains(s))
                            .map(
                              (s) => ActionChip(
                                label: Text(s),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  color: theme.hintColor,
                                ),
                                backgroundColor: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.grey.shade100,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                onPressed: () =>
                                    setState(() => _objetivos.add(s)),
                              ),
                            )
                            .toList(),
                      ),

                      const SizedBox(height: 32),

                      _buildSectionTitle(theme, "PLAN Y FACTURACIÓN"),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedTarifaId,
                        isExpanded: true, // Prevent overflow for long items
                        decoration: InputDecoration(
                          labelText: "Seleccionar Tarifa",
                          labelStyle: TextStyle(color: theme.hintColor),
                          prefixIcon: Icon(
                            Icons.calendar_today_rounded,
                            color: theme.primaryColor.withOpacity(0.7),
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                        dropdownColor: theme.cardColor,
                        items: _tarifas
                            .map(
                              (t) => DropdownMenuItem(
                                value: t.id,
                                child: Text(
                                  '${t.nombre} - ${t.precio}€ (${t.duracionDias} días)',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedTarifaId = v),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Extras Mensuales",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.hintColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _extras.map((e) {
                          final isSel = _selectedExtrasIds.contains(e.id);
                          return FilterChip(
                            label: Text('${e.nombre} (+${e.precio}€)'),
                            selected: isSel,
                            showCheckmark: false,
                            selectedColor: theme.primaryColor,
                            labelStyle: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : theme.textTheme.bodyMedium?.color,
                              fontWeight: isSel
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
                            onSelected: (sel) {
                              setState(() {
                                sel
                                    ? _selectedExtrasIds.add(e.id)
                                    : _selectedExtrasIds.remove(e.id);
                              });
                            },
                          );
                        }).toList(),
                      ),

                      if (_selectedTarifaId != null) ...[
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.dividerColor.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Tarifa Base",
                                    style: TextStyle(
                                      color: theme.textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                  Text(
                                    "${_totalBase.toStringAsFixed(2)} €",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Extras ($_meses meses)",
                                    style: TextStyle(
                                      color: theme.textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                  Text(
                                    "${_totalExtras.toStringAsFixed(2)} €",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Divider(
                                  color: theme.dividerColor.withOpacity(0.1),
                                  height: 1,
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "TOTAL ESTIMADO",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: theme.hintColor,
                                      fontSize: 12,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  Text(
                                    "${_totalFinal.toStringAsFixed(2)} €",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 24,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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
                          'Crear Cliente',
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
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: theme.textTheme.bodyMedium?.color,
      ),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.4)),
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
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
