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
          if (_lastFat == null && entry['grasaCorporal'] != null)
            _lastFat = date;
          if (_lastMuscle == null && entry['MasaMusculoEsqueletica'] != null)
            _lastMuscle = date;
          if (_lastMeasures == null &&
              entry['musculo'] != null &&
              (entry['musculo'] as List).isNotEmpty)
            _lastMeasures = date;
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

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      title: Text(
        'Añadir Progreso',
        style: TextStyle(color: theme.textTheme.titleLarge?.color),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 16),
                        color: isDark
                            ? Colors.red.withOpacity(0.2)
                            : Colors.red.shade50,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: isDark
                                ? Colors.redAccent
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pesoController,
                            style: TextStyle(
                              color: _isWeightEnabled
                                  ? theme.textTheme.bodyMedium?.color
                                  : theme.disabledColor,
                            ),
                            enabled: _isWeightEnabled,
                            decoration: InputDecoration(
                              labelText: 'Peso (kg)',
                              hintText: _isWeightEnabled
                                  ? null
                                  : 'Disponible ${_getNextDate(_lastWeight, _settings?.weightFrequency ?? "weekly")}',
                              labelStyle: TextStyle(color: theme.hintColor),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.dividerColor,
                                ),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.dividerColor.withOpacity(0.1),
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _grasaController,
                            style: TextStyle(
                              color: _isFatEnabled
                                  ? theme.textTheme.bodyMedium?.color
                                  : theme.disabledColor,
                            ),
                            enabled: _isFatEnabled,
                            decoration: InputDecoration(
                              labelText: 'Grasa (%)',
                              hintText: _isFatEnabled
                                  ? null
                                  : 'Disp. ${_getNextDate(_lastFat, _settings?.fatFrequency ?? "weekly")}',
                              labelStyle: TextStyle(color: theme.hintColor),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.dividerColor,
                                ),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.dividerColor.withOpacity(0.1),
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _masaMusculoController,
                      enabled: _isMuscleEnabled,
                      style: TextStyle(
                        color: _isMuscleEnabled
                            ? theme.textTheme.bodyMedium?.color
                            : theme.disabledColor,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Masa Músculo-Esquelética (kg)',
                        hintText: _isMuscleEnabled
                            ? null
                            : 'Disponible ${_getNextDate(_lastMuscle, _settings?.muscleFrequency ?? "monthly")}',
                        labelStyle: TextStyle(color: theme.hintColor),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: theme.dividerColor.withOpacity(0.1),
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    MuscleMassBar(
                      weight: double.tryParse(_pesoController.text) ?? 0,
                      muscleMass:
                          double.tryParse(_masaMusculoController.text) ?? 0,
                      height: _clientHeight,
                      gender: _clientGender,
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          for (var c in _muscleControllers.values) {
                            c.clear();
                          }
                        },
                        child: const Text('Limpiar medidas'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildMeasureRow(
                      theme,
                      "BRAZOS",
                      "Brazo derecho",
                      "Brazo izquierdo",
                    ),
                    const SizedBox(height: 12),
                    _buildMeasureRow(
                      theme,
                      "PIERNAS",
                      "Pierna derecha",
                      "Pierna izquierda",
                    ),
                    const SizedBox(height: 12),
                    _buildMeasureRow(
                      theme,
                      "GEMELOS",
                      "Gemelo derecho",
                      "Gemelo izquierdo",
                    ),
                    const SizedBox(height: 12),
                    _buildMeasureRow(
                      theme,
                      "ANTEBRAZOS",
                      "Antebrazo derecho",
                      "Antebrazo izquierdo",
                    ),
                    const SizedBox(height: 12),
                    _buildMeasureRow(
                      theme,
                      "HOMBROS",
                      "Hombro derecho",
                      "Hombro izquierdo",
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "OTRAS MEDIDAS",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor.withOpacity(0.8),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildSingleMeasure(theme, "Espalda", "Espalda"),
                        _buildSingleMeasure(theme, "Pecho", "Pecho"),
                        _buildSingleMeasure(theme, "Trapecio", "Trapecio"),
                        _buildSingleMeasure(theme, "Glúteo", "Glúteo"),
                        _buildSingleMeasure(
                          theme,
                          "Cint. Ancha",
                          "CINTURA ANCHA",
                        ),
                        _buildSingleMeasure(
                          theme,
                          "Cint. Estrecha",
                          "CINTURA ESTRECHA",
                        ),
                      ],
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

  Widget _buildMeasureRow(
    ThemeData theme,
    String title,
    String derKey,
    String izqKey,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.hintColor.withOpacity(0.7),
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildSmallField(theme, "Der.", derKey)),
            const SizedBox(width: 12),
            Expanded(child: _buildSmallField(theme, "Izq.", izqKey)),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleMeasure(ThemeData theme, String label, String key) {
    // For mobile, we want 2 items per row in the Wrap.
    // Taking the screen width, subtracting dialog padding (~48) and wrap spacing (12).
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth =
        (screenWidth - 80) / 2; // Conservative estimate for mobile dialogs

    return SizedBox(
      width: itemWidth > 150 ? 150 : itemWidth,
      child: _buildSmallField(theme, label, key),
    );
  }

  Widget _buildSmallField(ThemeData theme, String label, String key) {
    return TextField(
      controller: _muscleControllers[key],
      enabled: _isMeasuresEnabled,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        labelStyle: TextStyle(color: theme.hintColor, fontSize: 13),
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
          borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
        ),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(
        fontSize: 14,
        color: _isMeasuresEnabled
            ? theme.textTheme.bodyMedium?.color
            : theme.disabledColor,
      ),
    );
  }
}
