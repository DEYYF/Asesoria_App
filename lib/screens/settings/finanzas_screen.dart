import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/super_admin_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/notification_helper.dart';
import '../../widgets/advisor_selector.dart';
import '../../widgets/budget_detail_dialog.dart';
import '../facturas/create_factura_screen.dart';
import '../facturas/facturas_list_screen.dart';

class FinanzasScreen extends StatefulWidget {
  const FinanzasScreen({super.key});

  @override
  State<FinanzasScreen> createState() => _FinanzasScreenState();
}

class _FinanzasScreenState extends State<FinanzasScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _isLoading = true;
  Map<String, dynamic> _resumen = {};
  List<dynamic> _movimientos = [];
  List<dynamic> _controlPagos = [];
  List<dynamic> _historicoGrafico = [];

  String _selectedPeriod = 'mensual';
  String _paymentFilter = 'TODOS';

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_ES',
    symbol: '€',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final saProvider = Provider.of<SuperAdminProvider>(
        context,
        listen: false,
      );
      saProvider.addListener(_onAdvisorChanged);
    });
  }

  @override
  void dispose() {
    try {
      final saProvider = Provider.of<SuperAdminProvider>(
        context,
        listen: false,
      );
      saProvider.removeListener(_onAdvisorChanged);
    } catch (_) {}
    _tabController.dispose();
    super.dispose();
  }

  void _onAdvisorChanged() {
    if (mounted) _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final saProvider = Provider.of<SuperAdminProvider>(context, listen: false);

    try {
      final query = <String>[];
      if (auth.isSuperAdmin) {
        if (saProvider.selectedAdvisorId != null) {
          query.add('asesorId=${saProvider.selectedAdvisorId}');
        }
      } else if (auth.userId != null) {
        query.add('asesorId=${auth.userId}');
      }
      query.add('periodo=$_selectedPeriod');
      final fullQuery = query.join('&');

      final responses = await Future.wait([
        api.get('/finanzas/resumen?$fullQuery'),
        api.get('/finanzas/movimientos?$fullQuery'),
        api.get('/finanzas/control-pagos?$fullQuery'),
        api.get('/finanzas/historico-grafico?$fullQuery'),
      ]);

      if (!mounted) return;
      setState(() {
        _resumen = _decodeMap(responses[0].body);
        _movimientos = _decodeList(responses[1].body);
        _controlPagos = _decodeList(responses[2].body);
        _historicoGrafico = _decodeList(responses[3].body);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading finanzas: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      NotificationHelper.showError(
        context,
        'Error al cargar el panel financiero: $e',
      );
    }
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }

  List<dynamic> _decodeList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is List) return decoded;
    return [];
  }

  num _num(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value.replaceAll(',', '.')) ?? 0;
    return 0;
  }

  String _money(dynamic value) => _currencyFormat.format(_num(value));

  Map<String, dynamic> get _periodoActual {
    final raw = _resumen['periodoActual'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {'ingresos': 0, 'gastos': 0, 'balance': 0};
  }

  Map<String, dynamic> get _historico {
    final raw = _resumen['historico'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {'ingresos': 0, 'gastos': 0, 'balance': 0};
  }

  List<dynamic> get _filteredPayments {
    if (_paymentFilter == 'TODOS') return _controlPagos;
    return _controlPagos.where((p) => p['status'] == _paymentFilter).toList();
  }

  int get _paidCount =>
      _controlPagos.where((p) => p['status'] == 'AL_DIA').length;

  int get _expiredCount =>
      _controlPagos.where((p) => p['status'] == 'EXPIRADO').length;

  int get _waitingCount =>
      _controlPagos.where((p) => p['status'] == 'ESPERANDO_PAGO').length;

  double get _collectionHealth {
    if (_controlPagos.isEmpty) return 0;
    return (_paidCount / _controlPagos.length).clamp(0, 1).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Panel financiero'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Actualizar datos',
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.primaryColor,
          labelColor: theme.primaryColor,
          unselectedLabelColor: theme.hintColor,
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Cobros'),
            Tab(text: 'Movimientos'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMovimiento,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Movimiento'),
      ),
      body: Column(
        children: [
          if (Provider.of<AuthService>(context, listen: false).isSuperAdmin)
            const AdvisorSelector(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: _buildPeriodSelector(),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildResumenTab(),
                        _buildPagosTab(),
                        _buildMovimientosTab(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenTab() {
    final periodo = _periodoActual;
    final ingresos = _num(periodo['ingresos']);
    final gastos = _num(periodo['gastos']);
    final balance = _num(periodo['balance']);
    final margin = ingresos <= 0 ? 0.0 : (balance / ingresos).clamp(-1, 1).toDouble();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      children: [
        _buildHeroCard(ingresos: ingresos, gastos: gastos, balance: balance),
        const SizedBox(height: 16),
        _buildKpiGrid(margin: margin),
        const SizedBox(height: 24),
        _buildSectionTitle(
          'Flujo de caja',
          _selectedPeriod == 'mensual'
              ? 'Ingresos y gastos de los últimos meses'
              : 'Evolución anual agrupada por mes',
        ),
        const SizedBox(height: 12),
        _buildChart(),
        const SizedBox(height: 24),
        _buildSectionTitle(
          'Estado de cobros',
          'Clientes al día, vencidos o esperando pago',
        ),
        const SizedBox(height: 12),
        _buildCollectionHealthCard(),
        const SizedBox(height: 24),
        _buildSectionTitle('Acciones rápidas', 'Atajos útiles del área financiera'),
        const SizedBox(height: 12),
        _buildQuickActions(),
      ],
    );
  }

  Widget _buildHeroCard({
    required num ingresos,
    required num gastos,
    required num balance,
  }) {
    final theme = Theme.of(context);
    final isPositive = balance >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor,
            theme.primaryColor.withValues(alpha: 0.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedPeriod == 'mensual'
                          ? 'Resultado mensual'
                          : 'Resultado anual',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isPositive ? 'Negocio en positivo' : 'Revisar gastos',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isPositive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 20),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _money(balance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.1,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _HeroMiniMetric(
                  label: 'Ingresos',
                  value: _money(ingresos),
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroMiniMetric(
                  label: 'Gastos',
                  value: _money(gastos),
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid({required double margin}) {
    final hist = _historico;
    final totalClients = _controlPagos.length;
    final marginText = '${(margin * 100).toStringAsFixed(0)}%';

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 620 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: constraints.maxWidth > 620 ? 1.45 : 1.23,
          children: [
            _FinanceKpiCard(
              title: 'Ingresos totales',
              value: _money(hist['ingresos']),
              icon: Icons.trending_up_rounded,
              color: Colors.green,
            ),
            _FinanceKpiCard(
              title: 'Gastos totales',
              value: _money(hist['gastos']),
              icon: Icons.trending_down_rounded,
              color: Colors.redAccent,
            ),
            _FinanceKpiCard(
              title: 'Margen periodo',
              value: marginText,
              icon: Icons.percent_rounded,
              color: Theme.of(context).primaryColor,
            ),
            _FinanceKpiCard(
              title: 'Clientes controlados',
              value: totalClients.toString(),
              icon: Icons.groups_rounded,
              color: Colors.orange,
            ),
          ],
        );
      },
    );
  }

  Widget _buildChart() {
    final theme = Theme.of(context);

    if (_historicoGrafico.isEmpty) {
      return _buildEmptyPanel(
        icon: Icons.query_stats_rounded,
        title: 'Sin histórico suficiente',
        message: 'Cuando haya movimientos, aparecerá aquí la tendencia.',
      );
    }

    final ingresosSpots = <FlSpot>[];
    final gastosSpots = <FlSpot>[];
    double maxY = 0;

    for (int i = 0; i < _historicoGrafico.length; i++) {
      final row = _historicoGrafico[i];
      final ingresos = _num(row['ingresos']).toDouble();
      final gastos = _num(row['gastos']).toDouble();
      ingresosSpots.add(FlSpot(i.toDouble(), ingresos));
      gastosSpots.add(FlSpot(i.toDouble(), gastos));
      if (ingresos > maxY) maxY = ingresos;
      if (gastos > maxY) maxY = gastos;
    }

    if (maxY <= 0) maxY = 100;

    return _PanelCard(
      child: SizedBox(
        height: 260,
        child: Column(
          children: [
            Row(
              children: [
                _buildChartLegend('Ingresos', Colors.green),
                const SizedBox(width: 14),
                _buildChartLegend('Gastos', Colors.redAccent),
                const Spacer(),
                Text(
                  _selectedPeriod == 'mensual' ? 'Últimos meses' : 'Año',
                  style: TextStyle(
                    color: theme.hintColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY * 1.2,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: theme.dividerColor.withValues(alpha: 0.12),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
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
                        interval: 1,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= _historicoGrafico.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              '${_historicoGrafico[index]['mes'] ?? ''}',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.hintColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((spot) {
                        final isIncome = spot.barIndex == 0;
                        return LineTooltipItem(
                          '${isIncome ? 'Ingresos' : 'Gastos'}\n${_money(spot.y)}',
                          TextStyle(
                            color: isIncome ? Colors.green : Colors.redAccent,
                            fontWeight: FontWeight.w800,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    _chartLine(ingresosSpots, Colors.green),
                    _chartLine(gastosSpots, Colors.redAccent),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _chartLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 4,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionHealthCard() {
    final theme = Theme.of(context);
    final total = _controlPagos.length;
    final health = _collectionHealth;

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.health_and_safety_rounded,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Salud de cobros',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      total == 0
                          ? 'No hay clientes en control de pagos'
                          : '$_paidCount de $total clientes al día',
                      style: TextStyle(color: theme.hintColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '${(health * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: health,
              minHeight: 10,
              backgroundColor: theme.dividerColor.withValues(alpha: 0.14),
              color: health >= 0.75
                  ? Colors.green
                  : health >= 0.45
                      ? Colors.orange
                      : Colors.redAccent,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatusPill(
                  label: 'Pagados',
                  value: _paidCount.toString(),
                  color: Colors.green,
                  icon: Icons.check_circle_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusPill(
                  label: 'Pendientes',
                  value: _waitingCount.toString(),
                  color: Colors.orange,
                  icon: Icons.hourglass_top_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusPill(
                  label: 'Vencidos',
                  value: _expiredCount.toString(),
                  color: Colors.redAccent,
                  icon: Icons.warning_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                title: 'Crear factura',
                subtitle: 'Emitir una nueva factura',
                icon: Icons.receipt_long_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateFacturaScreen()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                title: 'Ver facturas',
                subtitle: 'Listado y estados',
                icon: Icons.list_alt_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FacturasListScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                title: 'Presupuestos',
                subtitle: 'Borradores y aceptados',
                icon: Icons.request_quote_rounded,
                onTap: () => context.go('/presupuestos'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                title: 'Añadir gasto',
                subtitle: 'Registro manual',
                icon: Icons.add_card_rounded,
                onTap: _showAddMovimiento,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPagosTab() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      children: [
        _buildSectionTitle(
          _selectedPeriod == 'mensual' ? 'Cobros del mes' : 'Cobros del año',
          'Controla clientes vencidos, pendientes y al día',
        ),
        const SizedBox(height: 12),
        _buildPaymentFilters(),
        const SizedBox(height: 16),
        if (_filteredPayments.isEmpty)
          _buildEmptyPanel(
            icon: Icons.payments_outlined,
            title: 'Sin cobros en este filtro',
            message: 'Cambia el filtro o revisa otro periodo.',
          )
        else
          ..._filteredPayments.map(_buildPaymentCard),
      ],
    );
  }

  Widget _buildPaymentFilters() {
    final items = <Map<String, dynamic>>[
      {
        'value': 'TODOS',
        'label': 'Todos',
        'count': _controlPagos.length,
        'color': Theme.of(context).primaryColor,
      },
      {
        'value': 'AL_DIA',
        'label': 'Pagados',
        'count': _paidCount,
        'color': Colors.green,
      },
      {
        'value': 'ESPERANDO_PAGO',
        'label': 'Pendientes',
        'count': _waitingCount,
        'color': Colors.orange,
      },
      {
        'value': 'EXPIRADO',
        'label': 'Vencidos',
        'count': _expiredCount,
        'color': Colors.redAccent,
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final value = item['value'] as String;
          final label = item['label'] as String;
          final count = item['count'] as int;
          final color = item['color'] as Color;
          final selected = _paymentFilter == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              label: Text('$label · $count'),
              selectedColor: color.withValues(alpha: 0.16),
              checkmarkColor: color,
              labelStyle: TextStyle(
                color: selected ? color : Theme.of(context).hintColor,
                fontWeight: FontWeight.w800,
              ),
              side: BorderSide(
                color: selected
                    ? color.withValues(alpha: 0.45)
                    : Theme.of(context).dividerColor.withValues(alpha: 0.18),
              ),
              onSelected: (_) => setState(() => _paymentFilter = value),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaymentCard(dynamic raw) {
    final c = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final theme = Theme.of(context);
    final meta = _paymentMeta(c['status']);
    final nombre = (c['nombre'] ?? 'Cliente sin nombre').toString();
    final email = (c['email'] ?? '').toString();
    final fechaFin = _parseDate(c['fechaFin']);

    return _PanelCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: c['id'] != null ? () => context.go('/clientes/${c['id']}') : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: meta.color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.hintColor, fontSize: 12),
                      ),
                    ],
                    if (fechaFin != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.event_rounded,
                            size: 13,
                            color: meta.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Vence ${DateFormat('dd MMM yyyy').format(fechaFin)}',
                            style: TextStyle(
                              color: meta.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SmallStatusBadge(meta: meta),
                  if (c['presupuestoId'] != null) ...[
                    const SizedBox(height: 8),
                    IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      tooltip: 'Ver presupuesto',
                      icon: const Icon(Icons.receipt_long_rounded),
                      onPressed: () => _showBudgetDetail('${c['presupuestoId']}'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMovimientosTab() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      children: [
        _buildSectionTitle(
          _selectedPeriod == 'mensual'
              ? 'Movimientos de este mes'
              : 'Movimientos de este año',
          'Ingresos, gastos y registros manuales',
        ),
        const SizedBox(height: 12),
        if (_movimientos.isEmpty)
          _buildEmptyPanel(
            icon: Icons.history_rounded,
            title: 'Sin movimientos',
            message: 'Añade un registro manual o genera facturas para ver actividad.',
          )
        else
          ..._movimientos.map(_buildMovementCard),
      ],
    );
  }

  Widget _buildMovementCard(dynamic raw) {
    final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final theme = Theme.of(context);
    final isIngreso = m['tipoMovimiento'] == 'INGRESO';
    final color = isIngreso ? Colors.green : Colors.redAccent;
    final date = _parseDate(m['fecha']) ?? DateTime.now();
    final categoria = (m['categoria'] ?? 'General').toString();

    return _PanelCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isIngreso
                  ? Icons.keyboard_double_arrow_up_rounded
                  : Icons.keyboard_double_arrow_down_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (m['descripcion'] ?? 'Sin descripción').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      DateFormat('dd MMM · HH:mm').format(date),
                      style: TextStyle(
                        color: theme.hintColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        categoria.toUpperCase(),
                        style: TextStyle(
                          color: theme.hintColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIngreso ? '+' : '-'}${_money(m['monto'])}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
              ),
              if (m['presupuestoId'] != null)
                Text(
                  'PRESUPUESTO',
                  style: TextStyle(
                    color: theme.primaryColor.withValues(alpha: 0.72),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          _buildPeriodOption('mensual', 'Mensual'),
          _buildPeriodOption('anual', 'Anual'),
        ],
      ),
    );
  }

  Widget _buildPeriodOption(String value, String label) {
    final theme = Theme.of(context);
    final selected = _selectedPeriod == value;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: selected
            ? null
            : () {
                setState(() => _selectedPeriod = value);
                _loadData();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? theme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: theme.primaryColor.withValues(alpha: 0.24),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : theme.hintColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: theme.hintColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).hintColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPanel({
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    return _PanelCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(icon, size: 46, color: theme.hintColor.withValues(alpha: 0.32)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.hintColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  _PaymentMeta _paymentMeta(dynamic status) {
    switch (status) {
      case 'AL_DIA':
        return const _PaymentMeta(
          label: 'Pagado',
          icon: Icons.check_circle_rounded,
          color: Colors.green,
        );
      case 'EXPIRADO':
        return const _PaymentMeta(
          label: 'Vencido',
          icon: Icons.error_rounded,
          color: Colors.redAccent,
        );
      case 'ESPERANDO_PAGO':
        return const _PaymentMeta(
          label: 'Pendiente',
          icon: Icons.hourglass_top_rounded,
          color: Colors.orange,
        );
      default:
        return const _PaymentMeta(
          label: 'Revisar',
          icon: Icons.help_rounded,
          color: Colors.grey,
        );
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  Future<void> _showBudgetDetail(String id) async {
    final api = Provider.of<ApiService>(context, listen: false);

    var loaderVisible = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ).then((_) => loaderVisible = false);

    try {
      final res = await api.get('/presupuestos/$id');

      if (mounted && loaderVisible) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (res.statusCode == 200) {
        final budget = jsonDecode(res.body);
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => BudgetDetailDialog(budget: budget),
        );
      } else {
        throw Exception('Error al obtener el presupuesto: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Error showing budget detail: $e');
      if (!mounted) return;
      if (loaderVisible) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      NotificationHelper.showError(context, 'Error: $e');
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
        builder: (ctx, setS) {
          final theme = Theme.of(context);
          return SafeArea(
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                top: 12,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.dividerColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Nuevo movimiento',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.dividerColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _MovementTypeButton(
                                label: 'Ingreso',
                                selected: type == 'INGRESO',
                                color: Colors.green,
                                onTap: () => setS(() => type = 'INGRESO'),
                              ),
                            ),
                            Expanded(
                              child: _MovementTypeButton(
                                label: 'Gasto',
                                selected: type == 'GASTO',
                                color: Colors.redAccent,
                                onTap: () => setS(() => type = 'GASTO'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: montoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Importe',
                          prefixIcon: const Icon(Icons.euro_rounded),
                          filled: true,
                          fillColor: theme.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa un importe';
                          }
                          final n = double.tryParse(value.replaceAll(',', '.'));
                          if (n == null || n <= 0) return 'Importe no válido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: descripcionCtrl,
                        decoration: InputDecoration(
                          labelText: 'Concepto',
                          prefixIcon: const Icon(Icons.edit_note_rounded),
                          filled: true,
                          fillColor: theme.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa un concepto';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: InputDecoration(
                          labelText: 'Categoría',
                          prefixIcon: const Icon(Icons.grid_view_rounded),
                          filled: true,
                          fillColor: theme.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: const [
                          'General',
                          'Suscripción',
                          'Equipamiento',
                          'Publicidad',
                          'Local',
                          'Sueldo',
                          'Impuestos',
                          'Otros',
                        ]
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setS(() => category = value);
                        },
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: type == 'INGRESO'
                                ? Colors.green
                                : Colors.redAccent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
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
                              if (!mounted) return;
                              if (res.statusCode == 201 || res.statusCode == 200) {
                                Navigator.pop(ctx);
                                _loadData();
                                NotificationHelper.showSuccess(
                                  context,
                                  'Movimiento registrado',
                                );
                              } else {
                                throw Exception('Error ${res.statusCode}');
                              }
                            } catch (e) {
                              if (mounted) {
                                NotificationHelper.showError(context, 'Error: $e');
                              }
                            }
                          },
                          icon: const Icon(Icons.save_rounded),
                          label: const Text(
                            'Guardar movimiento',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HeroMiniMetric extends StatelessWidget {
  const _HeroMiniMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceKpiCard extends StatelessWidget {
  const _FinanceKpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PanelCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.hintColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).hintColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _PanelCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.primaryColor),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.hintColor, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMeta {
  const _PaymentMeta({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

class _SmallStatusBadge extends StatelessWidget {
  const _SmallStatusBadge({required this.meta});

  final _PaymentMeta meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, color: meta.color, size: 13),
          const SizedBox(width: 5),
          Text(
            meta.label.toUpperCase(),
            style: TextStyle(
              color: meta.color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementTypeButton extends StatelessWidget {
  const _MovementTypeButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Theme.of(context).hintColor,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
