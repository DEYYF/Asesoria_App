import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../utils/notification_helper.dart';
import 'dart:convert';
import 'widgets/premium_settings_widgets.dart';
import 'widgets/advisor_detail/intelligence_settings_dialog.dart';
import 'widgets/advisor_detail/pdf_designer_dialog.dart';
import 'widgets/advisor_detail/advisor_stats_tab.dart';
import 'widgets/advisor_detail/general_info_form.dart';
import 'widgets/advisor_detail/advisor_calendar_tab.dart';
import 'widgets/advisor_detail/kanban_settings_form.dart';

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
          _passwordController.text = ''; // Don't show current hashed password
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
        NotificationHelper.showSuccess(context, 'Información general guardada');
        _loadAdvisor(); // Reload to update UI
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.showError(context, 'Error: $e');
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
        NotificationHelper.showSuccess(context, 'Ajustes guardados');
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.showError(context, 'Error: $e');
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildGeneralTab(ThemeData theme) {
    if (_advisor == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return GeneralInfoForm(
      advisor: _advisor,
      nombreController: _nombreController,
      emailController: _emailController,
      passwordController: _passwordController,
      role: _role,
      onRoleChanged: (v) => setState(() => _role = v),
      isSaving: _isSaving,
      onSave: _saveGeneral,
    );
  }

  Future<void> _saveCalendar() async {
    setState(() => _isSaving = true);
    final api = Provider.of<ApiService>(context, listen: false);

    try {
      await api.put('/users/${widget.advisorId}', {
        'calendarSettings': _calendarSettings,
      });
      if (mounted) {
        NotificationHelper.showSuccess(context, 'Calendario guardado');
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.showError(context, 'Error: $e');
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
                  AdvisorStatsTab(stats: _stats),
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

  Widget _buildSettingsTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      children: [
        _buildSectionHeader(theme, 'Notificaciones & Estilo'),
        _buildPremiumCard([
          PremiumToggle(
            title: 'Notificaciones Push',
            subtitle: 'Recibir alertas en el dispositivo',
            value: _settings['pushNotifications'] ?? true,
            onChanged: (v) =>
                setState(() => _settings['pushNotifications'] = v),
          ),
          PremiumToggle(
            title: 'Email Marketing',
            subtitle: 'Recibir novedades por correo',
            value: _settings['emailNotifications'] ?? true,
            onChanged: (v) =>
                setState(() => _settings['emailNotifications'] = v),
          ),
          const Divider(height: 32, indent: 16, endIndent: 16),
          PremiumDropdown(
            label: 'Tema de la App',
            value: _settings['theme'] ?? 'system',
            options: const ['light', 'dark', 'system'],
            onChanged: (v) => setState(() => _settings['theme'] = v),
          ),
          PremiumTextField(
            label: 'Color de Acento',
            hint: 'Código Hex',
            data: _settings,
            field: 'accentColor',
            icon: Icons.colorize_rounded,
          ),
        ]),

        const SizedBox(height: 24),
        _buildSectionHeader(theme, 'Módulos Activos'),
        _buildPremiumCard([
          PremiumToggle(
            title: 'Chat en vivo',
            subtitle: 'Comunicación directa con clientes',
            value: _settings['enabledChat'] ?? true,
            onChanged: (v) => setState(() => _settings['enabledChat'] = v),
          ),
          PremiumToggle(
            title: 'Email Automatizado',
            subtitle: 'Envío de planes por correo',
            value: _settings['enabledEmail'] ?? true,
            onChanged: (v) => setState(() => _settings['enabledEmail'] = v),
          ),
          PremiumToggle(
            title: 'Automatización IA',
            subtitle: 'Tareas inteligentes en segundo plano',
            value: _settings['enabledAutomation'] ?? true,
            onChanged: (v) =>
                setState(() => _settings['enabledAutomation'] = v),
          ),
          PremiumToggle(
            title: 'Módulo de Finanzas',
            subtitle: 'Gestión de cobros y presupuestos',
            value: _settings['enabledFinanzas'] ?? true,
            onChanged: (v) => setState(() => _settings['enabledFinanzas'] = v),
          ),
          PremiumToggle(
            title: 'Plantillas',
            subtitle: 'Gestión de documentos base',
            value: _settings['enabledTemplateManagement'] ?? true,
            onChanged: (v) =>
                setState(() => _settings['enabledTemplateManagement'] = v),
          ),
          PremiumToggle(
            title: 'Registro de Entreno',
            subtitle: 'Bitácora de ejercicios para clientes',
            value: _settings['enabledTrainingLog'] ?? true,
            onChanged: (v) =>
                setState(() => _settings['enabledTrainingLog'] = v),
          ),
          PremiumToggle(
            title: 'Food Scanner',
            subtitle: 'Reconocimiento de macros por foto',
            value: _settings['enabledFoodScanner'] ?? true,
            onChanged: (v) =>
                setState(() => _settings['enabledFoodScanner'] = v),
          ),
          PremiumToggle(
            title: 'Seguimiento de Progreso',
            subtitle: 'Frecuencias de toma de medidas',
            value: _settings['enabledProgressFrequencies'] ?? true,
            onChanged: (v) =>
                setState(() => _settings['enabledProgressFrequencies'] = v),
          ),
        ]),

        const SizedBox(height: 24),
        _buildSectionHeader(theme, 'Configuración Especializada'),
        _buildPremiumCard([
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.withOpacity(0.1),
              child: const Icon(Icons.psychology_rounded, color: Colors.purple),
            ),
            title: const Text(
              'Inteligencia Artificial',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('IA para estancamientos y macros'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showIntelligenceSettings,
          ),
          const Divider(height: 1, indent: 72),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: Colors.blue,
              ),
            ),
            title: const Text(
              'Diseñador de PDF',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Identidad visual de planes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showPdfSettings,
          ),
        ]),

        if (_settings['enabledProgressFrequencies'] == true) ...[
          const SizedBox(height: 24),
          _buildSectionHeader(theme, 'Frecuencias de Progreso'),
          _buildPremiumCard([
            PremiumDropdown(
              label: 'Peso Corporal',
              value: _settings['weightFrequency'] ?? 'weekly',
              options: const ['daily', 'weekly', 'biweekly', 'monthly'],
              onChanged: (v) =>
                  setState(() => _settings['weightFrequency'] = v),
            ),
            PremiumDropdown(
              label: 'Porcentaje Grasa',
              value: _settings['fatFrequency'] ?? 'weekly',
              options: const ['daily', 'weekly', 'biweekly', 'monthly'],
              onChanged: (v) => setState(() => _settings['fatFrequency'] = v),
            ),
            PremiumDropdown(
              label: 'Medidas Cinta',
              value: _settings['measuresFrequency'] ?? 'monthly',
              options: const ['daily', 'weekly', 'biweekly', 'monthly'],
              onChanged: (v) =>
                  setState(() => _settings['measuresFrequency'] = v),
            ),
            PremiumDropdown(
              label: 'Músculo (IA)',
              value: _settings['muscleFrequency'] ?? 'monthly',
              options: const ['daily', 'weekly', 'biweekly', 'monthly'],
              onChanged: (v) =>
                  setState(() => _settings['muscleFrequency'] = v),
            ),
          ]),
        ],

        const SizedBox(height: 24),
        const SizedBox(height: 24),
        _buildSectionHeader(theme, 'Kanban (Columnas)'),
        KanbanSettingsForm(
          settings: _settings,
          onColumnsUpdated: (cols) {
            setState(() => _settings['kanbanColumns'] = cols);
          },
        ),

        const SizedBox(height: 24),
        _buildSectionHeader(theme, 'Identidad de Email'),
        _buildPremiumCard([
          PremiumTextField(
            label: 'Email de Negocio',
            hint: 'nombre@empresa.com',
            data: _settings,
            field: 'businessEmail',
            icon: Icons.business_rounded,
          ),
          PremiumTextField(
            label: 'Imagen de Firma',
            hint: 'Enlace directo URL',
            data: _settings,
            field: 'signatureImageUrl',
            icon: Icons.image_rounded,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _emailSignatureController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Firma de Texto',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                fillColor: Colors.grey.withOpacity(0.05),
                filled: true,
                hintText: 'Saludos cordiales...',
              ),
              onChanged: (v) => _settings['emailSignature'] = v,
            ),
          ),
        ]),

        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            onPressed: _isSaving ? null : _saveSettings,
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'GUARDAR CONFIGURACIÓN',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildPremiumCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildCalendarTab(ThemeData theme) {
    return AdvisorCalendarTab(
      calendarSettings: _calendarSettings,
      isSaving: _isSaving,
      onSave: _saveCalendar,
    );
  }

  void _showIntelligenceSettings() {
    showDialog(
      context: context,
      builder: (context) => IntelligenceSettingsDialog(
        settings: _settings,
        onSave: (updatedIntel) {
          setState(() {
            _settings['intelligence'] = updatedIntel;
          });
          _saveSettings();
        },
      ),
    );
  }

  void _showPdfSettings() {
    showDialog(
      context: context,
      builder: (context) => PdfDesignerDialog(
        settings: _settings,
        onSave: (updatedPdf) {
          setState(() {
            _settings['pdfSettings'] = updatedPdf;
          });
          _saveSettings();
        },
      ),
    );
  }
}
