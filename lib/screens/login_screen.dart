import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../providers/theme_provider.dart';
import '../services/biometric_service.dart';

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
  bool _obscurePass = true;
  bool _showPassword = false; // Add for two-step client login

  final BiometricService _biometricService = BiometricService();
  bool _isBiometricAvailable = false;
  bool _hasBiometricCredentials = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final isAvailable = await _biometricService.isBiometricAvailable();
    final hasCreds = await _biometricService.hasStoredCredentials();
    if (mounted) {
      setState(() {
        _isBiometricAvailable = isAvailable;
        _hasBiometricCredentials = hasCreds;
      });

      // Optional: Auto-trigger if credentials exist
      if (isAvailable && hasCreds) {
        // We could auto-trigger here if we want, but a button is safer for UX
      }
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleContinueEmail(AuthService auth) async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _localLoading = true;
      _error = false;
    });

    try {
      final status = await auth.checkClientStatus(email);
      if (!mounted) return;

      if (status['exists'] == true) {
        if (status['requiresPasswordSetup'] == true) {
          // Redirect to first login
          context.go('/first-login?email=${Uri.encodeComponent(email)}');
        } else {
          // Show password field
          setState(() => _showPassword = true);
        }
      } else {
        setState(() {
          _error = true;
          _errorMessage = 'No se encontró ningún cliente con ese correo';
        });
      }
    } catch (e) {
      setState(() {
        _error = true;
        _errorMessage = 'Error al verificar el correo';
      });
    } finally {
      if (mounted) setState(() => _localLoading = false);
    }
  }

  Future<void> _handleLogin(AuthService auth) async {
    if (!mounted) return;

    setState(() {
      _error = false;
      _localLoading = true;
    });

    try {
      if (_isClientLogin) {
        final result = await auth.clientLogin(_emailCtrl.text, _passCtrl.text);

        if (!mounted) return;

        if (result == 'requiresPasswordSetup') {
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
            // Sync theme settings after login
            final settings = auth.user?['settings'];
            if (settings != null && settings is Map<String, dynamic>) {
              Provider.of<ThemeProvider>(
                context,
                listen: false,
              ).syncWithSettings(settings);
            }
            context.go('/');
          }

          // Offer to save biometrics if not already saved
          if (_isBiometricAvailable && !_hasBiometricCredentials) {
            _showBiometricOptIn(auth);
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

  Future<void> _handleBiometricLogin(AuthService auth) async {
    final authenticated = await _biometricService.authenticate();
    if (!authenticated) return;

    final creds = await _biometricService.getCredentials();
    if (creds == null) {
      setState(() {
        _error = true;
        _errorMessage = 'No se encontraron credenciales guardadas';
      });
      return;
    }

    _emailCtrl.text = creds['email']!;
    _passCtrl.text = creds['password']!;

    // Determinamos si es login de cliente por el formato del mail o guardando el tipo en secure storage
    // Por ahora, asumimos que intenta el login normal y si falla probamos cliente,
    // o mejor, el servicio debería guardar el 'role'.
    // Simplificación: intentamos login de asesor primero.

    await _handleLogin(auth);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Premium Mesh-like background circles
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withOpacity(isDark ? 0.05 : 0.03),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.primaryColor.withOpacity(isDark ? 0.03 : 0.02),
              ),
            ),
          ),

          Center(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Logo Branding
                      Hero(
                        tag: 'app_logo_login',
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: theme.primaryColor.withOpacity(0.1),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.fitness_center_rounded,
                            size: 64,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'ASESORÍA APP',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ENTRENA . APRENDE . EVOLUCIONA',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor.withOpacity(0.5),
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Selector Admin/Cliente
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1C1C1E)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(35),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            _buildSelectorOption('ADMIN', !_isClientLogin),
                            _buildSelectorOption('CLIENTE', _isClientLogin),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Form Fields
                      _buildTextField(
                        controller: _emailCtrl,
                        label: 'Email',
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        isDark: isDark,
                        theme: theme,
                        enabled:
                            !(_isClientLogin &&
                                _showPassword), // Disable if showing pass
                      ),

                      if (!_isClientLogin || _showPassword) ...[
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _passCtrl,
                          label: 'Contraseña',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscurePass,
                          isDark: isDark,
                          theme: theme,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: theme.primaryColor.withOpacity(0.5),
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() => _obscurePass = !_obscurePass);
                            },
                          ),
                        ),
                      ] else ...[
                        // Option to clear and go back if it's the wrong email
                        if (_emailCtrl.text.isNotEmpty)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _showPassword = false;
                                  _emailCtrl.clear();
                                });
                              },
                              child: Text(
                                '¿No es tu correo?',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                      ],

                      if (_error)
                        Padding(
                          padding: const EdgeInsets.only(top: 24.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: isDark ? 0 : 8,
                            shadowColor: isDark
                                ? Colors.transparent
                                : theme.primaryColor.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: _localLoading
                              ? null
                              : () {
                                  if (_isClientLogin && !_showPassword) {
                                    _handleContinueEmail(auth);
                                  } else {
                                    _handleLogin(auth);
                                  }
                                },
                          child: _localLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  (_isClientLogin && !_showPassword)
                                      ? 'CONTINUAR'
                                      : 'INICIAR SESIÓN',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      if (_isBiometricAvailable &&
                          _hasBiometricCredentials) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              side: BorderSide(
                                color: theme.primaryColor.withOpacity(0.5),
                              ),
                            ),
                            onPressed: _localLoading
                                ? null
                                : () => _handleBiometricLogin(auth),
                            icon: Icon(
                              Icons.face_unlock_rounded,
                              color: theme.primaryColor,
                            ),
                            label: Text(
                              'IDENTIDAD BIOMÉTRICA',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.primaryColor,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorOption(String label, bool isSelected) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isClientLogin = (label == 'CLIENTE');
            _showPassword = false;
            _emailCtrl.clear();
            _passCtrl.clear();
            _error = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            boxShadow: (isSelected && !isDark)
                ? [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[500] : Colors.black54),
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    required bool isDark,
    required ThemeData theme,
    Widget? suffix,
    bool enabled = true,
  }) {
    final bgColor = !enabled
        ? (isDark ? Colors.white.withOpacity(0.04) : Colors.grey[100])
        : (isDark ? Colors.white.withOpacity(0.08) : Colors.white);

    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey[200]!;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      textAlignVertical: TextAlignVertical.center,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        letterSpacing: 0.2,
      ),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(
          color: theme.hintColor.withOpacity(0.4),
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 20, right: 12),
          child: Icon(icon, color: theme.primaryColor, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        suffixIcon: suffix,
        // Using filled and fillColor within InputDecoration is more stable
        filled: true,
        fillColor: bgColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: borderColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: theme.primaryColor, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: borderColor.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _showBiometricOptIn(AuthService auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Activar acceso biométrico?'),
        content: const Text(
          'Podrás iniciar sesión con FaceID o tu huella dactilar la próxima vez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('MÁS TARDE'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _biometricService.saveCredentials(
                _emailCtrl.text,
                _passCtrl.text,
              );
              if (mounted) {
                Navigator.pop(ctx);
                setState(() => _hasBiometricCredentials = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Acceso biométrico activado')),
                );
              }
            },
            child: const Text('ACTIVAR'),
          ),
        ],
      ),
    );
  }
}
