import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../services/settings_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../providers/theme_provider.dart';
import '../models/settings_model.dart';

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
          _buildSectionHeader('NOTIFICACIONES'),
          _buildSettingsGroup([
            _buildSwitchTile(
              title: 'Notificaciones Push',
              icon: Icons.notifications_active_rounded,
              iconColor: Colors.redAccent,
              value: _settings!.pushNotifications,
              onChanged: (val) =>
                  _updateSettings(_settings!.copyWith(pushNotifications: val)),
            ),
            _buildSwitchTile(
              title: 'Notificaciones Email',
              icon: Icons.alternate_email_rounded,
              iconColor: Colors.blueAccent,
              value: _settings!.emailNotifications,
              onChanged: (val) =>
                  _updateSettings(_settings!.copyWith(emailNotifications: val)),
            ),
          ]),

          // Appearance section
          _buildSectionHeader('APARIENCIA'),
          _buildSettingsGroup([
            _buildNavigationTile(
              title: 'Tema',
              icon: Icons.palette_rounded,
              iconColor: Colors.purple,
              trailing: Text(
                _getThemeLabel(_settings!.theme),
                style: TextStyle(color: theme.hintColor),
              ),
              onTap: _showThemePicker,
            ),
            _buildNavigationTile(
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
          ]),

          // Account section
          _buildSectionHeader('CUENTA'),
          _buildSettingsGroup([
            _buildNavigationTile(
              title: 'Exportar Datos',
              icon: Icons.download_for_offline_rounded,
              iconColor: Colors.green,
              onTap: _exportData,
            ),
            _buildNavigationTile(
              title: 'Eliminar Cuenta',
              icon: Icons.person_remove_rounded,
              iconColor: Colors.grey,
              titleColor: Colors.red,
              onTap: _confirmDeleteAccount,
            ),
          ]),

          // Admin section
          if (auth.isAdmin) ...[
            _buildSectionHeader('ADMINISTRACIÓN'),
            _buildSettingsGroup([
              _buildNavigationTile(
                title: 'Configuración de Negocio',
                icon: Icons.business_center_rounded,
                iconColor: const Color(0xFF5856D6),
                trailing: Text(
                  'Signature & Email',
                  style: TextStyle(color: theme.hintColor, fontSize: 13),
                ),
                onTap: _showBusinessSettingsDialog,
              ),
            ]),
          ],

          // System section
          _buildSectionHeader('SISTEMA'),
          _buildSettingsGroup([
            _buildInfoTile(
              title: 'Versión',
              icon: Icons.info_outline_rounded,
              iconColor: Colors.grey,
              value: _appVersion,
            ),
            _buildNavigationTile(
              title: 'Soporte',
              icon: Icons.help_outline_rounded,
              iconColor: Colors.teal,
              onTap: _showSupportDialog,
            ),
          ]),

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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(children: _addDividers(children)),
    );
  }

  List<Widget> _addDividers(List<Widget> children) {
    final result = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(const Divider(height: 1, indent: 56));
      }
    }
    return result;
  }

  Widget _buildSwitchTile({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: _buildIcon(icon, iconColor),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 16,
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: Colors.green.withValues(alpha: 0.35),
        activeThumbColor: Colors.green,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildNavigationTile({
    required String title,
    required IconData icon,
    required Color iconColor,
    Widget? trailing,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: _buildIcon(icon, iconColor),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? (isDark ? Colors.white : Colors.black87),
          fontSize: 16,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) ...[trailing, const SizedBox(width: 8)],
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
        ],
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: _buildIcon(icon, iconColor),
      title: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 16,
        ),
      ),
      trailing: Text(value, style: const TextStyle(color: Colors.grey)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
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

  void _showBusinessSettingsDialog() {
    final signatureController = TextEditingController(
      text: _settings!.emailSignature,
    );
    final emailController = TextEditingController(
      text: _settings!.businessEmail,
    );
    String? localBase64Image = _settings!.signatureImageUrl;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Configuración de Negocio'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Corporativo',
                      hintText: 'ejemplo@empresa.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: signatureController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Firma de Email',
                      hintText: 'Tu firma en formato HTML o texto...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Logo de Empresa',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      debugPrint('Seleccionando imagen...');
                      try {
                        final picker = ImagePicker();
                        final image = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 800,
                          maxHeight: 800,
                          imageQuality: 85,
                        );
                        if (image != null) {
                          debugPrint('Imagen seleccionada: ${image.path}');
                          final bytes = await image.readAsBytes();
                          setDialogState(() {
                            localBase64Image = base64Encode(bytes);
                          });
                        } else {
                          debugPrint('No se seleccionó ninguna imagen.');
                        }
                      } catch (e) {
                        debugPrint('Error al seleccionar imagen: $e');
                      }
                    },
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                      child:
                          localBase64Image != null &&
                              localBase64Image!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: _buildLogoPreview(localBase64Image!),
                                  ),
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.black54,
                                      radius: 14,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        onPressed: () {
                                          setDialogState(() {
                                            localBase64Image = null;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 32,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Subir Logo',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  _updateSettings(
                    _settings!.copyWith(
                      businessEmail: emailController.text,
                      emailSignature: signatureController.text,
                      signatureImageUrl: localBase64Image,
                    ),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogoPreview(String base64String) {
    try {
      if (base64String.startsWith('http')) {
        return Image.network(base64String, fit: BoxFit.contain);
      }
      return Image.memory(
        base64Decode(base64String),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );
    } catch (e) {
      return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
    }
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
                Provider.of(context, listen: false),
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
      Provider.of(context, listen: false),
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

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Soporte Técnico'),
        content: const Text(
          'Si tienes algún problema o sugerencia, contáctanos en:\nsoporte@asesoria_app.com',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
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
