import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'templates_screen.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/automation_service.dart';

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
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final futures = await Future.wait([
        _service.getAutomations(auth.userId!),
        api.get('/templates?userId=${auth.userId}'),
        api.get('/clientes/asesor/${auth.userId}'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Automatización'), elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _automations.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _automations.length,
              itemBuilder: (context, index) =>
                  _buildAutomationCard(_automations[index]),
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
    final isActive = auto['active'] ?? true;
    final trigger = auto['trigger'] ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: InkWell(
        onTap: () => _showEditDialog(auto),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      auto['name'] ?? 'Sin nombre',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: isActive,
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
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  auto['type'] == 'SCHEDULED'
                      ? _getScheduledLabel(auto)
                      : 'SI: ${_getTriggerLabel(trigger)}',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              ...(auto['actions'] as List).map(
                (action) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        action['type'] == 'SEND_EMAIL'
                            ? Icons.alternate_email_rounded
                            : Icons.chat_bubble_outline_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_getActionLabel(action['type'])} ${action['delay'] > 0 ? ' (en ${action['delay']}m)' : ''}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
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
      default:
        return trigger;
    }
  }

  String _getActionLabel(String type) {
    return type == 'SEND_EMAIL' ? 'Enviar Email' : 'Enviar Mensaje Chat';
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

  void _showAutomationForm({dynamic auto}) {
    String selectedType = auto?['type'] ?? 'EVENT';
    String selectedTrigger = auto?['trigger'] ?? 'CLIENT_REGISTERED';
    DateTime selectedDate = auto?['scheduledDate'] != null
        ? DateTime.parse(auto['scheduledDate'])
        : DateTime.now().add(const Duration(hours: 1));
    bool allClients = auto?['allClients'] ?? true;
    List<String> selectedClients = List<String>.from(
      auto?['targetClientIds'] ?? [],
    );
    List<int> selectedDays = List<int>.from(auto?['daysOfWeek'] ?? []);
    int selectedHour = auto?['hour'] ?? 10;
    int selectedMinute = auto?['minute'] ?? 0;

    final List<String> dayNames = [
      'Dom',
      'Lun',
      'Mar',
      'Mie',
      'Jue',
      'Vie',
      'Sab',
    ];

    // We only support 1 action in the form for simplicity now, but model supports multiple
    final existingAction =
        (auto != null && (auto['actions'] as List).isNotEmpty)
        ? auto['actions'][0]
        : null;
    String selectedActionType = existingAction?['type'] ?? 'SEND_CHAT';
    String? selectedTemplateId =
        existingAction?['templateId']?['_id'] ?? existingAction?['templateId'];
    final nameController = TextEditingController(text: auto?['name'] ?? '');
    final delayController = TextEditingController(
      text: (existingAction?['delay'] ?? 0).toString(),
    );
    final contentOverrideController = TextEditingController(
      text: existingAction?['contentOverride'] ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      auto == null
                          ? 'Nueva Automatización'
                          : 'Editar Automatización',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (auto != null)
                      IconButton(
                        color: Colors.red,
                        onPressed: () async {
                          final confirm = await _showDeleteConfirm();
                          if (confirm == true) {
                            await _service.deleteAutomation(auto['_id']);
                            Navigator.pop(ctx);
                            _loadData();
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la Regla',
                    hintText: 'Ej: Mensaje Programado de Lunes',
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Tipo de Automatización:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'EVENT',
                      label: Text('Por Evento'),
                      icon: Icon(Icons.bolt_rounded),
                    ),
                    ButtonSegment(
                      value: 'SCHEDULED',
                      label: Text('Programada'),
                      icon: Icon(Icons.calendar_month_rounded),
                    ),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (val) =>
                      setS(() => selectedType = val.first),
                ),
                const SizedBox(height: 24),
                if (selectedType == 'EVENT') ...[
                  const Text(
                    'SI ocurre este evento (Trigger):',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedTrigger,
                    items:
                        [
                              'CLIENT_REGISTERED',
                              'BUDGET_CREATED',
                              'APPOINTMENT_CREATED',
                              'APPOINTMENT_MISSED',
                              'BUDGET_ACCEPTED',
                            ]
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(_getTriggerLabel(e)),
                              ),
                            )
                            .toList(),
                    onChanged: (val) => setS(() => selectedTrigger = val!),
                  ),
                ] else ...[
                  const Text(
                    'Cuándo enviar:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Días de la semana (vacío para una sola vez):',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(7, (i) {
                      final isSelected = selectedDays.contains(i);
                      return ChoiceChip(
                        label: Text(dayNames[i]),
                        selected: isSelected,
                        onSelected: (val) {
                          setS(() {
                            if (val)
                              selectedDays.add(i);
                            else
                              selectedDays.remove(i);
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  if (selectedDays.isEmpty)
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      title: Text('${selectedDate.toLocal()}'.substring(0, 16)),
                      subtitle: const Text(
                        'Fecha específica (Ejecución única)',
                      ),
                      trailing: const Icon(Icons.edit_calendar_rounded),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedDate),
                          );
                          if (time != null) {
                            setS(
                              () => selectedDate = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              ),
                            );
                          }
                        }
                      },
                    )
                  else
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      title: Text(
                        '${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}',
                      ),
                      subtitle: const Text('Hora de ejecución (Recurrente)'),
                      trailing: const Icon(Icons.access_time_rounded),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: selectedHour,
                            minute: selectedMinute,
                          ),
                        );
                        if (time != null) {
                          setS(() {
                            selectedHour = time.hour;
                            selectedMinute = time.minute;
                          });
                        }
                      },
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Para quién:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  CheckboxListTile(
                    title: const Text('Enviar a todos los clientes'),
                    value: allClients,
                    onChanged: (val) => setS(() => allClients = val!),
                  ),
                  if (!allClients) ...[
                    const Text(
                      'Seleccionar clientes:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        itemCount: _clients.length,
                        itemBuilder: (ctx, i) {
                          final c = _clients[i];
                          final isSelected = selectedClients.contains(c['_id']);
                          return CheckboxListTile(
                            dense: true,
                            title: Text(c['nombre'] ?? 'Sin nombre'),
                            value: isSelected,
                            onChanged: (val) {
                              setS(() {
                                if (val == true)
                                  selectedClients.add(c['_id']);
                                else
                                  selectedClients.remove(c['_id']);
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                const Text(
                  'ENTONCES realizar esta acción:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ActionChoiceChip(
                        label: 'Chat',
                        icon: Icons.chat_bubble_rounded,
                        selected: selectedActionType == 'SEND_CHAT',
                        onSelected: (val) => setS(() {
                          selectedActionType = 'SEND_CHAT';
                          final isStillValid = _templates.any(
                            (t) =>
                                t['_id'].toString() == selectedTemplateId &&
                                t['type'] == 'chat',
                          );
                          if (!isStillValid) selectedTemplateId = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ActionChoiceChip(
                        label: 'Email',
                        icon: Icons.alternate_email_rounded,
                        selected: selectedActionType == 'SEND_EMAIL',
                        onSelected: (val) => setS(() {
                          selectedActionType = 'SEND_EMAIL';
                          final isStillValid = _templates.any(
                            (t) =>
                                t['_id'].toString() == selectedTemplateId &&
                                t['type'] == 'email',
                          );
                          if (!isStillValid) selectedTemplateId = null;
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Usar Plantilla:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                InkWell(
                  onTap: () => _showTemplateSelector(
                    setS,
                    contentOverrideController,
                    (val) {
                      setS(() {
                        selectedTemplateId = val;
                        if (val != null) contentOverrideController.clear();
                      });
                    },
                    selectedActionType,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedTemplateId == null
                              ? Icons.edit_note_rounded
                              : Icons.description_rounded,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedTemplateId == null
                                ? 'Escribir mensaje manual...'
                                : _templates.firstWhere(
                                        (t) =>
                                            t['_id'].toString() ==
                                            selectedTemplateId,
                                        orElse: () => {
                                          'title': 'Plantilla seleccionada',
                                        },
                                      )['title'] ??
                                      'Plantilla',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => const TemplatesScreen(),
                          ),
                        );
                        _loadData();
                      },
                      icon: const Icon(
                        Icons.settings_suggest_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'Gestionar Plantillas',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                if (selectedTemplateId != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vista previa y Unión de variables:',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildHighlightedContent(
                          _templates.firstWhere(
                                (t) =>
                                    t['_id'].toString() == selectedTemplateId,
                                orElse: () => {'content': ''},
                              )['content'] ??
                              '',
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (selectedTemplateId == null) ...[
                  const Text(
                    'O escribir mensaje personalizado:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  TextField(
                    controller: contentOverrideController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Introduce el mensaje...',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ExpansionTile(
                  title: const Text(
                    'Variables disponibles',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        children: [
                          _VariableInfo(
                            variable: '{{cliente_nombre}}',
                            description: 'Nombre completo',
                            onTap: (v) {
                              final text = contentOverrideController.text;
                              final selection =
                                  contentOverrideController.selection;
                              final newText = text.replaceRange(
                                selection.start == -1
                                    ? text.length
                                    : selection.start,
                                selection.end == -1
                                    ? text.length
                                    : selection.end,
                                v,
                              );
                              contentOverrideController.text = newText;
                              contentOverrideController.selection =
                                  TextSelection.collapsed(
                                    offset:
                                        (selection.start == -1
                                            ? text.length
                                            : selection.start) +
                                        v.length,
                                  );
                            },
                          ),
                          _VariableInfo(
                            variable: '{{cliente_email}}',
                            description: 'Correo electrónico',
                            onTap: (v) {
                              final text = contentOverrideController.text;
                              final selection =
                                  contentOverrideController.selection;
                              final newText = text.replaceRange(
                                selection.start == -1
                                    ? text.length
                                    : selection.start,
                                selection.end == -1
                                    ? text.length
                                    : selection.end,
                                v,
                              );
                              contentOverrideController.text = newText;
                              contentOverrideController.selection =
                                  TextSelection.collapsed(
                                    offset:
                                        (selection.start == -1
                                            ? text.length
                                            : selection.start) +
                                        v.length,
                                  );
                            },
                          ),
                          _VariableInfo(
                            variable: '{{cliente_telefono}}',
                            description: 'Teléfono',
                            onTap: (v) {
                              final text = contentOverrideController.text;
                              final selection =
                                  contentOverrideController.selection;
                              final newText = text.replaceRange(
                                selection.start == -1
                                    ? text.length
                                    : selection.start,
                                selection.end == -1
                                    ? text.length
                                    : selection.end,
                                v,
                              );
                              contentOverrideController.text = newText;
                              contentOverrideController.selection =
                                  TextSelection.collapsed(
                                    offset:
                                        (selection.start == -1
                                            ? text.length
                                            : selection.start) +
                                        v.length,
                                  );
                            },
                          ),
                          _VariableInfo(
                            variable: '{{tarifa}}',
                            description: 'Tarifa actual',
                            onTap: (v) {
                              final text = contentOverrideController.text;
                              final selection =
                                  contentOverrideController.selection;
                              final newText = text.replaceRange(
                                selection.start == -1
                                    ? text.length
                                    : selection.start,
                                selection.end == -1
                                    ? text.length
                                    : selection.end,
                                v,
                              );
                              contentOverrideController.text = newText;
                              contentOverrideController.selection =
                                  TextSelection.collapsed(
                                    offset:
                                        (selection.start == -1
                                            ? text.length
                                            : selection.start) +
                                        v.length,
                                  );
                            },
                          ),
                          _VariableInfo(
                            variable: '{{fecha}}',
                            description: 'Fecha de envío',
                            onTap: (v) {
                              final text = contentOverrideController.text;
                              final selection =
                                  contentOverrideController.selection;
                              final newText = text.replaceRange(
                                selection.start == -1
                                    ? text.length
                                    : selection.start,
                                selection.end == -1
                                    ? text.length
                                    : selection.end,
                                v,
                              );
                              contentOverrideController.text = newText;
                              contentOverrideController.selection =
                                  TextSelection.collapsed(
                                    offset:
                                        (selection.start == -1
                                            ? text.length
                                            : selection.start) +
                                        v.length,
                                  );
                            },
                          ),
                          _VariableInfo(
                            variable: '{{hora}}',
                            description: 'Hora de envío',
                            onTap: (v) {
                              final text = contentOverrideController.text;
                              final selection =
                                  contentOverrideController.selection;
                              final newText = text.replaceRange(
                                selection.start == -1
                                    ? text.length
                                    : selection.start,
                                selection.end == -1
                                    ? text.length
                                    : selection.end,
                                v,
                              );
                              contentOverrideController.text = newText;
                              contentOverrideController.selection =
                                  TextSelection.collapsed(
                                    offset:
                                        (selection.start == -1
                                            ? text.length
                                            : selection.start) +
                                        v.length,
                                  );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: delayController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Retraso (minutos)',
                    hintText: '0 para inmediato',
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty) return;

                      final auth = Provider.of<AuthService>(
                        context,
                        listen: false,
                      );
                      final action = {
                        'type': selectedActionType,
                        'templateId': selectedTemplateId,
                        'contentOverride':
                            contentOverrideController.text.isNotEmpty
                            ? contentOverrideController.text
                            : null,
                        'delay': int.tryParse(delayController.text) ?? 0,
                      };

                      final Map<String, dynamic> data = {
                        'name': nameController.text,
                        'type': selectedType,
                        'allClients': allClients,
                        'targetClientIds': selectedClients,
                        'actions': [action],
                        'advisorId': auth.userId,
                      };

                      if (selectedType == 'EVENT') {
                        data['trigger'] = selectedTrigger;
                      } else {
                        if (selectedDays.isEmpty) {
                          data['scheduledDate'] = selectedDate
                              .toIso8601String();
                        } else {
                          data['daysOfWeek'] = selectedDays;
                          data['hour'] = selectedHour;
                          data['minute'] = selectedMinute;
                        }
                      }

                      try {
                        if (auto == null) {
                          await _service.createAutomation(data);
                        } else {
                          await _service.updateAutomation(auto['_id'], data);
                        }
                        Navigator.pop(ctx);
                        _loadData();
                      } catch (e) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                    child: const Text('Guardar Automatización'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showTemplateSelector(
    StateSetter setS,
    TextEditingController contentCtrl,
    Function(String?) onSelect,
    String actionType,
  ) async {
    final typeFilter = actionType == 'SEND_EMAIL' ? 'email' : 'chat';
    final filtered = _templates.where((t) => t['type'] == typeFilter).toList();

    // Group by category
    final Map<String, List<dynamic>> grouped = {};
    for (var t in filtered) {
      final cats = List<String>.from(t['categories'] ?? ['General']);
      for (var cat in cats) {
        grouped.putIfAbsent(cat, () => []).add(t);
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded, color: Colors.blue),
                  const SizedBox(width: 12),
                  const Text(
                    'Seleccionar Plantilla',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        onSelect(null);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white12
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit_note_rounded,
                                color: Colors.blue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Escribir mensaje manual',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Sin plantilla predefinida',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.add_circle_outline_rounded,
                              color: Colors.blue,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  ...grouped.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 24,
                            bottom: 12,
                            left: 4,
                          ),
                          child: Text(
                            entry.key.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        ...entry.value.map((t) {
                          final isDark =
                              Theme.of(context).brightness == Brightness.dark;
                          final theme = Theme.of(context);
                          final List<String> cats = List<String>.from(
                            t['categories'] ?? [],
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () =>
                                  _showTemplateFullPreview(t, onSelect),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white12
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color:
                                            (t['type'] == 'email'
                                                    ? Colors.blue
                                                    : Colors.green)
                                                .withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        t['type'] == 'email'
                                            ? Icons.email_rounded
                                            : Icons.chat_bubble_rounded,
                                        color: t['type'] == 'email'
                                            ? Colors.blue
                                            : Colors.green,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  (t['title'] != null &&
                                                          t['title']
                                                              .toString()
                                                              .isNotEmpty)
                                                      ? t['title'].toString()
                                                      : (t['subject'] != null &&
                                                            t['subject']
                                                                .toString()
                                                                .isNotEmpty)
                                                      ? t['subject'].toString()
                                                      : (t['content'] != null &&
                                                            t['content']
                                                                    .toString()
                                                                    .length >
                                                                20)
                                                      ? '${t['content'].toString().substring(0, 20)}...'
                                                      : 'Plantilla sin título',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              ...cats.map(
                                                (cat) => Container(
                                                  margin: const EdgeInsets.only(
                                                    right: 4,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: theme.primaryColor
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    cat.toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 8,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: theme.primaryColor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            t['content'] ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.hintColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.remove_red_eye_outlined,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTemplateFullPreview(
    dynamic t,
    Function(String?) onSelect,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const Icon(Icons.visibility_rounded, color: Colors.blue),
                  const SizedBox(width: 12),
                  const Text(
                    'Vista Previa Completa',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (t['title'] != null && t['title'].toString().isNotEmpty)
                          ? t['title'].toString()
                          : (t['subject'] != null &&
                                t['subject'].toString().isNotEmpty)
                          ? t['subject'].toString()
                          : 'Plantilla sin título',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: List<String>.from(t['categories'] ?? [])
                          .map(
                            (cat) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                cat.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'CONTENIDO DEL MENSAJE:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: _buildHighlightedContent(t['content'] ?? ''),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'VARIABLES DETECTADAS:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _VariableLegend(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    onSelect(t['_id'].toString());
                    Navigator.pop(ctx); // Close preview
                    Navigator.pop(context); // Close selector
                  },
                  child: const Text(
                    'Confirmar Selección',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedContent(String content) {
    final List<String> variables = [
      '{{cliente_nombre}}',
      '{{cliente_email}}',
      '{{cliente_telefono}}',
      '{{tarifa}}',
      '{{fecha}}',
      '{{hora}}',
    ];
    List<TextSpan> spans = [];

    // Simple logic to find and highlight variables
    String remaining = content;
    while (remaining.isNotEmpty) {
      int firstIdx = -1;
      String? foundVar;
      for (var v in variables) {
        int idx = remaining.indexOf(v);
        if (idx != -1 && (firstIdx == -1 || idx < firstIdx)) {
          firstIdx = idx;
          foundVar = v;
        }
      }

      if (firstIdx == -1) {
        spans.add(
          TextSpan(
            text: remaining,
            style: const TextStyle(color: Colors.black87, fontSize: 12),
          ),
        );
        break;
      }

      if (firstIdx > 0) {
        spans.add(
          TextSpan(
            text: remaining.substring(0, firstIdx),
            style: const TextStyle(color: Colors.black87, fontSize: 12),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: foundVar,
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            backgroundColor: Color(0x1A2196F3),
          ),
        ),
      );

      remaining = remaining.substring(firstIdx + foundVar!.length);
    }

    return RichText(text: TextSpan(children: spans));
  }

  Future<bool?> _showDeleteConfirm() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar regla?'),
        content: const Text(
          'Esta acción desactivará la automatización para siempre.',
        ),
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
  }
}

class _VariableInfo extends StatelessWidget {
  final String variable;
  final String description;
  final Function(String)? onTap;

  const _VariableInfo({
    required this.variable,
    required this.description,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap != null ? () => onTap!(variable) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                variable,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            Text(
              description,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class ActionChoiceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const ActionChoiceChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onSelected(true),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? theme.primaryColor
              : (theme.brightness == Brightness.dark
                    ? Colors.white10
                    : Colors.grey[100]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? theme.primaryColor : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : Colors.grey),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariableLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vars = [
      {'v': '{{cliente_nombre}}', 'd': 'Nombre del cliente'},
      {'v': '{{tarifa}}', 'd': 'Tarifa contratada'},
      {'v': '{{fecha}}', 'd': 'Fecha actual'},
      {'v': '{{hora}}', 'd': 'Hora actual'},
    ];
    return Column(
      children: vars
          .map(
            (v) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      v['v']!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    v['d']!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
