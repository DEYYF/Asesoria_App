import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CreateDietMethodScreen extends StatelessWidget {
  final String clienteId;

  const CreateDietMethodScreen({super.key, required this.clienteId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Crear dieta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Elige cómo quieres crear la dieta',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Puedes mantener el flujo actual por opciones o planificar una dieta completa por días de la semana.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 24),
            _MethodCard(
              icon: Icons.tune_rounded,
              title: 'Por opciones',
              description:
                  'Usa la creación actual: comidas con alternativas, alimentos, recetas y combinaciones.',
              actionText: 'Crear por opciones',
              onTap: () => context.push('/clientes/$clienteId/crear-dieta/opciones'),
            ),
            const SizedBox(height: 16),
            _MethodCard(
              icon: Icons.calendar_month_rounded,
              title: 'Por calendario',
              description:
                  'Define una dieta estipulada por lunes, martes, miércoles, jueves, viernes, sábado y domingo.',
              actionText: 'Crear por calendario',
              onTap: () => context.push('/clientes/$clienteId/crear-dieta/calendario'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String actionText;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: theme.primaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(color: theme.hintColor, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    actionText,
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.hintColor),
          ],
        ),
      ),
    );
  }
}
