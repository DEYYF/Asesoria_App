import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _error = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Asesoría App',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
              ),
              if (_error)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Error al iniciar sesión',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: auth.isLoading
                    ? null
                    : () async {
                        setState(() => _error = false);
                        final success = await auth.login(
                          _emailCtrl.text,
                          _passCtrl.text,
                        );
                        if (success) {
                          if (context.mounted) context.go('/');
                        } else {
                          setState(() => _error = true);
                        }
                      },
                child: auth.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Iniciar Sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
