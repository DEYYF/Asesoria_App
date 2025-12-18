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
  String _errorMessage = 'Error al iniciar sesión';
  bool _isClientLogin = false;
  bool _localLoading = false;

  @override
  void initState() {
    super.initState();
    print('LoginScreen: initState');
  }

  @override
  void dispose() {
    print('LoginScreen: dispose');
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(AuthService auth) async {
    if (!mounted) return;

    setState(() {
      _error = false;
      _localLoading = true;
    });

    try {
      if (_isClientLogin) {
        print('Starting client login for: ${_emailCtrl.text}');
        final result = await auth.clientLogin(_emailCtrl.text, _passCtrl.text);

        print('After clientLogin: result=$result, mounted=$mounted');

        if (!mounted) {
          print('ABORTING: LoginScreen is no longer mounted!');
          return;
        }

        if (result == 'requiresPasswordSetup') {
          print('Redirecting to FirstLoginScreen...');
          final email = Uri.encodeComponent(_emailCtrl.text);
          context.go('/first-login?email=$email');
          return;
        } else if (result == true) {
          if (context.mounted) {
            context.go('/clientes/${auth.userId}');
          }
        } else {
          setState(() {
            _error = true;
            _errorMessage = 'Credenciales incorrectas';
          });
        }
      } else {
        final success = await auth.login(_emailCtrl.text, _passCtrl.text);

        if (!mounted) return;

        if (success) {
          if (context.mounted) {
            context.go('/');
          }
        } else {
          setState(() {
            _error = true;
            _errorMessage = 'Credenciales incorrectas';
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _localLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use listen: false to avoid rebuilding the whole screen when auth notifies
    // (We use _localLoading for the spinner)
    final auth = Provider.of<AuthService>(context, listen: false);

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

              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isClientLogin = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isClientLogin
                                ? const Color(0xFF007AFF)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Text(
                            'Admin',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: !_isClientLogin
                                  ? Colors.white
                                  : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isClientLogin = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isClientLogin
                                ? const Color(0xFF007AFF)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Text(
                            'Cliente',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isClientLogin
                                  ? Colors.white
                                  : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _localLoading ? null : () => _handleLogin(auth),
                  child: _localLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Iniciar Sesión'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
