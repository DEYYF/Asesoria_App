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
  final _confirmPassCtrl = TextEditingController();
  bool _error = false;
  String _errorMessage = 'Error al iniciar sesión';
  bool _isClientLogin = false;
  bool _requiresPasswordSetup = false;

  Future<void> _handleLogin(AuthService auth) async {
    setState(() {
      _error = false;
      _requiresPasswordSetup = false;
    });

    if (_isClientLogin) {
      final result = await auth.clientLogin(
        _emailCtrl.text,
        _passCtrl.text,
        isFirstLogin: _requiresPasswordSetup,
      );

      if (result == 'requiresPasswordSetup') {
        setState(() {
          _requiresPasswordSetup = true;
          _errorMessage = 'Establece tu contraseña para continuar';
        });
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
  }

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

              if (!_requiresPasswordSetup) ...[
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
              ],

              if (_requiresPasswordSetup) ...[
                const Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Color(0xFF007AFF),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Primera vez',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Establece tu contraseña',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 32),
              ],

              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                enabled: !_requiresPasswordSetup,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                decoration: InputDecoration(
                  labelText: _requiresPasswordSetup
                      ? 'Nueva Contraseña'
                      : 'Contraseña',
                ),
                obscureText: true,
              ),

              if (_requiresPasswordSetup) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPassCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar Contraseña',
                  ),
                  obscureText: true,
                ),
              ],

              if (_error)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: auth.isLoading
                    ? null
                    : () async {
                        if (_requiresPasswordSetup) {
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
                              _errorMessage =
                                  'La contraseña debe tener al menos 6 caracteres';
                            });
                            return;
                          }
                        }
                        await _handleLogin(auth);
                      },
                child: auth.isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        _requiresPasswordSetup
                            ? 'Establecer Contraseña'
                            : 'Iniciar Sesión',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
