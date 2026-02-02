import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/client_service.dart';
import '../../../services/api_service.dart';
import '../../../utils/notification_helper.dart';

class HabitDialog extends StatefulWidget {
  final String clientId;

  const HabitDialog({super.key, required this.clientId});

  @override
  State<HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends State<HabitDialog> {
  double _waterLiters = 2.0;
  double _hoursSleep = 7.5;
  String _mood = 'Motivado';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _moods = [
    {
      'label': 'Cansado',
      'icon': Icons.sentiment_dissatisfied_rounded,
      'color': Colors.orange,
    },
    {
      'label': 'Normal',
      'icon': Icons.sentiment_neutral_rounded,
      'color': Colors.blue,
    },
    {
      'label': 'Motivado',
      'icon': Icons.sentiment_very_satisfied_rounded,
      'color': Colors.green,
    },
    {'label': 'Estresado', 'icon': Icons.bolt_rounded, 'color': Colors.red},
  ];

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final clientService = ClientService(
        Provider.of<ApiService>(context, listen: false),
      );

      final data = {
        'fecha': DateTime.now().toIso8601String(),
        'habitos': {'agua': _waterLiters, 'sueno': _hoursSleep, 'animo': _mood},
      };

      await clientService.addProgress(widget.clientId, data);

      if (!mounted) return;
      Navigator.pop(context, true);
      NotificationHelper.showSuccess(
        context,
        '¡Hábitos registrados! Sigue así 🚀',
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Seguimiento Diario',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // AGUA
              _buildHabitSection(
                label: 'Agua (Litros)',
                icon: Icons.water_drop_rounded,
                color: Colors.blue,
                child: Column(
                  children: [
                    Text(
                      '${_waterLiters.toStringAsFixed(1)} L',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Slider(
                      value: _waterLiters,
                      min: 0,
                      max: 6,
                      divisions: 60,
                      onChanged: (val) => setState(() => _waterLiters = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // SUEÑO
              _buildHabitSection(
                label: 'Sueño (Horas)',
                icon: Icons.bedtime_rounded,
                color: Colors.indigo,
                child: Column(
                  children: [
                    Text(
                      '${_hoursSleep.toStringAsFixed(1)} h',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Slider(
                      value: _hoursSleep,
                      min: 0,
                      max: 12,
                      divisions: 24,
                      onChanged: (val) => setState(() => _hoursSleep = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ÁNIMO
              _buildHabitSection(
                label: '¿Cómo te sientes hoy?',
                icon: Icons.mood_rounded,
                color: Colors.amber,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: _moods.map((m) {
                    final isSelected = _mood == m['label'];
                    return InkWell(
                      onTap: () => setState(() => _mood = m['label']),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? m['color']
                                  : m['color'].withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              m['icon'],
                              color: isSelected ? Colors.white : m['color'],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            m['label'],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected ? m['color'] : theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
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
                          : const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHabitSection({
    required String label,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
