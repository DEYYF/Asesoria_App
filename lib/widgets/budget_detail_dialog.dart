import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BudgetDetailDialog extends StatelessWidget {
  final Map<String, dynamic> budget;

  const BudgetDetailDialog({super.key, required this.budget});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = budget['createdAt'] != null
        ? DateTime.parse(budget['createdAt'])
        : DateTime.now();

    final status = budget['estado'] as String;
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'pagado':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'aceptado':
        statusColor = Colors.blue;
        statusIcon = Icons.thumb_up_rounded;
        break;
      case 'rechazado':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty_rounded;
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalle del Presupuesto',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.dividerColor.withOpacity(0.05),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildInfoCard(context, [
                  _buildInfoRow(
                    context,
                    Icons.person_rounded,
                    'CLIENTE',
                    budget['clienteId']?['nombre'] ??
                        budget['nombreCliente'] ??
                        'N/A',
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    context,
                    Icons.email_rounded,
                    'EMAIL',
                    budget['clienteId']?['email'] ??
                        budget['emailCliente'] ??
                        'N/A',
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    context,
                    Icons.calendar_today_rounded,
                    'FECHA',
                    DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
                  ),
                ]),
                const SizedBox(height: 32),
                Text(
                  'CONCEPTOS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.hintColor,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.dividerColor.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildConceptRow(
                        theme,
                        budget['tarifaId']?['nombre'] ?? 'Tarifa Base',
                        '${budget['tarifaId']?['precio'] ?? 0} €',
                      ),
                      if (budget['extras'] != null &&
                          (budget['extras'] as List).isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                        ...(budget['extras'] as List).map((e) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: _buildConceptRow(
                              theme,
                              'Extra: ${e['extraId']?['nombre'] ?? 'Extra'}',
                              '${e['precioTotal']} €',
                              icon: Icons.add_circle_outline_rounded,
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            if ((budget['descuento'] ?? 0) > 0) ...[
                              _buildConceptRow(
                                theme,
                                'Descuento (${budget['descuento']}%)',
                                '- ${((budget['total'] * 100 / (100 - budget['descuento'])) - budget['total']).toStringAsFixed(2)} €',
                                color: Colors.green,
                                icon: Icons.discount_rounded,
                              ),
                              const SizedBox(height: 12),
                            ],
                            _buildConceptRow(
                              theme,
                              'TOTAL',
                              '${budget['total']} €',
                              isTotal: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<Widget> children) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: theme.primaryColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.hintColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConceptRow(
    ThemeData theme,
    String label,
    String value, {
    bool isTotal = false,
    Color? color,
    IconData? icon,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: color ?? theme.hintColor.withOpacity(0.5),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: isTotal ? FontWeight.w900 : FontWeight.w500,
                  fontSize: isTotal ? 18 : 14,
                  color: isTotal ? null : theme.hintColor,
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
            fontSize: isTotal ? 22 : 14,
            color: color ?? (isTotal ? theme.primaryColor : null),
          ),
        ),
      ],
    );
  }
}
