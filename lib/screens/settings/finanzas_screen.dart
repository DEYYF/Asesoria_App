import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/budget_detail_dialog.dart';
import '../../providers/super_admin_provider.dart';
import '../../widgets/advisor_selector.dart';

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
  String _selectedPeriod = 'mensual'; // Added: 'mensual' or 'anual'
  final _currencyFormat = NumberFormat.currency(symbol: '€', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();

    // Listen for advisor changes if superadmin
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saProvider = Provider.of<SuperAdminProvider>(
        context,
        listen: false,
      );
      saProvider.addListener(_onAdvisorChanged);
    });
  }

  void _onAdvisorChanged() {
    if (mounted) _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    try {
      final saProvider = Provider.of<SuperAdminProvider>(
        context,
        listen: false,
      );
      saProvider.removeListener(_onAdvisorChanged);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final saProvider = Provider.of<SuperAdminProvider>(context, listen: false);

    try {
      String queryParam = '';
      if (auth.isSuperAdmin) {
        if (saProvider.selectedAdvisorId != null) {
          queryParam = 'asesorId=${saProvider.selectedAdvisorId}';
        }
      } else {
        queryParam = 'asesorId=${auth.userId}';
      }

      // Add period to query
      final periodParam = 'periodo=$_selectedPeriod';
      final fullQuery = queryParam.isEmpty
          ? periodParam
          : '$queryParam&$periodParam';

      final responses = await Future.wait([
        api.get('/finanzas/resumen?$fullQuery'),
        api.get('/finanzas/movimientos?$fullQuery'),
        api.get('/finanzas/control-pagos?$fullQuery'),
        api.get('/finanzas/historico-grafico?$fullQuery'),
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
      body: Column(
        children: [
          if (Provider.of<AuthService>(context, listen: false).isSuperAdmin)
            const AdvisorSelector(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _buildPeriodSelector(),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildResumenTab(),
                      _buildPagosTab(),
                      _buildMovimientosTab(),
                    ],
                  ),
          ),
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
    final theme = Theme.of(context);
    final periodo =
        _resumen['periodoActual'] ??
        {'ingresos': 0.0, 'gastos': 0.0, 'balance': 0.0};

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.primaryColor,
                theme.primaryColor.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: theme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedPeriod == 'mensual'
                        ? 'Balance Mensual'
                        : 'Balance Anual',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _currencyFormat.format(periodo['balance'] ?? 0),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _SummaryMiniItem(
                      label: 'Ingresos',
                      amount: _currencyFormat.format(periodo['ingresos'] ?? 0),
                      icon: Icons.arrow_upward_rounded,
                      color: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _SummaryMiniItem(
                      label: 'Gastos',
                      amount: _currencyFormat.format(periodo['gastos'] ?? 0),
                      icon: Icons.arrow_downward_rounded,
                      color: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    if (_historicoGrafico.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No hay datos suficientes')),
      );
    }

    final theme = Theme.of(context);

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(8, 24, 24, 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedPeriod == 'mensual'
                    ? 'TENDENCIA (ÚLTIMOS 6 MESES)'
                    : 'TENDENCIA (AÑO COMPLETO)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: theme.hintColor.withValues(alpha: 0.5),
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  _buildChartLegend('Ingresos', Colors.greenAccent),
                  const SizedBox(width: 12),
                  _buildChartLegend('Gastos', Colors.redAccent),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: theme.dividerColor.withValues(alpha: 0.05),
                      strokeWidth: 1,
                    );
                  },
                ),
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
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int idx = value.toInt();
                        if (idx >= 0 && idx < _historicoGrafico.length) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              _historicoGrafico[idx]['mes'],
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.hintColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.greenAccent.withValues(alpha: 0.2),
                          Colors.greenAccent.withValues(alpha: 0.0),
                        ],
                      ),
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
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.redAccent.withValues(alpha: 0.15),
                          Colors.redAccent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
      childAspectRatio: 1.4,
      children: [
        _buildStatCard(
          'Ingresos Totales',
          hist['ingresos'],
          Colors.green,
          Icons.trending_up_rounded,
          theme,
        ),
        _buildStatCard(
          'Gastos Totales',
          hist['gastos'],
          Colors.red,
          Icons.trending_down_rounded,
          theme,
        ),
        _buildStatCard(
          'Balance Global',
          hist['balance'],
          theme.primaryColor,
          Icons.pie_chart_rounded,
          theme,
        ),
        _buildStatCard(
          'Clientes Activos',
          _controlPagos.where((c) => c['status'] == 'AL_DIA').length.toDouble(),
          Colors.orange,
          Icons.people_alt_rounded,
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
    IconData icon,
    ThemeData theme, {
    bool isCurrency = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: theme.hintColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
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
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: theme.textTheme.bodyLarge?.color,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagosTab() {
    if (_controlPagos.isEmpty)
      return _buildEmptyState(
        _selectedPeriod == 'mensual'
            ? 'No hay pagos que venzan este mes'
            : 'No hay pagos que venzan este año',
      );

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _controlPagos.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildSectionHeader(
              _selectedPeriod == 'mensual'
                  ? 'CLIENTES QUE VENCEN ESTE MES'
                  : 'CLIENTES QUE VENCEN ESTE AÑO',
            ),
          );
        }
        final c = _controlPagos[index - 1];
        final status = c['status'];
        final theme = Theme.of(context);

        Color statusColor;
        String statusText;
        IconData icon;

        switch (status) {
          case 'AL_DIA':
            statusColor = Colors.green;
            statusText = 'Pagado';
            icon = Icons.check_circle_rounded;
            break;
          case 'EXPIRADO':
            statusColor = Colors.red;
            statusText = 'Caducado';
            icon = Icons.error_rounded;
            break;
          case 'ESPERANDO_PAGO':
            statusColor = Colors.orange;
            statusText = 'Aceptado';
            icon = Icons.hourglass_top_rounded;
            break;
          default:
            statusColor = Colors.grey;
            statusText = 'Pendiente';
            icon = Icons.help_rounded;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => context.go('/clientes/${c['id']}'),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        c['nombre'][0].toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['nombre'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c['email'],
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.hintColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (c['fechaFin'] != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 10,
                                color: statusColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Vence: ${DateFormat('dd MMM').format(DateTime.parse(c['fechaFin']))}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: statusColor, size: 12),
                            const SizedBox(width: 6),
                            Text(
                              statusText.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (c['presupuestoId'] != null)
                        IconButton(
                          icon: Icon(
                            Icons.receipt_long_rounded,
                            size: 18,
                            color: theme.primaryColor,
                          ),
                          onPressed: () =>
                              _showBudgetDetail(c['presupuestoId']),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMovimientosTab() {
    if (_movimientos.isEmpty) {
      return _buildEmptyState(
        _selectedPeriod == 'mensual'
            ? 'No hay movimientos este mes'
            : 'No hay movimientos este año',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _movimientos.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildSectionHeader(
              _selectedPeriod == 'mensual'
                  ? 'HISTORIAL DE ESTE MES'
                  : 'HISTORIAL DE ESTE AÑO',
            ),
          );
        }
        final m = _movimientos[index - 1];
        final isIngreso = m['tipoMovimiento'] == 'INGRESO';
        final theme = Theme.of(context);
        final date = DateTime.parse(m['fecha']).toLocal();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isIngreso ? Colors.green : Colors.red).withValues(
                      alpha: 0.1,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isIngreso
                        ? Icons.keyboard_double_arrow_up_rounded
                        : Icons.keyboard_double_arrow_down_rounded,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            DateFormat('dd MMM · HH:mm').format(date),
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.hintColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.dividerColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              m['categoria'].toString().toUpperCase(),
                              style: TextStyle(
                                fontSize: 8,
                                color: theme.hintColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isIngreso ? '+' : '-'}${_currencyFormat.format(m['monto'])}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: isIngreso ? Colors.green : Colors.redAccent,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (m['presupuestoId'] != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 10,
                            color: theme.primaryColor.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'PPTO',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
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
        builder: (ctx, setS) {
          final theme = Theme.of(context);
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
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
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Nuevo Movimiento',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.dividerColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTypeButton(
                            label: 'INGRESO',
                            isSelected: type == 'INGRESO',
                            color: Colors.green,
                            onTap: () => setS(() => type = 'INGRESO'),
                          ),
                        ),
                        Expanded(
                          child: _buildTypeButton(
                            label: 'GASTO',
                            isSelected: type == 'GASTO',
                            color: Colors.red,
                            onTap: () => setS(() => type = 'GASTO'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: montoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Monto total',
                      prefixIcon: const Icon(Icons.euro_rounded),
                      filled: true,
                      fillColor: theme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
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
                      if (value == null || value.isEmpty)
                        return 'Ingresa una descripción';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: type == 'INGRESO'
                            ? Colors.green
                            : Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
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
                      child: const Text(
                        'Guardar Registro',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeButton({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
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
        color: isDark ? const Color(0xFF1C1C1E) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          _buildPeriodOption('mensual', 'MENSUAL'),
          _buildPeriodOption('anual', 'ANUAL'),
        ],
      ),
    );
  }

  Widget _buildPeriodOption(String value, String label) {
    final theme = Theme.of(context);
    final isSelected = _selectedPeriod == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPeriod = value);
          _loadData();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.primaryColor.withValues(alpha: 0.3),
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
              color: isSelected ? Colors.white : theme.hintColor,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class _SummaryMiniItem extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color color;
  final Color? backgroundColor;

  const _SummaryMiniItem({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  amount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
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
