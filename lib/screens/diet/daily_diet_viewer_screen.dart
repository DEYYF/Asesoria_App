import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/dieta_model.dart';
import '../../models/macros_model.dart';

class DailyDietViewerScreen extends StatelessWidget {
  final Dieta dieta;
  final DiaCalendario dia;
  final DateTime fecha;

  const DailyDietViewerScreen({
    super.key,
    required this.dieta,
    required this.dia,
    required this.fecha,
  });

  Macros _sumDayMacros() {
    return dia.comidas.fold<Macros>(
      Macros(),
      (acc, comida) => Macros(
        kcal: acc.kcal + comida.totales.kcal,
        proteinas: acc.proteinas + comida.totales.proteinas,
        carbohidratos: acc.carbohidratos + comida.totales.carbohidratos,
        grasas: acc.grasas + comida.totales.grasas,
      ),
    );
  }

  String _optionSubtitle(OpcionDieta option) {
    final parts = <String>[];
    if (option.gramos != null && option.gramos! > 0) {
      parts.add('${option.gramos!.toStringAsFixed(option.gramos! % 1 == 0 ? 0 : 1)} g');
    }
    if (option.unidades != null && option.unidades! > 0) {
      parts.add('${option.unidades} uds');
    }
    if (option.tipo == 'receta') parts.add('Receta');
    if (option.tipo == 'combinacion') parts.add('Combinación');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macros = _sumDayMacros();
    final dateLabel = DateFormat('EEEE, d MMMM', 'es').format(fecha);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: const Text('Dieta del día'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              dieta.nombre,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$dateLabel · ${dia.dia}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            _buildMacrosCard(theme, macros),
            const SizedBox(height: 24),
            if (dia.comidas.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text(
                    'No hay comidas asignadas para este día.',
                    style: TextStyle(color: theme.hintColor),
                  ),
                ),
              )
            else
              ...dia.comidas.map((comida) => _buildMealCard(theme, comida)),
          ],
        ),
      ),
    );
  }

  Widget _buildMacrosCard(ThemeData theme, Macros macros) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _macroItem('Kcal', macros.kcal),
          _macroItem('P', macros.proteinas),
          _macroItem('C', macros.carbohidratos),
          _macroItem('G', macros.grasas),
        ],
      ),
    );
  }

  Widget _macroItem(String label, double value) {
    return Column(
      children: [
        Text(
          value.toStringAsFixed(0),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildMealCard(ThemeData theme, Comida comida) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  comida.titulo,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (comida.hora != null && comida.hora!.isNotEmpty)
                Text(
                  comida.hora!,
                  style: TextStyle(
                    color: theme.hintColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${comida.totales.kcal.toStringAsFixed(0)} kcal · P ${comida.totales.proteinas.toStringAsFixed(0)} · C ${comida.totales.carbohidratos.toStringAsFixed(0)} · G ${comida.totales.grasas.toStringAsFixed(0)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          ...comida.opciones.map((option) => _buildOption(theme, option)),
          if (comida.notas != null && comida.notas!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              comida.notas!,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOption(ThemeData theme, OpcionDieta option) {
    final subtitle = _optionSubtitle(option);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 7, right: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF34C759),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.nombre ?? 'Opción',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                if (option.items != null && option.items!.isNotEmpty)
                  ...option.items!.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        '- ${item.nombre ?? 'Ingrediente'} · ${item.gramos.toStringAsFixed(0)} g',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
