import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/template_model.dart';
import '../../services/api_service.dart';
import '../../services/settings_service.dart';
import '../../services/template_service.dart';
import '../../models/settings_model.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  UserSettings? _settings;
  bool _loadingSettings = true;
  String _selectedCategory = 'Todas';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  final List<String> _categories = [
    'Todas',
    'General',
    'Dieta',
    'Entreno',
    'Seguimiento',
    'Cobros',
    'Otros',
  ];
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final settingsService = SettingsService(api);
    final templateService = Provider.of<TemplateService>(
      context,
      listen: false,
    );

    try {
      final results = await Future.wait([
        templateService.loadTemplates(),
        settingsService.getSettings(),
      ]);
      if (mounted) {
        setState(() {
          _settings = results[1] as UserSettings;
          _loadingSettings = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingSettings = false);
    }
  }

  void _showEditor([MessageTemplate? template]) {
    showDialog(
      context: context,
      builder: (context) => _TemplateEditorDialog(template: template),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<TemplateService>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter logic
    var filteredTemplates = service.templates;
    if (_selectedCategory != 'Todas') {
      filteredTemplates = filteredTemplates
          .where((t) => t.categories.contains(_selectedCategory))
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      filteredTemplates = filteredTemplates
          .where(
            (t) =>
                t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                t.content.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text(
          'Plantillas',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton:
          (_loadingSettings || !(_settings?.enabledTemplateManagement ?? true))
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva Plantilla'),
              backgroundColor: theme.primaryColor,
            ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Buscar por título o contenido...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCategory = cat);
                    },
                    selectedColor: theme.primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : theme.hintColor,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    backgroundColor: isDark ? Colors.white10 : Colors.white,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: service.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredTemplates.isEmpty
                ? _buildEmptyState(theme)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: filteredTemplates.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final t = filteredTemplates[index];
                      return _buildTemplateItem(t, theme, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 80,
            color: theme.hintColor.withOpacity(0.2),
          ),
          const SizedBox(height: 24),
          Text(
            'No hay plantillas creadas',
            style: TextStyle(
              color: theme.hintColor,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea una para ahorrar tiempo en tus mensajes',
            style: TextStyle(
              color: theme.hintColor.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateItem(MessageTemplate t, ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (_settings?.enabledTemplateManagement ?? true)
                ? () => _showEditor(t)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (t.type == 'email' ? Colors.blue : Colors.green)
                          .withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      t.type == 'email'
                          ? Icons.email_rounded
                          : Icons.chat_bubble_rounded,
                      color: t.type == 'email' ? Colors.blue : Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              t.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Wrap(
                              spacing: 4,
                              children: t.categories.map((cat) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    cat.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.subject ?? t.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_settings?.enabledTemplateManagement ?? true)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 22,
                      ),
                      onPressed: () => _confirmDelete(t),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(MessageTemplate t) async {
    final service = Provider.of<TemplateService>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar plantilla?'),
        content: Text('Se borrará la plantilla "${t.title}" permanentemente.'),
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
    if (confirm == true) {
      service.deleteTemplate(t.id);
    }
  }
}

class _TemplateEditorDialog extends StatefulWidget {
  final MessageTemplate? template;
  const _TemplateEditorDialog({this.template});

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  String _type = 'email'; // email, chat
  List<String> _selectedCategories = ['General'];

  final List<String> _categories = [
    'General',
    'Dieta',
    'Entreno',
    'Seguimiento',
    'Cobros',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      final t = widget.template!;
      _titleCtrl.text = t.title;
      _type = t.type;
      _subjectCtrl.text = t.subject ?? '';
      _contentCtrl.text = t.content;
      _selectedCategories = List<String>.from(t.categories);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subjectCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final service = Provider.of<TemplateService>(context, listen: false);
    final data = {
      'title': _titleCtrl.text.trim(),
      'type': _type,
      'subject': _type == 'email' || _type == 'both'
          ? _subjectCtrl.text.trim()
          : null,
      'content': _contentCtrl.text.trim(),
      'categories': _selectedCategories,
    };

    if (widget.template == null) {
      final t = MessageTemplate(
        id: '', // Dummy, backend ignores
        title: data['title'] as String,
        type: data['type'] as String,
        subject: data['subject'] as String?,
        content: data['content'] as String,
        categories: List<String>.from(data['categories'] as List),
      );
      await service.createTemplate(t);
    } else {
      await service.updateTemplate(widget.template!.id, data);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 550,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // GRADIENT HEADER
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.primaryColor,
                        theme.primaryColor.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.template == null
                            ? 'Nueva Plantilla'
                            : 'Editar Plantilla',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white10,
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TYPE SELECTOR
                      const Text(
                        'Tipo de plantilla',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildTypeButton(
                            'email',
                            Icons.email_outlined,
                            'Email',
                          ),
                          const SizedBox(width: 12),
                          _buildTypeButton(
                            'chat',
                            Icons.chat_bubble_outline_rounded,
                            'Chat',
                          ),
                          const SizedBox(width: 12),
                          _buildTypeButton(
                            'both',
                            Icons.layers_outlined,
                            'Ambos',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      _buildTextField(
                        controller: _titleCtrl,
                        label: 'Título interno',
                        hint: 'Ej: Bienvenida Clientes',
                        icon: Icons.title_rounded,
                      ),
                      if (_type == 'email' || _type == 'both') ...[
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _subjectCtrl,
                          label: 'Asunto del Email',
                          hint: 'El asunto que verá el cliente',
                          icon: Icons.subject_rounded,
                        ),
                      ],
                      const SizedBox(height: 24),
                      // CATEGORY SELECTOR
                      const Text(
                        'Categoría',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((cat) {
                          final isSelected = _selectedCategories.contains(cat);
                          return ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedCategories.add(cat);
                                } else {
                                  if (_selectedCategories.length > 1) {
                                    _selectedCategories.remove(cat);
                                  }
                                }
                              });
                            },
                            selectedColor: theme.primaryColor,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : theme.hintColor,
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Contenido del mensaje',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          // Placeholders Toolbar
                          Row(
                            children: [
                              _buildPlaceholderBadge('{{nombre}}'),
                              const SizedBox(width: 4),
                              _buildPlaceholderBadge('{{fecha}}'),
                              const SizedBox(width: 4),
                              _buildPlaceholderBadge('{{empresa}}'),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _contentCtrl,
                        label: '',
                        hint: 'Escribe aquí tu mensaje...',
                        icon: Icons.message_rounded,
                        maxLines: 6,
                        showLabel: false,
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: theme.primaryColor.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Guardar Plantilla',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String value, IconData icon, String label) {
    final isSelected = _type == value;
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _type = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? theme.primaryColor : theme.dividerColor,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? theme.primaryColor : theme.hintColor,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? theme.primaryColor : theme.hintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderBadge(String tag) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        final text = _contentCtrl.text;
        final selection = _contentCtrl.selection;
        final newText = text.replaceRange(
          selection.start == -1 ? text.length : selection.start,
          selection.end == -1 ? text.length : selection.end,
          tag,
        );
        _contentCtrl.text = newText;
        _contentCtrl.selection = TextSelection.collapsed(
          offset:
              (selection.start == -1 ? text.length : selection.start) +
              tag.length,
        );
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: theme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
        ),
        child: Text(
          tag,
          style: TextStyle(
            fontSize: 10,
            color: theme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool showLabel = true,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          validator: (v) =>
              v == null || v.isEmpty ? 'Este campo es requerido' : null,
        ),
      ],
    );
  }
}
