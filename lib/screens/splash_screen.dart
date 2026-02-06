import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  String? _phrase;

  @override
  void initState() {
    super.initState();
    // Configurar pantalla completa inmersiva
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    _fetchPhrase();

    // Navegar después del delay
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) _checkAuthAndNavigate();
    });
  }

  Future<void> _fetchPhrase() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.positive-api.online/phrase/esp?category_id=2'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _phrase = data['text'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching phrase: $e');
    }
  }

  void _checkAuthAndNavigate() {
    // Restaurar UI del sistema antes de salir
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    final auth = Provider.of<AuthService>(context, listen: false);

    if (auth.isAuthenticated) {
      // Si está autenticado, el router redirigirá a dashboard o cliente app
      // pero aquí forzamos la navegación a la raíz '/' que tiene la lógica de redirección
      context.go('/');
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Usar tema oscuro para el splash o colores de marca
    final primaryColor = Theme.of(
      context,
    ).primaryColor; // O usar Color(0xFF...) específico

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [primaryColor.withOpacity(0.8), Colors.black],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(4.0), // Padding opcional
                    child: Image.asset(
                      'assets/images/logo.jpeg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.fitness_center,
                          size: 80,
                          color: primaryColor,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(opacity: _fadeAnimation.value, child: child);
              },
              child: const Text(
                'ASESORÍA APP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
            if (_phrase != null) ...[
              const SizedBox(height: 40),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: Curves.easeIn.transform(
                      (_controller.value - 0.5).clamp(0.0, 1.0) * 2,
                    ),
                    child: child,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    '"$_phrase"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w300,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 50),
            const CircularProgressIndicator(
              color: Colors.white24,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
