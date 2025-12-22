import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../models/ejercicio_model.dart';
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
        final data = jsonDecode(res.body);
        final List<dynamic> items = data is List ? data : (data['items'] ?? []);

        setState(() {
          _ejercicios = items.map((e) => Ejercicio.fromJson(e)).toList();
          _filteredEjercicios = _ejercicios;
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

  void _applyFilters() {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Ejercicios'), elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header with count and clear filters
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total: ${_filteredEjercicios.length}',
                        style: Theme.of(context).textTheme.titleMedium,
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
                        decoration: InputDecoration(
                          labelText: 'Buscar',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Filter dropdowns
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedGrupo,
                              decoration: InputDecoration(
                                labelText: 'Grupo',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Todos'),
                                ),
                                ..._grupos.map(
                                  (g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(g),
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
                              decoration: InputDecoration(
                                labelText: 'Equipo',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Todos'),
                                ),
                                ..._equipos.map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
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
                        decoration: InputDecoration(
                          labelText: 'Nivel',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todos'),
                          ),
                          ..._niveles.map(
                            (n) => DropdownMenuItem(value: n, child: Text(n)),
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
                      ? const Center(
                          child: Text('No se encontraron ejercicios'),
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
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: const Icon(Icons.fitness_center),
                                ),
                                title: Text(
                                  ejercicio.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (ejercicio.grupo != null)
                                      Text('Grupo: ${ejercicio.grupo}'),
                                    if (ejercicio.equipo != null)
                                      Text('Equipo: ${ejercicio.equipo}'),
                                    if (ejercicio.nivel != null)
                                      Text('Nivel: ${ejercicio.nivel}'),
                                  ],
                                ),
                                trailing: ejercicio.urlVideo != null
                                    ? const Icon(Icons.play_circle_outline)
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
