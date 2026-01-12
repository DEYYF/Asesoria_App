import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../models/cliente_model.dart';
import '../models/tarifa_model.dart';
import '../utils/isolate_utils.dart';
import '../widgets/cliente_card.dart';
import '../widgets/add_client_dialog.dart';
import '../widgets/dialogs/bulk_email_dialog.dart';
import '../widgets/dialogs/bulk_chat_dialog.dart';
import '../widgets/dialogs/communication_choice_dialog.dart';

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();

  List<Cliente> _clientes = [];
  List<Tarifa> _tarifas = [];
  bool _isLoading = true;
  String? _error;

  // Filters
  String _searchQuery = '';
  String? _filterTarifa;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) setState(() {});
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final resClientes = await api.get('/clientes');
      final resTarifas = await api.get('/tarifas');

      if (resClientes.statusCode == 200) {
        // Parse clientes in isolate for better performance
        final listC = await parseClientesInIsolate(resClientes.body);

        List<Tarifa> listT = [];
        if (resTarifas.statusCode == 200) {
          // Parse tarifas - small list, can do on main thread
          final data = await parseJsonInIsolate(resTarifas.body);
          listT = (data as List).map((i) => Tarifa.fromJson(i)).toList();
        }

        setState(() {
          _clientes = listC;
          _tarifas = listT;
          _isLoading = false;
        });
      } else {
        throw Exception('Error loading clients: ${resClientes.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showAddClient() {
    showDialog(
      context: context,
      builder: (_) => AddClientDialog(
        onSuccess: () {
          _loadData(); // Refresh
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Cliente creado')));
        },
      ),
    );
  }

  Future<void> _toggleStatus(Cliente c) async {
    final api = Provider.of<ApiService>(context, listen: false);
    final index = _clientes.indexWhere((i) => i.id == c.id);
    if (index == -1) return;

    final oldStatus = c.estado;
    final newStatus = oldStatus == 'Baja' ? 'Activo' : 'Baja';

    // Copy the client with new status
    final updatedClient = c.copyWith(estado: newStatus);

    try {
      // Optimistic update
      setState(() {
        _clientes[index] = updatedClient;
      });
      await api.put('/clientes/${c.id}/status', {'estado': newStatus});
    } catch (e) {
      // Revert if fails
      setState(() {
        if (index < _clientes.length) {
          _clientes[index] = c.copyWith(estado: oldStatus);
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteClient(Cliente c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Cliente'),
        content: Text('¿Seguro que quieres eliminar a ${c.nombre}?'),
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
      await api.delete('/clientes/${c.id}');
      setState(() {
        _clientes.removeWhere((item) => item.id == c.id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cliente eliminado')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  List<Cliente> _applyFilters(List<Cliente> source, {bool? onlyBaja}) {
    return source.where((c) {
      // Tab Filter (if specified)
      if (onlyBaja == true && c.estado != 'Baja') return false;
      if (onlyBaja == false && c.estado == 'Baja') return false;

      // Text Filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = c.nombre.toLowerCase().contains(q);
        final matchEmail = c.email.toLowerCase().contains(q);
        if (!matchName && !matchEmail) return false;
      }

      // Tarifa Filter
      if (_filterTarifa != null && c.tipoServicio != _filterTarifa) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Calculate filtered list for current tab, and separately calculate counts.

    final filteredActivos = _applyFilters(_clientes, onlyBaja: false);
    final filteredBajas = _applyFilters(_clientes, onlyBaja: true);

    final currentTabBaja = _tabController.index == 1;
    final displayedList = currentTabBaja ? filteredBajas : filteredActivos;

    final total = _clientes.length;
    final totalActivos = _clientes.where((c) => c.estado != 'Baja').length;
    final totalBajas = _clientes.where((c) => c.estado == 'Baja').length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row and Logout
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Clientes',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                              color: theme.textTheme.titleLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _SummaryChip(label: 'Total: $total'),
                              const SizedBox(width: 8),
                              _SummaryChip(
                                label: 'Activos: $totalActivos',
                                color: isDark
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.green.shade50,
                                textColor: isDark
                                    ? Colors.greenAccent
                                    : Colors.green.shade700,
                              ),
                              const SizedBox(width: 8),
                              _SummaryChip(
                                label: 'Baja: $totalBajas',
                                color: isDark
                                    ? Colors.red.withOpacity(0.2)
                                    : Colors.red.shade50,
                                textColor: isDark
                                    ? Colors.redAccent
                                    : Colors.red.shade700,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Filters Layout
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Search Field
                        Container(
                          width: 320,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Center(
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText:
                                    'Buscar por nombre, email o teléfono...',
                                border: InputBorder.none,
                                icon: Icon(
                                  Icons.search,
                                  size: 20,
                                  color: theme.hintColor,
                                ),
                                isDense: true,
                                hintStyle: TextStyle(color: theme.hintColor),
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Tarifa Dropdown
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _filterTarifa,
                              hint: Text(
                                'Tarifa',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.hintColor,
                                ),
                              ),
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: theme.iconTheme.color,
                              ),
                              dropdownColor: theme.colorScheme.surface,
                              onChanged: (val) =>
                                  setState(() => _filterTarifa = val),
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text(
                                    'Todas',
                                    style: TextStyle(
                                      color: theme.textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                ),
                                ..._tarifas.map(
                                  (t) => DropdownMenuItem(
                                    value: t.nombre,
                                    child: Text(
                                      t.nombre,
                                      style: TextStyle(
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Action Buttons
                        OutlinedButton.icon(
                          onPressed: displayedList.isEmpty
                              ? null
                              : () async {
                                  final method = await showDialog<String>(
                                    context: context,
                                    builder: (_) =>
                                        const CommunicationChoiceDialog(),
                                  );
                                  if (!context.mounted) return;

                                  if (method == 'email') {
                                    showDialog(
                                      context: context,
                                      builder: (context) => BulkEmailDialog(
                                        clientes: displayedList,
                                      ),
                                    );
                                  } else if (method == 'chat') {
                                    showDialog(
                                      context: context,
                                      builder: (context) => BulkChatDialog(
                                        clientes: displayedList,
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.send_outlined, size: 18),
                          label: const Text('Enviar Mensaje Masivo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark
                                ? Colors.white
                                : theme.primaryColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white54
                                  : theme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        ElevatedButton.icon(
                          onPressed: _showAddClient,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Nuevo cliente'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tabs
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: isDark ? Colors.white : theme.primaryColor,
                      unselectedLabelColor: theme.hintColor,
                      indicatorColor: theme.primaryColor,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.normal,
                      ),
                      tabs: [
                        Tab(text: 'Activos (${filteredActivos.length})'),
                        Tab(text: 'Baja (${filteredBajas.length})'),
                      ],
                      // Override standard tab behavior to not stretch
                      tabAlignment: TabAlignment.start,
                    ),
                  ),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : displayedList.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron clientes',
                        style: TextStyle(color: theme.hintColor),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: displayedList.length,
                      itemBuilder: (context, index) {
                        final c = displayedList[index];
                        return ClienteCard(
                          cliente: c,
                          onTap: () {
                            context.push('/clientes/${c.id}');
                          },
                          onDelete: () => _deleteClient(c),
                          onToggleStatus: () => _toggleStatus(c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;

  const _SummaryChip({required this.label, this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Default colors based on theme
    final defaultBg = isDark ? theme.colorScheme.surface : Colors.white;
    final defaultText = isDark ? Colors.white70 : Colors.grey.shade700;
    final border = theme.dividerColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? defaultBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor ?? defaultText,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
