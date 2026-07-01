import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/dieta_model.dart';
import '../../models/macros_model.dart';
import '../../services/api_service.dart';

class MealTemplatesSettingsScreen extends StatefulWidget {
  const MealTemplatesSettingsScreen({super.key});

  @override
  State<MealTemplatesSettingsScreen> createState() => _MealTemplatesSettingsScreenState();
}

class _MealTemplatesSettingsScreenState extends State<MealTemplatesSettingsScreen> {
  bool _loading = true;
  String? _error;
  List<_MealTemplateEntry> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.get('/meal-templates', params: {'scope': 'global'});
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! List) throw Exception('Respuesta inválida del servidor');

      if (!mounted) return;
      setState(() {
        _templates = decoded
            .whereType<Map>()
            .map((item) => _MealTemplateEntry.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _editTemplate(_MealTemplateEntry template) async {
    final result = await showDialog<_TemplateEditResult>(
      context: context,
      builder: (_) => _TemplateEditDialog(template: template),
    );

    if (result == null) return;

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final body = {
        'nombre': result.nombre,
        'categoria': result.categoria,
        'scope': 'global',
        'comida': result.comida.toJson(),
      };

      final res = await api.put('/meal-templates/${template.id}', body);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final updated = _MealTemplateEntry.fromJson(jsonDecode(res.body));
      if (!mounted) return;
      setState(() {
        final index = _templates.indexWhere((item) => item.id == template.id);
        if (index != -1) _templates[index] = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plantilla actualizada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
    }
  }

  Future<void> _deleteTemplate(_MealTemplateEntry template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar plantilla'),
        content: Text('¿Quieres eliminar "${template.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.delete('/meal-templates/${template.id}');
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      if (!mounted) return;
      setState(() => _templates.removeWhere((item) => item.id == template.id));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plantilla eliminada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plantillas de comidas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loadTemplates,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 44),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadTemplates, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    if (_templates.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aún no tienes plantillas globales. Guárdalas desde una comida del calendario y aparecerán aquí.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _templates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final template = _templates[index];
        final macros = _calculateMealMacros(template.comida);
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: CircleAvatar(
              child: Text(template.nombre.isEmpty ? 'P' : template.nombre[0].toUpperCase()),
            ),
            title: Text(template.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${template.categoria} · ${template.comida.titulo} · ${template.comida.opciones.length} opción(es) · ${macros.kcal.round()} kcal',
              ),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _editTemplate(template);
                if (value == 'delete') _deleteTemplate(template);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
          ),
        );
      },
    );
  }

  Macros _calculateMealMacros(Comida meal) {
    double kcal = 0;
    double proteinas = 0;
    double carbohidratos = 0;
    double grasas = 0;
    for (final option in meal.opciones) {
      final macros = option.macrosTotales;
      if (macros == null) continue;
      kcal += macros.kcal;
      proteinas += macros.proteinas;
      carbohidratos += macros.carbohidratos;
      grasas += macros.grasas;
    }
    return Macros(kcal: kcal, proteinas: proteinas, carbohidratos: carbohidratos, grasas: grasas);
  }
}

class _TemplateEditDialog extends StatefulWidget {
  final _MealTemplateEntry template;

  const _TemplateEditDialog({required this.template});

  @override
  State<_TemplateEditDialog> createState() => _TemplateEditDialogState();
}

class _TemplateEditDialogState extends State<_TemplateEditDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _mealTitleCtrl;
  late final TextEditingController _timeCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.template.nombre);
    _categoryCtrl = TextEditingController(text: widget.template.categoria);
    _mealTitleCtrl = TextEditingController(text: widget.template.comida.titulo);
    _timeCtrl = TextEditingController(text: widget.template.comida.hora ?? '');
    _notesCtrl = TextEditingController(text: widget.template.comida.notas ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _mealTitleCtrl.dispose();
    _timeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final category = _categoryCtrl.text.trim().isEmpty ? 'General' : _categoryCtrl.text.trim();
    final mealTitle = _mealTitleCtrl.text.trim();
    if (name.isEmpty || mealTitle.isEmpty) return;

    final meal = widget.template.comida.copyWith(
      titulo: mealTitle,
      hora: _timeCtrl.text.trim().isEmpty ? null : _timeCtrl.text.trim(),
      notas: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    Navigator.pop(
      context,
      _TemplateEditResult(nombre: name, categoria: category, comida: meal),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar plantilla'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre de la plantilla'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(labelText: 'Categoría'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _mealTitleCtrl,
              decoration: const InputDecoration(labelText: 'Nombre de la comida'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _timeCtrl,
              decoration: const InputDecoration(labelText: 'Hora'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notas'),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            Text(
              'Los alimentos, recetas y combos de la plantilla se conservan. Para cambiar el contenido exacto, crea una nueva plantilla desde una comida editada.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

class _TemplateEditResult {
  final String nombre;
  final String categoria;
  final Comida comida;

  const _TemplateEditResult({
    required this.nombre,
    required this.categoria,
    required this.comida,
  });
}

class _MealTemplateEntry {
  final String id;
  final String nombre;
  final String categoria;
  final String scope;
  final Comida comida;

  const _MealTemplateEntry({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.scope,
    required this.comida,
  });

  factory _MealTemplateEntry.fromJson(Map<String, dynamic> json) {
    final comidaJson = json['comida'];
    return _MealTemplateEntry(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      nombre: json['nombre']?.toString() ?? 'Plantilla',
      categoria: json['categoria']?.toString() ?? 'General',
      scope: json['scope']?.toString() ?? 'global',
      comida: comidaJson is Map
          ? Comida.fromJson(Map<String, dynamic>.from(comidaJson))
          : Comida(titulo: 'Plantilla', opciones: const [], totales: Macros()),
    );
  }
}
