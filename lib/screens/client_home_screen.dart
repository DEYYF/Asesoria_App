import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'client_profile_screen.dart';
import 'ejercicios_screen.dart';

class ClientHomeScreen extends StatefulWidget {
  final String clienteId;

  const ClientHomeScreen({super.key, required this.clienteId});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  final _pageController = PageController(initialPage: 0);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    // Only show bottom nav for ADMINS (usuarios), not for clients
    if (auth.isClient) {
      return ClientProfileScreen(clienteId: widget.clienteId);
    }

    final screens = [
      ClientProfileScreen(clienteId: widget.clienteId),
      const EjerciciosScreen(),
    ];

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: screens,
      ),
      extendBody: true,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _pageController.page?.toInt() ?? 0,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.ease,
          );
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Ejercicios',
          ),
        ],
      ),
    );
  }
}
