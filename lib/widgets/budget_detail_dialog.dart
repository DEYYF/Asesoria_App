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

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Detalle del Presupuesto',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                _buildDetailSection(
                  context,
                  'CLIENTE',
                  budget['clienteId']?['nombre'] ??
                      budget['nombreCliente'] ??
                      'N/A',
                ),
                _buildDetailSection(
                  context,
                  'EMAIL',
                  budget['clienteId']?['email'] ??
                      budget['emailCliente'] ??
                      'N/A',
                ),
                _buildDetailSection(
                  context,
                  'FECHA',
                  DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
                ),
                const SizedBox(height: 24),
                Text(
                  'CONCEPTOS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.hintColor,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                _buildConceptRow(
                  theme,
                  budget['tarifaId']?['nombre'] ?? 'Tarifa Base',
                  '${budget['tarifaId']?['precio'] ?? 0} €',
                ),
                if (budget['extras'] != null)
                  ...(budget['extras'] as List).map((e) {
                    return _buildConceptRow(
                      theme,
                      'Extra: ${e['extraId']?['nombre'] ?? 'Extra'}',
                      '${e['precioTotal']} €',
                    );
                  }),
                const Divider(height: 32),
                if ((budget['descuento'] ?? 0) > 0)
                  _buildConceptRow(
                    theme,
                    'Descuento (${budget['descuento']}%)',
                    '- ${((budget['total'] * 100 / (100 - budget['descuento'])) - budget['total']).toStringAsFixed(2)} €',
                    color: Colors.green,
                  ),
                _buildConceptRow(
                  theme,
                  'TOTAL',
                  '${budget['total']} €',
                  isTotal: true,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConceptRow(
    ThemeData theme,
    String label,
    String value, {
    bool isTotal = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              fontSize: isTotal ? 18 : 14,
              color: color ?? (isTotal ? theme.primaryColor : null),
            ),
          ),
        ],
      ),
    );
  }
}
