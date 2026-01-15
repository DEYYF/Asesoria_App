import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/cliente_model.dart';

class AdvisorViewLayout extends StatelessWidget {
  final Cliente cliente;
  final String? budgetEstado;
  final bool hasEntrenamiento;
  final bool canEditFeatures;
  final List<Widget> tabs;
  final List<Widget> tabViews;
  final VoidCallback onAddProgress;
  final VoidCallback onNavigateToLiveSession;
  final VoidCallback onShowChat;

  const AdvisorViewLayout({
    super.key,
    required this.cliente,
    required this.budgetEstado,
    required this.hasEntrenamiento,
    required this.canEditFeatures,
    required this.tabs,
    required this.tabViews,
    required this.onAddProgress,
    required this.onNavigateToLiveSession,
    required this.onShowChat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter Quick Action Buttons: Only show relevant ones for Advisors
    // Actually, originally the code showed buttons even for advisors?
    // Let's re-verify: "if (auth.isClient) ...Chat Button". So Advisors didn't see Chat button here.
    // Advisors saw "Entrenar" (maybe debug?) and "Progreso".
    // We will keep the same logic: Show buttons based on role checks or passed props.

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: DefaultTabController(
        length: tabs.length,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                stretch: true,
                backgroundColor: theme.primaryColor,
                elevation: 0,
                automaticallyImplyLeading: true,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.primaryColor,
                              theme.primaryColor.withBlue(200),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: -50,
                        top: -50,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Hero(
                            tag: 'client_${cliente.id}',
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 45,
                                backgroundColor: Colors.white24,
                                child: Text(
                                  cliente.nombre[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            cliente.nombre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  blurRadius: 10,
                                  color: Colors.black26,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getDuration(cliente.fechaInicio, cliente.fechaFin),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ],
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(
                    120.0 + (budgetEstado == 'pendiente' ? 60.0 : 0.0) + 50.0,
                  ),
                  child: Container(
                    color: theme.scaffoldBackgroundColor,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (budgetEstado == 'pendiente')
                          _buildBudgetWarning(isDark),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              if (hasEntrenamiento && canEditFeatures) ...[
                                Expanded(
                                  child: _QuickActionButton(
                                    icon: Icons.play_arrow_rounded,
                                    label: 'Entrenar',
                                    color: Colors.green,
                                    onPressed: onNavigateToLiveSession,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: _QuickActionButton(
                                  icon: Icons.add_chart_rounded,
                                  label: 'Progreso',
                                  color: Colors.orange,
                                  onPressed: onAddProgress,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TabBar(
                          tabs: tabs,
                          labelColor: theme.primaryColor,
                          unselectedLabelColor: theme.hintColor,
                          indicatorSize: TabBarIndicatorSize.label,
                          indicator: UnderlineTabIndicator(
                            borderSide: BorderSide(
                              width: 3,
                              color: theme.primaryColor,
                            ),
                            insets: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          dividerColor: theme.dividerColor.withOpacity(0.1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(children: tabViews),
        ),
      ),
    );
  }

  String _getDuration(DateTime? start, DateTime? end) {
    if (start == null || end == null) return cliente.tiempoTarifa ?? '1 Mes';
    final days = end.difference(start).inDays.abs();
    if (days >= 360) return '12 Meses';
    if (days >= 180) return '6 Meses';
    if (days >= 90) return '3 Meses';
    if (days >= 28) return '1 Mes';
    if (days == 0) return '0 Días';
    return '$days Días';
  }

  Widget _buildBudgetWarning(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.orange.withOpacity(0.1) : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.orange.withOpacity(0.2)
              : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: isDark ? Colors.orangeAccent : Colors.orange.shade800,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Presupuesto pendiente. Funciones restringidas.',
              style: TextStyle(
                color: isDark ? Colors.orangeAccent : Colors.orange.shade900,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
