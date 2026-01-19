import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../models/cliente_model.dart';
import 'info_tab.dart';
import '../../services/chat_service.dart';
import 'diet_tab.dart';
import 'training_tab.dart';
import 'progress_tab.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../models/entrenamiento_model.dart';
import 'calendar_tab.dart';

class ClientViewLayout extends StatefulWidget {
  final Cliente cliente;
  final bool hasDieta;
  final bool hasEntrenamiento;
  final bool canEditFeatures;
  // Methods to open specific tabs
  final VoidCallback onRenovar;
  final VoidCallback onDelete;
  final VoidCallback onAddProgress;
  final VoidCallback onManageExtras;
  final VoidCallback onChangeTariff;
  final VoidCallback onEditInfo;
  final void Function(String action)? onSessionAction;
  final Widget chatTabWidget;
  final VoidCallback onNavigateToLiveSession;

  const ClientViewLayout({
    super.key,
    required this.cliente,
    required this.hasDieta,
    required this.hasEntrenamiento,
    required this.canEditFeatures,
    required this.onRenovar,
    required this.onDelete,
    required this.onAddProgress,
    required this.onManageExtras,
    required this.onChangeTariff,
    required this.onEditInfo,
    required this.onSessionAction,
    required this.chatTabWidget,
    required this.onNavigateToLiveSession,
  });

  @override
  State<ClientViewLayout> createState() => _ClientViewLayoutState();
}

class _ClientViewLayoutState extends State<ClientViewLayout> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Prepare bodies map or list
    // 0: Info (Home)
    // 1: Diet
    // 2: Training
    // 3: Progress
    // 4: Chat

    // We build the body dynamically to show content
    Widget content;

    switch (_selectedIndex) {
      case 0: // Inicio
        content = _buildHomeTab(context);
        break;
      case 1: // Nutrición
        if (widget.hasDieta) {
          content = widget.canEditFeatures
              ? DietTab(clienteId: widget.cliente.id)
              : const _LockedView();
        } else {
          content = const Center(child: Text("Servicio no contratado"));
        }
        break;
      case 2: // Entreno
        if (widget.hasEntrenamiento) {
          content = widget.canEditFeatures
              ? TrainingTab(clienteId: widget.cliente.id)
              : const _LockedView();
        } else {
          content = const Center(child: Text("Servicio no contratado"));
        }
        break;
      case 3: // Calendario
        content = CalendarTab(
          cliente: widget.cliente,
          onPlanSession: () => _handleRegisterSession(context),
        );
        break;
      case 4: // Progreso
        if (widget.hasDieta || widget.hasEntrenamiento) {
          content = widget.canEditFeatures
              ? ProgressTab(
                  cliente: widget.cliente,
                  onAddProgress: widget.onAddProgress,
                )
              : const _LockedView();
        } else {
          content = const Center(child: Text("Sin progreso disponible"));
        }
        break;
      case 5: // Chat
        content = widget.chatTabWidget;
        break;
      default:
        content = Container();
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: theme.scaffoldBackgroundColor,
              elevation: 0,
              automaticallyImplyLeading: false,
              leadingWidth: 0,
              pinned: true,
              toolbarHeight: 80,
              title: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.primaryColor,
                            theme.primaryColor.withOpacity(0.7),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          widget.cliente.nombre[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bienvenido de nuevo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.hintColor.withOpacity(0.6),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          widget.cliente.nombre,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: theme.textTheme.bodyLarge?.color,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  onPressed: () =>
                      Provider.of<AuthService>(context, listen: false).logout(),
                ),
                const SizedBox(width: 16),
              ],
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _ActionHeaderDelegate(
                child: Container(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  color: theme.scaffoldBackgroundColor,
                  child: _buildQuickActions(context),
                ),
              ),
            ),
          ];
        },
        body: content,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: theme.dividerColor.withOpacity(0.05),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          backgroundColor: theme.scaffoldBackgroundColor,
          indicatorColor: theme.primaryColor.withOpacity(0.1),
          height: 65,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              selectedIcon: Icon(
                Icons.grid_view_rounded,
                color: Color(0xFF007AFF),
              ),
              label: 'Inicio',
            ),
            const NavigationDestination(
              icon: Icon(Icons.restaurant_menu_rounded),
              selectedIcon: Icon(
                Icons.restaurant_menu_rounded,
                color: Color(0xFF34C759),
              ),
              label: 'Nutrición',
            ),
            const NavigationDestination(
              icon: Icon(Icons.fitness_center_rounded),
              selectedIcon: Icon(
                Icons.fitness_center_rounded,
                color: Color(0xFFFF9500),
              ),
              label: 'Entreno',
            ),
            const NavigationDestination(
              icon: Icon(Icons.calendar_month_rounded),
              selectedIcon: Icon(
                Icons.calendar_month_rounded,
                color: Color(0xFFAF52DE),
              ),
              label: 'Calendario',
            ),
            const NavigationDestination(
              icon: Icon(Icons.analytics_rounded),
              selectedIcon: Icon(
                Icons.analytics_rounded,
                color: Color(0xFFFF2D55),
              ),
              label: 'Progreso',
            ),
            NavigationDestination(
              icon: _buildChatIcon(context, isSelected: false),
              selectedIcon: _buildChatIcon(context, isSelected: true),
              label: 'Chat',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context) {
    return InfoTab(
      cliente: widget.cliente,
      onRenovar: widget.onRenovar,
      onDelete: widget.onDelete,
      onAddProgress: widget.onAddProgress,
      onManageExtras: widget.onManageExtras,
      onChangeTariff: widget.onChangeTariff,
      onEditInfo: widget.onEditInfo,
      onSessionAction: widget.onSessionAction,
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionButton(
              icon: Icons.chat_bubble_rounded,
              label: 'CHAT',
              color: const Color(0xFF007AFF),
              onPressed: () {
                setState(() => _selectedIndex = 5);
              },
            ),
          ),
          const SizedBox(width: 12),
          if (widget.hasEntrenamiento && widget.canEditFeatures) ...[
            Expanded(
              child: _QuickActionButton(
                icon: Icons.play_arrow_rounded,
                label: 'ENTRENAR',
                color: const Color(0xFF34C759),
                onPressed: widget.onNavigateToLiveSession,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.edit_calendar_rounded,
                label: 'REGISTRAR',
                color: const Color(0xFFAF52DE),
                onPressed: () {
                  _handleRegisterSession(context);
                },
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: _QuickActionButton(
              icon: Icons.add_chart_rounded,
              label: 'PROGRESO',
              color: const Color(0xFFFF9500),
              onPressed: () {
                setState(() => _selectedIndex = 4);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatIcon(BuildContext context, {required bool isSelected}) {
    final theme = Theme.of(context);
    return StreamBuilder<int>(
      stream: Provider.of<ChatService>(
        context,
        listen: false,
      ).unreadCountStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Badge(
          label: Text('$count'),
          isLabelVisible: count > 0,
          backgroundColor: Colors.redAccent,
          textColor: Colors.white,
          child: Icon(
            isSelected
                ? Icons.chat_bubble_rounded
                : Icons.chat_bubble_outline_rounded,
            color: isSelected
                ? const Color(0xFF007AFF)
                : theme.dividerColor.withOpacity(0.5),
          ),
        );
      },
    );
  }

  Future<void> _handleRegisterSession(BuildContext context) async {
    // 1. Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cargando entrenamientos...'),
        duration: Duration(seconds: 1),
      ),
    );

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      // 2. Fetch trainings
      final res = await api.get(
        '/entrenamientos?clienteId=${widget.cliente.id}',
      );
      if (res.statusCode != 200) {
        throw Exception('Error al cargar entrenamientos');
      }

      final List<dynamic> list = jsonDecode(res.body);
      final List<Entrenamiento> entrenamientos = list
          .map((e) => Entrenamiento.fromJson(e))
          .toList();

      // Filter active ones if needed, assuming backend returns all
      final activeEntrenamientos = entrenamientos
          .where((e) => e.activo)
          .toList();

      if (!context.mounted) return;

      if (activeEntrenamientos.isEmpty) {
        // 3. 0 Trainings
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tienes planes de entrenamiento activos'),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (activeEntrenamientos.length == 1) {
        // 4. 1 Training -> Go directly
        context.push(
          '/entrenamientos/cuaderno/${activeEntrenamientos.first.id}',
        );
      } else {
        // 5. Multiple -> Show Selection Dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Registrar Sesión'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: activeEntrenamientos.length,
                separatorBuilder: (ctx, i) => const Divider(),
                itemBuilder: (ctx, i) {
                  final ent = activeEntrenamientos[i];
                  return ListTile(
                    title: Text(ent.titulo),
                    subtitle: Text('${ent.semanas.length} semanas'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(ctx); // Close dialog
                      context.push('/entrenamientos/cuaderno/${ent.id}');
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _LockedView extends StatelessWidget {
  const _LockedView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_person_rounded,
                size: 40,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Función Premium',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Este servicio no está incluido en tu plan actual.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _requestAccess(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Solicitar Acceso',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _requestAccess(BuildContext context) {
    // We assume active conversation is handled or we just send message
    // Actually we need conversation ID to send message.
    // But _LockedView doesn't have it.
    // Easiest: Switch to Chat tab
    // But we are inside ClientViewLayout logic potentially...
    // Or just show snackbar "Solicitud enviada"

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Contacta a tu asesor en el chat para activar este servicio',
        ),
      ),
    );
  }
}

class _ActionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _ActionHeaderDelegate({required this.child});

  @override
  double get minExtent => 115; // Increased to avoid overflow (90 was too small)

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_ActionHeaderDelegate oldDelegate) => true;
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

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
