import 'package:flutter/material.dart';

class TriggerSelector extends StatelessWidget {
  final String selectedTrigger;
  final ValueChanged<String> onTriggerChanged;

  const TriggerSelector({
    super.key,
    required this.selectedTrigger,
    required this.onTriggerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTriggerCategory(
          context,
          'Gestión de Clientes',
          Icons.people_alt_rounded,
          Colors.blue,
          [
            'CLIENT_REGISTERED',
            'PLAN_EXPIRED',
            'PLAN_EXPIRING_3_DAYS',
            'BIRTHDAY',
          ],
        ),
        const Divider(height: 1),
        _buildTriggerCategory(
          context,
          'Citas y Agenda',
          Icons.calendar_month_rounded,
          Colors.purple,
          [
            'APPOINTMENT_CREATED',
            'APPOINTMENT_CONFIRMED',
            'APPOINTMENT_CANCELLED',
            'APPOINTMENT_MISSED',
          ],
        ),
        const Divider(height: 1),
        _buildTriggerCategory(
          context,
          'Presupuestos y Pagos',
          Icons.attach_money_rounded,
          Colors.green,
          [
            'BUDGET_CREATED',
            'BUDGET_ACCEPTED',
            'BUDGET_REJECTED',
            'BUDGET_PAID',
          ],
        ),
        const Divider(height: 1),
        _buildTriggerCategory(
          context,
          'Entrenamiento y Dieta',
          Icons.fitness_center_rounded,
          Colors.orange,
          [
            'DIET_ASSIGNED',
            'WORKOUT_ASSIGNED',
            'WORKOUT_COMPLETED',
            'STREAK_7_DAYS',
          ],
        ),
        const Divider(height: 1),
        _buildTriggerCategory(
          context,
          'Progreso e Inactividad',
          Icons.trending_up_rounded,
          Colors.red,
          [
            'PROGRESS_RECORDED',
            'WEIGHT_GOAL_REACHED',
            'PROGRESS_STALLED',
            'INACTIVE_3_DAYS',
            'INACTIVE_7_DAYS',
          ],
        ),
      ],
    );
  }

  Widget _buildTriggerCategory(
    BuildContext context,
    String categoryTitle,
    IconData icon,
    Color color,
    List<String> triggers,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          categoryTitle,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        childrenPadding: const EdgeInsets.only(bottom: 12),
        children: triggers.map((trigger) {
          final isSelected = selectedTrigger == trigger;
          return InkWell(
            onTap: () => onTriggerChanged(trigger),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: isSelected ? color.withOpacity(0.05) : null,
              child: Row(
                children: [
                  Radio<String>(
                    value: trigger,
                    groupValue: selectedTrigger,
                    activeColor: color,
                    onChanged: (val) {
                      if (val != null) onTriggerChanged(val);
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTriggerLabel(trigger),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? color
                                : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                        if (_getTriggerDescription(trigger).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              _getTriggerDescription(trigger),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getTriggerLabel(String trigger) {
    switch (trigger) {
      // Cliente
      case 'CLIENT_REGISTERED':
        return 'Nuevo cliente registrado';
      case 'PLAN_EXPIRED':
        return 'Plan/Tarifa vencido';
      case 'PLAN_EXPIRING_3_DAYS':
        return 'Plan vence pronto (3 días)';
      case 'BIRTHDAY':
        return 'Cumpleaños del cliente';

      // Citas
      case 'APPOINTMENT_CREATED':
        return 'Nueva cita solicitada';
      case 'APPOINTMENT_CONFIRMED':
        return 'Cita confirmada';
      case 'APPOINTMENT_CANCELLED':
        return 'Cita cancelada';
      case 'APPOINTMENT_MISSED':
        return 'Cita no asistida (Ausente)';

      // Presupuestos
      case 'BUDGET_CREATED':
        return 'Presupuesto creado';
      case 'BUDGET_ACCEPTED':
        return 'Presupuesto aceptado';
      case 'BUDGET_REJECTED':
        return 'Presupuesto rechazado';
      case 'BUDGET_PAID':
        return 'Presupuesto pagado';

      // Actividad
      case 'DIET_ASSIGNED':
        return 'Dieta asignada/actualizada';
      case 'WORKOUT_ASSIGNED':
        return 'Entreno asignado/actualizado';
      case 'WORKOUT_COMPLETED':
        return 'Sesión de entreno completada';
      case 'STREAK_7_DAYS':
        return 'Racha de 7 días';

      // Progreso
      case 'PROGRESS_RECORDED':
        return 'Nuevo registro de progreso';
      case 'WEIGHT_GOAL_REACHED':
        return 'Meta de peso alcanzada';
      case 'PROGRESS_STALLED':
        return 'Estancamiento detectado';
      case 'INACTIVE_3_DAYS':
        return 'Inactividad (3 días)';
      case 'INACTIVE_7_DAYS':
        return 'Inactividad (7 días)';

      default:
        return trigger;
    }
  }

  String _getTriggerDescription(String trigger) {
    switch (trigger) {
      case 'CLIENT_REGISTERED':
        return 'Se activa al crear un nuevo perfil.';
      case 'PLAN_EXPIRING_3_DAYS':
        return 'Ideal para recordatorios de renovación.';
      case 'APPOINTMENT_CREATED':
        return 'Cuando agendan una cita.';
      case 'APPOINTMENT_MISSED':
        return 'Si el cliente no se presenta a la cita.';
      case 'BUDGET_CREATED':
        return 'Al enviar una propuesta económica.';
      case 'WORKOUT_COMPLETED':
        return 'Cuando marcan una sesión como hecha.';
      case 'PROGRESS_STALLED':
        return 'Si el peso no varía en 3 semanas.';
      case 'INACTIVE_7_DAYS':
        return 'Sin entrar a la app por una semana.';
      default:
        return '';
    }
  }
}
