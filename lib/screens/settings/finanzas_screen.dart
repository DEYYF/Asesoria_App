import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/budget_detail_dialog.dart';

class FinanzasScreen extends StatefulWidget {
  const FinanzasScreen({super.key});

  @override
  State<FinanzasScreen> createState() => _FinanzasScreenState();
}

class _FinanzasScreenState extends State<FinanzasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _resumen = {};
  List<dynamic> _movimientos = [];
  List<dynamic> _controlPagos = [];
  List<dynamic> _historicoGrafico = [];
  final _currencyFormat = NumberFormat.currency(symbol: '€', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);

    try {
      final responses = await Future.wait([
        api.get('/finanzas/resumen?asesorId=${auth.userId}'),
        api.get('/finanzas/movimientos?asesorId=${auth.userId}'),
        api.get('/finanzas/control-pagos?asesorId=${auth.userId}'),
        api.get('/finanzas/historico-grafico?asesorId=${auth.userId}'),
      ]);

      if (mounted) {
        setState(() {
          _resumen = jsonDecode(responses[0].body);
          _movimientos = jsonDecode(responses[1].body);
          _controlPagos = jsonDecode(responses[2].body);
          _historicoGrafico = jsonDecode(responses[3].body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading finanzas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos financieros: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Panel Financiero'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.primaryColor,
          labelColor: theme.primaryColor,
          unselectedLabelColor: theme.hintColor,
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Pagos'),
            Tab(text: 'Historial'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildResumenTab(),
                _buildPagosTab(),
                _buildMovimientosTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMovimiento,
        icon: const Icon(Icons.add),
        label: const Text('Registro Manual'),
      ),
    );
  }

  Widget _buildResumenTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSummaryCards(),
        const SizedBox(height: 32),
        _buildSectionHeader('TENDENCIA DE INGRESOS Y GASTOS'),
        const SizedBox(height: 16),
        _buildChart(),
        const SizedBox(height: 32),
        _buildSectionHeader('ESTADÍSTICAS RÁPIDAS'),
        const SizedBox(height: 12),
        _buildQuickStats(),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildSummaryCards() {
    final mes =
        _resumen['mesActual'] ??
        {'ingresos': 0.0, 'gastos': 0.0, 'balance': 0.0};

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF007AFF), Color(0xFF00C7BE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Balance del Mes',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            _currencyFormat.format(mes['balance'] ?? 0),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _SummaryMiniItem(
                label: 'Ingresos',
                amount: _currencyFormat.format(mes['ingresos'] ?? 0),
                icon: Icons.arrow_upward_rounded,
                color: Colors.greenAccent,
              ),
              const Spacer(),
              _SummaryMiniItem(
                label: 'Gastos',
                amount: _currencyFormat.format(mes['gastos'] ?? 0),
                icon: Icons.arrow_downward_rounded,
                color: Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    if (_historicoGrafico.isEmpty)
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No hay datos suficientes')),
      );

    final theme = Theme.of(context);

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int idx = value.toInt();
                  if (idx >= 0 && idx < _historicoGrafico.length) {
                    return Text(
                      _historicoGrafico[idx]['mes'],
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            // Ingresos
            LineChartBarData(
              spots: _historicoGrafico
                  .asMap()
                  .entries
                  .map(
                    (e) => FlSpot(
                      e.key.toDouble(),
                      (e.value['ingresos'] as num).toDouble(),
                    ),
                  )
                  .toList(),
              isCurved: true,
              color: Colors.greenAccent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.greenAccent.withOpacity(0.1),
              ),
            ),
            // Gastos
            LineChartBarData(
              spots: _historicoGrafico
                  .asMap()
                  .entries
                  .map(
                    (e) => FlSpot(
                      e.key.toDouble(),
                      (e.value['gastos'] as num).toDouble(),
                    ),
                  )
                  .toList(),
              isCurved: true,
              color: Colors.redAccent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.redAccent.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    final hist =
        _resumen['historico'] ??
        {'ingresos': 0.0, 'gastos': 0.0, 'balance': 0.0};
    final theme = Theme.of(context);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Ingresos Totales',
          hist['ingresos'],
          Colors.green,
          theme,
        ),
        _buildStatCard('Gastos Totales', hist['gastos'], Colors.red, theme),
        _buildStatCard(
          'Balance Histórico',
          hist['balance'],
          Colors.blue,
          theme,
        ),
        _buildStatCard(
          'Clientes con Pagos',
          _controlPagos.where((c) => c['status'] == 'AL_DIA').length.toDouble(),
          Colors.orange,
          theme,
          isCurrency: false,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    num value,
    Color color,
    ThemeData theme, {
    bool isCurrency = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: theme.hintColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isCurrency
                  ? _currencyFormat.format(value)
                  : value.toInt().toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagosTab() {
    if (_controlPagos.isEmpty)
      return _buildEmptyState('No hay clientes registrados');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _controlPagos.length,
      itemBuilder: (context, index) {
        final c = _controlPagos[index];
        final status = c['status'];

        Color statusColor;
        String statusText;
        IconData icon;

        switch (status) {
          case 'AL_DIA':
            statusColor = Colors.green;
            statusText = 'Pagado';
            icon = Icons.check_circle_outline;
            break;
          case 'EXPIRADO':
            statusColor = Colors.red;
            statusText = 'Caducado';
            icon = Icons.error_outline;
            break;
          case 'ESPERANDO_PAGO':
            statusColor = Colors.orange;
            statusText = 'Aceptado';
            icon = Icons.hourglass_empty;
            break;
          default:
            statusColor = Colors.grey;
            statusText = 'Pendiente';
            icon = Icons.help_outline;
        }

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.05),
            ),
          ),
          child: ListTile(
            onTap: () => context.go('/clientes/${c['id']}'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.1),
              child: Icon(icon, color: statusColor, size: 24),
            ),
            title: Text(
              c['nombre'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  c['email'],
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (c['fechaFin'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Vence: ${DateFormat('dd MMM yyyy').format(DateTime.parse(c['fechaFin']))}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                if (c['presupuestoId'] != null)
                  IconButton(
                    icon: const Icon(Icons.receipt_long_outlined, size: 20),
                    onPressed: () => _showBudgetDetail(c['presupuestoId']),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMovimientosTab() {
    if (_movimientos.isEmpty)
      return _buildEmptyState('No hay movimientos registrados');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _movimientos.length,
      itemBuilder: (context, index) {
        final m = _movimientos[index];
        final isIngreso = m['tipoMovimiento'] == 'INGRESO';
        final theme = Theme.of(context);
        final date = DateTime.parse(m['fecha']).toLocal();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isIngreso ? Colors.green : Colors.red).withOpacity(
                    0.1,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIngreso ? Icons.add_rounded : Icons.remove_rounded,
                  color: isIngreso ? Colors.green : Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m['descripcion'] ?? 'Sin descripción',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${DateFormat('dd MMM, HH:mm').format(date)} · ${m['categoria']}',
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIngreso ? '+' : '-'}${_currencyFormat.format(m['monto'])}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: isIngreso
                          ? Colors.green
                          : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  if (m['presupuestoId'] != null)
                    const Icon(Icons.link, size: 12, color: Colors.blue),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.grey.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  void _showBudgetDetail(String id) async {
    final api = Provider.of<ApiService>(context, listen: false);

    bool loaderVisible = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    ).then((_) => loaderVisible = false);

    try {
      final res = await api.get('/presupuestos/$id');

      if (mounted && loaderVisible) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (res.statusCode == 200) {
        final budget = jsonDecode(res.body);
        if (mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => BudgetDetailDialog(budget: budget),
          );
        }
      } else {
        throw Exception('Error al obtener el presupuesto: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Error showing budget detail: $e');
      if (mounted) {
        if (loaderVisible) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddMovimiento() {
    final descripcionCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    String type = 'GASTO';
    String category = 'General';
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nuevo Registro',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'INGRESO',
                      label: Text('Ingreso'),
                      icon: Icon(Icons.add_circle_outline),
                    ),
                    ButtonSegment(
                      value: 'GASTO',
                      label: Text('Gasto'),
                      icon: Icon(Icons.remove_circle_outline),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (val) => setS(() => type = val.first),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: montoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Monto (€)',
                    prefixIcon: Icon(Icons.euro_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Ingresa un monto';
                    final n = double.tryParse(value.replaceAll(',', '.'));
                    if (n == null) return 'Monto no válido';
                    if (n <= 0) return 'El monto debe ser positivo';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descripcionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Ingresa una descripción';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items:
                      [
                            'General',
                            'Suscripción',
                            'Equipamiento',
                            'Publicidad',
                            'Local',
                            'Sueldo',
                            'Otros',
                          ]
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                  onChanged: (val) => setS(() => category = val!),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final auth = Provider.of<AuthService>(
                        context,
                        listen: false,
                      );
                      final api = Provider.of<ApiService>(
                        context,
                        listen: false,
                      );
                      try {
                        final res = await api.post('/finanzas/movimientos', {
                          'asesorId': auth.userId,
                          'descripcion': descripcionCtrl.text.trim(),
                          'monto': double.parse(
                            montoCtrl.text.replaceAll(',', '.'),
                          ),
                          'tipoMovimiento': type,
                          'categoria': category,
                        });
                        if (res.statusCode == 201) {
                          Navigator.pop(ctx);
                          _loadData();
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                    child: const Text('Guardar Registro'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryMiniItem extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color color;

  const _SummaryMiniItem({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          amount,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
