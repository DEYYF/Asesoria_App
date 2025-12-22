import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'client_profile_screen.dart';

/// Wrapper screen that gets the client ID from the current route or auth context
class ClientProfileWrapper extends StatelessWidget {
  final String? clienteId;

  const ClientProfileWrapper({super.key, this.clienteId});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);

    // Use provided clienteId or fall back to authenticated user's ID
    final effectiveClientId = clienteId ?? auth.userId ?? '';

    return ClientProfileScreen(clienteId: effectiveClientId);
  }
}
