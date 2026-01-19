import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/automation_service.dart';
import '../../providers/super_admin_provider.dart';
import 'automation_form_sheet.dart';
import '../../widgets/advisor_selector.dart';

class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  late AutomationService _service;
  List<dynamic> _automations = [];
  List<dynamic> _templates = [];
  List<dynamic> _clients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = AutomationService(
      Provider.of<ApiService>(context, listen: false),
    );
    _loadData();

    // Listen to Advisor changes for SuperAdmin
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saProvider = Provider.of<SuperAdminProvider>(
        context,
        listen: false,
      );
      saProvider.addListener(_onAdvisorChanged);
    });
  }

  void _onAdvisorChanged() {
    if (mounted) _loadData();
  }

  @override
  void dispose() {
    try {
      final saProvider = Provider.of<SuperAdminProvider>(
        context,
        listen: false,
      );
      saProvider.removeListener(_onAdvisorChanged);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final saProvider = Provider.of<SuperAdminProvider>(
        context,
        listen: false,
      );
      String? advisorId;
      if (auth.isSuperAdmin) {
        advisorId = saProvider.selectedAdvisorId; // Null = Global
      } else {
        advisorId = auth.userId;
      }

      final futures = await Future.wait([
        _service.getAutomations(advisorId),
        api.get(
          '/templates?userId=${advisorId ?? auth.userId}',
        ), // Templates might need specific user or global? Assuming current user or selected.
        api.get('/clientes?asesorId=${advisorId ?? auth.userId}'),
      ]);

      setState(() {
        _automations = futures[0] as List;
        _templates = (futures[1] as dynamic).statusCode == 200
            ? (jsonDecode((futures[1] as dynamic).body) as List)
            : [];
        _clients = (futures[2] as dynamic).statusCode == 200
            ? (jsonDecode((futures[2] as dynamic).body) as List)
            : [];
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading automation data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context); // Listen to auth changes
    return Scaffold(
      appBar: AppBar(title: const Text('Automatización'), elevation: 0),
      body: Column(
        children: [
          if (auth.isSuperAdmin) const AdvisorSelector(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _automations.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _automations.length,
                    itemBuilder: (context, index) =>
                        _buildAutomationCard(_automations[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Nueva Regla'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_fix_high_rounded,
            size: 80,
            color: Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          const Text(
            'No tienes automatizaciones',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
            child: Text(
              'Crea reglas para enviar mensajes o emails automáticamente cuando ocurran eventos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: _showCreateDialog,
            child: const Text('Crear Primera Regla'),
          ),
        ],
      ),
    );
  }

  Widget _buildAutomationCard(dynamic auto) {
    final theme = Theme.of(context);
    final isActive = auto['active'] == true;
    final trigger = auto['trigger'];
    final autoType = auto['type'];
    final actions = auto['actions'] as List;

    // Get color based on action type
    Color getActionColor(String actionType) {
      switch (actionType) {
        case 'SEND_CHAT':
          return Colors.blue;
        case 'SEND_EMAIL':
          return Colors.green;
        case 'CREATE_TASK':
          return Colors.orange;
        case 'SEND_PUSH_NOTIFICATION':
          return Colors.purple;
        case 'ADD_TAG':
          return Colors.teal;
        case 'SEND_SMS':
          return Colors.red;
        default:
          return theme.primaryColor;
      }
    }

    final primaryActionColor = actions.isNotEmpty
        ? getActionColor(actions[0]['type'])
        : theme.primaryColor;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive
              ? primaryActionColor.withOpacity(0.3)
              : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryActionColor.withOpacity(0.05), Colors.white],
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Status Indicator
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? Colors.green : Colors.grey,
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auto['name'] ?? 'Sin nombre',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (auto['description'] != null &&
                            auto['description'].toString().isNotEmpty)
                          Text(
                            auto['description'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Active Switch
                  Transform.scale(
                    scale: 0.8,
                    child: Switch.adaptive(
                      value: isActive,
                      activeColor: primaryActionColor,
                      onChanged: (val) async {
                        try {
                          await _service.updateAutomation(auto['_id'], {
                            'active': val,
                          });
                          _loadData();
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      },
                    ),
                  ),
                  // Actions Menu
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: Colors.grey[600],
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (val) {
                      if (val == 'edit') {
                        _showEditDialog(auto);
                      } else if (val == 'delete') {
                        _confirmDelete(auto);
                      } else if (val == 'transfer') {
                        _handleTransferAutomation(auto);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18),
                            SizedBox(width: 12),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Colors.red,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Eliminar',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'transfer',
                        child: Row(
                          children: [
                            Icon(Icons.swap_horiz_rounded, size: 18),
                            SizedBox(width: 12),
                            Text('Transferir'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Trigger/Schedule Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: primaryActionColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primaryActionColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      autoType == 'SCHEDULED'
                          ? Icons.schedule_rounded
                          : Icons.bolt_rounded,
                      size: 16,
                      color: primaryActionColor,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        autoType == 'SCHEDULED'
                            ? _getScheduledLabel(auto)
                            : 'SI: ${_getTriggerLabel(trigger)}',
                        style: TextStyle(
                          color: primaryActionColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Actions Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.play_arrow_rounded,
                          size: 16,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'ENTONCES:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...actions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final action = entry.value;
                      final actionColor = getActionColor(action['type']);

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index < actions.length - 1 ? 10 : 0,
                        ),
                        child: Row(
                          children: [
                            // Action Icon with colored background
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: actionColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getActionIcon(action['type']),
                                size: 18,
                                color: actionColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Action Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getActionLabel(action['type']),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (action['delay'] > 0)
                                    Text(
                                      'Retraso: ${action['delay']} minutos',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTriggerLabel(String? trigger) {
    if (trigger == null) return 'Desconocido';
    switch (trigger) {
      case 'CLIENT_REGISTERED':
        return 'Cliente Registrado';
      case 'BUDGET_CREATED':
        return 'Presupuesto Creado';
      case 'APPOINTMENT_CREATED':
        return 'Cita Programada';
      case 'APPOINTMENT_MISSED':
        return 'Cita No Asistida';
      case 'BUDGET_ACCEPTED':
        return 'Presupuesto Aceptado';
      case 'BUDGET_REJECTED':
        return 'Presupuesto Rechazado';
      case 'BUDGET_PAID':
        return 'Presupuesto Pagado';
      case 'DIET_ASSIGNED':
        return 'Dieta Asignada';
      case 'WORKOUT_ASSIGNED':
        return 'Entrenamiento Asignado';
      case 'APPOINTMENT_CONFIRMED':
        return 'Cita Confirmada';
      case 'APPOINTMENT_CANCELLED':
        return 'Cita Cancelada';
      case 'PROGRESS_RECORDED':
        return 'Progreso Registrado';
      case 'WORKOUT_COMPLETED':
        return 'Sesión Completada';
      default:
        return trigger;
    }
  }

  String _getActionLabel(String type) {
    switch (type) {
      case 'SEND_EMAIL':
        return 'Enviar Email';
      case 'SEND_CHAT':
        return 'Enviar Mensaje Chat';
      case 'CREATE_TASK':
        return 'Crear Tarea';
      case 'SEND_PUSH_NOTIFICATION':
        return 'Notificación Push';
      case 'ADD_TAG':
        return 'Añadir Etiqueta';
      case 'SEND_SMS':
        return 'Enviar SMS';
      default:
        return type;
    }
  }

  IconData _getActionIcon(String type) {
    switch (type) {
      case 'SEND_EMAIL':
        return Icons.alternate_email_rounded;
      case 'SEND_CHAT':
        return Icons.chat_bubble_outline_rounded;
      case 'CREATE_TASK':
        return Icons.task_alt_rounded;
      case 'SEND_PUSH_NOTIFICATION':
        return Icons.notifications_active_rounded;
      case 'ADD_TAG':
        return Icons.label_rounded;
      case 'SEND_SMS':
        return Icons.sms_rounded;
      default:
        return Icons.settings_rounded;
    }
  }

  String _getScheduledLabel(dynamic auto) {
    if (auto['daysOfWeek'] != null && (auto['daysOfWeek'] as List).isNotEmpty) {
      final List<String> dayNames = [
        'Dom',
        'Lun',
        'Mar',
        'Mie',
        'Jue',
        'Vie',
        'Sab',
      ];
      final days = (auto['daysOfWeek'] as List)
          .map((d) => dayNames[d as int])
          .join(', ');
      final time =
          '${auto['hour'] ?? 0}:${(auto['minute'] ?? 0).toString().padLeft(2, '0')}';
      return 'RECURRENTE: $days a las $time';
    } else if (auto['scheduledDate'] != null) {
      try {
        return 'UNICA: ${DateTime.parse(auto['scheduledDate']).toLocal().toString().substring(0, 16)}';
      } catch (e) {
        return 'HORA: Fecha inválida';
      }
    }
    return 'PROGRAMADA: Sin hora';
  }

  void _showCreateDialog() {
    _showAutomationForm();
  }

  void _showEditDialog(dynamic auto) {
    _showAutomationForm(auto: auto);
  }

  Future<void> _showAutomationForm({dynamic auto}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AutomationFormSheet(
        automation: auto,
        templates: _templates,
        clients: _clients,
        onSave: () => _loadData(),
      ),
    );
  }

  void _confirmDelete(dynamic auto) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar automatización?'),
        content: Text(
          '¿Estás seguro de que quieres eliminar "${auto['name']}"? Esta acción no se puede deshacer.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _service.deleteAutomation(auto['_id']);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Automatización eliminada')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleTransferAutomation(dynamic auto) async {
    final api = Provider.of<ApiService>(context, listen: false);
    List<dynamic> advisors = [];
    String? selectedAdvisorId;

    // Load advisors
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await api.get('/users');
      if (res.statusCode == 200) {
        final List<dynamic> allUsers = await api.parseJsonResponse(res);
        // Filter out current owner
        advisors = allUsers.where((u) {
          final uid = u['_id']?.toString();
          final ownerId = auto['advisorId']?.toString();
          return uid != null && uid != ownerId;
        }).toList();
      }
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error cargando asesores: $e')));
      }
      return;
    }

    if (!mounted) return;

    // Show Selection Dialog
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Transferir Automatización'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Selecciona el nuevo asesor para "${auto['name']}".'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Nuevo Asesor',
                    border: OutlineInputBorder(),
                  ),
                  items: advisors.map<DropdownMenuItem<String>>((u) {
                    final String uid = u['_id'].toString();
                    final String uname =
                        u['nombre']?.toString() ?? 'Sin nombre';
                    return DropdownMenuItem(value: uid, child: Text(uname));
                  }).toList(),
                  onChanged: (val) {
                    setState(() => selectedAdvisorId = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: selectedAdvisorId == null
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _executeTransfer(auto['_id'], selectedAdvisorId!);
                      },
                child: const Text('Transferir'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeTransfer(
    String automationId,
    String targetAdvisorId,
  ) async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.post('/automations/$automationId/transfer', {
        'targetAdvisorId': targetAdvisorId,
      });

      if (mounted) {
        if (res.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Automatización transferida exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        } else {
          final err = jsonDecode(res.body)['error'] ?? 'Error desconocido';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
      }
    }
  }
}
