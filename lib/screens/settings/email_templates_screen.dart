import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/settings_model.dart';
import '../../providers/settings_provider.dart';
import '../../utils/notification_helper.dart';

class EmailTemplatesScreen extends StatefulWidget {
  const EmailTemplatesScreen({super.key});

  @override
  State<EmailTemplatesScreen> createState() => _EmailTemplatesScreenState();
}

class _EmailTemplatesScreenState extends State<EmailTemplatesScreen> {
  // Types: citaCreated, citaUpdated, citaReminder
  Map<String, EmailTemplateConfig> _drafts = {};
  bool _isLoading = false;

  final Map<String, String> _templateTitanles = {
    'citaCreated': 'Nueva Cita',
    'citaUpdated': 'Cita Modificada',
    'citaReminder': 'Recordatorio de Cita',
  };

  final Map<String, String> _templateDescriptions = {
    'citaCreated': 'Enviado al cliente cuando creas una cita.',
    'citaUpdated': 'Enviado cuando modificas una cita existente.',
    'citaReminder': 'Enviado automáticamente (hoy/mañana) según configuración.',
  };

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  void _loadTemplates() {
    final settings = Provider.of<SettingsProvider>(
      context,
      listen: false,
    ).settings;

    // Initialize drafts from settings or defaults
    if (settings != null) {
      _drafts = Map.from(settings.emailTemplates);
    } else {
      _drafts = {};
    }

    // Default templates to use if not configured
    final defaults = {
      'citaCreated': EmailTemplateConfig(
        subject: 'Nueva Cita Agendada',
        body:
            'Hola {{clienteNombre}},\n\nSe ha agendado una nueva cita:\n\nTítulo: {{titulo}}\nFecha: {{fecha}}\nHora: {{hora}}\n\nSaludos,\n{{asesorNombre}}',
        enabled: true,
      ),
      'citaUpdated': EmailTemplateConfig(
        subject: 'Cita Modificada',
        body:
            'Hola {{clienteNombre}},\n\nTu cita ha sido modificada:\n\nTítulo: {{titulo}}\nNueva Fecha: {{fecha}}\nNueva Hora: {{hora}}\n\nSaludos,\n{{asesorNombre}}',
        enabled: true,
      ),
      'citaReminder': EmailTemplateConfig(
        subject: 'Recordatorio de Cita',
        body:
            'Hola {{clienteNombre}},\n\nRecuerda que tienes una cita programada:\n\nTítulo: {{titulo}}\nFecha: {{fecha}}\nHora: {{hora}}\n\nTe esperamos.',
        enabled: true,
      ),
    };

    // Ensure all keys exist
    for (var key in _templateTitanles.keys) {
      if (!_drafts.containsKey(key)) {
        _drafts[key] =
            defaults[key] ??
            EmailTemplateConfig(subject: '', body: '', enabled: true);
      }
    }
    setState(() {});
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<SettingsProvider>(context, listen: false);

    if (provider.settings == null) {
      if (mounted)
        NotificationHelper.showError(context, 'Error: No settings loaded');
      setState(() => _isLoading = false);
      return;
    }

    final newSettings = provider.settings!.copyWith(emailTemplates: _drafts);

    try {
      await provider.updateSettings(newSettings);
      if (mounted) {
        NotificationHelper.showSuccess(
          context,
          'Plantillas guardadas correctamente',
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.showError(context, 'Error al guardar: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _editTemplate(String key) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateEditor(
          title: _templateTitanles[key]!,
          description: _templateDescriptions[key]!,
          initialConfig: _drafts[key]!,
          onSave: (newConfig) {
            setState(() {
              _drafts[key] = newConfig;
            });
            _saveChanges(); // Auto-save on exit/save from editor
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Plantillas de Correo'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: theme.textTheme.titleLarge?.color,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: theme.iconTheme,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildInfoCard(theme),
                const SizedBox(height: 24),
                ..._templateTitanles.keys.map((key) {
                  final config = _drafts[key];
                  return _buildTemplateTile(key, config!);
                }),
              ],
            ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: theme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Personaliza los correos automáticos. Usa variables como {{clienteNombre}}, {{fecha}}, {{hora}} para insertar datos dinámicos.',
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateTile(String key, EmailTemplateConfig config) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        onTap: () => _editTemplate(key),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: config.enabled
                ? theme.primaryColor.withOpacity(0.1)
                : theme.disabledColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mail_outline_rounded,
            color: config.enabled ? theme.primaryColor : theme.disabledColor,
          ),
        ),
        title: Text(
          _templateTitanles[key]!,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          config.enabled ? 'Activo' : 'Desactivado',
          style: TextStyle(
            color: config.enabled ? Colors.green : Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      ),
    );
  }
}

class TemplateEditor extends StatefulWidget {
  final String title;
  final String description;
  final EmailTemplateConfig initialConfig;
  final Function(EmailTemplateConfig) onSave;

  const TemplateEditor({
    super.key,
    required this.title,
    required this.description,
    required this.initialConfig,
    required this.onSave,
  });

  @override
  State<TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<TemplateEditor> {
  late TextEditingController _subjectCtrl;
  late TextEditingController _bodyCtrl;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _subjectCtrl = TextEditingController(text: widget.initialConfig.subject);
    _bodyCtrl = TextEditingController(text: widget.initialConfig.body);
    _enabled = widget.initialConfig.enabled;
  }

  void _insertVariable(String variable) {
    final text = '{{$variable}}';
    final selection = _bodyCtrl.selection;
    if (selection.isValid) {
      final newText = _bodyCtrl.text.replaceRange(
        selection.start,
        selection.end,
        text,
      );
      _bodyCtrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + text.length,
        ),
      );
    } else {
      _bodyCtrl.text += text;
    }
  }

  void _save() {
    widget.onSave(
      EmailTemplateConfig(
        subject: _subjectCtrl.text,
        body: _bodyCtrl.text,
        enabled: _enabled,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: theme.textTheme.titleLarge?.color,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: theme.iconTheme,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded),
            onPressed: _save,
            color: theme.primaryColor,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enable Switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Activar Envío Automático',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                value: _enabled,
                onChanged: (val) => setState(() => _enabled = val),
                activeColor: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Asunto',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _subjectCtrl,
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Contenido',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyCtrl,
              maxLines: 12,
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Variables Disponibles',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildVariableChip('clienteNombre', theme),
                _buildVariableChip('asesorNombre', theme),
                _buildVariableChip('titulo', theme),
                _buildVariableChip('fecha', theme),
                _buildVariableChip('hora', theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariableChip(String label, ThemeData theme) {
    return ActionChip(
      label: Text(
        '{{$label}}',
        style: TextStyle(
          color: theme.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      backgroundColor: theme.primaryColor.withOpacity(0.1),
      onPressed: () => _insertVariable(label),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.primaryColor.withOpacity(0.2)),
      ),
    );
  }
}
