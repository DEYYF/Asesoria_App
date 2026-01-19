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
import '../widgets/advisor_selector.dart';
import '../providers/super_admin_provider.dart';
import '../services/auth_service.dart';

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _isSearchExpanded = false;
  bool _showFilters = false;

  List<Cliente> _clientes = [];
  List<Tarifa> _tarifas = [];
  bool _isLoading = true;
  String? _error;

  // Filters
  String _searchQuery = '';
  final Set<String> _selectedTarifas = {};
  final Set<String> _selectedObjetivos = {};
  final Set<String> _selectedGenders = {};

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
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
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();

    // Safely remove listener
    try {
      final saProvider = Provider.of<SuperAdminProvider>(
        context,
        listen: false,
      );
      saProvider.removeListener(_onAdvisorChanged);
    } catch (_) {}

    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) setState(() {});
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    final saProvider = Provider.of<SuperAdminProvider>(context, listen: false);

    try {
      Map<String, dynamic> params = {};

      // If NOT SuperAdmin, force own ID
      if (!Provider.of<AuthService>(context, listen: false).isSuperAdmin) {
        params['asesorId'] = Provider.of<AuthService>(
          context,
          listen: false,
        ).userId;
      } else {
        // If SuperAdmin, use selected advisor ID (if any)
        // If selectedAdvisorId is null, we send NO asesorId param, which means "Global View" (All)
        if (saProvider.selectedAdvisorId != null) {
          params['asesorId'] = saProvider.selectedAdvisorId;
        }
      }

      final resClientes = await api.get('/clientes', params: params);
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
        onSuccess: (_) {
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
      if (onlyBaja != null) {
        if (onlyBaja && c.estado != 'Baja') return false;
        if (!onlyBaja && c.estado == 'Baja') return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!c.nombre.toLowerCase().contains(q) &&
            !c.email.toLowerCase().contains(q)) {
          return false;
        }
      }

      if (_selectedTarifas.isNotEmpty &&
          !_selectedTarifas.contains(c.tipoServicio)) {
        return false;
      }

      if (_selectedObjetivos.isNotEmpty) {
        final hasAnyObjetivo =
            c.objetivos?.any((o) => _selectedObjetivos.contains(o)) ?? false;
        if (!hasAnyObjetivo) return false;
      }

      if (_selectedGenders.isNotEmpty && !_selectedGenders.contains(c.sexo)) {
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor, // Ensure solid background
                border: Border(
                  bottom: BorderSide(color: theme.dividerColor, width: 0.5),
                ),
                boxShadow: [
                  if (isDark)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (Provider.of<AuthService>(
                        context,
                        listen: false,
                      ).isSuperAdmin)
                        const AdvisorSelector(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position:
                                        Tween<Offset>(
                                          begin: const Offset(0.1, 0),
                                          end: Offset.zero,
                                        ).animate(
                                          CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOutCubic,
                                          ),
                                        ),
                                    child: child,
                                  ),
                                );
                              },
                              child: _isSearchExpanded
                                  ? Container(
                                      key: const ValueKey('search_active'),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.05)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          if (!isDark)
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.05,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.arrow_back_rounded,
                                            ),
                                            color: theme.primaryColor,
                                            onPressed: () => setState(() {
                                              _isSearchExpanded = false;
                                              _searchCtrl.clear();
                                              _searchQuery = '';
                                            }),
                                          ),
                                          Expanded(
                                            child: TextField(
                                              controller: _searchCtrl,
                                              focusNode: _searchFocusNode,
                                              autofocus: true,
                                              onChanged: (val) => setState(
                                                () => _searchQuery = val,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: 'Buscar clientes...',
                                                hintStyle: TextStyle(
                                                  color: theme.hintColor
                                                      .withOpacity(0.4),
                                                ),
                                                border: InputBorder.none,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 16,
                                                    ),
                                              ),
                                            ),
                                          ),
                                          if (_searchQuery.isNotEmpty)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.close_rounded,
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                _searchCtrl.clear();
                                                setState(
                                                  () => _searchQuery = '',
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                    )
                                  : Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Clientes',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                          color:
                                              theme.textTheme.titleLarge?.color,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          if (!_isSearchExpanded)
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.search_rounded,
                                    color: theme.primaryColor,
                                  ),
                                  onPressed: () =>
                                      setState(() => _isSearchExpanded = true),
                                ),
                                const SizedBox(width: 8),
                                _buildFilterButton(theme, isDark),
                                const SizedBox(width: 8),
                                _SummaryChip(
                                  label: 'Total: $total',
                                  color: isDark
                                      ? Colors.grey.shade900
                                      : Colors.grey.shade100,
                                ),
                              ],
                            ),
                        ],
                      ),

                      if (!_isSearchExpanded) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _SummaryChip(
                              label: 'Activos: $totalActivos',
                              color: isDark
                                  ? Colors.green.withOpacity(0.15)
                                  : Colors.green.shade50,
                              textColor: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            _SummaryChip(
                              label: 'Baja: $totalBajas',
                              color: isDark
                                  ? Colors.red.withOpacity(0.15)
                                  : Colors.red.shade50,
                              textColor: Colors.red,
                            ),
                            const Spacer(),
                            _HeaderActionButton(
                              icon: Icons.send_rounded,
                              label: 'Masivo',
                              onPressed: () async {
                                final method = await showDialog<String>(
                                  context: context,
                                  builder: (_) =>
                                      const CommunicationChoiceDialog(),
                                );
                                if (!context.mounted) return;
                                if (method == 'email') {
                                  showDialog(
                                    context: context,
                                    builder: (_) => BulkEmailDialog(
                                      clientes: displayedList,
                                    ),
                                  );
                                } else if (method == 'chat') {
                                  showDialog(
                                    context: context,
                                    builder: (_) =>
                                        BulkChatDialog(clientes: displayedList),
                                  );
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            _HeaderActionButton(
                              icon: Icons.add_circle_outline_rounded,
                              label: 'Nuevo',
                              isPrimary: true,
                              onPressed: _showAddClient,
                            ),
                          ],
                        ),
                      ],

                      if (_showFilters) _buildAdvancedFilters(theme, isDark),

                      const SizedBox(height: 12),

                      // Tabs
                      SizedBox(
                        height: 38,
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          labelColor: theme.primaryColor,
                          unselectedLabelColor: theme.hintColor,
                          indicatorColor: theme.primaryColor,
                          indicatorWeight: 3,
                          dividerColor: Colors.transparent,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          tabs: [
                            Tab(text: 'Activos (${filteredActivos.length})'),
                            Tab(text: 'Baja (${filteredBajas.length})'),
                          ],
                          tabAlignment: TabAlignment.start,
                        ),
                      ),
                    ],
                  ),
                ),
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

  Widget _buildFilterButton(ThemeData theme, bool isDark) {
    final hasActiveFilters =
        _selectedTarifas.isNotEmpty ||
        _selectedObjetivos.isNotEmpty ||
        _selectedGenders.isNotEmpty;
    return GestureDetector(
      onTap: () => setState(() => _showFilters = !_showFilters),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: _showFilters
              ? theme.primaryColor
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.tune_rounded,
              color: _showFilters ? Colors.white : theme.primaryColor,
              size: 20,
            ),
            if (hasActiveFilters && !_showFilters)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedFilters(ThemeData theme, bool isDark) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: theme.primaryColor.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.style_rounded, size: 14, color: theme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'TARIFAS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _tarifas.map((t) {
                  final isSelected = _selectedTarifas.contains(t.nombre);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(t.nombre),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          if (val)
                            _selectedTarifas.add(t.nombre);
                          else
                            _selectedTarifas.remove(t.nombre);
                        });
                      },
                      selectedColor: theme.primaryColor.withOpacity(0.15),
                      checkmarkColor: theme.primaryColor,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? theme.primaryColor
                            : theme.hintColor,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                      ),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(
                        color: isSelected
                            ? theme.primaryColor
                            : theme.dividerColor.withOpacity(0.1),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.flag_rounded, size: 14, color: theme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'OBJETIVOS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: ['Ganar músculo', 'Perder grasa', 'Mantenimiento']
                    .map((obj) {
                      final isSelected = _selectedObjetivos.contains(obj);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(obj),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() {
                              if (val)
                                _selectedObjetivos.add(obj);
                              else
                                _selectedObjetivos.remove(obj);
                            });
                          },
                          selectedColor: theme.primaryColor.withOpacity(0.15),
                          checkmarkColor: theme.primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? theme.primaryColor
                                : theme.hintColor,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                          backgroundColor: Colors.transparent,
                          side: BorderSide(
                            color: isSelected
                                ? theme.primaryColor
                                : theme.dividerColor.withOpacity(0.1),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.person_rounded, size: 14, color: theme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'SEXO',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: ['Hombre', 'Mujer'].map((gx) {
                final isSelected = _selectedGenders.contains(gx);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(gx),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        if (val)
                          _selectedGenders.add(gx);
                        else
                          _selectedGenders.remove(gx);
                      });
                    },
                    selectedColor: theme.primaryColor.withOpacity(0.15),
                    checkmarkColor: theme.primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? theme.primaryColor : theme.hintColor,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: isSelected
                          ? theme.primaryColor
                          : theme.dividerColor.withOpacity(0.1),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                );
              }).toList(),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? (isDark ? Colors.white10 : Colors.white),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor ?? (isDark ? Colors.white70 : Colors.grey.shade700),
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _HeaderActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isPrimary
              ? theme.primaryColor
              : (isDark ? theme.cardColor : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: isPrimary
              ? null
              : Border.all(color: theme.dividerColor.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isPrimary ? Colors.white : theme.primaryColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isPrimary
                    ? Colors.white
                    : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
