import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../providers/theme_provider.dart';
import '../../models/settings_model.dart';
import 'widgets/settings_widgets.dart';
import 'widgets/business_settings_dialog.dart';
import 'widgets/support_dialog.dart';

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
    final settingsService = SettingsService(
      Provider.of<ApiService>(context, listen: false),
    );
    try {
      final settings = await settingsService.getSettings();
      setState(() {
        _settings = settings;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() {
        _settings = UserSettings();
        _loading = false;
      });
    }
  }

  Future<void> _updateSettings(UserSettings newSettings) async {
    final oldSettings = _settings;
    setState(() => _settings = newSettings);

    final settingsService = SettingsService(
      Provider.of<ApiService>(context, listen: false),
    );

    try {
      await settingsService.updateSettings(newSettings);
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
      backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text(
          'Ajustes',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          // Notifications section
          const SettingsSectionHeader(title: 'NOTIFICACIONES'),
          SettingsGroup(
            children: [
              SettingsSwitchTile(
                title: 'Notificaciones Push',
                icon: Icons.notifications_active_rounded,
                iconColor: Colors.redAccent,
                value: _settings!.pushNotifications,
                onChanged: (val) => _updateSettings(
                  _settings!.copyWith(pushNotifications: val),
                ),
              ),
              SettingsSwitchTile(
                title: 'Notificaciones Email',
                icon: Icons.alternate_email_rounded,
                iconColor: Colors.blueAccent,
                value: _settings!.emailNotifications,
                onChanged: (val) => _updateSettings(
                  _settings!.copyWith(emailNotifications: val),
                ),
              ),
            ],
          ),

          // Appearance section
          const SettingsSectionHeader(title: 'APARIENCIA'),
          SettingsGroup(
            children: [
              SettingsNavigationTile(
                title: 'Tema',
                icon: Icons.palette_rounded,
                iconColor: Colors.purple,
                trailing: Text(
                  _getThemeLabel(_settings!.theme),
                  style: TextStyle(color: theme.hintColor),
                ),
                onTap: _showThemePicker,
              ),
              SettingsNavigationTile(
                title: 'Color de Acento',
                icon: Icons.colorize_rounded,
                iconColor: Colors.orange,
                trailing: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _parseColor(_settings!.accentColor),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                onTap: _showColorPicker,
              ),
            ],
          ),

          // Account section
          const SettingsSectionHeader(title: 'CUENTA'),
          SettingsGroup(
            children: [
              SettingsNavigationTile(
                title: 'Exportar Datos',
                icon: Icons.download_for_offline_rounded,
                iconColor: Colors.green,
                onTap: _exportData,
              ),
              SettingsNavigationTile(
                title: 'Eliminar Cuenta',
                icon: Icons.person_remove_rounded,
                iconColor: Colors.grey,
                titleColor: Colors.red,
                onTap: _confirmDeleteAccount,
              ),
            ],
          ),

          // Frequency section
          const SettingsSectionHeader(title: 'FRECUENCIA DE MEDICIONES'),
          SettingsGroup(
            children: [
              SettingsNavigationTile(
                title: 'Peso',
                icon: Icons.monitor_weight_rounded,
                iconColor: Colors.blueAccent,
                trailing: Text(
                  _getFrequencyLabel(_settings!.weightFrequency),
                  style: TextStyle(color: theme.hintColor),
                ),
                onTap: () => _showFrequencyPicker(
                  'Peso',
                  _settings!.weightFrequency,
                  (val) {
                    _updateSettings(_settings!.copyWith(weightFrequency: val));
                  },
                ),
              ),
              SettingsNavigationTile(
                title: 'Porcentaje Graso',
                icon: Icons.percent_rounded,
                iconColor: Colors.orangeAccent,
                trailing: Text(
                  _getFrequencyLabel(_settings!.fatFrequency),
                  style: TextStyle(color: theme.hintColor),
                ),
                onTap: () => _showFrequencyPicker(
                  'Porcentaje Graso',
                  _settings!.fatFrequency,
                  (val) {
                    _updateSettings(_settings!.copyWith(fatFrequency: val));
                  },
                ),
              ),
              SettingsNavigationTile(
                title: 'Medidas',
                icon: Icons.straighten_rounded,
                iconColor: Colors.greenAccent,
                trailing: Text(
                  _getFrequencyLabel(_settings!.measuresFrequency),
                  style: TextStyle(color: theme.hintColor),
                ),
                onTap: () => _showFrequencyPicker(
                  'Medidas',
                  _settings!.measuresFrequency,
                  (val) {
                    _updateSettings(
                      _settings!.copyWith(measuresFrequency: val),
                    );
                  },
                ),
              ),
              SettingsNavigationTile(
                title: 'Porcentaje Musculoesquelético',
                icon: Icons.fitness_center_rounded,
                iconColor: Colors.redAccent,
                trailing: Text(
                  _getFrequencyLabel(_settings!.muscleFrequency),
                  style: TextStyle(color: theme.hintColor),
                ),
                onTap: () => _showFrequencyPicker(
                  'Porcentaje Musculoesquelético',
                  _settings!.muscleFrequency,
                  (val) {
                    _updateSettings(_settings!.copyWith(muscleFrequency: val));
                  },
                ),
              ),
            ],
          ),

          // Admin section
          if (auth.isAdmin) ...[
            const SettingsSectionHeader(title: 'ADMINISTRACIÓN'),
            SettingsGroup(
              children: [
                SettingsNavigationTile(
                  title: 'Configuración de Negocio',
                  icon: Icons.business_center_rounded,
                  iconColor: const Color(0xFF5856D6),
                  trailing: Text(
                    'Signature & Email',
                    style: TextStyle(color: theme.hintColor, fontSize: 13),
                  ),
                  onTap: _showBusinessSettingsDialog,
                ),
              ],
            ),
          ],

          // System section
          const SettingsSectionHeader(title: 'SISTEMA'),
          SettingsGroup(
            children: [
              SettingsInfoTile(
                title: 'Versión',
                icon: Icons.info_outline_rounded,
                iconColor: Colors.grey,
                value: _appVersion,
              ),
              SettingsNavigationTile(
                title: 'Soporte',
                icon: Icons.help_outline_rounded,
                iconColor: Colors.teal,
                onTap: _showSupportDialog,
              ),
            ],
          ),

          // Logout button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton(
              onPressed: () => _confirmLogout(auth),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFF1C1C1E)
                    : Colors.white,
                foregroundColor: Colors.red,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Cerrar Sesión',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
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

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.blue;
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

  void _showColorPicker() {
    final colors = [
      {'name': 'Azul', 'color': Colors.blue},
      {'name': 'Rojo', 'color': Colors.red},
      {'name': 'Verde', 'color': Colors.green},
      {'name': 'Naranja', 'color': Colors.orange},
      {'name': 'Morado', 'color': Colors.purple},
      {'name': 'Rosa', 'color': Colors.pink},
      {'name': 'Teal', 'color': Colors.teal},
      {'name': 'Indigo', 'color': Colors.indigo},
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
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Color de Acento',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemCount: colors.length,
              itemBuilder: (context, index) {
                final color = colors[index]['color'] as Color;
                final hex =
                    '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
                final isSelected = _settings!.accentColor.toUpperCase() == hex;

                return GestureDetector(
                  onTap: () {
                    final themeProvider = Provider.of<ThemeProvider>(
                      context,
                      listen: false,
                    );
                    Navigator.pop(context);
                    themeProvider.setAccentColor(hex);
                    _updateSettings(_settings!.copyWith(accentColor: hex));
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: Theme.of(context).primaryColor,
                              width: 3,
                            )
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
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
