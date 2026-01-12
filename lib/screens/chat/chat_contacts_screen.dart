import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';

class ChatContactsScreen extends StatefulWidget {
  const ChatContactsScreen({super.key});

  @override
  State<ChatContactsScreen> createState() => _ChatContactsScreenState();
}

class _ChatContactsScreenState extends State<ChatContactsScreen> {
  bool _isLoading = true;
  List<dynamic> _clients = [];
  List<dynamic> _advisors = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      final data = await chatService.getContacts();
      setState(() {
        _clients = data['clients'] ?? [];
        _advisors = data['advisors'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startChat(String type, String recipientId) async {
    final chatService = Provider.of<ChatService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);

    try {
      final conv = await chatService.findOrCreateConversation(
        type: type,
        asesorId: auth.userId!,
        clienteId: type == 'advisor-client' ? recipientId : null,
        recipientAsesorId: type == 'advisor-advisor' ? recipientId : null,
      );
      if (mounted) {
        context.push('/chat/${conv.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al iniciar chat: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nuevo Chat',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: const [
                      Tab(text: 'Clientes'),
                      Tab(text: 'Asesores'),
                    ],
                    labelColor: theme.primaryColor,
                    unselectedLabelColor: theme.hintColor,
                    indicatorColor: theme.primaryColor,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildContactList(_clients, 'advisor-client', theme),
                        _buildContactList(_advisors, 'advisor-advisor', theme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildContactList(
    List<dynamic> contacts,
    String type,
    ThemeData theme,
  ) {
    if (contacts.isEmpty) {
      return Center(
        child: Text(
          'No se encontraron contactos',
          style: TextStyle(color: theme.hintColor),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: contacts.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.primaryColor.withOpacity(0.1),
            child: Text(
              (contact['nombre'] ?? '?')[0].toUpperCase(),
              style: TextStyle(
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            contact['nombre'] ?? 'Sin nombre',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(contact['email'] ?? ''),
          onTap: () => _startChat(type, contact['_id']),
        );
      },
    );
  }
}
