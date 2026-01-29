import 'package:flutter/material.dart';

class AdvisorCalendarTab extends StatefulWidget {
  final Map<String, dynamic> calendarSettings;
  final bool isSaving;
  final VoidCallback onSave;

  const AdvisorCalendarTab({
    super.key,
    required this.calendarSettings,
    required this.isSaving,
    required this.onSave,
  });

  @override
  State<AdvisorCalendarTab> createState() => _AdvisorCalendarTabState();
}

class _AdvisorCalendarTabState extends State<AdvisorCalendarTab> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workHours =
        widget.calendarSettings['workHours'] ?? {'startHour': 7, 'endHour': 22};
    final vacationDays = List<String>.from(
      widget.calendarSettings['vacationDays'] ?? [],
    );
    final bloques = List<Map<String, dynamic>>.from(
      widget.calendarSettings['bloques'] ?? [],
    );

    return ListView(
      padding: const EdgeInsets.all(0),
      children: [
        _buildSectionHeader(theme, 'Horario Laboral General'),
        _buildFormGroup(theme, [
          ListTile(
            title: const Text('Inicio de Jornada'),
            trailing: DropdownButton<int>(
              value: workHours['startHour'] ?? 7,
              underline: const SizedBox(),
              items: List.generate(
                24,
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text('${i.toString().padLeft(2, '0')}:00'),
                ),
              ),
              onChanged: (v) => setState(() {
                widget.calendarSettings['workHours'] = {
                  ...workHours,
                  'startHour': v,
                };
              }),
            ),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            title: const Text('Fin de Jornada'),
            trailing: DropdownButton<int>(
              value: workHours['endHour'] ?? 22,
              underline: const SizedBox(),
              items: List.generate(
                24,
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text('${i.toString().padLeft(2, '0')}:00'),
                ),
              ),
              onChanged: (v) => setState(() {
                widget.calendarSettings['workHours'] = {
                  ...workHours,
                  'endHour': v,
                };
              }),
            ),
          ),
        ]),
        _buildSectionHeader(theme, 'Bloques de Disponibilidad'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              if (bloques.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay bloques configurados'),
                ),
              ...bloques.map((b) {
                final weekday = _getWeekdayName(b['weekday']);
                return ListTile(
                  title: Text(weekday),
                  subtitle: Text('${b['start']} - ${b['end']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        bloques.remove(b);
                        widget.calendarSettings['bloques'] = bloques;
                      });
                    },
                  ),
                );
              }),
              Divider(height: 1, color: theme.dividerColor),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Añadir Bloque'),
                onTap: () => _addAvailabilityBlock(bloques),
              ),
            ],
          ),
        ),
        _buildSectionHeader(theme, 'Días No Laborables'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...vacationDays.map(
                    (day) => Chip(
                      label: Text(day),
                      onDeleted: () {
                        setState(() {
                          vacationDays.remove(day);
                          widget.calendarSettings['vacationDays'] =
                              vacationDays;
                        });
                      },
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('Añadir Día'),
                    onPressed: () => _addVacationDay(vacationDays),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: widget.isSaving ? null : widget.onSave,
            child: widget.isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Guardar Calendario'),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  String _getWeekdayName(int weekday) {
    const days = [
      'Domingo',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
    ];
    if (weekday >= 0 && weekday < days.length) return days[weekday];
    return 'Día $weekday';
  }

  Future<void> _addAvailabilityBlock(List<Map<String, dynamic>> blocks) async {
    int selectedDay = 1;
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 17, minute: 0);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Nuevo Bloque'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedDay,
                  items: List.generate(
                    7,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(_getWeekdayName(i)),
                    ),
                  ),
                  onChanged: (v) => setState(() => selectedDay = v!),
                  decoration: const InputDecoration(labelText: 'Día'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: start,
                          );
                          if (t != null) setState(() => start = t);
                        },
                        child: Text('Inicio: ${start.format(context)}'),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: end,
                          );
                          if (t != null) setState(() => end = t);
                        },
                        child: Text('Fin: ${end.format(context)}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Añadir'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      if (mounted) {
        setState(() {
          blocks.add({
            'weekday': selectedDay,
            'start':
                '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
            'end':
                '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
          });
          widget.calendarSettings['bloques'] = blocks;
        });
      }
    }
  }

  Future<void> _addVacationDay(List<String> vacationDays) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final dateStr = date.toIso8601String().split('T')[0];
      if (!vacationDays.contains(dateStr)) {
        setState(() {
          vacationDays.add(dateStr);
          widget.calendarSettings['vacationDays'] = vacationDays;
        });
      }
    }
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.hintColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFormGroup(ThemeData theme, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}
