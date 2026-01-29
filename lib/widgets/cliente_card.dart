import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../models/cliente_model.dart';
import '../services/api_service.dart';
import 'dialog_cita.dart';
import 'dialog_correo.dart';
import 'dialogs/compose_chat_dialog.dart';
import 'dialogs/communication_choice_dialog.dart';
import '../services/settings_service.dart';
import '../utils/batch_pdf_helper.dart';
import '../utils/notification_helper.dart';

class ClienteCard extends StatefulWidget {
  final Cliente cliente;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;
  final VoidCallback? onTransfer;

  const ClienteCard({
    super.key,
    required this.cliente,
    required this.onTap,
    required this.onDelete,
    required this.onToggleStatus,
    this.onTransfer,
  });

  @override
  State<ClienteCard> createState() => _ClienteCardState();
}

class _ClienteCardState extends State<ClienteCard> {
  String _computedStatus = '...';
  int? _ultimaDietaDias;
  Color _statusColor = Colors.grey;
  bool _isProgressOverdue = false;
  bool _isStalled = false;
  String _overdueMetric = '';

  @override
  void initState() {
    super.initState();
    _calculateStatus();
  }

  Future<void> _calculateStatus() async {
    final c = widget.cliente;
    if (c.estado == 'Baja') {
      if (mounted)
        setState(() {
          _computedStatus = 'Baja';
          _statusColor = Colors.red;
        });
      return;
    }

    final now = DateTime.now();
    final fechaFin = c.fechaFin;

    if (fechaFin != null && fechaFin.isBefore(now)) {
      if (mounted)
        setState(() {
          _computedStatus = 'Caducado';
          _statusColor = Colors.redAccent;
        });
    }

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final hits = await Future.wait([
        api.get('/dietas?clienteId=${c.id}'),
        api.get('/dietas/cliente/${c.id}/ultima'),
      ]);

      if (!mounted) return;

      bool hasDiets = false;
      if (hits[0].statusCode == 200) {
        final list = jsonDecode(hits[0].body);
        if (list is List && list.isNotEmpty) hasDiets = true;
      }

      if (hits[1].statusCode == 200) {
        final data = jsonDecode(hits[1].body);
        if (data != null &&
            (data['createdAt'] != null || data['fechaCreacion'] != null)) {
          final dateStr = data['createdAt'] ?? data['fechaCreacion'];
          final dietDate = DateTime.parse(dateStr);
          final diff = DateTime.now().difference(dietDate).inDays;
          setState(() => _ultimaDietaDias = diff);
        }
      }

      if (fechaFin != null && fechaFin.isAfter(now)) {
        if (hasDiets) {
          setState(() {
            _computedStatus = 'Activo';
            _statusColor = Colors.green;
          });
        } else {
          setState(() {
            _computedStatus = 'En Proceso';
            _statusColor = Colors.orange;
          });
        }
      }

      final settingsService = SettingsService(api);
      final settings = await settingsService.getSettings();

      // Stall detection logic (last 3 entries)
      if (c.historialProgreso != null && c.historialProgreso!.length >= 3) {
        final history = c.historialProgreso!;
        final latest = history.last;
        final prev = history[history.length - 2];
        final previousPrev = history[history.length - 3];

        final w1 = (latest['peso'] as num?)?.toDouble() ?? 0;
        final w2 = (prev['peso'] as num?)?.toDouble() ?? 0;
        final w3 = (previousPrev['peso'] as num?)?.toDouble() ?? 0;

        if (w1 > 0 && w2 > 0 && w3 > 0) {
          if ((w1 - w2).abs() < 0.2 && (w2 - w3).abs() < 0.2) {
            setState(() => _isStalled = true);
          }
        }
      }

      if (settings.enabledProgressFrequencies &&
          c.historialProgreso != null &&
          c.historialProgreso!.isNotEmpty) {
        // Simple logic for brevity in compression
        final lastEntry = c.historialProgreso!.last;
        final lastDate = DateTime.parse(lastEntry['fecha']);
        final diff = DateTime.now().difference(lastDate).inDays;
        if (diff > 7) {
          setState(() {
            _isProgressOverdue = true;
            _overdueMetric = 'Peso';
          });
        }
      }
    } catch (e) {
      print('Error calc status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cliente;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Area
                _buildAvatar(theme),
                const SizedBox(width: 12),

                // Info Area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              c.nombre,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusBadges(),
                          const SizedBox(width: 8),

                          // Three Dots Menu
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert_rounded,
                              color: theme.hintColor,
                              size: 20,
                            ),
                            onSelected: (val) {
                              if (val == 'baja') widget.onToggleStatus();
                              if (val == 'delete') widget.onDelete();
                              if (val == 'transfer') widget.onTransfer?.call();
                              if (val == 'password')
                                _showChangePasswordDialog();
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'baja',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person_off_rounded,
                                      size: 18,
                                      color: theme.hintColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.cliente.estado == 'Baja'
                                          ? 'Dar de alta'
                                          : 'Dar de baja',
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'password',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.lock_reset_rounded,
                                      size: 18,
                                      color: theme.primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Cambiar Contraseña'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Eliminar',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.onTransfer != null)
                                PopupMenuItem(
                                  value: 'transfer',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.swap_horiz_rounded,
                                        size: 18,
                                        color: theme.primaryColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Transferir',
                                        style: TextStyle(
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            c.email.length > 15
                                ? '${c.email.substring(0, 12)}...'
                                : c.email,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.hintColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          if (c.telefono != null) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.phone_rounded,
                              size: 12,
                              color: theme.hintColor,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              c.telefono!,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Compact Objectives
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: (c.objetivos ?? [])
                            .take(2)
                            .map((obj) => _ObjectiveChip(label: obj))
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      // Activities
                      Row(
                        children: [
                          Icon(
                            Icons.restaurant_menu_rounded,
                            size: 12,
                            color: theme.hintColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _ultimaDietaDias == null
                                ? 'Sin dieta'
                                : 'Hace $_ultimaDietaDias d',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.hintColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${c.fechaFin?.day}/${c.fechaFin?.month}/${c.fechaFin?.year.toString().substring(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.hintColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildBottomActions(theme),
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

  Widget _buildAvatar(ThemeData theme) {
    return Stack(
      children: [
        Hero(
          tag: 'avatar_${widget.cliente.id}',
          child: CircleAvatar(
            radius: 26,
            backgroundColor: theme.primaryColor.withOpacity(0.1),
            backgroundImage: widget.cliente.avatarUrl != null
                ? NetworkImage(widget.cliente.avatarUrl!)
                : null,
            child: widget.cliente.avatarUrl == null
                ? Text(
                    widget.cliente.nombre[0].toUpperCase(),
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  )
                : null,
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: theme.cardColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadges() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isStalled)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
            ),
            child: Row(
              children: const [
                Icon(Icons.bolt_rounded, size: 10, color: Colors.orange),
                SizedBox(width: 2),
                Text(
                  'ESTANCADO',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.orange,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        if (_isProgressOverdue)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 10,
                  color: Colors.red,
                ),
                const SizedBox(width: 2),
                Text(
                  'Atr: $_overdueMetric',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _computedStatus,
            style: TextStyle(
              fontSize: 9,
              color: _statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(ThemeData theme) {
    return Row(
      children: [
        _CompactIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: 'Mensaje',
          onPressed: _handleMessageAction,
        ),
        const SizedBox(width: 8),
        _CompactIconButton(
          icon: Icons.phone_enabled_rounded,
          tooltip: 'Llamar',
          onPressed: _makeCall,
        ),
        const SizedBox(width: 8),
        _CompactIconButton(
          icon: Icons.calendar_today_rounded,
          tooltip: 'Cita',
          onPressed: _openCitaDialog,
        ),
        const SizedBox(width: 8),
        _buildPdfActionMenu(theme),
        const SizedBox(width: 8),
        _CompactIconButton(
          icon: Icons.visibility_outlined,
          tooltip: 'Ver Perfil',
          onPressed: widget.onTap,
        ),
      ],
    );
  }

  Future<void> _handleMessageAction() async {
    final method = await showDialog<String>(
      context: context,
      builder: (_) => const CommunicationChoiceDialog(),
    );
    if (!mounted || method == null) return;

    if (method == 'email') {
      showDialog(
        context: context,
        builder: (_) => DialogCorreo(cliente: widget.cliente),
      );
    } else if (method == 'chat') {
      showDialog(
        context: context,
        builder: (_) => ComposeChatDialog(cliente: widget.cliente),
      );
    }
  }

  Future<void> _makeCall() async {
    final phone = widget.cliente.telefono;
    if (phone != null) launchUrl(Uri.parse('tel:$phone'));
  }

  void _openCitaDialog() {
    showDialog(
      context: context,
      builder: (_) => DialogCita(cliente: widget.cliente),
    );
  }

  Widget _buildPdfActionMenu(ThemeData theme) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      elevation: 8,
      shadowColor: theme.primaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: _CompactIconButton(
        icon: Icons.picture_as_pdf_rounded,
        tooltip: 'Reportes PDF',
        onPressed: null,
      ),
      onSelected: (val) => _showPdfSelectionDialog(val == 'email'),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'download',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.download_rounded,
                  size: 16,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Descargar reportes', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'email',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.email_rounded,
                  size: 16,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Enviar por correo', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  void _showPdfSelectionDialog(bool isEmail) {
    showDialog(
      context: context,
      builder: (context) =>
          _PdfSelectionDialog(cliente: widget.cliente, isEmail: isEmail),
    );
  }

  void _showChangePasswordDialog() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ctrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Cambiar Contraseña'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ingresa la nueva contraseña para ${widget.cliente.nombre}.',
                style: TextStyle(fontSize: 13, color: theme.hintColor),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Nueva Contraseña',
                  hintText: 'Mínimo 6 caracteres',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final pass = ctrl.text.trim();
                      if (pass.length < 6) {
                        NotificationHelper.showError(
                          context,
                          'La contraseña es demasiado corta',
                        );
                        return;
                      }

                      setStateDialog(() => isLoading = true);
                      try {
                        final api = Provider.of<ApiService>(
                          context,
                          listen: false,
                        );
                        final res = await api.put(
                          '/clientes/${widget.cliente.id}/password',
                          {'newPassword': pass},
                        );

                        if (!mounted) return;

                        if (res.statusCode == 200) {
                          Navigator.pop(ctx);
                          NotificationHelper.showSuccess(
                            context,
                            'Contraseña actualizada correctamente',
                          );
                        } else {
                          final msg =
                              jsonDecode(res.body)['error'] ??
                              'Error desconocido';
                          NotificationHelper.showError(context, msg);
                          setStateDialog(() => isLoading = false);
                        }
                      } catch (e) {
                        if (mounted) {
                          NotificationHelper.showError(context, 'Error: $e');
                          setStateDialog(() => isLoading = false);
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfSelectionDialog extends StatefulWidget {
  final Cliente cliente;
  final bool isEmail;

  const _PdfSelectionDialog({required this.cliente, required this.isEmail});

  @override
  State<_PdfSelectionDialog> createState() => _PdfSelectionDialogState();
}

class _PdfSelectionDialogState extends State<_PdfSelectionDialog> {
  final Map<String, bool> _selected = {
    'dieta': true,
    'entrenamiento': true,
    'corporal': true,
    'rendimiento': true,
  };

  bool _isProcessing = false;

  bool get _allSelected => _selected.values.every((v) => v);

  void _toggleAll() {
    final target = !_allSelected;
    setState(() {
      _selected.updateAll((key, value) => target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 380,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isEmail
                              ? 'Enviar Reportes'
                              : 'Descargar Reportes',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.cliente.nombre,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSelectAllToggle(theme),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                children: [
                  _buildCardOption(
                    'Dieta',
                    'dieta',
                    Icons.restaurant_menu_rounded,
                    theme,
                    isDark,
                  ),
                  _buildCardOption(
                    'Plan Entrenamiento',
                    'entrenamiento',
                    Icons.fitness_center_rounded,
                    theme,
                    isDark,
                  ),
                  _buildCardOption(
                    'Informe Corporal',
                    'corporal',
                    Icons.accessibility_new_rounded,
                    theme,
                    isDark,
                  ),
                  _buildCardOption(
                    'Evolución Rendimiento',
                    'rendimiento',
                    Icons.trending_up_rounded,
                    theme,
                    isDark,
                  ),
                ],
              ),
            ),

            if (_isProcessing)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        backgroundColor: theme.primaryColor.withOpacity(0.1),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generando documentos...',
                      style: TextStyle(fontSize: 12, color: theme.primaryColor),
                    ),
                  ],
                ),
              ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isProcessing
                          ? null
                          : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'CANCELAR',
                        style: TextStyle(color: theme.hintColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _handleAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.isEmail
                                ? Icons.send_rounded
                                : Icons.download_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(widget.isEmail ? 'ENVIAR' : 'DESCARGAR'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectAllToggle(ThemeData theme) {
    return InkWell(
      onTap: _toggleAll,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _allSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: _allSelected ? theme.primaryColor : theme.hintColor,
              size: 20,
            ),
            const Text(
              'Todos',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardOption(
    String label,
    String key,
    IconData icon,
    ThemeData theme,
    bool isDark,
  ) {
    final isSelected = _selected[key] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selected[key] = !isSelected),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.primaryColor.withOpacity(0.08)
                : isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? theme.primaryColor.withOpacity(0.3)
                  : theme.dividerColor.withOpacity(0.05),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.primaryColor.withOpacity(0.1)
                      : isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? theme.primaryColor : theme.hintColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? theme.textTheme.bodyLarge?.color
                        : theme.hintColor,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.primaryColor,
                  size: 20,
                )
              else
                Icon(
                  Icons.circle_outlined,
                  color: theme.hintColor.withOpacity(0.3),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction() async {
    if (_selected.values.every((v) => !v)) {
      NotificationHelper.showInfo(
        context,
        'Por favor, selecciona al menos un reporte',
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await BatchPdfHelper.processBatch(
        context: context,
        cliente: widget.cliente,
        selectedReports: _selected,
        isEmail: widget.isEmail,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        NotificationHelper.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

class _ObjectiveChip extends StatelessWidget {
  final String label;
  const _ObjectiveChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : Colors.grey.shade800,
        ),
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _CompactIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget content = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Icon(icon, size: 16, color: theme.primaryColor),
    );

    if (onPressed != null) {
      content = InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: content,
      );
    }

    return Tooltip(message: tooltip, child: content);
  }
}
