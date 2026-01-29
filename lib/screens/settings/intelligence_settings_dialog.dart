import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../services/api_service.dart';
import '../../utils/notification_helper.dart';

class IntelligenceSettingsDialog extends StatefulWidget {
  final Map<String, dynamic> currentSettings;
  final VoidCallback onSaved;

  const IntelligenceSettingsDialog({
    super.key,
    required this.currentSettings,
    required this.onSaved,
  });

  @override
  State<IntelligenceSettingsDialog> createState() =>
      _IntelligenceSettingsDialogState();
}

class _IntelligenceSettingsDialogState
    extends State<IntelligenceSettingsDialog> {
  late double _stallThreshold;
  late double _rapidGainThreshold;
  late double _rapidLossThreshold; // New
  late bool _advancedAnalysis;

  // Steps
  late bool _enableSteps;
  late double _stepsIncrement;

  // Macros - Loss
  late double _lossKcal;
  late double _lossCarbs;

  // Macros - Gain
  late double _gainKcal;
  late double _gainCarbs;

  // Macros - Rapid Gain
  // Macros - Rapid Gain
  late double _rapidGainKcal;
  late double _rapidGainCarbs;

  // Macros - Rapid Loss
  late double _rapidLossKcal;
  late double _rapidLossCarbs;

  // Training
  late double _trainLarge;
  late double _trainMedium;
  late double _trainSmall;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.currentSettings['intelligence'] ?? {};
    _stallThreshold = (settings['stallThreshold'] ?? 0.2).toDouble();
    _rapidGainThreshold = (settings['rapidGainThreshold'] ?? 0.5).toDouble();
    _rapidLossThreshold = (settings['rapidLossThreshold'] ?? 1.0).toDouble();
    _advancedAnalysis = settings['advancedAnalysis'] ?? false;

    final steps = settings['steps'] ?? {};
    _enableSteps = steps['enabled'] ?? true;
    _stepsIncrement = (steps['increment'] ?? 2000).toDouble();

    final macros = settings['macroAdjustment'] ?? {};
    final loss = macros['loss'] ?? {};
    final gain = macros['gain'] ?? {};
    final rapidGain = macros['rapidGain'] ?? {};

    _lossKcal = (loss['kcal'] ?? 0.9).toDouble();
    _lossCarbs = (loss['carbs'] ?? 0.85).toDouble();

    _gainKcal = (gain['kcal'] ?? 1.05).toDouble();
    _gainCarbs = (gain['carbs'] ?? 1.1).toDouble();

    _rapidGainKcal = (rapidGain['kcal'] ?? 0.95).toDouble();
    _rapidGainCarbs = (rapidGain['carbs'] ?? 0.9).toDouble();

    final rapidLoss = macros['rapidLoss'] ?? {};
    _rapidLossKcal = (rapidLoss['kcal'] ?? 1.05).toDouble();
    _rapidLossCarbs = (rapidLoss['carbs'] ?? 1.1).toDouble();

    final train = settings['trainingIncrements'] ?? {};
    _trainLarge = (train['large'] ?? 5.0).toDouble();
    _trainMedium = (train['medium'] ?? 2.5).toDouble();
    _trainSmall = (train['small'] ?? 1.25).toDouble();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final api = Provider.of<ApiService>(context, listen: false);
    final service = SettingsService(api);

    try {
      // 1. Get current full settings to avoid overwriting other fields
      // Assuming we can merge or update specific field via API
      // Since our API updates the whole settings object, we usually need the full object.
      // However, we passed `currentSettings` which might be just intelligence part or full?
      // Let's assume we need to update the intelligence part of the user settings.

      final updatedIntelligence = {
        'stallThreshold': _stallThreshold,
        'rapidGainThreshold': _rapidGainThreshold,
        'rapidLossThreshold': _rapidLossThreshold,
        'advancedAnalysis': _advancedAnalysis,
        'macroAdjustment': {
          'loss': {'kcal': _lossKcal, 'carbs': _lossCarbs},
          'gain': {'kcal': _gainKcal, 'carbs': _gainCarbs},
          'rapidGain': {'kcal': _rapidGainKcal, 'carbs': _rapidGainCarbs},
          'rapidLoss': {'kcal': _rapidLossKcal, 'carbs': _rapidLossCarbs},
        },
        'steps': {
          'enabled': _enableSteps,
          'increment': _stepsIncrement,
          'prioritize': true,
        },
        'trainingIncrements': {
          'large': _trainLarge,
          'medium': _trainMedium,
          'small': _trainSmall,
        },
      };

      // We need to fetch full settings first to merge, or specific endpoint.
      // Using SettingsService to update full settings map
      final currentFull = await service.getSettingsMap();
      currentFull['intelligence'] = updatedIntelligence;

      await service.updateSettingsMap(currentFull);

      if (mounted) {
        NotificationHelper.showSuccess(context, 'Configuración actualizada');
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.showError(context, 'Error: $e');
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.psychology_rounded, color: theme.primaryColor),
                  const SizedBox(width: 12),
                  const Text(
                    'Configuración de Inteligencia',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildSectionTitle(theme, 'Detección de Estancamiento'),
                  SwitchListTile(
                    title: const Text(
                      'Análisis Avanzado (Composición Corporal)',
                    ),
                    subtitle: const Text(
                      'Usar % Grasa y M. Muscular para refinar ajustes',
                    ),
                    value: _advancedAnalysis,
                    activeColor: theme.primaryColor,
                    onChanged: (val) => setState(() => _advancedAnalysis = val),
                    secondary: Tooltip(
                      message:
                          'Si se activa, el sistema verificará si el aumento de peso es músculo (bueno) o grasa (malo) antes de sugerir cambios.',
                      child: Icon(
                        Icons.psychology_alt_rounded,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                  const Divider(),
                  _buildSliderRow(
                    'Margen de Peso (Estancamiento)',
                    'Considerar estancado si varía menos de...',
                    _stallThreshold,
                    0.1,
                    1.0,
                    (v) => setState(() => _stallThreshold = v),
                    unit: 'kg',
                  ),
                  const SizedBox(height: 16),
                  _buildSliderRow(
                    'Límite de Ganancia Rápida',
                    'Alertar si sube más de... (en 3 registros)',
                    _rapidGainThreshold,
                    0.3,
                    2.0,
                    (v) => setState(() => _rapidGainThreshold = v),
                    unit: 'kg',
                  ),
                  const SizedBox(height: 16),
                  _buildSliderRow(
                    'Límite de Pérdida Rápida',
                    'Alertar si baja más de... (Protección muscular)',
                    _rapidLossThreshold,
                    0.5,
                    3.0,
                    (v) => setState(() => _rapidLossThreshold = v),
                    unit: 'kg',
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle(theme, 'Comodín: Pasos / Cardio'),
                  SwitchListTile(
                    title: const Text('Sugerir Pasos antes que Dieta'),
                    subtitle: const Text(
                      'En estancamiento, sugerir moverse más primero',
                    ),
                    value: _enableSteps,
                    activeColor: theme.primaryColor,
                    onChanged: (val) => setState(() => _enableSteps = val),
                    secondary: const Icon(Icons.directions_walk_rounded),
                  ),
                  if (_enableSteps)
                    _buildSliderRow(
                      'Incremento de Pasos',
                      'Pasos extra a sugerir',
                      _stepsIncrement,
                      1000,
                      5000,
                      (v) => setState(() => _stepsIncrement = v),
                      unit: ' pasos',
                    ),

                  const SizedBox(height: 24),
                  _buildSectionTitle(theme, 'Ajuste Automático de Macros'),
                  const Text(
                    'Déficit / Pérdida',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  _buildPercentageInput(
                    'Kcal',
                    _lossKcal,
                    (v) => setState(() => _lossKcal = v),
                  ),
                  _buildPercentageInput(
                    'Carbohidratos',
                    _lossCarbs,
                    (v) => setState(() => _lossCarbs = v),
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'Superávit / Ganancia',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  _buildPercentageInput(
                    'Kcal',
                    _gainKcal,
                    (v) => setState(() => _gainKcal = v),
                  ),
                  _buildPercentageInput(
                    'Carbohidratos',
                    _gainCarbs,
                    (v) => setState(() => _gainCarbs = v),
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'Ganancia Rápida (Corrección)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  _buildPercentageInput(
                    'Kcal',
                    _rapidGainKcal,
                    (v) => setState(() => _rapidGainKcal = v),
                  ),
                  _buildPercentageInput(
                    'Carbohidratos',
                    _rapidGainCarbs,
                    (v) => setState(() => _rapidGainCarbs = v),
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'Pérdida Rápida (Protección)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  _buildPercentageInput(
                    'Kcal',
                    _rapidLossKcal,
                    (v) => setState(() => _rapidLossKcal = v),
                  ),
                  _buildPercentageInput(
                    'Carbohidratos',
                    _rapidLossCarbs,
                    (v) => setState(() => _rapidLossCarbs = v),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle(theme, 'Progresión de Cargas (IA)'),
                  _buildWeightInput(
                    'Grupo Grande (Pierna, Espalda...)',
                    _trainLarge,
                    (v) => setState(() => _trainLarge = v),
                  ),
                  _buildWeightInput(
                    'Grupo Medio (Hombro, Pecho...)',
                    _trainMedium,
                    (v) => setState(() => _trainMedium = v),
                  ),
                  _buildWeightInput(
                    'Grupo Pequeño (Bíceps, Tríceps...)',
                    _trainSmall,
                    (v) => setState(() => _trainSmall = v),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar Cambios'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.primaryColor,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSliderRow(
    String title,
    String subtitle,
    double value,
    double min,
    double max,
    Function(double) onChanged, {
    String unit = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            Text(
              '${value.toStringAsFixed(2)} $unit',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) / 0.05).round(),
          label: value.toStringAsFixed(2),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildPercentageInput(
    String label,
    double value,
    Function(double) onChanged,
  ) {
    final percent = ((value - 1) * 100).round();
    final isNegative = percent < 0;
    final display = isNegative ? '$percent%' : '+$percent%';
    final color = isNegative ? Colors.red : Colors.green;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Row(
              children: [
                Text(label),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Ajuste de $label para este objetivo',
                  child: const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: 0.5,
              max: 1.5,
              divisions: 20,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              display,
              textAlign: TextAlign.end,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightInput(
    String label,
    double value,
    Function(double) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: Text(label)),
                Tooltip(
                  message: 'Incremento sugerido para este grupo',
                  child: const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          DropdownButton<double>(
            value: [0.5, 1.0, 1.25, 2.0, 2.5, 5.0, 10.0].contains(value)
                ? value
                : 2.5, // Default to 2.5 if not found
            underline: const SizedBox(),
            items: [0.5, 1.0, 1.25, 2.0, 2.5, 5.0, 10.0]
                .map((v) => DropdownMenuItem(value: v, child: Text('+${v}kg')))
                .toList(),
            onChanged: (v) => v != null ? onChanged(v) : null,
          ),
        ],
      ),
    );
  }
}
