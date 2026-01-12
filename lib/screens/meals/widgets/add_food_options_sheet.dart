import 'package:flutter/material.dart';

class AddFoodOptionsSheet extends StatelessWidget {
  final int currentTabIndex;
  final bool showScan;
  final VoidCallback onAddManual;
  final VoidCallback onScanProduct;

  const AddFoodOptionsSheet({
    super.key,
    required this.currentTabIndex,
    this.showScan = true,
    required this.onAddManual,
    required this.onScanProduct,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'Añadir a ${currentTabIndex == 0 ? "Ingredientes" : "Recetas"}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 24),
          _buildOptionItem(
            context,
            title: 'Añadir manualmente',
            subtitle: 'Escribe los detalles tú mismo',
            icon: Icons.edit_note_rounded,
            color: theme.primaryColor,
            onTap: onAddManual,
          ),
          if (showScan) ...[
            const SizedBox(height: 12),
            _buildOptionItem(
              context,
              title: 'Scannea el producto',
              subtitle: 'Obtén macros mediante código de barras',
              icon: Icons.qr_code_scanner_rounded,
              color: Colors.orange,
              onTap: onScanProduct,
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOptionItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.dividerColor),
            ],
          ),
        ),
      ),
    );
  }
}
