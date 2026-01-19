import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import 'dart:convert';

class AdvisorDetailScreen extends StatefulWidget {
  final String advisorId;
  const AdvisorDetailScreen({super.key, required this.advisorId});

  @override
  State<AdvisorDetailScreen> createState() => _AdvisorDetailScreenState();
}

class _AdvisorDetailScreenState extends State<AdvisorDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _advisor;
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers
  late TextEditingController _nombreController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _businessEmailController;
  late TextEditingController _emailSignatureController;
  late TextEditingController _signatureImageController;

  String _role = 'advisor';
  bool _passwordVisible = false;

  // Settings
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _calendarSettings = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _nombreController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _businessEmailController = TextEditingController();
    _emailSignatureController = TextEditingController();
    _signatureImageController = TextEditingController();
    _loadAdvisor();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _businessEmailController.dispose();
    _emailSignatureController.dispose();
    _signatureImageController.dispose();
    super.dispose();
  }

  Future<void> _loadAdvisor() async {
    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);

    try {
      final [advisorRes, statsRes] = await Future.wait([
        api.get('/users/${widget.advisorId}'),
        api.get('/users/${widget.advisorId}/stats'),
      ]);

      if (advisorRes.statusCode == 200) {
        final data = jsonDecode(advisorRes.body);
        setState(() {
          _advisor = data;
          _nombreController.text = data['nombre'] ?? '';
          _emailController.text = data['email'] ?? '';
          _passwordController.text = data['password'] ?? '';
          _role = data['role'] ?? 'advisor';
          _settings = data['settings'] ?? {};
          _businessEmailController.text = _settings['businessEmail'] ?? '';
          _emailSignatureController.text = _settings['emailSignature'] ?? '';
          _signatureImageController.text = _settings['signatureImageUrl'] ?? '';

          _calendarSettings =
              data['calendarSettings'] ??
              {
                'workHours': {'startHour': 7, 'endHour': 22},
                'bloques': [],
                'vacationDays': [],
              };

          // Ensure defaults for new settings
          _settings.putIfAbsent('pushNotifications', () => true);
          _settings.putIfAbsent('emailNotifications', () => true);
          _settings.putIfAbsent('signatureImageUrl', () => '');
          _settings.putIfAbsent('weightFrequency', () => 'weekly');
          _settings.putIfAbsent('fatFrequency', () => 'weekly');
          _settings.putIfAbsent('measuresFrequency', () => 'monthly');
          _settings.putIfAbsent('muscleFrequency', () => 'monthly');
          _settings.putIfAbsent('enabledProgressFrequencies', () => true);
          _settings.putIfAbsent(
            'kanbanColumns',
            () => [
              {
                'id': 'todo',
                'title': 'PENDIENTE',
                'color': 'orange',
                'order': 0,
              },
              {
                'id': 'doing',
                'title': 'EN PROGRESO',
                'color': 'blue',
                'order': 1,
              },
              {
                'id': 'done',
                'title': 'COMPLETADO',
                'color': 'green',
                'order': 2,
              },
            ],
          );
        });
      }

      if (statsRes.statusCode == 200) {
        setState(() => _stats = jsonDecode(statsRes.body));
      }
    } catch (e) {
      debugPrint('Error loading advisor: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveGeneral() async {
    setState(() => _isSaving = true);
    final api = Provider.of<ApiService>(context, listen: false);

    final data = {
      'nombre': _nombreController.text,
      'email': _emailController.text,
      'role': _role,
      'password': _passwordController.text,
    };

    try {
      await api.put('/users/${widget.advisorId}', data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Información general guardada')),
        );
        _loadAdvisor(); // Reload to update UI
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final api = Provider.of<ApiService>(context, listen: false);

    _settings['businessEmail'] = _businessEmailController.text;
    _settings['emailSignature'] = _emailSignatureController.text;
    _settings['signatureImageUrl'] = _signatureImageController.text;

    try {
      await api.put('/users/${widget.advisorId}', {'settings': _settings});
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Configuración guardada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveCalendar() async {
    setState(() => _isSaving = true);
    final api = Provider.of<ApiService>(context, listen: false);

    try {
      await api.put('/users/${widget.advisorId}', {
        'calendarSettings': _calendarSettings,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Calendario guardado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 320.0,
                    floating: false,
                    pinned: true,
                    elevation: 0,
                    backgroundColor: theme.scaffoldBackgroundColor,
                    surfaceTintColor: Colors.transparent,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isDark
                                ? [Colors.black, const Color(0xFF1C1C1E)]
                                : [Colors.white, const Color(0xFFF2F2F7)],
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.primaryColor.withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: theme.primaryColor,
                                child: Text(
                                  (_advisor?['nombre'] ?? '?')[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _advisor?['nombre'] ?? 'Sin Nombre',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (_advisor?['role'] == 'superadmin'
                                            ? Colors.purple
                                            : theme.primaryColor)
                                        .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _advisor?['role'] == 'superadmin'
                                    ? 'Super Admin'
                                    : 'Asesor',
                                style: TextStyle(
                                  color: _advisor?['role'] == 'superadmin'
                                      ? Colors.purple
                                      : theme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(48),
                      child: Container(
                        color: theme.scaffoldBackgroundColor,
                        child: TabBar(
                          controller: _tabController,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.normal,
                          ),
                          indicatorSize: TabBarIndicatorSize.label,
                          tabs: const [
                            Tab(text: 'General'),
                            Tab(text: 'Ajustes'),
                            Tab(text: 'Calendario'),
                            Tab(text: 'Stats'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildGeneralTab(theme),
                  _buildSettingsTab(theme),
                  _buildCalendarTab(theme),
                  _buildStatsTab(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.hintColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildGeneralTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(0),
      children: [
        _buildSectionHeader(theme, 'Información Personal'),
        _buildFormGroup(theme, [
          _buildTextField(
            theme,
            _nombreController,
            'Nombre Completo',
            Icons.person_outline,
          ),
          _buildTextField(
            theme,
            _emailController,
            'Email',
            Icons.email_outlined,
          ),
        ]),
        _buildSectionHeader(theme, 'Rol & Accesos'),
        _buildFormGroup(theme, [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(
                border: InputBorder.none,
                prefixIcon: Icon(Icons.badge_outlined),
                labelText: 'Rol del Sistema',
              ),
              items: const [
                DropdownMenuItem(value: 'advisor', child: Text('Asesor')),
                DropdownMenuItem(
                  value: 'superadmin',
                  child: Text('Super Admin'),
                ),
              ],
              onChanged: (v) => setState(() => _role = v!),
            ),
          ),
        ]),
        _buildSectionHeader(theme, 'Seguridad'),
        _buildFormGroup(theme, [
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Contraseña Actual',
              prefixIcon: const Icon(Icons.lock_outline),
              border: InputBorder.none,
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
              ),
            ),
            obscureText: !_passwordVisible,
          ),
        ]),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveGeneral,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Guardar Cambios'),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSettingsTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(0),
      children: [
        _buildSectionHeader(theme, 'Notificaciones'),
        _buildFormGroup(theme, [
          _buildSwitch('Push Notifications', 'pushNotifications'),
          _buildSwitch('Email Notifications', 'emailNotifications'),
        ]),
        _buildSectionHeader(theme, 'Apariencia'),
        _buildFormGroup(theme, [
          ListTile(
            title: const Text('Tema de la App'),
            trailing: DropdownButton<String>(
              value: _settings['theme'] ?? 'system',
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'light', child: Text('Claro')),
                DropdownMenuItem(value: 'dark', child: Text('Oscuro')),
                DropdownMenuItem(value: 'system', child: Text('Sistema')),
              ],
              onChanged: (v) => setState(() => _settings['theme'] = v),
            ),
          ),
          ListTile(
            title: const Text('Color de Acento'),
            subtitle: const Text('Hex code (ej. #007AFF)'),
            trailing: SizedBox(
              width: 100,
              child: TextField(
                controller: TextEditingController(
                  text: _settings['accentColor'] ?? '#007AFF',
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                textAlign: TextAlign.end,
                onChanged: (v) => _settings['accentColor'] = v,
              ),
            ),
          ),
        ]),
        _buildSectionHeader(theme, 'Módulos & Funcionalidades'),
        _buildFormGroup(theme, [
          _buildSwitch('Chat', 'enabledChat'),
          _buildSwitch('Email', 'enabledEmail'),
          _buildSwitch('Automatización', 'enabledAutomation'),
          _buildSwitch('Finanzas', 'enabledFinanzas'),
          _buildSwitch('Plantillas', 'enabledTemplateManagement'),
          _buildSwitch('Registro Entrenamiento', 'enabledTrainingLog'),
          _buildSwitch('Escáner de Comida', 'enabledFoodScanner'),
          _buildSwitch('Frecuencias de Progreso', 'enabledProgressFrequencies'),
        ]),
        if (_settings['enabledProgressFrequencies'] == true) ...[
          _buildSectionHeader(theme, 'Frecuencias de Progreso'),
          _buildFormGroup(theme, [
            _buildFrequencyDropdown('Peso', 'weightFrequency'),
            _buildFrequencyDropdown('Grasa', 'fatFrequency'),
            _buildFrequencyDropdown('Medidas', 'measuresFrequency'),
            _buildFrequencyDropdown('Músculo', 'muscleFrequency'),
          ]),
        ],
        _buildSectionHeader(theme, 'Kanban (Columnas)'),
        _buildKanbanConfig(theme),
        _buildSectionHeader(theme, 'Comunicación'),
        _buildFormGroup(theme, [
          _buildTextField(
            theme,
            _businessEmailController,
            'Email de Negocio',
            Icons.business,
          ),
          const Divider(height: 1, indent: 56),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _signatureImageController,
              decoration: const InputDecoration(
                labelText: 'URL Imagen Firma',
                prefixIcon: Icon(Icons.image, size: 24),
                border: InputBorder.none,
              ),
            ),
          ),
          const Divider(height: 1, indent: 56),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _emailSignatureController,
              decoration: const InputDecoration(
                labelText: 'Firma de Email',
                alignLabelWithHint: true,
                border: InputBorder.none,
                prefixIcon: Icon(Icons.edit_note, size: 28),
              ),
              maxLines: 4,
            ),
          ),
        ]),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveSettings,
            child: const Text('Guardar Configuración'),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSwitch(String title, String key) {
    return SwitchListTile.adaptive(
      title: Text(title),
      value: _settings[key] ?? true,
      onChanged: (v) => setState(() => _settings[key] = v),
      activeColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildFrequencyDropdown(String title, String key) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<String>(
        value: _settings[key] ?? 'weekly',
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: 'daily', child: Text('Diario')),
          DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
          DropdownMenuItem(value: 'biweekly', child: Text('Quincenal')),
          DropdownMenuItem(value: 'monthly', child: Text('Mensual')),
        ],
        onChanged: (v) => setState(() => _settings[key] = v),
      ),
    );
  }

  Widget _buildKanbanConfig(ThemeData theme) {
    List<dynamic> columns = _settings['kanbanColumns'] ?? [];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
            // Update 'order' property
            for (int i = 0; i < columns.length; i++) {
              columns[i]['order'] = i;
            }
            _settings['kanbanColumns'] = columns;
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
                _editKanbanColumn(column); // Reopen to refresh or just setState
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
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarTab(ThemeData theme) {
    final workHours =
        _calendarSettings['workHours'] ?? {'startHour': 7, 'endHour': 22};
    final vacationDays = List<String>.from(
      _calendarSettings['vacationDays'] ?? [],
    );

    final bloques = List<Map<String, dynamic>>.from(
      _calendarSettings['bloques'] ?? [],
    );

    return ListView(
      padding: const EdgeInsets.all(0),
      children: [
        _buildSectionHeader(theme, 'Horario Laboral General'),
        _buildFormGroup(theme, [
          ListTile(
            title: const Text('Inicio de Jornada'),
            trailing: DropdownButton<int>(
              value: workHours['startHour'] ?? 7,
              underline: const SizedBox(),
              items: List.generate(
                24,
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text('${i.toString().padLeft(2, '0')}:00'),
                ),
              ),
              onChanged: (v) => setState(
                () => _calendarSettings['workHours'] = {
                  ...workHours,
                  'startHour': v,
                },
              ),
            ),
          ),
          const Divider(height: 1, indent: 16),
          ListTile(
            title: const Text('Fin de Jornada'),
            trailing: DropdownButton<int>(
              value: workHours['endHour'] ?? 22,
              underline: const SizedBox(),
              items: List.generate(
                24,
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text('${i.toString().padLeft(2, '0')}:00'),
                ),
              ),
              onChanged: (v) => setState(
                () => _calendarSettings['workHours'] = {
                  ...workHours,
                  'endHour': v,
                },
              ),
            ),
          ),
        ]),
        _buildSectionHeader(theme, 'Bloques de Disponibilidad'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              if (bloques.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No hay bloques configurados'),
                ),
              ...bloques.map((b) {
                final weekday = _getWeekdayName(b['weekday']);
                return ListTile(
                  title: Text(weekday),
                  subtitle: Text('${b['start']} - ${b['end']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        bloques.remove(b);
                        _calendarSettings['bloques'] = bloques;
                      });
                    },
                  ),
                );
              }),
              Divider(height: 1, color: theme.dividerColor),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Añadir Bloque'),
                onTap: () => _addAvailabilityBlock(bloques),
              ),
            ],
          ),
        ),
        _buildSectionHeader(theme, 'Días No Laborables'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...vacationDays.map(
                    (day) => Chip(
                      label: Text(day),
                      onDeleted: () {
                        setState(() {
                          vacationDays.remove(day);
                          _calendarSettings['vacationDays'] = vacationDays;
                        });
                      },
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('Añadir Día'),
                    onPressed: () => _addVacationDay(vacationDays),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveCalendar,
            child: const Text('Guardar Calendario'),
          ),
        ),
      ],
    );
  }

  String _getWeekdayName(int weekday) {
    const days = [
      'Domingo',
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
    ];
    if (weekday >= 0 && weekday < days.length) return days[weekday];
    return 'Día $weekday';
  }

  Future<void> _addAvailabilityBlock(List<Map<String, dynamic>> blocks) async {
    int selectedDay = 1;
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 17, minute: 0);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Nuevo Bloque'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedDay,
                  items: List.generate(
                    7,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(_getWeekdayName(i)),
                    ),
                  ),
                  onChanged: (v) => setState(() => selectedDay = v!),
                  decoration: const InputDecoration(labelText: 'Día'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: start,
                          );
                          if (t != null) setState(() => start = t);
                        },
                        child: Text('Inicio: ${start.format(context)}'),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: end,
                          );
                          if (t != null) setState(() => end = t);
                        },
                        child: Text('Fin: ${end.format(context)}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Añadir'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      if (mounted) {
        setState(() {
          blocks.add({
            'weekday': selectedDay,
            'start':
                '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
            'end':
                '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
          });
          _calendarSettings['bloques'] = blocks;
        });
      }
    }
  }

  Future<void> _addVacationDay(List<String> vacationDays) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final dateStr = date.toIso8601String().split('T')[0];
      if (!vacationDays.contains(dateStr)) {
        setState(() {
          vacationDays.add(dateStr);
          _calendarSettings['vacationDays'] = vacationDays;
        });
      }
    }
  }

  Widget _buildStatsTab(ThemeData theme) {
    if (_stats == null) return const Center(child: CircularProgressIndicator());

    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          theme,
          'Clientes',
          _stats!['clients']?.toString() ?? '0',
          Icons.people_alt,
          Colors.blue,
        ),
        _buildStatCard(
          theme,
          'Citas',
          _stats!['appointments']?.toString() ?? '0',
          Icons.calendar_month,
          Colors.green,
        ),
        _buildStatCard(
          theme,
          'Tareas',
          _stats!['tasks']?.toString() ?? '0',
          Icons.check_circle,
          Colors.orange,
        ),
        _buildStatCard(
          theme,
          'Sesiones',
          (_stats!['sessions'] ?? 0).toString(),
          Icons.video_camera_front,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: theme.hintColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormGroup(ThemeData theme, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField(
    ThemeData theme,
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: InputBorder.none,
      ),
    );
  }
}
