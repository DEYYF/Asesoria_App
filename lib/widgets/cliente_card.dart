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

class ClienteCard extends StatefulWidget {
  final Cliente cliente;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  const ClienteCard({
    super.key,
    required this.cliente,
    required this.onTap,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  State<ClienteCard> createState() => _ClienteCardState();
}

class _ClienteCardState extends State<ClienteCard> {
  String _computedStatus = '...';
  int? _ultimaDietaDias;
  Color _statusColor = Colors.grey;
  bool _isProgressOverdue = false;
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
                                      c.estado == 'Baja'
                                          ? 'Dar de alta'
                                          : 'Dar de baja',
                                    ),
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
  final VoidCallback onPressed;

  const _CompactIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
          ),
          child: Icon(icon, size: 16, color: theme.primaryColor),
        ),
      ),
    );
  }
}
