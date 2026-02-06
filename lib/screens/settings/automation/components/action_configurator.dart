import 'package:flutter/material.dart';
import 'automation_ui_helpers.dart';

class ActionConfigurator extends StatelessWidget {
  final String selectedActionType;
  final TextEditingController contentOverrideController;
  final TextEditingController taskDueDateController;
  final TextEditingController delayController;
  final List<Map<String, dynamic>> selectedButtons;
  final ValueChanged<List<Map<String, dynamic>>> onButtonsChanged;
  final String shoppingListPeriod;
  final ValueChanged<String> onShoppingListPeriodChanged;
  final String shoppingListChannel;
  final ValueChanged<String> onShoppingListChannelChanged;
  final Function(String) onInsertVariable;
  final VoidCallback onShowTemplateSelector;

  const ActionConfigurator({
    super.key,
    required this.selectedActionType,
    required this.contentOverrideController,
    required this.taskDueDateController,
    required this.delayController,
    required this.selectedButtons,
    required this.onButtonsChanged,
    required this.shoppingListPeriod,
    required this.onShoppingListPeriodChanged,
    required this.shoppingListChannel,
    required this.onShoppingListChannelChanged,
    required this.onInsertVariable,
    required this.onShowTemplateSelector,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SEND_CHAT configuration
        if (selectedActionType == 'SEND_CHAT') ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onShowTemplateSelector,
              icon: const Icon(Icons.description_outlined),
              label: const Text('Seleccionar Plantilla de Chat'),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Variables disponibles:',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Scrollbar(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  AutomationVariableInfo(
                    variable: '{{nombre_cliente}}',
                    description: 'Nombre del cliente',
                    onTap: onInsertVariable,
                  ),
                  AutomationVariableInfo(
                    variable: '{{peso_actual}}',
                    description: 'Último peso registrado',
                    onTap: onInsertVariable,
                  ),
                  AutomationVariableInfo(
                    variable: '{{peso_inicial}}',
                    description: 'Peso al iniciar',
                    onTap: onInsertVariable,
                  ),
                  AutomationVariableInfo(
                    variable: '{{peso_perdido_total}}',
                    description: 'Kg totales perdidos',
                    onTap: onInsertVariable,
                  ),
                  AutomationVariableInfo(
                    variable: '{{objetivo_actual}}',
                    description: 'Objetivo dieta',
                    onTap: onInsertVariable,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.smart_button_rounded,
                size: 16,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              const Text(
                'Botones Interactivos',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  final newButtons = List<Map<String, dynamic>>.from(
                    selectedButtons,
                  );
                  newButtons.add({'text': 'Nuevo Botón', 'action': 'CUSTOM'});
                  onButtonsChanged(newButtons);
                },
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text('Añadir', style: TextStyle(fontSize: 10)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ],
          ),

          if (selectedButtons.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: Column(
                  children: [
                    InkWell(
                      onTap: () {
                        final newButtons = List<Map<String, dynamic>>.from(
                          selectedButtons,
                        );
                        newButtons.add({
                          'text': 'Registrar Medidas',
                          'action': 'OPEN_MEASUREMENTS_DIALOG',
                        });
                        onButtonsChanged(newButtons);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.2),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_task_rounded,
                              size: 16,
                              color: Colors.blue,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Sugerencia: "Registrar Medidas"',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'O sugerencias rápidas:',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        AutomationQuickButton(
                          label: 'Registrar Hábitos',
                          icon: Icons.spa_rounded,
                          action: 'OPEN_HABITS_DIALOG',
                          color: Colors.green,
                          onTap: () {
                            final newButtons = List<Map<String, dynamic>>.from(
                              selectedButtons,
                            );
                            newButtons.add({
                              'text': 'Registrar Hábitos',
                              'action': 'OPEN_HABITS_DIALOG',
                            });
                            onButtonsChanged(newButtons);
                          },
                        ),
                        AutomationQuickButton(
                          label: 'Ver Dieta',
                          icon: Icons.restaurant_menu_rounded,
                          action: 'NAVIGATE_TO_DIET',
                          color: Colors.orange,
                          onTap: () {
                            final newButtons = List<Map<String, dynamic>>.from(
                              selectedButtons,
                            );
                            newButtons.add({
                              'text': 'Ver Dieta',
                              'action': 'NAVIGATE_TO_DIET',
                            });
                            onButtonsChanged(newButtons);
                          },
                        ),
                        AutomationQuickButton(
                          label: 'Ver Entreno',
                          icon: Icons.fitness_center_rounded,
                          action: 'NAVIGATE_TO_WORKOUT',
                          color: Colors.purple,
                          onTap: () {
                            final newButtons = List<Map<String, dynamic>>.from(
                              selectedButtons,
                            );
                            newButtons.add({
                              'text': 'Ver Entreno',
                              'action': 'NAVIGATE_TO_WORKOUT',
                            });
                            onButtonsChanged(newButtons);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: selectedButtons.asMap().entries.map((entry) {
                final idx = entry.key;
                final btn = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Texto del botón',
                                isDense: true,
                                contentPadding: EdgeInsets.all(8),
                              ),
                              initialValue: btn['text'],
                              onChanged: (val) {
                                selectedButtons[idx]['text'] = val;
                                // We don't verify here because we're mutating the map directly
                                // but ideally we should copy and update
                              },
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              final newButtons =
                                  List<Map<String, dynamic>>.from(
                                    selectedButtons,
                                  );
                              newButtons.removeAt(idx);
                              onButtonsChanged(newButtons);
                            },
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: btn['action'],
                        decoration: const InputDecoration(
                          labelText: 'Acción al pulsar',
                          isDense: true,
                          contentPadding: EdgeInsets.all(8),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'OPEN_MEASUREMENTS_DIALOG',
                            child: Text(
                              'Abrir Diálogo de Medidas',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'OPEN_HABITS_DIALOG',
                            child: Text(
                              'Abrir Diálogo de Hábitos',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'NAVIGATE_TO_DIET',
                            child: Text(
                              'Navegar a Dieta',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'NAVIGATE_TO_WORKOUT',
                            child: Text(
                              'Navegar a Entreno',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'CUSTOM',
                            child: Text(
                              'Acción Personalizada',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          selectedButtons[idx]['action'] = val;
                          // Trigger rebuild if necessary, though direct mutation usually works for textfields
                          onButtonsChanged(selectedButtons);
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],

        // CREATE_TASK configuration
        if (selectedActionType == 'CREATE_TASK') ...[
          const Text(
            'Configuración de Tarea:',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
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
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
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

        // SEND_EMAIL configuration
        if (selectedActionType == 'SEND_EMAIL') ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onShowTemplateSelector,
              icon: const Icon(Icons.email_outlined),
              label: const Text('Seleccionar Plantilla de Email'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contentOverrideController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Contenido del Email (o sobrescribir plantilla)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
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
              border: Border.all(color: Colors.amber.withOpacity(0.2)),
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
                    AutomationOptionChip(
                      label: 'SEMANAL',
                      icon: Icons.calendar_view_week_rounded,
                      selected: shoppingListPeriod == 'semanal',
                      color: Colors.amber,
                      onSelected: (val) =>
                          onShoppingListPeriodChanged('semanal'),
                    ),
                    const SizedBox(width: 8),
                    AutomationOptionChip(
                      label: 'MENSUAL',
                      icon: Icons.calendar_month_rounded,
                      selected: shoppingListPeriod == 'mensual',
                      color: Colors.amber,
                      onSelected: (val) =>
                          onShoppingListPeriodChanged('mensual'),
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
                    AutomationOptionChip(
                      label: 'CHAT',
                      icon: Icons.chat_bubble_rounded,
                      selected: shoppingListChannel == 'CHAT',
                      color: Colors.blue,
                      onSelected: (val) => onShoppingListChannelChanged('CHAT'),
                    ),
                    const SizedBox(width: 8),
                    AutomationOptionChip(
                      label: 'EMAIL',
                      icon: Icons.alternate_email_rounded,
                      selected: shoppingListChannel == 'EMAIL',
                      color: Colors.green,
                      onSelected: (val) =>
                          onShoppingListChannelChanged('EMAIL'),
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
      ],
    );
  }
}
