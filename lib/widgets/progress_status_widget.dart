import 'package:flutter/material.dart';

class ProgressStatusWidget extends StatelessWidget {
  final String label;
  final DateTime? lastDate;
  final String
  frequency; // 'daily', 'weekly', 'biweekly', 'monthly', 'quarterly'
  final IconData icon;

  const ProgressStatusWidget({
    super.key,
    required this.label,
    required this.lastDate,
    required this.frequency,
    required this.icon,
  });

  int _getFrequencyDays() {
    switch (frequency) {
      case 'daily':
        return 1;
      case 'weekly':
        return 7;
      case 'biweekly':
        return 14;
      case 'monthly':
        return 30;
      case 'quarterly':
        return 90;
      default:
        return 7;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (lastDate == null) {
      return _buildStatusItem(
        theme,
        'Sin datos',
        Colors.grey,
        'Nunca registrado',
      );
    }

    final now = DateTime.now();
    final diff = now.difference(lastDate!).inDays;
    final days = _getFrequencyDays();

    Color statusColor;
    String statusText;
    String detailText;

    if (diff < days) {
      statusColor = Colors.green;
      statusText = 'Al día';
      final remaining = days - diff;
      detailText = 'Siguiente en $remaining ${remaining == 1 ? 'día' : 'días'}';
    } else if (diff == days) {
      statusColor = Colors.orange;
      statusText = 'Toca hoy';
      detailText = 'Última: $diff días ago';
    } else {
      statusColor = Colors.red;
      statusText = 'Atrasado';
      detailText = 'Hace ${diff - days} días debió actualizar';
    }

    return _buildStatusItem(theme, statusText, statusColor, detailText);
  }

  Widget _buildStatusItem(
    ThemeData theme,
    String status,
    Color color,
    String detail,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicWidth(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.hintColor,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 9,
                    color: theme.hintColor.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
