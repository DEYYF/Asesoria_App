import 'package:flutter/material.dart';

class ScheduleConfigurator extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final int selectedHour;
  final int selectedMinute;
  final Function(int, int) onTimeChanged;
  final List<int> selectedDays;
  final ValueChanged<List<int>> onDaysChanged;

  const ScheduleConfigurator({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    required this.selectedHour,
    required this.selectedMinute,
    required this.onTimeChanged,
    required this.selectedDays,
    required this.onDaysChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CUÁNDO:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),

        // Mode Selector: One-time vs Recurring
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              RadioListTile<bool>(
                title: const Text('Una vez (Fecha específica)'),
                value: true,
                groupValue: selectedDays.isEmpty,
                onChanged: (val) {
                  if (val == true) onDaysChanged([]);
                },
              ),
              RadioListTile<bool>(
                title: const Text('Recurrente (Días de la semana)'),
                value: false,
                groupValue: selectedDays.isEmpty,
                onChanged: (val) {
                  if (val == false && selectedDays.isEmpty) {
                    onDaysChanged([1]); // Default to Monday
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (selectedDays.isEmpty)
          // Date Picker for "One Time"
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) onDateChanged(date);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: Colors.blue),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fecha',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          // Day Selector for "Recurring"
          Column(
            children: [
              const Text(
                'Días activos:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildDayChip('L', 1),
                  _buildDayChip('M', 2),
                  _buildDayChip('X', 3),
                  _buildDayChip('J', 4),
                  _buildDayChip('V', 5),
                  _buildDayChip('S', 6),
                  _buildDayChip('D', 7),
                ],
              ),
            ],
          ),

        const SizedBox(height: 16),

        // Time Picker (Common for both)
        InkWell(
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(
                hour: selectedHour,
                minute: selectedMinute,
              ),
            );
            if (time != null) onTimeChanged(time.hour, time.minute);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded, color: Colors.orange),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hora',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayChip(String label, int day) {
    final isSelected = selectedDays.contains(day);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        final newDays = List<int>.from(selectedDays);
        if (selected) {
          newDays.add(day);
        } else {
          newDays.remove(day);
        }
        onDaysChanged(newDays);
      },
      showCheckmark: false,
      selectedColor: Colors.blue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
