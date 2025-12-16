import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../models/cliente_model.dart';
import '../services/api_service.dart';
import 'dialog_correo.dart';
import 'dialog_cita.dart';

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
  String _computedStatus = 'Cargando...';
  int? _ultimaDietaDias;
  Color _statusColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _calculateStatus();
  }

  @override
  void didUpdateWidget(covariant ClienteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cliente.id != widget.cliente.id ||
        oldWidget.cliente.fechaFin != widget.cliente.fechaFin ||
        oldWidget.cliente.estado != widget.cliente.estado) {
      // Added status check
      _calculateStatus();
    }
  }

  Future<void> _calculateStatus() async {
    final c = widget.cliente;

    // 0. Manual "Baja" override
    if (c.estado == 'Baja') {
      if (mounted) {
        setState(() {
          _computedStatus = 'Baja';
          _statusColor = Colors.red;
        });
      }
      return;
    }

    final now = DateTime.now();
    final fechaFin = c.fechaFin;

    // 1. Check Expiry
    if (fechaFin != null && fechaFin.isBefore(now)) {
      if (mounted) {
        setState(() {
          _computedStatus = 'Inactivo';
          _statusColor =
              Colors.grey; // Changed to grey for inactive vs red for Baja
        });
      }
    }

    // 2. Fetch Diets to determine "En Proceso" vs "Activo" and "Last Diet"
    try {
      final api = Provider.of<ApiService>(context, listen: false);

      // Parallel requests
      final hits = await Future.wait([
        api.get('/dietas/cliente/${c.id}'), // All diets (to check existence)
        api.get('/dietas/cliente/${c.id}/ultima'), // Last diet (for days)
      ]);

      if (!mounted) return;

      final dietasRes = hits[0];
      final ultimaRes = hits[1];

      bool hasDiets = false;
      if (dietasRes.statusCode == 200) {
        final list = jsonDecode(dietasRes.body);
        if (list is List && list.isNotEmpty) hasDiets = true;
      }

      // Check "ultima"
      if (ultimaRes.statusCode == 200) {
        final data = jsonDecode(ultimaRes.body);
        if (data != null &&
            (data['createdAt'] != null || data['fechaCreacion'] != null)) {
          final dateStr = data['createdAt'] ?? data['fechaCreacion'];
          final dietDate = DateTime.parse(dateStr);
          final diff = DateTime.now().difference(dietDate).inDays;
          setState(() => _ultimaDietaDias = diff);
        }
      }

      // Logic from React:
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
      } else {
        if (fechaFin == null) {
          setState(() {
            _computedStatus = 'Sin Fecha';
            _statusColor = Colors.grey;
          });
        }
      }
    } catch (e) {
      // Quiet fail
      print('Error calc status: $e');
    }
  }

  Future<void> _makeCall() async {
    final phone = widget.cliente.telefono?.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No se puede llamar')));
      }
    }
  }

  void _openEmailDialog() {
    showDialog(
      context: context,
      builder: (_) => DialogCorreo(cliente: widget.cliente),
    );
  }

  void _openCitaDialog() {
    showDialog(
      context: context,
      builder: (_) => DialogCita(cliente: widget.cliente),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cliente;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Avatar with Status Dot
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.blue.shade50,
                  backgroundImage: c.avatarUrl != null
                      ? NetworkImage(c.avatarUrl!)
                      : null,
                  child: c.avatarUrl == null
                      ? Text(
                          c.nombre.isEmpty
                              ? '?'
                              : c.nombre.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: Colors.blue.shade700,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),

            // 2. Main Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Just in case status is unknown or something
                    ],
                  ),
                  const SizedBox(height: 4),

                  Row(
                    children: [
                      // Email Clickable
                      Expanded(
                        child: InkWell(
                          onTap: _openEmailDialog,
                          child: Text(
                            c.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      if (c.telefono != null) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.phone,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: InkWell(
                            onTap: _makeCall,
                            child: Text(
                              c.telefono!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: (c.objetivos ?? [])
                        .take(3)
                        .map(
                          (obj) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              obj,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  if (c.objetivos == null || c.objetivos!.isEmpty)
                    Text(
                      'Sin objetivos',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // 3. Right Side (Status Chip, Last Diet, Dates, Actions)
            Flexible(
              fit: FlexFit.loose,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _computedStatus,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _ultimaDietaDias == null
                                    ? 'Sin dieta reciente'
                                    : 'Hace $_ultimaDietaDias días',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_formatDate(c.fechaInicio)} - ${_formatDate(c.fechaFin)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons (wrap to avoid overflow)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      _ActionButton(
                        label: 'Llamar',
                        icon: Icons.phone,
                        onPressed: _makeCall,
                      ),
                      _ActionButton(
                        label: 'Cita',
                        icon: Icons.calendar_today,
                        onPressed: _openCitaDialog,
                      ),
                      ElevatedButton(
                        onPressed: widget.onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Perfil'),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                        onSelected: (val) {
                          if (val == 'delete') widget.onDelete();
                          if (val == 'toggle') widget.onToggleStatus();
                          if (val == 'email') _openEmailDialog();
                          if (val == 'cita') _openCitaDialog();
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Text(
                              _computedStatus == 'Inactivo' ||
                                      _computedStatus == 'Baja'
                                  ? 'Reactivar'
                                  : 'Dar baja',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'email',
                            child: Text('Enviar correo'),
                          ),
                          const PopupMenuItem(
                            value: 'cita',
                            child: Text('Agendar cita'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Eliminar',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.blue.shade700,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(
        children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(label)],
      ),
    );
  }
}
