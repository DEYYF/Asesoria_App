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
      Provider.of<ChatService>(context, listen: false).loadUnreadCount();
      Provider.of<ChatService>(context, listen: false).connect();
      Provider.of<SettingsProvider>(context, listen: false).loadSettings();
    });
  }

  void _handleSidebarChange() {
    if (_isNavigating) return;

    final newIndex = _controller.selectedIndex;
    if (newIndex != widget.navigationShell.currentIndex) {
      _isNavigating = true;
      widget.navigationShell.goBranch(
        newIndex,
        initialLocation: newIndex == widget.navigationShell.currentIndex,
      );
      _isNavigating = false;
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

    final showNavBar = !auth.isClient;

    if (!showNavBar) {
      return Scaffold(body: widget.navigationShell);
    }

    return Scaffold(
      body: Row(
        children: [
          StreamBuilder<int>(
            stream: Provider.of<ChatService>(context).unreadCountStream,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              print(
                'Sidebar unread count snapshot: $count (Has data: ${snapshot.hasData})',
              );

              return AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return SidebarX(
                    controller: _controller,
                    theme: SidebarXTheme(
                      margin: const EdgeInsets.all(10),
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
                      selectedItemTextPadding: const EdgeInsets.only(left: 30),
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
                      const SidebarXItem(
                        icon: Icons.settings_outlined,
                        label: 'Ajustes',
                      ),
                      SidebarXItem(
                        icon: Icons.chat_outlined,
                        label: 'Chat',
                        iconWidget: count > 0
                            ? Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    Icons.chat_outlined,
                                    color: _controller.selectedIndex == 4
                                        ? Colors.white
                                        : theme.hintColor.withOpacity(0.5),
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                      const SidebarXItem(
                        icon: Icons.calendar_month_outlined,
                        label: 'Calendario',
                      ),
                      const SidebarXItem(
                        icon: Icons.receipt_long_outlined,
                        label: 'Presupuestos',
                      ),
                      if (Provider.of<SettingsProvider>(
                            context,
                          ).settings?.enabledAutomation ??
                          false)
                        const SidebarXItem(
                          icon: Icons.auto_mode_rounded,
                          label: 'Automatización',
                        ),
                    ],
                  );
                },
              );
            },
          ),
          Expanded(child: widget.navigationShell),
        ],
      ),
    );
  }
}
