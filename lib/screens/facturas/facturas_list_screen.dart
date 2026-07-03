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
  String _search = '';

  final List<String> _estados = ['Todas', 'pendiente', 'pagada', 'vencida', 'cancelada'];
  final _currency = NumberFormat.currency(locale: 'es_ES', symbol: '€');

  @override
  void initState() {
    super.initState();
    _facturaService = FacturaService(Provider.of<ApiService>(context, listen: false));
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  List<Factura> get _filteredFacturas {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _facturas;
    return _facturas.where((f) {
      final cliente = (f.clienteNombre ?? f.datosReceptor.nombre).toLowerCase();
      return f.numeroFactura.toLowerCase().contains(q) || cliente.contains(q) || f.concepto.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Facturación'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: theme.textTheme.titleLarge?.color, fontSize: 22, fontWeight: FontWeight.w800),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateFacturaScreen()));
          if (result == true) _loadFacturas();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Crear factura'),
        backgroundColor: theme.primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFacturas,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  _buildHero(theme, isDark),
                  const SizedBox(height: 16),
                  _buildSearch(theme, isDark),
                  const SizedBox(height: 12),
                  _buildFilterChips(theme),
                  const SizedBox(height: 16),
                  _buildSectionHeader(theme),
                  const SizedBox(height: 10),
                  if (_filteredFacturas.isEmpty) _buildEmptyState(theme) else ..._filteredFacturas.map((f) => _buildFacturaCard(f, theme, isDark)),
                ],
              ),
            ),
    );
  }

  Widget _buildHero(ThemeData theme, bool isDark) {
    final pagadas = _facturas.where((f) => f.estado == 'pagada').fold(0.0, (s, f) => s + f.total);
    final pendientes = _facturas.where((f) => f.estado == 'pendiente').fold(0.0, (s, f) => s + f.total);
    final vencidas = _facturas.where((f) => f.isVencida || f.estado == 'vencida').fold(0.0, (s, f) => s + f.total);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151517) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: theme.primaryColor.withOpacity(.12), borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.receipt_long_rounded, color: theme.primaryColor),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Control de facturas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _metric('Cobrado', _currency.format(pagadas), Icons.check_circle_rounded, Colors.green, isDark)),
              const SizedBox(width: 10),
              Expanded(child: _metric('Pendiente', _currency.format(pendientes), Icons.schedule_rounded, Colors.orange, isDark)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _metric('Vencido', _currency.format(vencidas), Icons.warning_rounded, Colors.red, isDark)),
              const SizedBox(width: 10),
              Expanded(child: _metric('Facturas', _facturas.length.toString(), Icons.numbers_rounded, theme.primaryColor, isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(.05) : const Color(0xFFF7F8FB), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(ThemeData theme, bool isDark) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Buscar por cliente, número o concepto',
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: isDark ? const Color(0xFF151517) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onChanged: (value) => setState(() => _search = value),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    String labelFor(String estado) {
      if (estado == 'Todas') return 'Todas';
      if (estado == 'pagada') return 'Pagadas';
      if (estado == 'pendiente') return 'Pendientes';
      if (estado == 'vencida') return 'Vencidas';
      return 'Canceladas';
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _estados.map((estado) {
          final isSelected = estado == 'Todas' ? _estadoFilter == null : _estadoFilter == estado;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(labelFor(estado)),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _estadoFilter = estado == 'Todas' ? null : estado);
                _loadFacturas();
              },
              selectedColor: theme.primaryColor.withOpacity(.16),
              labelStyle: TextStyle(color: isSelected ? theme.primaryColor : theme.textTheme.bodyMedium?.color, fontWeight: FontWeight.w700),
              side: BorderSide(color: isSelected ? theme.primaryColor.withOpacity(.35) : Colors.transparent),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Listado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: theme.textTheme.bodyLarge?.color)),
        Text('${_filteredFacturas.length} resultado(s)', style: TextStyle(fontSize: 12, color: theme.hintColor)),
      ],
    );
  }

  Widget _buildFacturaCard(Factura factura, ThemeData theme, bool isDark) {
    final color = _estadoColor(factura);
    final icon = _estadoIcon(factura);
    final cliente = factura.clienteNombre ?? factura.datosReceptor.nombre;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151517) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.16)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => FacturaDetailScreen(facturaId: factura.id)));
          if (result == true) _loadFacturas();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(factura.numeroFactura, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(cliente.isEmpty ? 'Cliente sin nombre' : cliente, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.hintColor, fontSize: 13)),
                    ]),
                  ),
                  Text(_currency.format(factura.total), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: theme.primaryColor)),
                ],
              ),
              const SizedBox(height: 12),
              Text(factura.concepto, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _smallChip(DateFormat('dd/MM/yyyy').format(factura.fecha), Icons.calendar_today_rounded, theme.hintColor),
                  const SizedBox(width: 8),
                  _smallChip(_estadoLabel(factura), icon, color),
                  if (factura.isPendiente && !factura.isVencida) ...[
                    const SizedBox(width: 8),
                    _smallChip('Vence en ${factura.diasVencimiento} días', Icons.schedule_rounded, Colors.orange),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallChip(String text, IconData icon, Color color) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }

  Color _estadoColor(Factura f) {
    if (f.isVencida || f.estado == 'vencida') return Colors.red;
    switch (f.estado) {
      case 'pagada': return Colors.green;
      case 'cancelada': return Colors.grey;
      default: return Colors.orange;
    }
  }

  IconData _estadoIcon(Factura f) {
    if (f.isVencida || f.estado == 'vencida') return Icons.warning_rounded;
    switch (f.estado) {
      case 'pagada': return Icons.check_circle_rounded;
      case 'cancelada': return Icons.cancel_rounded;
      default: return Icons.schedule_rounded;
    }
  }

  String _estadoLabel(Factura f) {
    if (f.isVencida || f.estado == 'vencida') return 'Vencida';
    switch (f.estado) {
      case 'pagada': return 'Pagada';
      case 'cancelada': return 'Cancelada';
      default: return 'Pendiente';
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded, size: 72, color: theme.hintColor.withOpacity(.35)),
          const SizedBox(height: 16),
          const Text('No hay facturas para mostrar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Crea una factura o cambia los filtros.', style: TextStyle(color: theme.hintColor)),
        ],
      ),
    );
  }
}
