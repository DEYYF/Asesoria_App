import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

class FirstLoginScreen extends StatefulWidget {
  final String email;
  const FirstLoginScreen({super.key, required this.email});

  @override
  State<FirstLoginScreen> createState() => _FirstLoginScreenState();
}

class _FirstLoginScreenState extends State<FirstLoginScreen> {
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _error = false;
  String _errorMessage = '';

  Future<void> _handleSetup(AuthService auth) async {
    if (_passCtrl.text != _confirmPassCtrl.text) {
      setState(() {
        _error = true;
        _errorMessage = 'Las contraseñas no coinciden';
      });
      return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() {
        _error = true;
        _errorMessage = 'Mínimo 6 caracteres';
      });
      return;
    }

    final success = await auth.clientLogin(
      widget.email,
      _passCtrl.text,
      isFirstLogin: true,
    );

    if (success == true) {
      if (mounted) context.go('/clientes/${auth.userId}');
    } else {
      if (mounted) {
        setState(() {
          _error = true;
          _errorMessage = 'Error al establecer la contraseña';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar Cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.lock_open, size: 64, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                'Hola, ${widget.email}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Establece tu contraseña por primera vez'),
              const SizedBox(height: 32),
              TextField(
                controller: _passCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nueva Contraseña',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPassCtrl,
                decoration: const InputDecoration(
                  labelText: 'Confirmar Contraseña',
                ),
                obscureText: true,
              ),
              if (_error) ...[
                const SizedBox(height: 16),
                Text(_errorMessage, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : () => _handleSetup(auth),
                  child: auth.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Activar Cuenta'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
