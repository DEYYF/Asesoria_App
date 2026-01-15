import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _clientes = [];
  bool _loading = true;

  // Search and Filter State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  bool _showFilters = false;
  final Set<String> _selectedStatus = {};
  final Set<String> _selectedGender = {};

  @override
  void initState() {
    super.initState();
    _loadClientes();
  }

  Future<void> _loadClientes() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get('/clientes');
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _clientes = jsonDecode(res.body);
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredClientes {
    return _clientes.where((c) {
      final nombre = (c['nombre'] ?? '').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      final status = (c['estado'] ?? 'Activo').toString();
      final gender = (c['sexo'] ?? 'No especificado').toString();

      final matchesSearch =
          _searchQuery.isEmpty ||
          nombre.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase());

      final matchesStatus =
          _selectedStatus.isEmpty || _selectedStatus.contains(status);
      final matchesGender =
          _selectedGender.isEmpty || _selectedGender.contains(gender);

      return matchesSearch && matchesStatus && matchesGender;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Panel de Clientes'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              auth.logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildHeader(theme, isDark),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadClientes,
                    child: _filteredClientes.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 64,
                                  color: theme.hintColor.withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No se encontraron clientes',
                                  style: TextStyle(
                                    color: theme.hintColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredClientes.length,
                            itemBuilder: (context, index) {
                              final c = _filteredClientes[index];
                              final nombre = c['nombre'] ?? 'Sin nombre';
                              final email = c['email'] ?? '';
                              final inicial = nombre.isNotEmpty
                                  ? nombre[0].toUpperCase()
                                  : '?';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.dividerColor.withOpacity(0.05),
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: theme.primaryColor
                                        .withOpacity(0.1),
                                    child: Text(
                                      inicial,
                                      style: TextStyle(
                                        color: theme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    email,
                                    style: TextStyle(
                                      color: theme.hintColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.chevron_right_rounded,
                                    color: theme.hintColor,
                                  ),
                                  onTap: () =>
                                      context.go('/clientes/${c['_id']}'),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: Row(
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
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_rounded),
                                color: theme.primaryColor,
                                onPressed: () => setState(() {
                                  _isSearchExpanded = false;
                                  _searchController.clear();
                                  _searchQuery = '';
                                }),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  autofocus: true,
                                  onChanged: (val) =>
                                      setState(() => _searchQuery = val),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Nombre o email...',
                                    hintStyle: TextStyle(
                                      color: theme.hintColor.withOpacity(0.4),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
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
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                ),
                            ],
                          ),
                        )
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Mis Clientes',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                ),
              ),
              if (!_isSearchExpanded)
                IconButton(
                  icon: Icon(Icons.search_rounded, color: theme.primaryColor),
                  onPressed: () => setState(() => _isSearchExpanded = true),
                ),
              const SizedBox(width: 8),
              _buildFilterButton(theme, isDark),
            ],
          ),
        ),
        if (_showFilters) _buildAdvancedFilters(theme, isDark),
      ],
    );
  }

  Widget _buildFilterButton(ThemeData theme, bool isDark) {
    final hasActiveFilters =
        _selectedStatus.isNotEmpty || _selectedGender.isNotEmpty;
    return GestureDetector(
      onTap: () => setState(() => _showFilters = !_showFilters),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          color: _showFilters
              ? theme.primaryColor
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
          borderRadius: BorderRadius.circular(20),
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
              size: 24,
            ),
            if (hasActiveFilters && !_showFilters)
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  width: 8,
                  height: 8,
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
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: theme.primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'ESTADO',
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
              children: ['Activo', 'Inactivo'].map((st) {
                final isSelected = _selectedStatus.contains(st);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(st),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        if (val)
                          _selectedStatus.add(st);
                        else
                          _selectedStatus.remove(st);
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
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 14,
                  color: theme.primaryColor,
                ),
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
                final isSelected = _selectedGender.contains(gx);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(gx),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        if (val)
                          _selectedGender.add(gx);
                        else
                          _selectedGender.remove(gx);
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
