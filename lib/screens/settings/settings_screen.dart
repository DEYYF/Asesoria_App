import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'email_history_screen.dart';
import '../../services/settings_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../providers/theme_provider.dart';
import '../../models/settings_model.dart';
import 'widgets/settings_widgets.dart';
import 'widgets/business_settings_dialog.dart';
import 'widgets/support_dialog.dart';
import 'templates_screen.dart';
import 'automation_screen.dart';
import 'modules_management_screen.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserSettings? _settings;
  bool _loading = true;
  final String _appVersion = '1.0.1';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    await settingsProvider.loadSettings();
    if (mounted) {
      setState(() {
        _settings = settingsProvider.settings;
        _loading = false;
      });
    }
  }

  Future<void> _updateSettings(UserSettings newSettings) async {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final oldSettings = _settings;
    setState(() => _settings = newSettings);

    try {
      await settingsProvider.updateSettings(newSettings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración guardada correctamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _settings = oldSettings);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al sincronizar con el servidor: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F9FB),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // PREMIUM HEADER WITH GRADIENT
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            stretch: true,
            elevation: 0,
            backgroundColor: isDark
                ? const Color(0xFF1C1C1E)
                : Colors.blue[800],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              title: const Text(
                'Configuración',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF1C1C1E), const Color(0xFF2C2C2E)]
                        : [Colors.teal[700]!, Colors.blue[900]!],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: -20,
                      child: Icon(
                        Icons.settings_suggest_rounded,
                        size: 200,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.white24,
                                    shape: BoxShape.circle,
                                  ),
                                  child: CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.white.withOpacity(
                                      0.2,
                                    ),
                                    child: const Icon(
                                      Icons.person_rounded,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        auth.user?['email'] ?? 'Asesor Pro',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'ID: ${auth.userId?.substring(0, 8) ?? 'Offline'}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 12),

              // Notifications section
              const SettingsSectionHeader(title: 'Notificaciones'),
              SettingsGroup(
                children: [
                  SettingsSwitchTile(
                    title: 'Notificaciones Push',
                    icon: Icons.notifications_active_rounded,
                    iconColor: Colors.orange,
                    value: _settings!.pushNotifications,
                    onChanged: (val) => _updateSettings(
                      _settings!.copyWith(pushNotifications: val),
                    ),
                  ),
                  SettingsSwitchTile(
                    title: 'Notificaciones Email',
                    icon: Icons.alternate_email_rounded,
                    iconColor: Colors.blue,
                    value: _settings!.emailNotifications,
                    onChanged: (val) => _updateSettings(
                      _settings!.copyWith(emailNotifications: val),
                    ),
                  ),
                ],
              ),

              // Appearance section
              const SettingsSectionHeader(title: 'Apariencia'),
              SettingsGroup(
                children: [
                  SettingsNavigationTile(
                    title: 'Tema Visual',
                    subtitle: 'Cambiar entre modo claro y oscuro',
                    icon: Icons.palette_rounded,
                    iconColor: Colors.purple,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getThemeLabel(_settings!.theme),
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey[800],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onTap: _showThemePicker,
                  ),
                ],
              ),

              // Communication section
              if (_settings!.enabledChat ||
                  _settings!.enabledEmail ||
                  _settings!.enabledTemplateManagement ||
                  _settings!.enabledAutomation) ...[
                const SettingsSectionHeader(title: 'Comunicación'),
                SettingsGroup(
                  children: [
                    if (_settings!.enabledTemplateManagement)
                      SettingsNavigationTile(
                        title: 'Plantillas de Mensajes',
                        subtitle: 'Gestionar respuestas rápidas',
                        icon: Icons.auto_awesome_motion_rounded,
                        iconColor: Colors.teal,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TemplatesScreen(),
                            ),
                          );
                        },
                      ),
                    SettingsNavigationTile(
                      title: 'Historial de Correos',
                      subtitle: 'Registro de correos enviados',
                      icon: Icons.history_edu_rounded,
                      iconColor: Colors.blueGrey,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EmailHistoryScreen(),
                          ),
                        );
                      },
                    ),
                    if (_settings!.enabledAutomation)
                      SettingsNavigationTile(
                        title: 'Automatización',
                        subtitle: 'Reglas para mensajes automáticos',
                        icon: Icons.auto_mode_rounded,
                        iconColor: Colors.deepPurpleAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AutomationScreen(),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],

              // Module Management section
              const SettingsSectionHeader(title: 'Sistema de Módulos'),
              SettingsGroup(
                children: [
                  SettingsNavigationTile(
                    title: 'Administrar Módulos',
                    subtitle: 'Activar o desactivar funciones de la app',
                    icon: Icons.settings_suggest_rounded,
                    iconColor: const Color(0xFF5856D6),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ModulesManagementScreen(settings: _settings!),
                        ),
                      ).then((_) => _loadSettings());
                    },
                  ),
                ],
              ),

              // Frequency section
              if (_settings!.enabledProgressFrequencies) ...[
                const SettingsSectionHeader(title: 'Frecuencia de Seguimiento'),
                SettingsGroup(
                  children: [
                    _buildFreqTile(
                      'Peso',
                      Icons.monitor_weight_rounded,
                      Colors.blueAccent,
                      _settings!.weightFrequency,
                      (val) => _updateSettings(
                        _settings!.copyWith(weightFrequency: val),
                      ),
                    ),
                    _buildFreqTile(
                      'Porcentaje Graso',
                      Icons.percent_rounded,
                      Colors.orangeAccent,
                      _settings!.fatFrequency,
                      (val) => _updateSettings(
                        _settings!.copyWith(fatFrequency: val),
                      ),
                    ),
                    _buildFreqTile(
                      'Medidas',
                      Icons.straighten_rounded,
                      Colors.greenAccent,
                      _settings!.measuresFrequency,
                      (val) => _updateSettings(
                        _settings!.copyWith(measuresFrequency: val),
                      ),
                    ),
                    _buildFreqTile(
                      'Músculo',
                      Icons.fitness_center_rounded,
                      Colors.redAccent,
                      _settings!.muscleFrequency,
                      (val) => _updateSettings(
                        _settings!.copyWith(muscleFrequency: val),
                      ),
                    ),
                  ],
                ),
              ],

              // Admin section
              if (auth.isAdmin) ...[
                const SettingsSectionHeader(title: 'Administración'),
                SettingsGroup(
                  children: [
                    SettingsNavigationTile(
                      title: 'Perfil de Negocio',
                      subtitle: 'Firma, logos y email corporativo',
                      icon: Icons.business_center_rounded,
                      iconColor: const Color(0xFF5856D6),
                      onTap: _showBusinessSettingsDialog,
                    ),
                  ],
                ),
              ],

              // Account section
              const SettingsSectionHeader(title: 'Datos y Cuenta'),
              SettingsGroup(
                children: [
                  SettingsNavigationTile(
                    title: 'Exportar Datos',
                    subtitle: 'Descarga tu información completa',
                    icon: Icons.cloud_download_rounded,
                    iconColor: Colors.blue,
                    onTap: _exportData,
                  ),
                  SettingsNavigationTile(
                    title: 'Eliminar Cuenta',
                    subtitle: 'Baja definitiva del servicio',
                    icon: Icons.no_accounts_rounded,
                    iconColor: Colors.redAccent,
                    titleColor: Colors.redAccent,
                    onTap: _confirmDeleteAccount,
                  ),
                ],
              ),

              // Information section
              const SettingsSectionHeader(title: 'Centro de Ayuda'),
              SettingsGroup(
                children: [
                  SettingsNavigationTile(
                    title: 'Soporte Técnico',
                    subtitle: 'Contactar con el equipo de ayuda',
                    icon: Icons.live_help_rounded,
                    iconColor: Colors.teal,
                    onTap: _showSupportDialog,
                  ),
                  SettingsInfoTile(
                    title: 'Versión de la App',
                    icon: Icons.info_outline_rounded,
                    iconColor: Colors.grey,
                    value: _appVersion,
                  ),
                ],
              ),

              // Logout button
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: InkWell(
                  onTap: () => _confirmLogout(auth),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: const Center(
                      child: Text(
                        'Cerrar Sesión Segura',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 60),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildFreqTile(
    String title,
    IconData icon,
    Color color,
    String value,
    ValueChanged<String> onSelected,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SettingsNavigationTile(
      title: title,
      icon: icon,
      iconColor: color,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _getFrequencyLabel(value),
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey[800],
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      onTap: () => _showFrequencyPicker(title, value, onSelected),
    );
  }

  void _showSupportDialog() {
    showDialog(context: context, builder: (context) => const SupportDialog());
  }

  void _showBusinessSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) =>
          BusinessSettingsDialog(settings: _settings!, onSave: _updateSettings),
    );
  }

  String _getThemeLabel(String theme) {
    switch (theme) {
      case 'light':
        return 'Claro';
      case 'dark':
        return 'Oscuro';
      default:
        return 'Sistema';
    }
  }

  String _getFrequencyLabel(String frequency) {
    switch (frequency) {
      case 'daily':
        return 'Diario';
      case 'weekly':
        return 'Semanal';
      case 'biweekly':
        return 'Quincenal';
      case 'monthly':
        return 'Mensual';
      case 'quarterly':
        return 'Trimestral';
      default:
        return 'Semanal';
    }
  }

  void _showFrequencyPicker(
    String title,
    String currentValue,
    ValueChanged<String> onSelected,
  ) {
    final options = [
      {'label': 'Diario', 'value': 'daily'},
      {'label': 'Semanal', 'value': 'weekly'},
      {'label': 'Quincenal', 'value': 'biweekly'},
      {'label': 'Mensual', 'value': 'monthly'},
      {'label': 'Trimestral', 'value': 'quarterly'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Frecuencia: $title',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
            ...options.map((opt) {
              final isSelected = currentValue == opt['value'];
              return ListTile(
                title: Text(opt['label']!),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  onSelected(opt['value']!);
                },
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showThemePicker() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Seleccionar Tema',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
            _buildThemeOption('Claro', 'light', themeProvider),
            _buildThemeOption('Oscuro', 'dark', themeProvider),
            _buildThemeOption('Sistema', 'system', themeProvider),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    String label,
    String value,
    ThemeProvider themeProvider,
  ) {
    final isSelected = _settings!.theme == value;
    return ListTile(
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () {
        Navigator.pop(context);
        themeProvider.setTheme(value);
        _updateSettings(_settings!.copyWith(theme: value));
      },
    );
  }

  void _exportData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exportar Datos'),
        content: const Text(
          'Se generará un archivo con toda tu información y se enviará a tu correo electrónico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final settingsService = SettingsService(
                Provider.of<ApiService>(context, listen: false),
              );
              final messenger = ScaffoldMessenger.of(context);
              try {
                await settingsService.exportData();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Exportación iniciada. Revisa tu email.'),
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Exportar'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar Cuenta?'),
        content: const Text(
          'Todas tus dietas, entrenamientos y datos personales se borrarán permanentemente. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final settingsService = SettingsService(
      Provider.of<ApiService>(context, listen: false),
    );
    try {
      await settingsService.deleteAccount();
      if (mounted) {
        Provider.of<AuthService>(context, listen: false).logout();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar cuenta: $e')));
      }
    }
  }

  void _confirmLogout(AuthService auth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              auth.logout();
            },
            child: const Text('Salir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
