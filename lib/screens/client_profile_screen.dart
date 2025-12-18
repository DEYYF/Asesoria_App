import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../models/cliente_model.dart';
import 'profile/info_tab.dart';
import 'profile/diet_tab.dart';
import 'profile/training_tab.dart';
import 'profile/progress_tab.dart';
import '../widgets/dialogs/add_progress_dialog.dart';
import '../widgets/dialogs/manage_extras_dialog.dart';
import '../widgets/dialogs/change_tariff_dialog.dart';
import '../widgets/dialogs/edit_info_dialog.dart';

class ClientProfileScreen extends StatefulWidget {
  final String clienteId;
  const ClientProfileScreen({super.key, required this.clienteId});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  Cliente? _cliente;
  bool _isLoading = true;
  String? _error;

  // Budget Status
  bool _canEditFeatures =
      true; // Default to true while loading? React defaults to restricted or loading.
  String? _budgetEstado; // 'pendiente' etc.

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      // Parallel fetch
      final results = await Future.wait([
        api.get('/clientes/${widget.clienteId}'),
        api.get('/clientes/${widget.clienteId}/budget-status'),
      ]);

      final resClient = results[0];
      final resBudget = results[1];

      if (!mounted) return;

      if (resClient.statusCode == 200) {
        final c = Cliente.fromJson(jsonDecode(resClient.body));

        bool canEdit = false; // Default safe
        String? bState;

        if (resBudget.statusCode == 200) {
          final bData = jsonDecode(resBudget.body);
          canEdit = bData['canEdit'] ?? false;
          bState = bData['estado'];
        } else {
          // If budget endpoint fails, what should we do?
          // React handles catch with console error.
          // If assume success:
          canEdit = true;
        }

        setState(() {
          _cliente = c;
          _canEditFeatures = canEdit;
          _budgetEstado = bState;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Error ${resClient.statusCode}: ${resClient.body}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  bool get _hasDieta {
    if (_cliente == null) return false;
    const types = [
      "Dieta",
      "Dieta y asesoramiento",
      "Dieta y Rutina",
      "Mensual",
      "Trimestral",
      "Semestral",
      "Anual",
    ];
    return types.contains(_cliente!.tipoServicio);
  }

  bool get _hasEntrenamiento {
    if (_cliente == null) return false;
    const types = [
      "Rutina",
      "Rutina y asesoramiento",
      "Dieta y Rutina",
      "Mensual",
      "Trimestral",
      "Semestral",
      "Anual",
    ];
    return types.contains(_cliente!.tipoServicio);
  }

  Future<void> _handleRenovar() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.put('/clientes/${widget.clienteId}/actualizar-tarifa', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud de renovación creada')),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al renovar: $e')));
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Cliente'),
        content: Text('¿Seguro que quieres eliminar a ${_cliente?.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.delete('/clientes/${widget.clienteId}');
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  void _showAddProgress() {
    showDialog(
      context: context,
      builder: (_) => AddProgressDialog(
        clienteId: widget.clienteId,
        onSuccess: () {
          _loadData();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Progreso añadido')));
        },
      ),
    );
  }

  void _showManageExtras() {
    showDialog(
      context: context,
      builder: (_) => ManageExtrasDialog(
        clienteId: widget.clienteId,
        onSuccess: () {
          _loadData();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Extras actualizados')));
        },
      ),
    );
  }

  void _showChangeTariff() {
    showDialog(
      context: context,
      builder: (_) => ChangeTariffDialog(
        clienteId: widget.clienteId,
        currentDuration: _cliente?.tiempoTarifa ?? '1 Mes',
        onSuccess: () {
          _loadData();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Tarifa actualizada')));
        },
      ),
    );
  }

  void _showEditInfo() {
    showDialog(
      context: context,
      builder: (_) => EditInfoDialog(
        cliente: _cliente!,
        onSuccess: () {
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Información actualizada')),
          );
        },
      ),
    );
  }

  Future<void> _handleSessionAction(String action) async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.put('/clientes/${widget.clienteId}/sesiones-counter', {
        'action': action,
      });
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar sesiones: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_error!)),
      );
    }
    if (_cliente == null) {
      return const Scaffold(body: Center(child: Text('Cliente no encontrado')));
    }

    // Build Tabs
    final tabs = <Widget>[const Tab(text: 'Información y Registro')];
    final tabViews = <Widget>[
      InfoTab(
        cliente: _cliente!,
        onRenovar: _handleRenovar,
        onDelete: _handleDelete,
        onAddProgress: _showAddProgress,
        onManageExtras: _showManageExtras,
        onChangeTariff: _showChangeTariff,
        onEditInfo: _showEditInfo,
        onSessionAction: _handleSessionAction,
      ),
    ];

    // Conditional Tabs
    if (_hasDieta) {
      if (_canEditFeatures) {
        tabs.add(const Tab(text: 'Dieta'));
        tabViews.add(DietTab(clienteId: _cliente!.id));
      } else {
        tabs.add(
          const Tab(
            child: Row(
              children: [
                Text('Dieta'),
                SizedBox(width: 4),
                Icon(Icons.lock, size: 14),
              ],
            ),
          ),
        );
        tabViews.add(const _LockedView());
      }
    }

    if (_hasEntrenamiento) {
      if (_canEditFeatures) {
        tabs.add(const Tab(text: 'Entrenamiento'));
        tabViews.add(TrainingTab(clienteId: _cliente!.id));
        tabs.add(const Tab(text: 'Progreso'));
        tabViews.add(
          ProgressTab(cliente: _cliente!, onAddProgress: _showAddProgress),
        );
      } else {
        tabs.add(
          const Tab(
            child: Row(
              children: [
                Text('Entrenamiento'),
                SizedBox(width: 4),
                Icon(Icons.lock, size: 14),
              ],
            ),
          ),
        );
        tabViews.add(const _LockedView());
        // Hide progress too or lock it?
        tabs.add(
          const Tab(
            child: Row(
              children: [
                Text('Progreso'),
                SizedBox(width: 4),
                Icon(Icons.lock, size: 14),
              ],
            ),
          ),
        );
        tabViews.add(const _LockedView());
      }
    }

    return Scaffold(
      body: SafeArea(
        child: DefaultTabController(
          length: tabs.length,
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Budget Warning
                        if (_budgetEstado == 'pendiente')
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber,
                                  color: Colors.orange.shade800,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Presupuesto pendiente. Funciones restringidas.',
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Perfil de\n${_cliente!.nombre}',
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                  letterSpacing: -0.5,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _StatusChip(
                                label:
                                    'Inicio: ${_formatDate(_cliente!.fechaInicio)}',
                              ),
                              const SizedBox(width: 8),
                              _StatusChip(
                                label:
                                    'Fin: ${_formatDate(_cliente!.fechaFin)}',
                              ),
                              const SizedBox(width: 8),
                              const _StatusChip(
                                label: '1 Mes',
                                isDuration: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      tabs: tabs,
                      labelColor: const Color(0xFF007AFF),
                      unselectedLabelColor: const Color(0xFF8E8E93),
                      indicatorColor: const Color(0xFF007AFF),
                      indicatorWeight: 2,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      dividerColor: const Color(0xFFC6C6C8),
                    ),
                  ),
                  pinned: true,
                ),
              ];
            },
            body: TabBarView(children: tabViews),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _LockedView extends StatelessWidget {
  const _LockedView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.lock_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Función bloqueada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'El presupuesto está pendiente de pago.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isDuration;
  const _StatusChip({required this.label, this.isDuration = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);
  @override
  double get minExtent => _tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => _tabBar.preferredSize.height + 1;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          _tabBar,
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
