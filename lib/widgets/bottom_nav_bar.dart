import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    // Only show bottom nav for ADMINS (usuarios), not for clients
    if (auth.isClient) {
      return const SizedBox.shrink();
    }

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        BottomNavigationBarItem(
          icon: Icon(Icons.fitness_center),
          label: 'Ejercicios',
        ),
      ],
    );
  }
}
