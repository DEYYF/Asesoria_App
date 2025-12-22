import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/ejercicio_model.dart';
import '../utils/isolate_utils.dart';
import 'ejercicio_detail_screen.dart';

class EjerciciosScreen extends StatefulWidget {
  const EjerciciosScreen({super.key});

  @override
  State<EjerciciosScreen> createState() => _EjerciciosScreenState();
}

class _EjerciciosScreenState extends State<EjerciciosScreen> {
  List<Ejercicio> _ejercicios = [];
  List<Ejercicio> _filteredEjercicios = [];
  bool _loading = true;

  final TextEditingController _searchController = TextEditingController();
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
    super.dispose();
  }

  Future<void> _loadEjercicios() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get('/ejercicios');
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
    // Use isolate for filtering if we have many ejercicios
    if (_ejercicios.length > 20) {
      final params = EjercicioFilterParams(
        ejercicios: _ejercicios,
        searchTerm: _searchController.text,
        grupo: _selectedGrupo,
        equipo: _selectedEquipo,
        nivel: _selectedNivel,
      );

      final filtered = await filterEjerciciosInIsolate(params);

      setState(() {
        _filteredEjercicios = filtered;
      });
    } else {
      // For small lists, filter on main thread (faster)
      setState(() {
        _filteredEjercicios = _ejercicios.where((ejercicio) {
          final matchesSearch =
              _searchController.text.isEmpty ||
              ejercicio.nombre.toLowerCase().contains(
                _searchController.text.toLowerCase(),
              );
          final matchesGrupo =
              _selectedGrupo == null || ejercicio.grupo == _selectedGrupo;
          final matchesEquipo =
              _selectedEquipo == null || ejercicio.equipo == _selectedEquipo;
          final matchesNivel =
              _selectedNivel == null || ejercicio.nivel == _selectedNivel;

          return matchesSearch && matchesGrupo && matchesEquipo && matchesNivel;
        }).toList();
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedGrupo = null;
      _selectedEquipo = null;
      _selectedNivel = null;
      _filteredEjercicios = _ejercicios;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Ejercicios')),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header with count and clear filters
                Container(
                  padding: const EdgeInsets.all(16),
                  color: isDark
                      ? theme.cardColor
                      : theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total: ${_filteredEjercicios.length}',
                        style: theme.textTheme.titleMedium,
                      ),
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Limpiar filtros'),
                      ),
                    ],
                  ),
                ),

                // Filters
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Search bar
                      TextField(
                        controller: _searchController,
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Buscar',
                          labelStyle: TextStyle(color: theme.hintColor),
                          prefixIcon: Icon(
                            Icons.search,
                            color: theme.iconTheme.color,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          filled: true,
                          fillColor: theme.inputDecorationTheme.fillColor,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Filter dropdowns
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedGrupo,
                              dropdownColor: theme.cardColor,
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Grupo',
                                labelStyle: TextStyle(color: theme.hintColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: theme.dividerColor,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: theme.dividerColor,
                                  ),
                                ),
                                filled: true,
                                fillColor: theme.inputDecorationTheme.fillColor,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text(
                                    'Todos',
                                    style: TextStyle(
                                      color: theme.textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                ),
                                ..._grupos.map(
                                  (g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(
                                      g,
                                      style: TextStyle(
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedGrupo = value);
                                _applyFilters();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedEquipo,
                              dropdownColor: theme.cardColor,
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Equipo',
                                labelStyle: TextStyle(color: theme.hintColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: theme.dividerColor,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: theme.dividerColor,
                                  ),
                                ),
                                filled: true,
                                fillColor: theme.inputDecorationTheme.fillColor,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text(
                                    'Todos',
                                    style: TextStyle(
                                      color: theme.textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                ),
                                ..._equipos.map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      e,
                                      style: TextStyle(
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedEquipo = value);
                                _applyFilters();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedNivel,
                        dropdownColor: theme.cardColor,
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Nivel',
                          labelStyle: TextStyle(color: theme.hintColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: theme.dividerColor),
                          ),
                          filled: true,
                          fillColor: theme.inputDecorationTheme.fillColor,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(
                              'Todos',
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                          ..._niveles.map(
                            (n) => DropdownMenuItem(
                              value: n,
                              child: Text(
                                n,
                                style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedNivel = value);
                          _applyFilters();
                        },
                      ),
                    ],
                  ),
                ),

                // Exercise list
                Expanded(
                  child: _filteredEjercicios.isEmpty
                      ? Center(
                          child: Text(
                            'No se encontraron ejercicios',
                            style: TextStyle(color: theme.hintColor),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredEjercicios.length,
                          itemBuilder: (context, index) {
                            final ejercicio = _filteredEjercicios[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              color: theme.cardColor,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: theme.dividerColor),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: theme.primaryColor
                                      .withOpacity(0.1),
                                  child: Icon(
                                    Icons.fitness_center,
                                    color: theme.primaryColor,
                                  ),
                                ),
                                title: Text(
                                  ejercicio.nombre,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.textTheme.titleMedium?.color,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (ejercicio.grupo != null)
                                      Text(
                                        'Grupo: ${ejercicio.grupo}',
                                        style: TextStyle(
                                          color: theme.hintColor,
                                        ),
                                      ),
                                    if (ejercicio.equipo != null)
                                      Text(
                                        'Equipo: ${ejercicio.equipo}',
                                        style: TextStyle(
                                          color: theme.hintColor,
                                        ),
                                      ),
                                    if (ejercicio.nivel != null)
                                      Text(
                                        'Nivel: ${ejercicio.nivel}',
                                        style: TextStyle(
                                          color: theme.hintColor,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: ejercicio.urlVideo != null
                                    ? Icon(
                                        Icons.play_circle_outline,
                                        color: theme.primaryColor,
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          EjercicioDetailScreen(
                                            ejercicio: ejercicio,
                                          ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
