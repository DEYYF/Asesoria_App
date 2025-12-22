import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/cliente_model.dart';
import '../../models/extra_model.dart';

class InfoTab extends StatefulWidget {
  final Cliente cliente;
  final VoidCallback? onRenovar;
  final VoidCallback? onDelete;
  final VoidCallback? onAddProgress;
  final VoidCallback? onManageExtras;
  final VoidCallback? onChangeTariff;
  final VoidCallback? onEditInfo;
  final void Function(String action)? onSessionAction;

  const InfoTab({
    super.key,
    required this.cliente,
    this.onRenovar,
    this.onDelete,
    this.onAddProgress,
    this.onManageExtras,
    this.onChangeTariff,
    this.onEditInfo,
    this.onSessionAction,
  });

  @override
  State<InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends State<InfoTab> {
  List<Extra> _extrasDisponibles = [];
  bool _isLoadingExtras = false;

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    setState(() => _isLoadingExtras = true);
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final resExtras = await api.get('/extras');
      if (resExtras.statusCode == 200) {
        final listExtras = (jsonDecode(resExtras.body) as List)
            .map((i) => Extra.fromJson(i))
            .toList();
        setState(() {
          _extrasDisponibles = listExtras;
          _isLoadingExtras = false;
        });
      } else {
        setState(() => _isLoadingExtras = false);
      }
    } catch (e) {
      debugPrint('Error loading extras: $e');
      setState(() => _isLoadingExtras = false);
    }
  }

  List<Extra> get _clienteExtras {
    if (widget.cliente.extras == null || widget.cliente.extras!.isEmpty)
      return [];
    final clienteExtraIds = widget.cliente.extras!
        .map((e) => (e is Map) ? (e['_id'] ?? e['id']) : e.toString())
        .toList();
    return _extrasDisponibles
        .where((extra) => clienteExtraIds.contains(extra.id))
        .toList();
  }

  bool _isTariffExpired() {
    if (widget.cliente.fechaFin == null) return false;
    return widget.cliente.fechaFin!.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPersonalHeader(theme),
          _buildGroup([
            _appleRow('Nombre', widget.cliente.nombre),
            _appleRow('Email', widget.cliente.email),
            _appleRow('Teléfono', widget.cliente.telefono ?? '-'),
            _appleRow('Sexo', widget.cliente.sexo ?? '-'),
            _appleRow('Altura', '${widget.cliente.altura ?? '-'} cm'),
          ]),

          const SizedBox(height: 32),
          _sectionTitle('TARIFA Y VIGENCIA'),
          _buildGroup([
            _appleRow(
              'Tarifa',
              '${widget.cliente.tipoServicio} (${widget.cliente.tiempoTarifa ?? '1 Mes'})',
              valueColor: theme.primaryColor,
            ),
            _appleRow(
              'Vigencia',
              '${_formatDate(widget.cliente.fechaInicio)} - ${_formatDate(widget.cliente.fechaFin)}',
            ),
          ]),

          const SizedBox(height: 32),
          _sectionTitle('OBJETIVOS'),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ObjectiveChip(label: 'Ganar masa muscular', theme: theme),
                _ObjectiveChip(label: 'Definición', theme: theme),
                _ObjectiveChip(label: 'Aumentar fuerza', theme: theme),
              ],
            ),
          ),

          if (!_isLoadingExtras && _clienteExtras.isNotEmpty) ...[
            const SizedBox(height: 32),
            _sectionTitle('EXTRAS ACTIVOS'),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _clienteExtras.map((extra) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFAF52DE).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFAF52DE).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Color(0xFFAF52DE),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${extra.nombre} (+${extra.precio}€)',
                          style: const TextStyle(
                            color: Color(0xFFAF52DE),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 32),
          _buildSessionCounter(context, theme, isDark),

          Builder(
            builder: (context) {
              final auth = Provider.of<AuthService>(context, listen: false);
              if (auth.isClient) return const SizedBox.shrink();

              return Column(
                children: [
                  const SizedBox(height: 32),
                  _sectionTitle('ACCIONES DE GESTIÓN'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _AppleButton(
                          label: 'Progreso',
                          icon: Icons.add_chart_rounded,
                          color: const Color(0xFF007AFF),
                          onPressed: widget.onAddProgress,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AppleButton(
                          label: 'Renovar',
                          icon: Icons.sync_rounded,
                          color: const Color(0xFF34C759),
                          onPressed: _isTariffExpired()
                              ? widget.onRenovar
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _AppleButton(
                          label: 'Cambiar Tarifa',
                          icon: Icons.swap_horiz_rounded,
                          color: Colors.blueGrey,
                          onPressed: _isTariffExpired()
                              ? widget.onChangeTariff
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AppleButton(
                          label: 'Gestionar Extras',
                          icon: Icons.star_outline_rounded,
                          color: const Color(0xFFFF9500),
                          onPressed: _isTariffExpired()
                              ? widget.onManageExtras
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildPersonalHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _sectionTitle('INFORMACIÓN PERSONAL'),
          IconButton.filledTonal(
            icon: const Icon(Icons.edit_rounded, size: 18),
            onPressed: widget.onEditInfo,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _sectionTitle(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: theme.hintColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildGroup(List<Widget> children) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: child,
              ),
              if (index < children.length - 1)
                Divider(
                  height: 1,
                  indent: 16,
                  thickness: 0.5,
                  color: theme.dividerColor.withOpacity(0.1),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _appleRow(String label, String? value, {Color? valueColor}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        Text(
          value ?? '-',
          style: TextStyle(
            fontSize: 15,
            color: valueColor ?? theme.hintColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionCounter(
    BuildContext context,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Entrenamientos',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Sesiones realizadas este mes',
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.cliente.sesionesCounter ?? 0}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          if (!Provider.of<AuthService>(context, listen: false).isClient) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _circleIconButton(
                  Icons.remove_rounded,
                  const Color(0xFFFF3B30),
                  () => widget.onSessionAction?.call('decrement'),
                ),
                const SizedBox(width: 40),
                _circleIconButton(
                  Icons.add_rounded,
                  const Color(0xFF34C759),
                  () => widget.onSessionAction?.call('increment'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _circleIconButton(IconData icon, Color color, VoidCallback onPressed) {
    return IconButton.filled(
      icon: Icon(icon, size: 28),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        minimumSize: const Size(56, 56),
      ),
    );
  }
}

class _ObjectiveChip extends StatelessWidget {
  final String label;
  final ThemeData theme;
  const _ObjectiveChip({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _AppleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _AppleButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1.0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
