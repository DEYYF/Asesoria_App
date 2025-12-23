import 'package:flutter/material.dart';

class SupportDialog extends StatelessWidget {
  const SupportDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Soporte Técnico'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.email_outlined, color: Colors.blue),
            title: Text('Email'),
            subtitle: Text('oc214@gmail.com'),
          ),
          ListTile(
            leading: Icon(Icons.chat_outlined, color: Colors.green),
            title: Text('WhatsApp'),
            subtitle: Text('+34 637 685 260'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
