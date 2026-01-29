import 'package:flutter/material.dart';

class GeneralInfoForm extends StatefulWidget {
  final Map<String, dynamic>? advisor;
  final TextEditingController nombreController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String role;
  final Function(String) onRoleChanged;
  final bool isSaving;
  final VoidCallback onSave;

  const GeneralInfoForm({
    super.key,
    required this.advisor,
    required this.nombreController,
    required this.emailController,
    required this.passwordController,
    required this.role,
    required this.onRoleChanged,
    required this.isSaving,
    required this.onSave,
  });

  @override
  State<GeneralInfoForm> createState() => _GeneralInfoFormState();
}

class _GeneralInfoFormState extends State<GeneralInfoForm> {
  bool _passwordVisible = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(0),
      children: [
        _buildSectionHeader(theme, 'Información Personal'),
        _buildFormGroup(theme, [
          _buildTextField(
            theme,
            widget.nombreController,
            'Nombre Completo',
            Icons.person_outline,
          ),
          _buildTextField(
            theme,
            widget.emailController,
            'Email',
            Icons.email_outlined,
          ),
        ]),
        _buildSectionHeader(theme, 'Rol & Accesos'),
        _buildFormGroup(theme, [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonFormField<String>(
              value: widget.role,
              decoration: const InputDecoration(
                border: InputBorder.none,
                prefixIcon: Icon(Icons.badge_outlined),
                labelText: 'Rol del Sistema',
              ),
              items: const [
                DropdownMenuItem(value: 'advisor', child: Text('Asesor')),
                DropdownMenuItem(
                  value: 'superadmin',
                  child: Text('Super Admin'),
                ),
              ],
              onChanged: (v) => widget.onRoleChanged(v!),
            ),
          ),
        ]),
        _buildSectionHeader(theme, 'Seguridad'),
        _buildFormGroup(theme, [
          TextField(
            controller: widget.passwordController,
            decoration: InputDecoration(
              labelText: 'Actualizar Contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              helperText: 'Dejar en blanco para mantener la actual',
              border: InputBorder.none,
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
              ),
            ),
            obscureText: !_passwordVisible,
          ),
        ]),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: widget.isSaving ? null : widget.onSave,
            child: widget.isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Guardar Cambios'),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.hintColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFormGroup(ThemeData theme, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField(
    ThemeData theme,
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: InputBorder.none,
      ),
    );
  }
}
