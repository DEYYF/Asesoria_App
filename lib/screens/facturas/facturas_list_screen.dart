import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/factura_model.dart';
import '../../services/factura_service.dart';
import '../../services/api_service.dart';
import 'factura_detail_screen.dart';
import 'create_factura_screen.dart';
import 'package:intl/intl.dart';

class FacturasListScreen extends StatefulWidget {
  const FacturasListScreen({super.key});

  @override
  State<FacturasListScreen> createState() => _FacturasListScreenState();
}

class _FacturasListScreenState extends State<FacturasListScreen> {
  late FacturaService _facturaService;
  List<Factura> _facturas = [];
  bool _isLoading = true;
  String? _estadoFilter;

  final List<String> _estados = [
    'Todas',
    'pendiente',
    'pagada',
    'vencida',
    'cancelada',
  ];

  @override
  void initState() {
    super.initState();
    _facturaService = FacturaService(
      Provider.of<ApiService>(context, listen: false),
    );
    _loadFacturas();
  }

  Future<void> _loadFacturas() async {
    setState(() => _isLoading = true);
    try {
      final facturas = await _facturaService.getFacturas(estado: _estadoFilter);
      setState(() {
        _facturas = facturas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Facturas'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: theme.textTheme.titleLarge?.color,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateFacturaScreen()),
          );
          if (result == true) _loadFacturas();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva Factura'),
        backgroundColor: theme.primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFacturas,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatsCards(theme, isDark),
                  const SizedBox(height: 24),
                  _buildFilterChips(theme),
                  const SizedBox(height: 16),
                  if (_facturas.isEmpty)
                    _buildEmptyState(theme)
                  else
                    ..._facturas.map(
                      (factura) => _buildFacturaCard(factura, theme, isDark),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCards(ThemeData theme, bool isDark) {
    final pendientes = _facturas.where((f) => f.estado == 'pendiente').length;
    final pagadas = _facturas.where((f) => f.estado == 'pagada').length;
    final totalPendiente = _facturas
        .where((f) => f.estado == 'pendiente')
        .fold(0.0, (sum, f) => sum + f.total);

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Pendientes',
            pendientes.toString(),
            Icons.pending_actions_rounded,
            Colors.orange,
            theme,
            isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Pagadas',
            pagadas.toString(),
            Icons.check_circle_rounded,
            Colors.green,
            theme,
            isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Por Cobrar',
            '${totalPendiente.toStringAsFixed(0)}€',
            Icons.euro_rounded,
            theme.primaryColor,
            theme,
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.hintColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _estados.map((estado) {
          final isSelected = estado == 'Todas'
              ? _estadoFilter == null
              : _estadoFilter == estado;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(estado == 'Todas' ? 'Todas' : estado.toUpperCase()),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _estadoFilter = estado == 'Todas' ? null : estado;
                });
                _loadFacturas();
              },
              selectedColor: theme.primaryColor.withOpacity(0.2),
              checkmarkColor: theme.primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? theme.primaryColor : theme.hintColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFacturaCard(Factura factura, ThemeData theme, bool isDark) {
    Color estadoColor;
    IconData estadoIcon;

    switch (factura.estado) {
      case 'pagada':
        estadoColor = Colors.green;
        estadoIcon = Icons.check_circle_rounded;
        break;
      case 'vencida':
        estadoColor = Colors.red;
        estadoIcon = Icons.error_rounded;
        break;
      case 'cancelada':
        estadoColor = Colors.grey;
        estadoIcon = Icons.cancel_rounded;
        break;
      default:
        estadoColor = Colors.orange;
        estadoIcon = Icons.pending_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FacturaDetailScreen(facturaId: factura.id),
            ),
          );
          if (result == true) _loadFacturas();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(estadoIcon, color: estadoColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      factura.numeroFactura,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      factura.clienteNombre ?? factura.datosReceptor.nombre,
                      style: TextStyle(color: theme.hintColor, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      factura.concepto,
                      style: TextStyle(color: theme.hintColor, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: theme.hintColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd/MM/yyyy').format(factura.fecha),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.hintColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (factura.isPendiente && !factura.isVencida) ...[
                          Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${factura.diasVencimiento} días',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${factura.total.toStringAsFixed(2)}€',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      factura.estado.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: estadoColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 80,
              color: theme.hintColor.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay facturas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea tu primera factura',
              style: TextStyle(
                fontSize: 14,
                color: theme.hintColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    // TODO: Implementar diálogo de filtros avanzados
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtros'),
        content: const Text('Próximamente: filtros por fecha, cliente, etc.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
