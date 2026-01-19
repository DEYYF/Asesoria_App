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

    // Calculate dynamic header heights to prevent overlap
    final bottomHeight = 160.0 + (budgetEstado == 'pendiente' ? 60.0 : 0.0);
    final expandedHeight = bottomHeight + 230.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: DefaultTabController(
        length: tabs.length,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: expandedHeight,
                pinned: true,
                stretch: true,
                backgroundColor: theme.primaryColor,
                elevation: 0,
                automaticallyImplyLeading: true,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: IconButton.filledTonal(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.15),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => context.pop(),
                  ),
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
                              theme.primaryColor.withBlue(220).withRed(50),
                            ],
                          ),
                        ),
                      ),
                      // Decorative circles for a "premium" depth feel
                      Positioned(
                        top: -40,
                        right: -40,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 60,
                        left: -50,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05),
                          ),
                        ),
                      ),
                      // Glassmorphic overlay for the profile area
                      Positioned(
                        bottom: bottomHeight + 20,
                        left: 20,
                        right: 20,
                        child: Column(
                          children: [
                            Hero(
                              tag: 'client_${cliente.id}',
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 48,
                                  backgroundColor: Colors.white24,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      cliente.nombre[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              cliente.nombre,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    offset: Offset(0, 2),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                _getDuration(
                                  cliente.fechaInicio,
                                  cliente.fechaFin,
                                ).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(bottomHeight),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 20),
                        if (budgetEstado == 'pendiente')
                          _buildBudgetWarning(isDark),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              if (hasEntrenamiento && canEditFeatures) ...[
                                Expanded(
                                  child: _QuickActionButton(
                                    icon: Icons.play_circle_filled_rounded,
                                    label: 'ENTRENAR',
                                    color: const Color(0xFF34C759),
                                    onPressed: onNavigateToLiveSession,
                                  ),
                                ),
                                const SizedBox(width: 16),
                              ],
                              Expanded(
                                child: _QuickActionButton(
                                  icon: Icons.analytics_rounded,
                                  label: 'PROGRESO',
                                  color: const Color(0xFFFF9500),
                                  onPressed: onAddProgress,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TabBar(
                          tabs: tabs,
                          labelColor: theme.primaryColor,
                          unselectedLabelColor: theme.hintColor.withOpacity(
                            0.4,
                          ),
                          indicatorSize: TabBarIndicatorSize.label,
                          indicator: UnderlineTabIndicator(
                            borderSide: BorderSide(
                              width: 3.5,
                              color: theme.primaryColor,
                            ),
                            insets: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.2,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          dividerColor: Colors.transparent,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
