import 'package:flutter/material.dart';

class MuscleMassBar extends StatelessWidget {
  final double weight;
  final double muscleMass;
  final double? height; // in cm
  final String? gender; // 'Hombre', 'Mujer', 'Otro'

  const MuscleMassBar({
    super.key,
    required this.weight,
    required this.muscleMass,
    this.height,
    this.gender,
  });

  @override
  Widget build(BuildContext context) {
    if (weight <= 0 || muscleMass <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final percentage = (muscleMass / weight) * 100;
    final isMujer = gender == 'Mujer';

    // Index based on height (SMI: kg/m^2)
    double? smi;
    if (height != null && height! > 0) {
      final heightM = height! / 100;
      smi = muscleMass / (heightM * heightM);
    }

    // Refined Scientific Ranges
    final lowMax = isMujer ? 24.0 : 33.0;
    final normalMax = isMujer ? 35.0 : 44.0; // Refined upper bound

    Color color;
    String label;
    double progress; // 0 to 1 for the visual indicator location

    if (percentage < lowMax) {
      color = Colors.redAccent;
      label = "BAJO";
      progress = (percentage / lowMax) * 0.33;
    } else if (percentage <= normalMax) {
      color = Colors.greenAccent;
      label = "NORMAL";
      progress = 0.33 + ((percentage - lowMax) / (normalMax - lowMax)) * 0.33;
    } else {
      color = const Color(0xFF00B2FF); // Profound Blue/Cyan
      label = "ALTO";
      progress =
          0.66 +
          ((percentage - normalMax) / 15) * 0.34; // Range of 15% above normal
    }
    if (progress > 1.0) progress = 1.0;
    if (progress < 0.0) progress = 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "% Masa Muscular: ${percentage.toStringAsFixed(1)}%",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "FÓRMULA: %M.M = (M.M / Peso) × 100",
                  style: TextStyle(
                    fontSize: 9,
                    color: theme.hintColor.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (smi != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    "SMI: ${smi.toStringAsFixed(1)} kg/m²",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  Text(
                    "FÓRMULA: SMI = M.M / Altura²",
                    style: TextStyle(
                      fontSize: 8,
                      color: theme.hintColor.withOpacity(0.5),
                    ),
                  ),
                ],
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 14,
          decoration: BoxDecoration(
            color: theme.dividerColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Stack(
            children: [
              // Segment Backdrops
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(7),
                          bottomLeft: Radius.circular(7),
                        ),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1, color: Colors.white24),
                  Expanded(
                    child: Container(color: Colors.green.withOpacity(0.15)),
                  ),
                  const VerticalDivider(width: 1, color: Colors.white24),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B2FF).withOpacity(0.15),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(7),
                          bottomRight: Radius.circular(7),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Indicator Bar
              AnimatedAlign(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                alignment: Alignment(progress * 2 - 1, 0),
                child: Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1.5),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildRangeLabel(theme, "Bajo", "< ${lowMax.toInt()}%"),
            _buildRangeLabel(
              theme,
              "Normal",
              "${lowMax.toInt()}-${normalMax.toInt()}%",
            ),
            _buildRangeLabel(theme, "Alto", "> ${normalMax.toInt()}%"),
          ],
        ),
      ],
    );
  }

  Widget _buildRangeLabel(ThemeData theme, String label, String range) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: theme.hintColor,
          ),
        ),
        Text(
          range,
          style: TextStyle(
            fontSize: 8,
            color: theme.hintColor.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
