import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/cliente_model.dart';
import 'profile/info_tab.dart';
import 'profile/diet_tab.dart';
import 'profile/training_tab.dart';
import 'profile/progress_tab.dart';
import '../widgets/dialogs/add_progress_dialog.dart';
import '../widgets/dialogs/manage_extras_dialog.dart';
import '../widgets/dialogs/change_tariff_dialog.dart';
import '../widgets/dialogs/edit_info_dialog.dart';
import 'profile/journal_tab.dart';
import 'chat/chat_detail_screen.dart';
import '../../services/settings_service.dart';
import '../../models/settings_model.dart';
import '../../services/chat_service.dart';
import '../../utils/isolate_utils.dart';
import 'profile/client_view_layout.dart';
import 'profile/advisor_view_layout.dart';
import 'profile/calendar_tab.dart'; // Add import

class ClientProfileScreen extends StatefulWidget {
  final String clienteId;
  const ClientProfileScreen({super.key, required this.clienteId});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  Cliente? _cliente;
  UserSettings? _settings;
  bool _isLoading = true;
  String? _error;

  // Budget Status
  bool _canEditFeatures = true;
  String? _budgetEstado;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final settingsService = SettingsService(api);
    try {
      final results = await Future.wait([
        api.get('/clientes/${widget.clienteId}'),
        api.get('/clientes/${widget.clienteId}/budget-status'),
        settingsService.getSettings(),
      ]);

      final resClient = results[0] as dynamic;
      final resBudget = results[1] as dynamic;
      final userSettings = results[2] as UserSettings;

      if (!mounted) return;

      if (resClient.statusCode == 200) {
        final c = await parseClienteInIsolate(resClient.body);

        bool canEdit = false;
        String? bState;

        if (resBudget.statusCode == 200) {
          final bData = jsonDecode(resBudget.body);
          canEdit = bData['canEdit'] ?? false;
          bState = bData['estado'];
        } else {
          canEdit = true;
        }

        setState(() {
          _cliente = c;
          _settings = userSettings;
          _canEditFeatures = canEdit;
          _budgetEstado = bState;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Error ${resClient.statusCode}: ${resClient.body}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  bool get _hasDieta {
    if (_cliente == null) return false;
    const types = [
      "Dieta",
      "Dieta y asesoramiento",
      "Dieta y Rutina",
      "Mensual",
      "Trimestral",
      "Semestral",
      "Anual",
    ];
    return types.contains(_cliente!.tipoServicio);
  }

  bool get _hasEntrenamiento {
    if (_cliente == null) return false;
    const types = [
      "Rutina",
      "Rutina y asesoramiento",
      "Dieta y Rutina",
      "Mensual",
      "Trimestral",
      "Semestral",
      "Anual",
    ];
    return types.contains(_cliente!.tipoServicio);
  }

  Future<void> _handleRenovar() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.put('/clientes/${widget.clienteId}/actualizar-tarifa', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud de renovación creada')),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al renovar: $e')));
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Cliente'),
        content: Text('¿Seguro que quieres eliminar a ${_cliente?.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.delete('/clientes/${widget.clienteId}');
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  void _showAddProgress() {
    showDialog(
      context: context,
      builder: (_) => AddProgressDialog(
        clienteId: widget.clienteId,
        onSuccess: () {
          _loadData();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Progreso añadido')));
        },
      ),
    );
  }

  void _showManageExtras() {
    showDialog(
      context: context,
      builder: (_) => ManageExtrasDialog(
        clienteId: widget.clienteId,
        onSuccess: () {
          _loadData();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Extras actualizados')));
        },
      ),
    );
  }

  void _showChangeTariff() {
    showDialog(
      context: context,
      builder: (_) => ChangeTariffDialog(
        clienteId: widget.clienteId,
        currentDuration: _cliente?.tiempoTarifa ?? '1 Mes',
        onSuccess: () {
          _loadData();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Tarifa actualizada')));
        },
      ),
    );
  }

  void _showEditInfo() {
    showDialog(
      context: context,
      builder: (_) => EditInfoDialog(
        cliente: _cliente!,
        onSuccess: () {
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Información actualizada')),
          );
        },
      ),
    );
  }

  Future<void> _handleSessionAction(String action) async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.put('/clientes/${widget.clienteId}/sesiones-counter', {
        'action': action,
      });
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar sesiones: $e')),
        );
      }
    }
  }

  Future<void> _navigateToLiveSession() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get('/entrenamientos/cliente/${widget.clienteId}');
      if (res.statusCode == 200) {
        final List<dynamic> trainings = jsonDecode(res.body);
        if (trainings.isNotEmpty) {
          final activeTraining = trainings.first;
          final entrenamientoId = activeTraining['_id'];
          if (mounted) {
            context.push('/entrenamientos/sesion/$entrenamientoId');
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No hay plan de entrenamiento activo'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar el entrenamiento')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final theme = Theme.of(context);
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Cargando perfil...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.hintColor.withOpacity(0.6),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_error!)),
      );
    }
    if (_cliente == null) {
      return const Scaffold(body: Center(child: Text('Cliente no encontrado')));
    }

    final theme = Theme.of(context);
    final auth = Provider.of<AuthService>(context);

    // Common tabs logic for Advisor view is now handled within AdvisorViewLayout
    // or passed as simple lists if we want to keep logic here.
    // But AdvisorViewLayout was designed to take 'tabs' and 'tabViews'.
    // Let's reconstruct them here for Advisor, but Client uses its own internal logic
    // inside ClientViewLayout? No, ClientViewLayout has its own internal bottom bar logic.
    // So distinct logic:

    if (auth.isClient) {
      return ClientViewLayout(
        cliente: _cliente!,
        hasDieta: _hasDieta,
        hasEntrenamiento: _hasEntrenamiento,
        showLibreta: _settings?.enabledTrainingLog ?? true,
        canEditFeatures: _canEditFeatures,
        onRenovar: _handleRenovar,
        onDelete: _handleDelete,
        onAddProgress: _showAddProgress,
        onManageExtras: _showManageExtras,
        onChangeTariff: _showChangeTariff,
        onEditInfo: _showEditInfo,
        onSessionAction: _handleSessionAction,
        onNavigateToLiveSession: _navigateToLiveSession,
        chatTabWidget: _buildChatTab(theme),
      );
    } else {
      // Reconstruct tabs for Advisor
      final tabs = <Widget>[const Tab(text: 'Información y Registro')];
      final tabViews = <Widget>[
        InfoTab(
          cliente: _cliente!,
          onRenovar: _handleRenovar,
          onDelete: _handleDelete,
          onAddProgress: _showAddProgress,
          onManageExtras: _showManageExtras,
          onChangeTariff: _showChangeTariff,
          onEditInfo: _showEditInfo,
          onSessionAction: _handleSessionAction,
        ),
      ];

      if (_hasDieta) {
        if (_canEditFeatures) {
          tabs.add(const Tab(text: 'Dieta'));
          tabViews.add(DietTab(clienteId: _cliente!.id));
        } else {
          tabs.add(
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Dieta'),
                  SizedBox(width: 4),
                  Icon(Icons.lock, size: 14),
                ],
              ),
            ),
          );
          tabViews.add(const Center(child: Icon(Icons.lock)));
        }
      }

      if (_hasEntrenamiento) {
        if (_canEditFeatures) {
          tabs.add(const Tab(text: 'Entrenamiento'));
          tabViews.add(TrainingTab(clienteId: _cliente!.id));
        } else {
          tabs.add(
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Entrenamiento'),
                  SizedBox(width: 4),
                  Icon(Icons.lock, size: 14),
                ],
              ),
            ),
          );
          tabViews.add(const Center(child: Icon(Icons.lock)));
        }
      }

      // Add Libreta (Journal) independently of service type
      if (_settings?.enabledTrainingLog ?? true) {
        if (_canEditFeatures) {
          tabs.add(const Tab(text: 'Libreta'));
          tabViews.add(JournalTab(cliente: _cliente!));
        } else {
          tabs.add(
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Libreta'),
                  SizedBox(width: 4),
                  Icon(Icons.lock, size: 14),
                ],
              ),
            ),
          );
          tabViews.add(const Center(child: Icon(Icons.lock)));
        }
      }

      // Progreso
      if (_hasDieta || _hasEntrenamiento) {
        if (_canEditFeatures) {
          tabs.add(const Tab(text: 'Progreso'));
          tabViews.add(
            ProgressTab(cliente: _cliente!, onAddProgress: _showAddProgress),
          );
        } else {
          tabs.add(
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Progreso'),
                  SizedBox(width: 4),
                  Icon(Icons.lock, size: 14),
                ],
              ),
            ),
          );
          tabViews.add(const Center(child: Icon(Icons.lock)));
        }
      }

      return AdvisorViewLayout(
        cliente: _cliente!,
        budgetEstado: _budgetEstado,
        hasEntrenamiento: _hasEntrenamiento,
        canEditFeatures: _canEditFeatures,
        tabs: tabs,
        tabViews: tabViews,
        onAddProgress: _showAddProgress,
        onNavigateToLiveSession: _navigateToLiveSession,
        onShowChat: () {},
      );
    }
  }

  Widget _buildChatTab(ThemeData theme) {
    return FutureBuilder<String?>(
      future: _getOrCreateConversationId(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Text('Error al cargar el chat: ${snapshot.error}'),
          );
        }
        return ChatDetailScreen(
          conversationId: snapshot.data!,
          isEmbedded: true,
        );
      },
    );
  }

  Future<String?> _getOrCreateConversationId() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);

    try {
      // If Advisor/Admin, we want the "official" conversation first
      if (!auth.isClient) {
        final resOfficial = await api.get(
          '/chat/conversations/client/${_cliente!.id}',
        );
        if (resOfficial.statusCode == 200 && resOfficial.body != 'null') {
          final official = jsonDecode(resOfficial.body);
          if (official != null) return official['_id'];
        }
      }

      final res = await api.get('/chat/conversations');
      if (res.statusCode == 200) {
        final List<dynamic> conversations = jsonDecode(res.body);

        dynamic existing;
        if (auth.isClient) {
          // Client looking for conversation with their advisor
          existing = conversations.firstWhere(
            (c) =>
                c['asesorId'] == _cliente!.asesorId ||
                (c['asesorId'] is Map &&
                    c['asesorId']['_id'] == _cliente!.asesorId),
            orElse: () => null,
          );
        } else {
          // Advisor looking for conversation with this specific client
          existing = conversations.firstWhere(
            (c) =>
                c['clienteId'] == _cliente!.id ||
                (c['clienteId'] is Map &&
                    c['clienteId']['_id'] == _cliente!.id),
            orElse: () => null,
          );
        }

        if (existing != null) return existing['_id'];
      }

      // If no conversation exists, create one (especially for advisors starting a chat)
      if (!auth.isClient) {
        final chatService = Provider.of<ChatService>(context, listen: false);
        final newConv = await chatService.findOrCreateConversation(
          type: 'advisor-client',
          asesorId: _cliente!.asesorId ?? auth.userId!,
          clienteId: _cliente!.id,
        );
        return newConv.id;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting conversation ID: $e');
      return null;
    }
  }
}
