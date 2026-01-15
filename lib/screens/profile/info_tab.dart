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
    if (widget.cliente.extras == null || widget.cliente.extras!.isEmpty) {
      return [];
    }
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
            _appleRow(
              'Nombre',
              widget.cliente.nombre,
              icon: Icons.person_outline_rounded,
            ),
            _appleRow(
              'Email',
              widget.cliente.email,
              icon: Icons.email_outlined,
            ),
            _appleRow(
              'Teléfono',
              widget.cliente.telefono ?? '-',
              icon: Icons.phone_android_rounded,
            ),
            _appleRow(
              'Sexo',
              widget.cliente.sexo ?? '-',
              icon: Icons.wc_rounded,
            ),
            _appleRow(
              'Altura',
              '${widget.cliente.altura ?? '-'} cm',
              icon: Icons.height_rounded,
            ),
          ]),

          const SizedBox(height: 24),
          _sectionTitle('TARIFA Y VIGENCIA'),
          _buildGroup([
            _appleRow(
              'Tarifa',
              '${widget.cliente.tipoServicio?.toUpperCase() ?? ''} (${_getDuration(widget.cliente.fechaInicio, widget.cliente.fechaFin)})',
              valueColor: theme.primaryColor,
              icon: Icons.auto_awesome_mosaic_rounded,
            ),
            _appleRow(
              'Vigencia',
              '${_formatDateShort(widget.cliente.fechaInicio)} - ${_formatDateShort(widget.cliente.fechaFin)}',
              icon: Icons.calendar_month_rounded,
              valueColor: _isTariffExpired() ? Colors.red : null,
            ),
          ]),

          const SizedBox(height: 24),
          _sectionTitle('OBJETIVOS'),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  (widget.cliente.objetivos ??
                          [
                            'Ganar masa muscular',
                            'Definición',
                            'Aumentar fuerza',
                          ])
                      .map((obj) => _ObjectiveChip(label: obj, theme: theme))
                      .toList(),
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

  String _formatDateShort(DateTime? date) {
    if (date == null) return '-';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString().substring(2);
    return '$d/$m/$y';
  }

  String _getDuration(DateTime? start, DateTime? end) {
    if (start == null || end == null) {
      return widget.cliente.tiempoTarifa ?? '1 Mes';
    }
    final days = end.difference(start).inDays.abs();
    if (days >= 360) return '12 Meses';
    if (days >= 180) return '6 Meses';
    if (days >= 90) return '3 Meses';
    if (days >= 28) return '1 Mes';
    if (days == 0) return '0 Días';
    return '$days Días';
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
        color: theme.cardTheme.color,
        borderRadius: theme.cardTheme.shape is RoundedRectangleBorder
            ? (theme.cardTheme.shape as RoundedRectangleBorder).borderRadius
            : BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
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

  Widget _appleRow(
    String label,
    String? value, {
    Color? valueColor,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: theme.primaryColor.withOpacity(0.7)),
          const SizedBox(width: 12),
        ],
        Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [theme.cardColor, theme.cardColor.withOpacity(0.8)]
              : [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bolt_rounded, color: theme.primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rendimiento Mensual',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Sesiones completadas',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.hintColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.primaryColor,
                      theme.primaryColor.withBlue(255),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${widget.cliente.sesionesCounter ?? 0}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (!Provider.of<AuthService>(context, listen: false).isClient) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _CounterButton(
                    icon: Icons.remove_rounded,
                    color: Colors.redAccent,
                    onPressed: () => widget.onSessionAction?.call('decrement'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _CounterButton(
                    icon: Icons.add_rounded,
                    color: Colors.greenAccent.shade700,
                    onPressed: () => widget.onSessionAction?.call('increment'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _CounterButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 28),
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
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? theme.primaryColor.withOpacity(0.1)
            : theme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 14,
            color: theme.primaryColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
        ],
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
