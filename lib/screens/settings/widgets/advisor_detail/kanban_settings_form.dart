import 'package:flutter/material.dart';

class KanbanSettingsForm extends StatefulWidget {
  final Map<String, dynamic> settings;
  final Function(List<dynamic>) onColumnsUpdated;

  const KanbanSettingsForm({
    super.key,
    required this.settings,
    required this.onColumnsUpdated,
  });

  @override
  State<KanbanSettingsForm> createState() => _KanbanSettingsFormState();
}

class _KanbanSettingsFormState extends State<KanbanSettingsForm> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    List<dynamic> columns = widget.settings['kanbanColumns'] ?? [];

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (oldIndex < newIndex) newIndex -= 1;
            final item = columns.removeAt(oldIndex);
            columns.insert(newIndex, item);
            for (int i = 0; i < columns.length; i++) {
              columns[i]['order'] = i;
            }
            widget.onColumnsUpdated(columns);
          });
        },
        children: [
          for (final col in columns)
            ListTile(
              key: ValueKey(col['id']),
              title: Text(col['title'] ?? ''),
              leading: Icon(
                Icons.circle,
                color: _getColor(col['color']),
                size: 16,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editKanbanColumn(col),
              ),
            ),
        ],
      ),
    );
  }

  Color _getColor(String? colorName) {
    switch (colorName) {
      case 'orange':
        return Colors.orange;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'red':
        return Colors.red;
      case 'purple':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _editKanbanColumn(Map<String, dynamic> column) {
    TextEditingController titleCtrl = TextEditingController(
      text: column['title'],
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Columna'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: column['color'],
              decoration: const InputDecoration(labelText: 'Color'),
              items: const [
                DropdownMenuItem(value: 'orange', child: Text('Naranja')),
                DropdownMenuItem(value: 'blue', child: Text('Azul')),
                DropdownMenuItem(value: 'green', child: Text('Verde')),
                DropdownMenuItem(value: 'red', child: Text('Rojo')),
                DropdownMenuItem(value: 'purple', child: Text('Morado')),
              ],
              onChanged: (v) {
                setState(() => column['color'] = v);
                Navigator.pop(context);
                _editKanbanColumn(column);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => column['title'] = titleCtrl.text);
              Navigator.pop(context);
              widget.onColumnsUpdated(widget.settings['kanbanColumns']);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
