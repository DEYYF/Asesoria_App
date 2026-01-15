import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/settings_service.dart';
import '../../models/settings_model.dart';
import '../../widgets/muscle_mass_bar.dart';

const musculosBase = [
  "Brazo derecho",
  "Brazo izquierdo",
  "Pierna derecha",
  "Pierna izquierda",
  "Gemelo derecho",
  "Gemelo izquierdo",
  "Antebrazo derecho",
  "Antebrazo izquierdo",
  "Hombro derecho",
  "Hombro izquierdo",
  "Espalda",
  "Pecho",
  "Trapecio",
  "Glúteo",
  "CINTURA ANCHA",
  "CINTURA ESTRECHA",
];

class AddProgressDialog extends StatefulWidget {
  final String clienteId;
  final VoidCallback onSuccess;

  const AddProgressDialog({
    super.key,
    required this.clienteId,
    required this.onSuccess,
  });

  @override
  State<AddProgressDialog> createState() => _AddProgressDialogState();
}

class _AddProgressDialogState extends State<AddProgressDialog> {
  final _pesoController = TextEditingController();
  final _grasaController = TextEditingController();
  final _masaMusculoController = TextEditingController();
  final Map<String, TextEditingController> _muscleControllers = {};
  bool _isLoading = true;
  String? _error;

  UserSettings? _settings;
  DateTime? _lastWeight;
  DateTime? _lastFat;
  DateTime? _lastMuscle;
  DateTime? _lastMeasures;

  bool _isWeightEnabled = true;
  bool _isFatEnabled = true;
  bool _isMuscleEnabled = true;
  bool _isMeasuresEnabled = true;

  String? _clientGender; // 'Hombre', 'Mujer', 'Otro'
  double? _clientHeight;

  @override
  void initState() {
    super.initState();
    for (var m in musculosBase) {
      _muscleControllers[m] = TextEditingController();
    }
    // Add listeners for real-time muscle bar update
    _pesoController.addListener(_updateMuscleUI);
    _masaMusculoController.addListener(_updateMuscleUI);
    _initData();
  }

  Future<void> _initData() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final settingsService = SettingsService(api);

    try {
      // 1. Load settings
      _settings = await settingsService.getSettings();

      // 2. Load client history to find last dates
      final response = await api.get('/clientes/${widget.clienteId}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> clientData = jsonDecode(response.body);
        _clientGender = clientData['sexo'];
        _clientHeight = (clientData['altura'] as num?)?.toDouble();

        final List<dynamic> history = clientData['historialProgreso'] ?? [];

        for (var entry in history.reversed) {
          final dateStr = entry['fecha'];
          if (dateStr == null) continue;
          final date = DateTime.parse(dateStr);

          if (_lastWeight == null && entry['peso'] != null) _lastWeight = date;
          if (_lastFat == null && entry['grasaCorporal'] != null) {
            _lastFat = date;
          }
          if (_lastMuscle == null && entry['MasaMusculoEsqueletica'] != null) {
            _lastMuscle = date;
          }
          if (_lastMeasures == null &&
              entry['musculo'] != null &&
              (entry['musculo'] as List).isNotEmpty) {
            _lastMeasures = date;
          }
        }
      }

      // 3. Calculate enabled states
      if (_settings != null) {
        _isWeightEnabled = _checkEnabled(
          _lastWeight,
          _settings!.weightFrequency,
        );
        _isFatEnabled = _checkEnabled(_lastFat, _settings!.fatFrequency);
        _isMuscleEnabled = _checkEnabled(
          _lastMuscle,
          _settings!.muscleFrequency,
        );
        _isMeasuresEnabled = _checkEnabled(
          _lastMeasures,
          _settings!.measuresFrequency,
        );
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error init AddProgressDialog: $e');
      setState(() {
        _isLoading = false;
        _error = "Error al cargar configuración: $e";
      });
    }
  }

  void _updateMuscleUI() {
    setState(() {});
  }

  bool _checkEnabled(DateTime? lastDate, String frequency) {
    if (lastDate == null) return true;
    final now = DateTime.now();
    final diff = now.difference(lastDate).inDays;

    switch (frequency) {
      case 'daily':
        return diff >= 1;
      case 'weekly':
        return diff >= 7;
      case 'biweekly':
        return diff >= 14;
      case 'monthly':
        return diff >= 30;
      case 'quarterly':
        return diff >= 90;
      default:
        return true;
    }
  }

  String _getNextDate(DateTime? lastDate, String frequency) {
    if (lastDate == null) return "Ya disponible";
    int days = 7;
    switch (frequency) {
      case 'daily':
        days = 1;
        break;
      case 'weekly':
        days = 7;
        break;
      case 'biweekly':
        days = 14;
        break;
      case 'monthly':
        days = 30;
        break;
      case 'quarterly':
        days = 90;
        break;
    }
    final next = lastDate.add(Duration(days: days));
    return "${next.day}/${next.month}/${next.year}";
  }

  @override
  void dispose() {
    _pesoController.dispose();
    _grasaController.dispose();
    _masaMusculoController.dispose();
    for (var c in _muscleControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() {
      _error = null;
    });

    final peso = _pesoController.text.trim();
    final grasa = _grasaController.text.trim();
    final masaMusculo = _masaMusculoController.text.trim();
    final muscles = <Map<String, dynamic>>[];

    bool hasData =
        peso.isNotEmpty || grasa.isNotEmpty || masaMusculo.isNotEmpty;

    _muscleControllers.forEach((name, ctrl) {
      final val = ctrl.text.trim();
      if (val.isNotEmpty) {
        hasData = true;
        muscles.add({"nombre": name, "medida": double.tryParse(val) ?? 0.0});
      }
    });

    if (!hasData) {
      setState(() {
        _error = "Debes ingresar al menos un dato.";
      });
      return;
    }

    if (peso.isNotEmpty && (double.tryParse(peso) ?? 0) <= 0) {
      setState(() {
        _error = "El peso debe ser mayor a 0.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final body = {
        "fecha": DateTime.now().toIso8601String(),
        if (peso.isNotEmpty) "peso": double.parse(peso),
        if (grasa.isNotEmpty) "grasaCorporal": double.parse(grasa),
        if (masaMusculo.isNotEmpty)
          "MasaMusculoEsqueletica": double.parse(masaMusculo),
        "musculo": muscles,
      };

      await api.put('/clientes/${widget.clienteId}/historial', body);
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = "Error al guardar: $e";
        _isLoading = false;
      });
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
        // Remove fixed width/height, use constraints
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: size.height * 0.9, // 90% of screen height
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Shrink wrap content
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment
                  .spaceBetween, // Use spaceBetween instead of Expanded/Icon
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nuevo Progreso',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Registra las nuevas medidas y peso del cliente',
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
            const SizedBox(height: 16),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else ...[
              if (_error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(theme, "GENERALES"),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _pesoController,
                              label: "Peso (kg)",
                              icon: Icons.monitor_weight_outlined,
                              enabled: _isWeightEnabled,
                              hint: _isWeightEnabled
                                  ? null
                                  : _getNextDate(
                                      _lastWeight,
                                      _settings?.weightFrequency ?? "weekly",
                                    ),
                              theme: theme,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _grasaController,
                              label: "Grasa (%)",
                              icon: Icons.opacity_outlined,
                              enabled: _isFatEnabled,
                              hint: _isFatEnabled
                                  ? null
                                  : _getNextDate(
                                      _lastFat,
                                      _settings?.fatFrequency ?? "weekly",
                                    ),
                              theme: theme,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _masaMusculoController,
                        label: "Masa Músculo-Esq. (kg)",
                        icon: Icons.fitness_center_outlined,
                        enabled: _isMuscleEnabled,
                        hint: _isMuscleEnabled
                            ? null
                            : _getNextDate(
                                _lastMuscle,
                                _settings?.muscleFrequency ?? "monthly",
                              ),
                        theme: theme,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      MuscleMassBar(
                        weight: double.tryParse(_pesoController.text) ?? 0,
                        muscleMass:
                            double.tryParse(_masaMusculoController.text) ?? 0,
                        height: _clientHeight,
                        gender: _clientGender,
                      ),

                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionTitle(theme, "MEDIDAS CORPORALES"),
                          TextButton(
                            onPressed: _isMeasuresEnabled
                                ? () {
                                    for (var c in _muscleControllers.values) {
                                      c.clear();
                                    }
                                  }
                                : null,
                            child: Text(
                              "Limpiar",
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Arms
                      _buildMeasureGroup(
                        theme,
                        isDark,
                        "BRAZOS",
                        "Brazo derecho",
                        "Brazo izquierdo",
                      ),
                      const SizedBox(height: 12),
                      // Legs
                      _buildMeasureGroup(
                        theme,
                        isDark,
                        "PIERNAS",
                        "Pierna derecha",
                        "Pierna izquierda",
                      ),
                      const SizedBox(height: 12),
                      // Calves
                      _buildMeasureGroup(
                        theme,
                        isDark,
                        "GEMELOS",
                        "Gemelo derecho",
                        "Gemelo izquierdo",
                      ),
                      const SizedBox(height: 12),
                      // Forearms
                      _buildMeasureGroup(
                        theme,
                        isDark,
                        "ANTEBRAZOS",
                        "Antebrazo derecho",
                        "Antebrazo izquierdo",
                      ),
                      const SizedBox(height: 12),
                      // Shoulders
                      _buildMeasureGroup(
                        theme,
                        isDark,
                        "HOMBROS",
                        "Hombro derecho",
                        "Hombro izquierdo",
                      ),

                      const SizedBox(height: 24),
                      Text(
                        "OTRAS ZONAS",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.hintColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final width = (constraints.maxWidth - 16) / 2;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: width,
                                child: _buildSmallField(
                                  theme,
                                  isDark,
                                  "Espalda",
                                  "Espalda",
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: _buildSmallField(
                                  theme,
                                  isDark,
                                  "Pecho",
                                  "Pecho",
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: _buildSmallField(
                                  theme,
                                  isDark,
                                  "Trapecio",
                                  "Trapecio",
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: _buildSmallField(
                                  theme,
                                  isDark,
                                  "Glúteo",
                                  "Glúteo",
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: _buildSmallField(
                                  theme,
                                  isDark,
                                  "Cint. Ancha",
                                  "CINTURA ANCHA",
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: _buildSmallField(
                                  theme,
                                  isDark,
                                  "Cint. Estrecha",
                                  "CINTURA ESTRECHA",
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
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
                    onPressed: _handleSave,
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
                    child: const Text(
                      'Guardar Progreso',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
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
    bool enabled = true,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: enabled
            ? theme.textTheme.bodyMedium?.color
            : theme.disabledColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: theme.hintColor.withOpacity(0.5),
          fontSize: 12,
        ),
        labelStyle: TextStyle(
          color: enabled ? theme.hintColor : theme.disabledColor,
        ),
        prefixIcon: Icon(
          icon,
          color: enabled
              ? theme.primaryColor.withOpacity(0.7)
              : theme.disabledColor.withOpacity(0.5),
          size: 20,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.05)),
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

  Widget _buildMeasureGroup(
    ThemeData theme,
    bool isDark,
    String title,
    String keyRight,
    String keyLeft,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: theme.hintColor.withOpacity(0.7),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildSmallField(theme, isDark, "Derecho", keyRight),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSmallField(theme, isDark, "Izquierdo", keyLeft),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallField(
    ThemeData theme,
    bool isDark,
    String label,
    String key,
  ) {
    bool enabled = _isMeasuresEnabled;
    return TextFormField(
      controller: _muscleControllers[key],
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: enabled
            ? theme.textTheme.bodyMedium?.color
            : theme.disabledColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        labelStyle: TextStyle(
          color: enabled ? theme.hintColor : theme.disabledColor,
          fontSize: 13,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.primaryColor),
        ),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}
