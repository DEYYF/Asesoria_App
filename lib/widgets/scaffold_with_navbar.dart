import 'package:asesoria_app/services/auth_service.dart';
import 'package:asesoria_app/services/chat_service.dart';
import 'package:asesoria_app/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sidebarx/sidebarx.dart';

class ScaffoldWithNavbar extends StatefulWidget {
  const ScaffoldWithNavbar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<ScaffoldWithNavbar> createState() => _ScaffoldWithNavbarState();
}

class _ScaffoldWithNavbarState extends State<ScaffoldWithNavbar> {
  late SidebarXController _controller;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _controller = SidebarXController(
      selectedIndex: widget.navigationShell.currentIndex,
      extended: false,
    );

    _controller.addListener(_handleSidebarChange);

    // Load unread count and settings on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<ChatService>(context, listen: false).loadUnreadCount();
      Provider.of<ChatService>(context, listen: false).connect();
      Provider.of<SettingsProvider>(context, listen: false).loadSettings();
    });
  }

  void _handleSidebarChange() {
    if (_isNavigating) return;

    final newIndex = _controller.selectedIndex;
    // Map UI Index to Branch Index
    final settings = Provider.of<SettingsProvider>(
      context,
      listen: false,
    ).settings;
    final showAutomation = settings?.enabledAutomation ?? false;
    final showFinanzas = settings?.enabledFinanzas ?? false;
    final auth = Provider.of<AuthService>(context, listen: false);

    final List<int> visibleBranches = [0, 1, 2, 3, 4, 5, 6, 9];
    if (showAutomation) visibleBranches.add(7);
    if (showFinanzas) visibleBranches.add(8);
    if (auth.isSuperAdmin) visibleBranches.add(10);

    if (newIndex < visibleBranches.length) {
      final targetBranch = visibleBranches[newIndex];
      if (targetBranch != widget.navigationShell.currentIndex) {
        _isNavigating = true;
        widget.navigationShell.goBranch(
          targetBranch,
          initialLocation: targetBranch == widget.navigationShell.currentIndex,
        );
        _isNavigating = false;
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleSidebarChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ScaffoldWithNavbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationShell.currentIndex != _controller.selectedIndex) {
      _isNavigating = true;
      _controller.selectIndex(widget.navigationShell.currentIndex);
      _isNavigating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 800;

    final showNavBar = !auth.isClient;

    if (!showNavBar) {
      return Scaffold(body: widget.navigationShell);
    }

    final settings = Provider.of<SettingsProvider>(context).settings;
    final showAutomation = settings?.enabledAutomation ?? false;
    final showFinanzas = settings?.enabledFinanzas ?? false;

    // Map UI indices to Branch indices
    final List<int> visibleBranches = [0, 1, 2, 3, 4, 5, 6, 9];
    if (showAutomation) visibleBranches.add(7);
    if (showFinanzas) visibleBranches.add(8);
    if (auth.isSuperAdmin) {
      if (!visibleBranches.contains(10)) visibleBranches.add(10);
    }

    int getUIIndex(int branchIndex) {
      final uiIdx = visibleBranches.indexOf(branchIndex);
      return uiIdx != -1 ? uiIdx : 0;
    }

    return StreamBuilder<int>(
      stream: Provider.of<ChatService>(context).unreadCountStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        if (isMobile) {
          return Scaffold(
            body: widget.navigationShell,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: getUIIndex(widget.navigationShell.currentIndex),
              onTap: (index) {
                if (index < visibleBranches.length) {
                  widget.navigationShell.goBranch(
                    visibleBranches[index],
                    initialLocation:
                        visibleBranches[index] ==
                        widget.navigationShell.currentIndex,
                  );
                }
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: theme.primaryColor,
              unselectedItemColor: theme.hintColor.withOpacity(0.5),
              showSelectedLabels: false,
              showUnselectedLabels: false,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.fitness_center_outlined),
                  activeIcon: Icon(Icons.fitness_center),
                  label: 'Ejercicios',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.restaurant_menu_outlined),
                  activeIcon: Icon(Icons.restaurant_menu),
                  label: 'Comidas',
                ),
                BottomNavigationBarItem(
                  icon: _buildChatIcon(count, theme.hintColor.withOpacity(0.5)),
                  activeIcon: _buildChatIcon(count, theme.primaryColor),
                  label: 'Chat',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Ajustes',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month_outlined),
                  activeIcon: Icon(Icons.calendar_month),
                  label: 'Calendario',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_outlined),
                  activeIcon: Icon(Icons.receipt_long),
                  label: 'Presupuestos',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.assignment_outlined),
                  activeIcon: Icon(Icons.assignment),
                  label: 'Tareas',
                ),
                if (showAutomation)
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.auto_mode_rounded),
                    label: 'Auto',
                  ),
                if (showFinanzas)
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    activeIcon: Icon(Icons.account_balance_wallet),
                    label: 'Finanzas',
                  ),
                if (auth.isSuperAdmin)
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.people_outline_rounded),
                    activeIcon: Icon(Icons.people_rounded),
                    label: 'Equipo',
                  ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  // Update sidebar selection to match mapped index
                  final uiIdx = getUIIndex(widget.navigationShell.currentIndex);
                  if (_controller.selectedIndex != uiIdx) {
                    _isNavigating = true;
                    _controller.selectIndex(uiIdx);
                    _isNavigating = false;
                  }

                  return SafeArea(
                    child: SidebarX(
                      controller: _controller,
                      theme: SidebarXTheme(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.transparent
                                  : Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        textStyle: TextStyle(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            0.7,
                          ),
                        ),
                        selectedTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        itemTextPadding: const EdgeInsets.only(left: 30),
                        selectedItemTextPadding: const EdgeInsets.only(
                          left: 30,
                        ),
                        itemDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        selectedItemDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: theme.primaryColor,
                        ),
                        iconTheme: IconThemeData(
                          color: theme.hintColor.withOpacity(0.5),
                          size: 20,
                        ),
                        selectedIconTheme: const IconThemeData(
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      extendedTheme: const SidebarXTheme(
                        width: 200,
                        decoration: BoxDecoration(
                          color: Colors.transparent, // Uses main decoration
                        ),
                      ),
                      footerDivider: Divider(
                        color: theme.dividerColor.withOpacity(0.2),
                        height: 1,
                      ),
                      headerBuilder: (context, extended) {
                        return SizedBox(
                          height: 100,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Center(
                              child: GestureDetector(
                                onTap: () => _controller.toggleExtended(),
                                child: Icon(
                                  Icons.fitness_center_rounded,
                                  size: 40,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      items: [
                        const SidebarXItem(
                          icon: Icons.dashboard_outlined,
                          label: 'Dashboard',
                        ),
                        const SidebarXItem(
                          icon: Icons.fitness_center_outlined,
                          label: 'Ejercicios',
                        ),
                        const SidebarXItem(
                          icon: Icons.restaurant_menu_outlined,
                          label: 'Comidas',
                        ),
                        SidebarXItem(
                          icon: Icons.chat_outlined,
                          label: 'Chat',
                          iconWidget: _buildChatIcon(
                            count,
                            getUIIndex(widget.navigationShell.currentIndex) == 3
                                ? Colors.white
                                : theme.hintColor.withOpacity(0.5),
                          ),
                        ),
                        const SidebarXItem(
                          icon: Icons.settings_outlined,
                          label: 'Ajustes',
                        ),
                        const SidebarXItem(
                          icon: Icons.calendar_month_outlined,
                          label: 'Calendario',
                        ),
                        const SidebarXItem(
                          icon: Icons.receipt_long_outlined,
                          label: 'Presupuestos',
                        ),
                        const SidebarXItem(
                          icon: Icons.assignment_outlined,
                          label: 'Tareas',
                        ),
                        if (showAutomation)
                          const SidebarXItem(
                            icon: Icons.auto_mode_rounded,
                            label: 'Automatización',
                          ),
                        if (showFinanzas)
                          const SidebarXItem(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Finanzas',
                          ),
                        if (auth.isSuperAdmin)
                          const SidebarXItem(
                            icon: Icons.people_outline_rounded,
                            label: 'Equipo',
                          ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(child: widget.navigationShell),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatIcon(int count, Color color) {
    if (count <= 0) {
      return Icon(Icons.chat_outlined, color: color);
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.chat_outlined, color: color),
        Positioned(
          right: -8,
          top: -8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            child: Center(
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
