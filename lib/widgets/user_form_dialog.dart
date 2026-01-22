import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../utils/notification_helper.dart';

class UserFormDialog extends StatefulWidget {
  final Map<String, dynamic>? user;
  const UserFormDialog({super.key, this.user});

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late String _role;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(
      text: widget.user?['nombre'] ?? '',
    );
    _emailController = TextEditingController(text: widget.user?['email'] ?? '');
    _passwordController = TextEditingController();
    _role = widget.user?['role'] ?? 'advisor';
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);

    final data = {
      'nombre': _nombreController.text,
      'email': _emailController.text,
      'role': _role,
    };

    if (_passwordController.text.isNotEmpty) {
      data['password'] = _passwordController.text;
    }

    try {
      if (widget.user == null) {
        // Create
        if (_passwordController.text.isEmpty) {
          NotificationHelper.showError(
            context,
            'La contraseña es obligatoria para nuevos usuarios',
          );
          setState(() => _isLoading = false);
          return;
        }
        await api.post('/users', data);
      } else {
        // Update
        await api.put('/users/${widget.user!['_id']}', data);
      }
      if (mounted) {
        NotificationHelper.showSuccess(
          context,
          widget.user == null ? 'Asesor creado' : 'Asesor actualizado',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.user != null;

    return AlertDialog(
      title: Text(isEdit ? 'Editar Asesor' : 'Nuevo Asesor'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre Completo',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  helperText: isEdit ? 'Dejar en blanco para no cambiar' : null,
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                obscureText: true,
                validator: (v) {
                  if (!isEdit && (v == null || v.isEmpty))
                    return 'Campo obligatorio';
                  if (v != null && v.isNotEmpty && v.length < 6)
                    return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'advisor', child: Text('Asesor')),
                  DropdownMenuItem(
                    value: 'superadmin',
                    child: Text('Super Admin'),
                  ),
                ],
                onChanged: (v) => setState(() => _role = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
