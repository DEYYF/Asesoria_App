import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/settings_model.dart';
import '../../providers/settings_provider.dart';
import 'widgets/settings_widgets.dart';

class ModulesManagementScreen extends StatefulWidget {
  final UserSettings settings;

  const ModulesManagementScreen({super.key, required this.settings});

  @override
  State<ModulesManagementScreen> createState() =>
      _ModulesManagementScreenState();
}

class _ModulesManagementScreenState extends State<ModulesManagementScreen> {
  late UserSettings _settings;
  bool _isLoading = false;
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _showPasswordPrompt() {
    final TextEditingController passwordCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Acceso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Introduce la contraseña para habilitar la edición de módulos:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Contraseña',
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white10
                    : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) =>
                  _verifyPassword(dialogContext, passwordCtrl.text),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => _verifyPassword(dialogContext, passwordCtrl.text),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Desbloquear'),
          ),
        ],
      ),
    );
  }

  void _verifyPassword(BuildContext dialogContext, String pass) {
    if (pass.toUpperCase() == 'GOLF') {
      Navigator.pop(dialogContext); // Close ONLY the dialog
      setState(() => _isUnlocked = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modo edición habilitado'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña incorrecta'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updateSettings(UserSettings newSettings) async {
    setState(() {
      _settings = newSettings;
      _isLoading = true;
    });

    final settingsService = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    try {
      await settingsService.updateSettings(newSettings);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showModuleInfo(String title, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(
          description,
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Gestión de Módulos'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isUnlocked)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: _showPasswordPrompt,
                icon: const Icon(Icons.lock_outline_rounded, size: 18),
                label: const Text('Habilitar Edición'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_open_rounded,
                      size: 18,
                      color: Colors.green,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Modo Edición',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              const SettingsSectionHeader(
                title: 'PERSONALIZACIÓN DE FUNCIONES',
              ),
              SettingsGroup(
                children: [
                  SettingsSwitchTile(
                    title: 'Chat en Tiempo Real',
                    icon: Icons.chat_bubble_rounded,
                    iconColor: Colors.green,
                    value: _settings.enabledChat,
                    onChanged: _isUnlocked
                        ? (val) => _updateSettings(
                            _settings.copyWith(enabledChat: val),
                          )
                        : null,
                    onInfoTap: () => _showModuleInfo(
                      'Chat en Tiempo Real',
                      'Permite la comunicación instantánea entre asesores y clientes.',
                    ),
                  ),
                  SettingsSwitchTile(
                    title: 'Sistema de Correo',
                    icon: Icons.email_rounded,
                    iconColor: Colors.blue,
                    value: _settings.enabledEmail,
                    onChanged: _isUnlocked
                        ? (val) => _updateSettings(
                            _settings.copyWith(enabledEmail: val),
                          )
                        : null,
                    onInfoTap: () => _showModuleInfo(
                      'Sistema de Correo',
                      'Controla el envío de correos individuales y campañas masivas.',
                    ),
                  ),
                  SettingsSwitchTile(
                    title: 'Frecuencia de Progreso',
                    icon: Icons.speed_rounded,
                    iconColor: Colors.orange,
                    value: _settings.enabledProgressFrequencies,
                    onChanged: _isUnlocked
                        ? (val) => _updateSettings(
                            _settings.copyWith(enabledProgressFrequencies: val),
                          )
                        : null,
                    onInfoTap: () => _showModuleInfo(
                      'Frecuencia de Progreso',
                      'Permite que el asesor modifique los periodos de registro de datos del cliente.',
                    ),
                  ),
                  SettingsSwitchTile(
                    title: 'Gestión de Plantillas',
                    icon: Icons.description_rounded,
                    iconColor: Colors.teal,
                    value: _settings.enabledTemplateManagement,
                    onChanged: _isUnlocked
                        ? (val) => _updateSettings(
                            _settings.copyWith(enabledTemplateManagement: val),
                          )
                        : null,
                    onInfoTap: () => _showModuleInfo(
                      'Gestión de Plantillas',
                      'Controla si el asesor puede crear, editar o eliminar plantillas de mensajes.',
                    ),
                  ),
                  SettingsSwitchTile(
                    title: 'Libreta y Entrenamiento',
                    icon: Icons.fitness_center_rounded,
                    iconColor: Colors.redAccent,
                    value: _settings.enabledTrainingLog,
                    onChanged: _isUnlocked
                        ? (val) => _updateSettings(
                            _settings.copyWith(enabledTrainingLog: val),
                          )
                        : null,
                    onInfoTap: () => _showModuleInfo(
                      'Libreta y Entrenamiento',
                      'Contiene el pack de registro de sesiones, libreta histórica y cronómetro.',
                    ),
                  ),
                  SettingsSwitchTile(
                    title: 'Escáner de Alimentos',
                    icon: Icons.qr_code_scanner_rounded,
                    iconColor: Colors.purple,
                    value: _settings.enabledFoodScanner,
                    onChanged: _isUnlocked
                        ? (val) => _updateSettings(
                            _settings.copyWith(enabledFoodScanner: val),
                          )
                        : null,
                    onInfoTap: () => _showModuleInfo(
                      'Escáner de Alimentos',
                      'Activa el escaneo de códigos de barras para importar información nutricional.',
                    ),
                  ),
                  SettingsSwitchTile(
                    title: 'Automatización de Mensajes',
                    icon: Icons.auto_mode_rounded,
                    iconColor: Colors.deepPurpleAccent,
                    value: _settings.enabledAutomation,
                    onChanged: _isUnlocked
                        ? (val) => _updateSettings(
                            _settings.copyWith(enabledAutomation: val),
                          )
                        : null,
                    onInfoTap: () => _showModuleInfo(
                      'Automatización',
                      'Reglas para enviar mensajes y correos automáticamente ante eventos del sistema.',
                    ),
                  ),
                  SettingsSwitchTile(
                    title: 'Panel Financiero',
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: Colors.amber,
                    value: _settings.enabledFinanzas,
                    onChanged: _isUnlocked
                        ? (val) => _updateSettings(
                            _settings.copyWith(enabledFinanzas: val),
                          )
                        : null,
                    onInfoTap: () => _showModuleInfo(
                      'Panel Financiero',
                      'Control de ingresos, gastos y vinculación automática con presupuestos pagados.',
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    if (!_isUnlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              color: Colors.blue,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Puedes consultar qué hace cada módulo usando el icono (i), pero para cambiar su estado pulsa "Habilitar Edición" arriba.',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Nota: Desactivar un módulo ocultará las funcionalidades correspondientes para el asesor.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
