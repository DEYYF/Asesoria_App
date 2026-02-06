import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/automation_service.dart';
import '../../services/api_service.dart';
import '../../utils/notification_helper.dart';
import 'automation/components/automation_header.dart';
import 'automation/components/trigger_selector.dart';
import 'automation/components/action_configurator.dart';
import 'automation/components/schedule_configurator.dart';
import 'automation/components/template_selector_sheet.dart';

class AutomationFormSheet extends StatefulWidget {
  final Map<String, dynamic>? automation;
  final Function() onSave;
  final List<dynamic> templates;
  final List<dynamic> clients;

  const AutomationFormSheet({
    super.key,
    this.automation,
    required this.onSave,
    required this.templates,
    required this.clients,
  });

  @override
  State<AutomationFormSheet> createState() => _AutomationFormSheetState();
}

class _AutomationFormSheetState extends State<AutomationFormSheet> {
  late AutomationService _service;
  final nameController = TextEditingController();
  final delayController = TextEditingController();

  // SCHEDULE controllers
  DateTime selectedDate = DateTime.now();
  int selectedHour = 9;
  int selectedMinute = 0;
  List<int> selectedDays = [];

  // EVENT controllers
  String selectedTrigger = 'NEW_DIET_ASSIGNED';

  // ACTION controllers
  String selectedActionType = 'SEND_CHAT';
  String? selectedTemplateId;
  final contentOverrideController = TextEditingController();
  final taskDueDateController = TextEditingController();

  List<Map<String, dynamic>> selectedButtons = [];
  String _shoppingListPeriod = 'semanal';
  String _shoppingListChannel = 'CHAT';

  // State variables for conditions, clients, etc.
  String selectedType = 'EVENT';
  bool allClients = true;
  List<String> selectedClients = [];
  List<Map<String, dynamic>> selectedConditions = [];

  String? _selectedAdvisorId;

  @override
  void initState() {
    super.initState();
    _service = AutomationService(
      Provider.of<ApiService>(context, listen: false),
    );
    _loadInitialData();
  }

  void _loadInitialData() {
    if (widget.automation != null) {
      final auto = widget.automation!;
      nameController.text = auto['name'] ?? '';
      selectedType = auto['type'] ?? 'EVENT';

      // Load actions
      if (auto['actions'] != null && (auto['actions'] as List).isNotEmpty) {
        final action = auto['actions'][0];
        selectedActionType = action['type'] ?? 'SEND_CHAT';
        selectedTemplateId = action['templateId'] is Map
            ? action['templateId']['_id']
            : action['templateId'];

        contentOverrideController.text = action['contentOverride'] ?? '';
        delayController.text = (action['delay'] ?? 0).toString();

        if (action['buttons'] != null) {
          selectedButtons = List<Map<String, dynamic>>.from(
            (action['buttons'] as List).map(
              (x) => Map<String, dynamic>.from(x),
            ),
          );
        }

        if (action['metadata'] != null) {
          final meta = action['metadata'];
          if (meta['dueDate'] != null)
            taskDueDateController.text = meta['dueDate'];
          if (meta['periodo'] != null) _shoppingListPeriod = meta['periodo'];
          if (meta['channel'] != null) _shoppingListChannel = meta['channel'];
        }
      }

      if (selectedType == 'EVENT') {
        selectedTrigger = auto['trigger'] ?? 'NEW_DIET_ASSIGNED';
      } else if (selectedType == 'SCHEDULE') {
        if (auto['scheduledDate'] != null) {
          selectedDate = DateTime.parse(auto['scheduledDate']);
        }
        if (auto['daysOfWeek'] != null) {
          selectedDays = List<int>.from(auto['daysOfWeek']);
        }
        selectedHour = auto['hour'] ?? 9;
        selectedMinute = auto['minute'] ?? 0;
      }

      allClients = auto['allClients'] ?? true;
      selectedClients = List<String>.from(auto['targetClientIds'] ?? []);
      _selectedAdvisorId = auto['advisorId'];
    } else {
      final auth = Provider.of<AuthService>(context, listen: false);
      _selectedAdvisorId = auth.userId;
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
          AutomationHeader(
            automation: widget.automation,
            onClose: () => Navigator.pop(context),
          ),

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
                      hintText: 'Ej: Bienvenida nuevo cliente',
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.label_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Event Type Selector
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        _buildTypeSegment('Eventos', 'EVENT'),
                        _buildTypeSegment('Programado', 'SCHEDULE'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (selectedType == 'EVENT') ...[
                    const Text(
                      'DISPARADOR:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: TriggerSelector(
                        selectedTrigger: selectedTrigger,
                        onTriggerChanged: (val) =>
                            setState(() => selectedTrigger = val),
                      ),
                    ),
                  ] else ...[
                    ScheduleConfigurator(
                      selectedDate: selectedDate,
                      onDateChanged: (val) =>
                          setState(() => selectedDate = val),
                      selectedHour: selectedHour,
                      selectedMinute: selectedMinute,
                      onTimeChanged: (h, m) => setState(() {
                        selectedHour = h;
                        selectedMinute = m;
                      }),
                      selectedDays: selectedDays,
                      onDaysChanged: (val) =>
                          setState(() => selectedDays = val),
                    ),
                  ],

                  const SizedBox(height: 24),
                  // Client Selection Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          title: const Text(
                            'Aplicar a todos los clientes',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            allClients
                                ? 'La regla se ejecutará para cualquier cliente'
                                : 'Selecciona clientes específicos',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          value: allClients,
                          onChanged: (val) => setState(() => allClients = val),
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (!allClients) ...[
                          const Divider(),
                          const Text(
                            'Clientes Seleccionados:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.clients.map((client) {
                              final isSelected = selectedClients.contains(
                                client['_id'],
                              );
                              return FilterChip(
                                label: Text(client['nombre'] ?? 'Sin nombre'),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      selectedClients.add(client['_id']);
                                    } else {
                                      selectedClients.remove(client['_id']);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'ACCIÓN:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action Type Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedActionType,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'SEND_CHAT',
                            child: Text('Enviar Mensaje de Chat'),
                          ),
                          DropdownMenuItem(
                            value: 'SEND_EMAIL',
                            child: Text('Enviar Email'),
                          ),
                          DropdownMenuItem(
                            value: 'CREATE_TASK',
                            child: Text('Crear Tarea'),
                          ),
                          DropdownMenuItem(
                            value: 'ADD_TAG',
                            child: Text('Añadir Etiqueta'),
                          ),
                          DropdownMenuItem(
                            value: 'SEND_SMS',
                            child: Text('Enviar SMS'),
                          ),
                          DropdownMenuItem(
                            value: 'SEND_PUSH_NOTIFICATION',
                            child: Text('Enviar Notificación Push'),
                          ),
                          DropdownMenuItem(
                            value: 'SEND_SHOPPING_LIST',
                            child: Text('Enviar Lista de Compra'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null)
                            setState(() => selectedActionType = val);
                        },
                      ),
                    ),
                  ),

                  ActionConfigurator(
                    selectedActionType: selectedActionType,
                    contentOverrideController: contentOverrideController,
                    taskDueDateController: taskDueDateController,
                    delayController: delayController,
                    selectedButtons: selectedButtons,
                    onButtonsChanged: (val) =>
                        setState(() => selectedButtons = val),
                    shoppingListPeriod: _shoppingListPeriod,
                    onShoppingListPeriodChanged: (val) =>
                        setState(() => _shoppingListPeriod = val),
                    shoppingListChannel: _shoppingListChannel,
                    onShoppingListChannelChanged: (val) =>
                        setState(() => _shoppingListChannel = val),
                    onInsertVariable: _insertVariable,
                    onShowTemplateSelector: _showTemplateSelector,
                  ),

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveAutomation,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Guardar Automatización',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSegment(String label, String value) {
    final isSelected = selectedType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey,
            ),
          ),
        ),
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

  void _showTemplateSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TemplateSelectorSheet(
        templates: widget.templates,
        actionType: selectedActionType,
        onSelect: (template) {
          setState(() {
            if (template != null) {
              selectedTemplateId = template['_id'];
              contentOverrideController.text = template['content'] ?? '';
            } else {
              selectedTemplateId = null;
              // Don't clear content if existing, or maybe clear?
              // Usually "manual" implies typing scratch, but let's leave existing
            }
          });
        },
      ),
    );
  }

  Future<void> _saveAutomation() async {
    if (nameController.text.isEmpty) return;

    final action = {
      'type': selectedActionType,
      'templateId': selectedTemplateId,
      'contentOverride': contentOverrideController.text.isNotEmpty
          ? contentOverrideController.text
          : null,
      'delay': int.tryParse(delayController.text) ?? 0,
      'buttons': selectedActionType == 'SEND_CHAT' ? selectedButtons : [],
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
      'conditions': selectedConditions,
      'actions': [action],
      'advisorId': _selectedAdvisorId,
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
}
