import 'package:flutter/material.dart';
import '../premium_settings_widgets.dart';

class IntelligenceSettingsDialog extends StatefulWidget {
  final Map<String, dynamic> settings;
  final Function(Map<String, dynamic>) onSave;

  const IntelligenceSettingsDialog({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<IntelligenceSettingsDialog> createState() =>
      _IntelligenceSettingsDialogState();
}

class _IntelligenceSettingsDialogState
    extends State<IntelligenceSettingsDialog> {
  late Map<String, dynamic> intel;
  late Map<String, dynamic> macros;
  late Map<String, dynamic> steps;
  late Map<String, dynamic> training;

  @override
  void initState() {
    super.initState();
    intel = Map<String, dynamic>.from(widget.settings['intelligence'] ?? {});
    macros = Map<String, dynamic>.from(intel['macroAdjustment'] ?? {});
    steps = Map<String, dynamic>.from(intel['steps'] ?? {});
    training = Map<String, dynamic>.from(intel['trainingIncrements'] ?? {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Row(
        children: [
          Icon(
            Icons.psychology_rounded,
            color: Colors.purple.shade400,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Text(
            'Inteligencia Artificial',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumCategory(
                title: 'ANÁLISIS DE PROGRESO',
                icon: Icons.auto_graph_rounded,
              ),
              PremiumToggle(
                title: 'Análisis Avanzado',
                subtitle:
                    'Usa IA para detectar cambios sutiles en composición corporal',
                value: intel['advancedAnalysis'] ?? false,
                onChanged: (v) => setState(() => intel['advancedAnalysis'] = v),
              ),
              PremiumSlider(
                title: 'Margen Estancamiento (kg)',
                subtitle: 'Umbral para considerar falta de progreso',
                value: intel['stallThreshold'] ?? 0.2,
                min: 0.1,
                max: 1.0,
                onChanged: (v) => setState(() => intel['stallThreshold'] = v),
              ),
              PremiumSlider(
                title: 'Límite Ganancia Rápida (kg)',
                subtitle: 'Alerta al superar este aumento semanal',
                value: intel['rapidGainThreshold'] ?? 0.5,
                min: 0.1,
                max: 2.0,
                onChanged: (v) =>
                    setState(() => intel['rapidGainThreshold'] = v),
              ),
              PremiumSlider(
                title: 'Límite Pérdida Rápida (kg)',
                subtitle: 'Alerta al superar este descenso semanal',
                value: intel['rapidLossThreshold'] ?? 1.0,
                min: 0.1,
                max: 3.0,
                onChanged: (v) =>
                    setState(() => intel['rapidLossThreshold'] = v),
              ),
              const SizedBox(height: 24),
              const PremiumCategory(
                title: 'ESTRATEGIA DE MACROS',
                icon: Icons.restaurant_rounded,
              ),
              _buildMacroGroup('PÉRDIDA / DEFINICIÓN', macros, 'loss'),
              _buildMacroGroup('GANANCIA / VOLUMEN', macros, 'gain'),
              _buildMacroGroup('PÉRDIDA RÁPIDA (REBOTE)', macros, 'rapidLoss'),
              _buildMacroGroup('GANANCIA RÁPIDA (REBOTO)', macros, 'rapidGain'),
              const SizedBox(height: 24),
              const PremiumCategory(
                title: 'PASOS & PROGRESIÓN',
                icon: Icons.directions_walk_rounded,
              ),
              PremiumToggle(
                title: 'Ajuste Automático de Pasos',
                subtitle: 'Sugiere incrementos basados en rendimiento',
                value: steps['enabled'] ?? true,
                onChanged: (v) => setState(() => steps['enabled'] = v),
              ),
              if (steps['enabled'] == true) ...[
                PremiumSlider(
                  title: 'Incremento de Pasos',
                  subtitle: 'Pasos extra a añadir por semana',
                  value: steps['increment'] ?? 2000,
                  min: 500,
                  max: 5000,
                  onChanged: (v) => setState(() => steps['increment'] = v),
                  isInteger: true,
                ),
                PremiumToggle(
                  title: 'Prioridad sobre Dieta',
                  subtitle: 'Aumentar pasos antes de recortar calorías',
                  value: steps['prioritize'] ?? true,
                  onChanged: (v) => setState(() => steps['prioritize'] = v),
                ),
              ],
              const SizedBox(height: 16),
              PremiumSlider(
                title: 'Progresión: Grupo Grande',
                subtitle: 'Incremento de peso sugerido (kg)',
                value: training['large'] ?? 5.0,
                min: 1.0,
                max: 10.0,
                onChanged: (v) => setState(() => training['large'] = v),
              ),
              PremiumSlider(
                title: 'Progresión: Grupo Pequeño',
                subtitle: 'Incremento de peso sugerido (kg)',
                value: training['small'] ?? 1.25,
                min: 0.25,
                max: 5.0,
                onChanged: (v) => setState(() => training['small'] = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'CANCELAR',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade400,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: () {
            final updatedIntel = Map<String, dynamic>.from(intel);
            updatedIntel['macroAdjustment'] = macros;
            updatedIntel['steps'] = steps;
            updatedIntel['trainingIncrements'] = training;
            widget.onSave(updatedIntel);
            Navigator.pop(context);
          },
          child: const Text(
            'GUARDAR AJUSTES',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildMacroGroup(
    String label,
    Map<String, dynamic> macros,
    String key,
  ) {
    final data = Map<String, dynamic>.from(
      macros[key] ?? {'kcal': 1.0, 'carbs': 1.0},
    );
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: PremiumSlider(
                  title: 'Kcal %',
                  subtitle: 'Factor Multiplicador',
                  value: data['kcal'] ?? 1.0,
                  min: 0.5,
                  max: 1.5,
                  onChanged: (v) => setState(() {
                    data['kcal'] = v;
                    macros[key] = data;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PremiumSlider(
                  title: 'Carbs %',
                  subtitle: 'Ajuste Hidratos',
                  value: data['carbs'] ?? 1.0,
                  min: 0.5,
                  max: 1.5,
                  onChanged: (v) => setState(() {
                    data['carbs'] = v;
                    macros[key] = data;
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
