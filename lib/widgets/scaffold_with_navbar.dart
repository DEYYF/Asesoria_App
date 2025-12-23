import 'package:asesoria_app/services/auth_service.dart';
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
          SidebarX(
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
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
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
            ],
          ),
          Expanded(child: widget.navigationShell),
        ],
      ),
    );
  }
}
