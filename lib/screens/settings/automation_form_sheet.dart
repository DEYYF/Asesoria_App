import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'templates_screen.dart';
import '../../services/auth_service.dart';
import '../../services/automation_service.dart';
import '../../services/api_service.dart';
import '../../utils/notification_helper.dart';

class AutomationFormSheet extends StatefulWidget {
  final Map<String, dynamic>? automation;
  final List<dynamic> templates;
  final List<dynamic> clients;
  final Function() onSave;

  const AutomationFormSheet({
    super.key,
    this.automation,
    required this.templates,
    required this.clients,
    required this.onSave,
  });

  @override
  State<AutomationFormSheet> createState() => _AutomationFormSheetState();
}

class _AutomationFormSheetState extends State<AutomationFormSheet> {
  late AutomationService _service;

  late TextEditingController nameController;
  late TextEditingController delayController;
  late TextEditingController contentOverrideController;
  late TextEditingController taskDueDateController;

  String selectedType = 'EVENT';
  String? selectedTrigger; // Nullable
  bool allClients = true;
  List<String> selectedClients = [];
  List<int> selectedDays = [];
  int selectedHour = 10;
  int selectedMinute = 0;
  DateTime selectedDate = DateTime.now();

  String selectedActionType = 'SEND_CHAT';
  String? selectedTemplateId;

  // Shopping List config
  String _shoppingListPeriod = 'semanal';
  String _shoppingListChannel = 'CHAT';

  // Helper lists
  final List<String> dayNames = [
    'Dom',
    'Lun',
    'Mar',
    'Mie',
    'Jue',
    'Vie',
    'Sab',
  ];

  @override
  void initState() {
    super.initState();
    _service = AutomationService(
      Provider.of<ApiService>(context, listen: false),
    );
    final auto = widget.automation;

    // Initialize controllers
    nameController = TextEditingController(text: auto?['name'] ?? '');

    final existingAction =
        (auto != null && (auto['actions'] as List).isNotEmpty)
        ? auto['actions'][0]
        : null;

    delayController = TextEditingController(
      text: (existingAction?['delay'] ?? 0).toString(),
    );
    contentOverrideController = TextEditingController(
      text: existingAction?['contentOverride'] ?? '',
    );
    taskDueDateController = TextEditingController(
      text: (existingAction?['metadata'] is Map)
          ? existingAction['metadata']['dueDate'] ?? ''
          : '',
    );

    // Initialize state
    if (auto != null) {
      selectedType = auto['type'] ?? 'EVENT';
      if (selectedType == 'EVENT') {
        selectedTrigger = auto['trigger'];
      } else {
        // Scheduled logic
        if (auto['scheduledDate'] != null) {
          selectedDate = DateTime.parse(auto['scheduledDate']);
        }
        if (auto['daysOfWeek'] != null) {
          selectedDays = List<int>.from(auto['daysOfWeek']);
          selectedHour = auto['hour'] ?? 10;
          selectedMinute = auto['minute'] ?? 0;
        }
      }

      allClients = auto['allClients'] ?? true;
      selectedClients = List<String>.from(auto['targetClientIds'] ?? []);

      selectedActionType = existingAction?['type'] ?? 'SEND_CHAT';
      // Handle template ID which might be an object or string
      selectedTemplateId = (existingAction?['templateId'] is Map)
          ? existingAction['templateId']['_id']?.toString()
          : existingAction?['templateId']?.toString();

      if (selectedActionType == 'SEND_SHOPPING_LIST') {
        _shoppingListPeriod =
            existingAction?['metadata']?['periodo'] ?? 'semanal';
        _shoppingListChannel =
            existingAction?['metadata']?['channel'] ?? 'CHAT';
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    delayController.dispose();
    contentOverrideController.dispose();
    taskDueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Enhanced Header
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.7),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.automation == null
                            ? 'Nueva Automatización'
                            : 'Editar Automatización',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Configura reglas para automatizar tu flujo de trabajo',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name Field
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Nombre de la automatización',
                      hintText: 'Ej: Bienvenida a nuevos clientes',
                      prefixIcon: const Icon(Icons.label_outline_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Type Section
                  Row(
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 20,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tipo de Automatización:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
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
                        setState(() => selectedType = val.first),
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
                    const SizedBox(height: 8),
                    // Grouped trigger selector
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Clientes
                          _buildTriggerCategory('👤 Clientes', [
                            'CLIENT_REGISTERED',
                          ]),
                          Divider(height: 1, color: Colors.grey.shade300),
                          // Presupuestos
                          _buildTriggerCategory('💰 Presupuestos', [
                            'BUDGET_CREATED',
                            'BUDGET_ACCEPTED',
                            'BUDGET_REJECTED',
                            'BUDGET_PAID',
                          ]),
                          Divider(height: 1, color: Colors.grey.shade300),
                          // Citas
                          _buildTriggerCategory('📅 Citas', [
                            'APPOINTMENT_CREATED',
                            'APPOINTMENT_CONFIRMED',
                            'APPOINTMENT_CANCELLED',
                            'APPOINTMENT_MISSED',
                          ]),
                          Divider(height: 1, color: Colors.grey.shade300),
                          // Planes
                          _buildTriggerCategory('📋 Planes', [
                            'DIET_ASSIGNED',
                            'WORKOUT_ASSIGNED',
                          ]),
                          Divider(height: 1, color: Colors.grey.shade300),
                          // Actividad
                          _buildTriggerCategory('⚡ Actividad del Cliente', [
                            'PROGRESS_RECORDED', // Equivalent to WEIGHT_LOGGED for now, or distinguish? Let's add WEIGHT_LOGGED separately if specific.
                            'WEIGHT_LOGGED',
                            'WORKOUT_COMPLETED',
                            'INACTIVE_7_DAYS',
                          ]),
                          Divider(height: 1, color: Colors.grey.shade300),
                          _buildTriggerCategory('📅 Fechas Especiales', [
                            'PLAN_EXPIRED',
                            'BIRTHDAY',
                          ]),
                        ],
                      ),
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
                            setState(() {
                              if (val) {
                                selectedDays.add(i);
                              } else {
                                selectedDays.remove(i);
                              }
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
                        title: Text(
                          '${selectedDate.toLocal()}'.substring(0, 16),
                        ),
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
                              setState(
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
                            setState(() {
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
                      onChanged: (val) => setState(() => allClients = val!),
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
                          itemCount: widget.clients.length,
                          itemBuilder: (ctx, i) {
                            final c = widget.clients[i];
                            final isSelected = selectedClients.contains(
                              c['_id'],
                            );
                            return CheckboxListTile(
                              dense: true,
                              title: Text(c['nombre'] ?? 'Sin nombre'),
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    selectedClients.add(c['_id']);
                                  } else {
                                    selectedClients.remove(c['_id']);
                                  }
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
                  const SizedBox(height: 12),
                  // Grid of action types (3 columns x 2 rows)
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: [
                      ActionChoiceChip(
                        label: 'Chat',
                        icon: Icons.chat_bubble_rounded,
                        selected: selectedActionType == 'SEND_CHAT',
                        customColor: Colors.blue,
                        onSelected: (val) => setState(() {
                          selectedActionType = 'SEND_CHAT';
                          final isStillValid = widget.templates.any(
                            (t) =>
                                t['_id'].toString() == selectedTemplateId &&
                                t['type'] == 'chat',
                          );
                          if (!isStillValid) selectedTemplateId = null;
                        }),
                      ),
                      ActionChoiceChip(
                        label: 'Email',
                        icon: Icons.alternate_email_rounded,
                        selected: selectedActionType == 'SEND_EMAIL',
                        customColor: Colors.green,
                        onSelected: (val) => setState(() {
                          selectedActionType = 'SEND_EMAIL';
                          final isStillValid = widget.templates.any(
                            (t) =>
                                t['_id'].toString() == selectedTemplateId &&
                                t['type'] == 'email',
                          );
                          if (!isStillValid) selectedTemplateId = null;
                        }),
                      ),
                      ActionChoiceChip(
                        label: 'Tarea',
                        icon: Icons.task_alt_rounded,
                        selected: selectedActionType == 'CREATE_TASK',
                        customColor: Colors.orange,
                        onSelected: (val) => setState(() {
                          selectedActionType = 'CREATE_TASK';
                          selectedTemplateId = null;
                        }),
                      ),
                      ActionChoiceChip(
                        label: 'Push',
                        icon: Icons.notifications_active_rounded,
                        selected:
                            selectedActionType == 'SEND_PUSH_NOTIFICATION',
                        customColor: Colors.purple,
                        onSelected: (val) => setState(() {
                          selectedActionType = 'SEND_PUSH_NOTIFICATION';
                          selectedTemplateId = null;
                        }),
                      ),
                      ActionChoiceChip(
                        label: 'Etiqueta',
                        icon: Icons.label_rounded,
                        selected: selectedActionType == 'ADD_TAG',
                        customColor: Colors.teal,
                        onSelected: (val) => setState(() {
                          selectedActionType = 'ADD_TAG';
                          selectedTemplateId = null;
                        }),
                      ),
                      ActionChoiceChip(
                        label: 'SMS',
                        icon: Icons.sms_rounded,
                        selected: selectedActionType == 'SEND_SMS',
                        customColor: Colors.red,
                        onSelected: (val) => setState(() {
                          selectedActionType = 'SEND_SMS';
                          selectedTemplateId = null;
                        }),
                      ),
                      ActionChoiceChip(
                        label: 'Lista Compra',
                        icon: Icons.shopping_basket_rounded,
                        selected: selectedActionType == 'SEND_SHOPPING_LIST',
                        customColor: Colors.amber,
                        onSelected: (val) => setState(() {
                          selectedActionType = 'SEND_SHOPPING_LIST';
                          selectedTemplateId = null;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Dynamic configuration based on action type
                  if (selectedActionType == 'SEND_CHAT' ||
                      selectedActionType == 'SEND_EMAIL') ...[
                    const Text(
                      'Usar Plantilla:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    InkWell(
                      onTap: () => _showTemplateSelector(
                        contentOverrideController,
                        (val) {
                          setState(() {
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
                                    : widget.templates.firstWhere(
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
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey,
                            ),
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
                            widget.onSave(); // Refresh data using the callback
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
                              widget.templates.firstWhere(
                                    (t) =>
                                        t['_id'].toString() ==
                                        selectedTemplateId,
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
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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
                                onTap: _insertVariable,
                              ),
                              _VariableInfo(
                                variable: '{{cliente_email}}',
                                description: 'Correo electrónico',
                                onTap: _insertVariable,
                              ),
                              _VariableInfo(
                                variable: '{{cliente_telefono}}',
                                description: 'Teléfono',
                                onTap: _insertVariable,
                              ),
                              _VariableInfo(
                                variable: '{{tarifa}}',
                                description: 'Tarifa actual',
                                onTap: _insertVariable,
                              ),
                              _VariableInfo(
                                variable: '{{fecha}}',
                                description: 'Fecha de envío',
                                onTap: _insertVariable,
                              ),
                              _VariableInfo(
                                variable: '{{hora}}',
                                description: 'Hora de envío',
                                onTap: _insertVariable,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],

                  // CREATE_TASK configuration
                  if (selectedActionType == 'CREATE_TASK') ...[
                    const Text(
                      'Configuración de Tarea:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentOverrideController,
                      decoration: const InputDecoration(
                        labelText: 'Título de la tarea',
                        hintText: 'Ej: Revisar progreso del cliente',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: taskDueDateController,
                      decoration: const InputDecoration(
                        labelText: 'Fecha de vencimiento (opcional)',
                        hintText: 'Ej: +3d (3 días después)',
                        prefixIcon: Icon(Icons.calendar_today_rounded),
                      ),
                    ),
                  ],

                  // ADD_TAG configuration
                  if (selectedActionType == 'ADD_TAG') ...[
                    const Text(
                      'Configuración de Etiqueta:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentOverrideController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la etiqueta',
                        hintText: 'Ej: VIP, Nuevo, Inactivo',
                        prefixIcon: Icon(Icons.label_rounded),
                      ),
                    ),
                  ],

                  // SEND_SMS or SEND_PUSH_NOTIFICATION configuration
                  if (selectedActionType == 'SEND_SMS' ||
                      selectedActionType == 'SEND_PUSH_NOTIFICATION') ...[
                    Text(
                      selectedActionType == 'SEND_SMS'
                          ? 'Mensaje SMS:'
                          : 'Notificación Push:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentOverrideController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: selectedActionType == 'SEND_SMS'
                            ? 'Introduce el mensaje SMS...'
                            : 'Introduce el mensaje de notificación...',
                        prefixIcon: Icon(
                          selectedActionType == 'SEND_SMS'
                              ? Icons.sms_rounded
                              : Icons.notifications_rounded,
                        ),
                      ),
                    ),
                  ],

                  // SEND_SHOPPING_LIST configuration
                  if (selectedActionType == 'SEND_SHOPPING_LIST') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: Colors.amber[800],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Esta acción enviará la lista basada en la dieta actual.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber[900],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'FRECUENCIA:',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildOptionChip(
                                label: 'SEMANAL',
                                icon: Icons.calendar_view_week_rounded,
                                selected: _shoppingListPeriod == 'semanal',
                                color: Colors.amber,
                                onSelected: (val) => setState(
                                  () => _shoppingListPeriod = 'semanal',
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildOptionChip(
                                label: 'MENSUAL',
                                icon: Icons.calendar_month_rounded,
                                selected: _shoppingListPeriod == 'mensual',
                                color: Colors.amber,
                                onSelected: (val) => setState(
                                  () => _shoppingListPeriod = 'mensual',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'ENVIAR POR:',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildOptionChip(
                                label: 'CHAT',
                                icon: Icons.chat_bubble_rounded,
                                selected: _shoppingListChannel == 'CHAT',
                                color: Colors.blue,
                                onSelected: (val) => setState(
                                  () => _shoppingListChannel = 'CHAT',
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildOptionChip(
                                label: 'EMAIL',
                                icon: Icons.alternate_email_rounded,
                                selected: _shoppingListChannel == 'EMAIL',
                                color: Colors.green,
                                onSelected: (val) => setState(
                                  () => _shoppingListChannel = 'EMAIL',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

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
                      onPressed: _saveAutomation,
                      child: const Text('Guardar Automatización'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _insertVariable(String v) {
    final text = contentOverrideController.text;
    final selection = contentOverrideController.selection;
    final start = selection.start == -1 ? text.length : selection.start;
    final end = selection.end == -1 ? text.length : selection.end;

    final newText = text.replaceRange(start, end, v);
    contentOverrideController.text = newText;
    contentOverrideController.selection = TextSelection.collapsed(
      offset: start + v.length,
    );
  }

  Widget _buildTriggerCategory(String categoryTitle, List<String> triggers) {
    return ExpansionTile(
      title: Text(
        categoryTitle,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      children: triggers.map((trigger) {
        return RadioListTile<String>(
          title: Text(
            _getTriggerLabel(trigger),
            style: const TextStyle(fontSize: 13),
          ),
          value: trigger,
          groupValue: selectedTrigger,
          onChanged: (val) {
            if (val != null) {
              setState(() => selectedTrigger = val);
            }
          },
        );
      }).toList(),
    );
  }

  Future<void> _saveAutomation() async {
    if (nameController.text.isEmpty) return;

    final auth = Provider.of<AuthService>(context, listen: false);
    final action = {
      'type': selectedActionType,
      'templateId': selectedTemplateId,
      'contentOverride': contentOverrideController.text.isNotEmpty
          ? contentOverrideController.text
          : null,
      'delay': int.tryParse(delayController.text) ?? 0,
      'metadata': selectedActionType == 'CREATE_TASK'
          ? {'dueDate': taskDueDateController.text}
          : selectedActionType == 'SEND_SHOPPING_LIST'
          ? {'periodo': _shoppingListPeriod, 'channel': _shoppingListChannel}
          : {},
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
        data['scheduledDate'] = selectedDate.toIso8601String();
      } else {
        data['daysOfWeek'] = selectedDays;
        data['hour'] = selectedHour;
        data['minute'] = selectedMinute;
      }
    }

    try {
      if (widget.automation == null) {
        await _service.createAutomation(data);
      } else {
        await _service.updateAutomation(widget.automation!['_id'], data);
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSave();
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.showError(context, 'Error: $e');
    }
  }

  Future<void> _showTemplateSelector(
    TextEditingController contentCtrl,
    Function(String?) onSelect,
    String actionType,
  ) async {
    final typeFilter = actionType == 'SEND_EMAIL' ? 'email' : 'chat';
    final filtered = widget.templates
        .where((t) => t['type'] == typeFilter)
        .toList();

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
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Text(
                        t['content'] ?? '',
                        style: const TextStyle(height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          onSelect(t['_id']);
                          Navigator.pop(ctx);
                          Navigator.pop(ctx); // Close list as well
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Usar esta plantilla'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedContent(String content) {
    if (content.isEmpty) return const SizedBox.shrink();

    // Simple basic highlighter for variables {{...}}
    List<TextSpan> spans = [];
    RegExp exp = RegExp(r'\{\{.*?\}\}');
    int start = 0;

    for (Match m in exp.allMatches(content)) {
      if (m.start > start) {
        spans.add(
          TextSpan(
            text: content.substring(start, m.start),
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: m.group(0),
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
            backgroundColor: Color(0x1F2196F3),
            fontFamily: 'monospace',
          ),
        ),
      );
      start = m.end;
    }

    if (start < content.length) {
      spans.add(
        TextSpan(
          text: content.substring(start),
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  String _getTriggerLabel(String trigger) {
    switch (trigger) {
      // Clientes
      case 'CLIENT_REGISTERED':
        return 'Nuevo cliente registrado';

      // Presupuestos
      case 'BUDGET_CREATED':
        return 'Nuevo presupuesto creado';
      case 'BUDGET_ACCEPTED':
        return 'Presupuesto aceptado';
      case 'BUDGET_REJECTED':
        return 'Presupuesto rechazado';
      case 'BUDGET_PAID':
        return 'Presupuesto pagado';

      // Citas
      case 'APPOINTMENT_CREATED':
        return 'Nueva cita creada';
      case 'APPOINTMENT_CONFIRMED':
        return 'Cita confirmada';
      case 'APPOINTMENT_CANCELLED':
        return 'Cita cancelada';
      case 'APPOINTMENT_MISSED':
        return 'Cita perdida (no asistió)';

      // Planes
      case 'DIET_ASSIGNED':
        return 'Nueva dieta asignada';
      case 'WORKOUT_ASSIGNED':
        return 'Nueva rutina asignada';

      // Actividad
      case 'PROGRESS_RECORDED':
        return 'Cliente registró progreso (General)';
      case 'WEIGHT_LOGGED':
        return 'Cliente registró nuevo peso';
      case 'WORKOUT_COMPLETED':
        return 'Cliente completó entrenamiento';
      case 'INACTIVE_7_DAYS':
        return 'Inactivo por 7 días';

      // Fechas
      case 'PLAN_EXPIRED':
        return 'Plan (Tarifa) ha vencido';
      case 'BIRTHDAY':
        return 'Es el cumpleaños del cliente';

      default:
        return trigger.replaceAll('_', ' ').toLowerCase();
    }
  }

  Widget _buildOptionChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required ValueChanged<bool> onSelected,
  }) {
    return Expanded(
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : color,
              ),
            ),
          ],
        ),
        selected: selected,
        onSelected: onSelected,
        selectedColor: color,
        checkmarkColor: Colors.white,
        showCheckmark: false,
        backgroundColor: color.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? color : color.withOpacity(0.3)),
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
  final Color? customColor;

  const ActionChoiceChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = customColor ?? theme.primaryColor;

    return InkWell(
      onTap: () => onSelected(true),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? effectiveColor
              : (theme.brightness == Brightness.dark
                    ? Colors.white10
                    : Colors.grey[100]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? effectiveColor : Colors.transparent,
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
