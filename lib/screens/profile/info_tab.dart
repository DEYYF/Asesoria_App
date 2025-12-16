import 'package:flutter/material.dart';
import '../../models/cliente_model.dart';
import '../../models/progreso_model.dart';
import '../../widgets/charts/weight_chart.dart';
import '../../widgets/charts/body_fat_chart.dart';
import '../../widgets/charts/muscle_chart.dart';
import '../../widgets/heatmap_panel.dart';

class InfoTab extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final List<Progreso> historial = cliente.historialProgreso != null
        ? cliente.historialProgreso!
              .map((json) => Progreso.fromJson(json))
              .toList()
        : [];

    final ultimoProgreso = historial.isNotEmpty ? historial.last : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionTitle('INFORMACIÓN PERSONAL'),
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                onPressed: onEditInfo,
                tooltip: 'Editar información',
              ),
            ],
          ),
          _buildGroup([
            _appleRow('Nombre', cliente.nombre),
            _appleRow('Email', cliente.email),
            _appleRow('Teléfono', cliente.telefono ?? '-'),
            _appleRow('Sexo', cliente.sexo ?? '-'),
            _appleRow('Altura', '${cliente.altura ?? '-'} cm'),
          ]),

          const SizedBox(height: 24),
          _sectionTitle('TARIFA Y VIGENCIA'),
          _buildGroup([
            _appleRow(
              'Tarifa',
              '${cliente.tipoServicio} (${cliente.tiempoTarifa ?? '1 Mes'})',
              valueColor: Colors.blue,
            ),
            _appleRow(
              'Vigencia',
              '${_formatDate(cliente.fechaInicio)} - ${_formatDate(cliente.fechaFin)}',
            ),
          ]),

          const SizedBox(height: 24),
          _sectionTitle('OBJETIVOS'),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _ObjectiveChip(label: 'Ganar masa muscular'),
                _ObjectiveChip(label: 'Definición'),
                _ObjectiveChip(label: 'Aumentar fuerza'),
              ],
            ),
          ),

          if (cliente.extras != null && cliente.extras!.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle('EXTRAS'),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cliente.extras!.map((e) {
                  // e can be String ID or Object. Handle both.
                  final label = e is Map ? e['nombre'] : e.toString();
                  return Chip(
                    label: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: const Color(0xFF9C27B0), // Purple color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 24),
          _buildSessionCounter(context),

          const SizedBox(height: 24),
          // Action Buttons Grid
          Row(
            children: [
              Expanded(
                child: _AppleButton(
                  label: 'Añadir progreso',
                  color: const Color(0xFF007AFF),
                  onPressed: onAddProgress,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AppleButton(
                  label: 'Renovar',
                  color: const Color(0xFF34C759),
                  onPressed: onRenovar,
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
                  color: Colors.blueGrey,
                  onPressed: onChangeTariff,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AppleButton(
                  label: 'Extras',
                  color: const Color(0xFFFF9500),
                  onPressed: onManageExtras,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          if (historial.isNotEmpty) ...[
            _sectionTitle('MAPA CORPORAL'),
            HeatmapPanel(historial: historial),
            const SizedBox(height: 24),
            _sectionTitle('EVOLUCIÓN'),
            WeightChart(historial: historial),
            const SizedBox(height: 16),
            BodyFatChart(historial: historial),
            const SizedBox(height: 16),
            MuscleChart(historial: historial),
          ] else ...[
            const Center(
              child: Text(
                'No hay registros de progreso',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF8E8E93), // iOS Section Title Gray
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
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
                  vertical: 12,
                ),
                child: child,
              ),
              if (index < children.length - 1)
                const Divider(height: 1, indent: 16, thickness: 0.5),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _appleRow(String label, String? value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 17, color: Colors.black)),
        Text(
          value ?? '-',
          style: TextStyle(
            fontSize: 17,
            color: valueColor ?? const Color(0xFF8E8E93),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionCounter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sesiones (Dic)',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${cliente.sesionesCounter ?? 2}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.remove_circle,
                  color: Color(0xFFFF3B30),
                  size: 32,
                ),
                onPressed: () => onSessionAction?.call('decrement'),
              ),
              const SizedBox(width: 32),
              IconButton(
                icon: const Icon(
                  Icons.add_circle,
                  color: Color(0xFF34C759),
                  size: 32,
                ),
                onPressed: () => onSessionAction?.call('increment'),
              ),
            ],
          ),
          const Text(
            'Se reinicia cada mes',
            style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
          ),
        ],
      ),
    );
  }
}

class _ObjectiveChip extends StatelessWidget {
  final String label;
  const _ObjectiveChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
    );
  }
}

class _AppleButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _AppleButton({
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
