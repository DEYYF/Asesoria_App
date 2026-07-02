import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/ejercicio_model.dart';
import '../../utils/isolate_utils.dart';
import 'ejercicio_detail_screen.dart';
import '../../widgets/dialogs/add_edit_ejercicio_dialog.dart';

class EjerciciosScreen extends StatefulWidget {
  const EjerciciosScreen({super.key});

  @override
  State<EjerciciosScreen> createState() => _EjerciciosScreenState();
}

class _EjerciciosScreenState extends State<EjerciciosScreen> {
  List<Ejercicio> _ejercicios = [];
  List<Ejercicio> _filteredEjercicios = [];
  bool _loading = true;

  bool _isSearchExpanded = false;
  bool _showFilters = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String? _selectedGrupo;
  String? _selectedEquipo;
  String? _selectedNivel;

  // Fixed lists from PanelEjercicios.jsx
  final List<String> _grupos = [
    "Pecho Superior",
    "Pecho Inferior",
    "Pecho Medio",
    "Trapecio",
    "Dorsal",
    "Espalda Baja",
    "Cuello",
    "Cuadriceps",
    "Isquiotibiales",
    "Gluteos",
    "Gemelos",
    "Hombros",
    "Bíceps",
    "Tríceps",
    "Abdominales",
    "Cardio",
    "Otro",
  ];

  final List<String> _equipos = [
    "Mancuernas",
    "Barra",
    "Máquinas",
    "Cuerpo libre",
    "Bandas elásticas",
    "TRX",
    "Balón medicinal",
    "Rueda abdominal",
    "Comba",
    "Peso corporal",
    "Poleas",
  ];

  final List<String> _niveles = ["Principiante", "Intermedio", "Avanzado"];

  @override
  void initState() {
    super.initState();
    _loadEjercicios();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadEjercicios() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get(
        '/ejercicios',
        params: {'limit': '5000', 'page': '1'},
      );
      if (res.statusCode == 200) {
        // Parse JSON in isolate to avoid blocking UI
        final ejercicios = await parseEjerciciosInIsolate(res.body);

        setState(() {
          _ejercicios = ejercicios;
          _filteredEjercicios = ejercicios;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar ejercicios: $e')),
        );
      }
    }
  }

  Future<void> _applyFilters() async {
    // For small lists, filter on main thread (faster)
    // We can re-introduce isolate dispatch if list grows > 500 items
    setState(() {
      _filteredEjercicios = _ejercicios.where((ejercicio) {
        final matchesSearch =
            _searchController.text.isEmpty ||
            ejercicio.nombre.toLowerCase().contains(
              _searchController.text.toLowerCase(),
            );
        final matchesGrupo =
            _selectedGrupo == null ||
            _selectedGrupo!.isEmpty ||
            ejercicio.grupo == _selectedGrupo;
        final matchesEquipo =
            _selectedEquipo == null ||
            _selectedEquipo!.isEmpty ||
            ejercicio.equipo == _selectedEquipo;
        final matchesNivel =
            _selectedNivel == null ||
            _selectedNivel!.isEmpty ||
            ejercicio.nivel == _selectedNivel;

        return matchesSearch && matchesGrupo && matchesEquipo && matchesNivel;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedGrupo = null;
      _selectedEquipo = null;
      _selectedNivel = null;
      _filteredEjercicios = _ejercicios;
      _isSearchExpanded = false;
      _showFilters = false;
    });
  }

  void _showAddEditDialog([Ejercicio? ejercicio]) {
    showDialog(
      context: context,
      builder: (context) => AddEditEjercicioDialog(
        ejercicio: ejercicio,
        onSuccess: _loadEjercicios,
      ),
    );
  }

  Widget _buildFilterButton(ThemeData theme, bool isDark) {
    final hasActiveFilters =
        (_selectedGrupo != null && _selectedGrupo!.isNotEmpty) ||
        (_selectedEquipo != null && _selectedEquipo!.isNotEmpty) ||
        (_selectedNivel != null && _selectedNivel!.isNotEmpty);

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
            _buildFilterCategory(
              theme,
              'GRUPO MUSCULAR',
              _grupos,
              _selectedGrupo,
              (val) {
                setState(() {
                  _selectedGrupo = _selectedGrupo == val ? null : val;
                  _applyFilters();
                });
              },
            ),
            const SizedBox(height: 20),
            _buildFilterCategory(theme, 'EQUIPO', _equipos, _selectedEquipo, (
              val,
            ) {
              setState(() {
                _selectedEquipo = _selectedEquipo == val ? null : val;
                _applyFilters();
              });
            }),
            const SizedBox(height: 20),
            _buildFilterCategory(theme, 'NIVEL', _niveles, _selectedNivel, (
              val,
            ) {
              setState(() {
                _selectedNivel = _selectedNivel == val ? null : val;
                _applyFilters();
              });
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCategory(
    ThemeData theme,
    String title,
    List<String> options,
    String? selectedValue,
    Function(String) onSelect,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.label_outline_rounded,
              size: 14,
              color: theme.primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
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
            children: options.map((opt) {
              final isSelected = selectedValue == opt;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(opt),
                  selected: isSelected,
                  onSelected: (_) => onSelect(opt),
                  selectedColor: theme.primaryColor.withOpacity(0.15),
                  checkmarkColor: theme.primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? theme.primaryColor : theme.hintColor,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
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
                                              _searchController.clear();
                                              _clearFilters();
                                            }),
                                          ),
                                          Expanded(
                                            child: TextField(
                                              controller: _searchController,
                                              focusNode: _searchFocusNode,
                                              autofocus: true,
                                              onChanged: (_) => _applyFilters(),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              decoration: InputDecoration(
                                                hintText:
                                                    'Buscar ejercicios...',
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
                                          if (_searchController.text.isNotEmpty)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.close_rounded,
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                _searchController.clear();
                                                _applyFilters();
                                              },
                                            ),
                                        ],
                                      ),
                                    )
                                  : Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Ejercicios',
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
                              ],
                            ),
                        ],
                      ),
                      if (!_isSearchExpanded) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                'Total: ${_filteredEjercicios.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withOpacity(0.7),
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (_filteredEjercicios.length !=
                                _ejercicios.length)
                              TextButton.icon(
                                onPressed: _clearFilters,
                                icon: const Icon(
                                  Icons.clear_all_rounded,
                                  size: 16,
                                ),
                                label: const Text('Limpiar'),
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.colorScheme.error,
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],

                      if (_showFilters) _buildAdvancedFilters(theme, isDark),
                    ],
                  ),
                ),
              ),
            ),

            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredEjercicios.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.fitness_center_outlined,
                            size: 48,
                            color: theme.hintColor.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No se encontraron ejercicios',
                            style: TextStyle(
                              color: theme.hintColor,
                              fontSize: 16,
                            ),
                          ),
                          if (_searchController.text.isNotEmpty ||
                              _selectedGrupo != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: TextButton(
                                onPressed: _clearFilters,
                                child: const Text('Limpiar filtros'),
                              ),
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredEjercicios.length,
                      itemBuilder: (context, index) {
                        final ejercicio = _filteredEjercicios[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.dividerColor.withOpacity(0.05),
                            ),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                final refresh = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EjercicioDetailScreen(
                                      ejercicio: ejercicio,
                                    ),
                                  ),
                                );
                                if (refresh == true) _loadEjercicios();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor.withOpacity(
                                          0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.fitness_center_rounded,
                                        color: theme.primaryColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ejercicio.nombre,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 8,
                                            children: [
                                              if (ejercicio.grupo != null)
                                                Text(
                                                  ejercicio.grupo!,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: theme.hintColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              if (ejercicio.nivel != null)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: theme.dividerColor
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    ejercicio.nivel!,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.color,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: theme.dividerColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: theme.primaryColor,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
