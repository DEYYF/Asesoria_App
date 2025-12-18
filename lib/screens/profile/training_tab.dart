import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/entrenamiento_model.dart';

class TrainingTab extends StatefulWidget {
  final String clienteId;
  const TrainingTab({super.key, required this.clienteId});

  @override
  State<TrainingTab> createState() => _TrainingTabState();
}

class _TrainingTabState extends State<TrainingTab> {
  List<Entrenamiento> _entrenamientos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntrenamientos();
  }

  Future<void> _loadEntrenamientos() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      // Matching React: GET /entrenamientos?clienteId=...
      final res = await api.get(
        '/entrenamientos?clienteId=${widget.clienteId}',
      );

      if (mounted) {
        if (res.statusCode == 200) {
          final List list = jsonDecode(res.body);
          setState(() {
            _entrenamientos = list
                .map((e) => Entrenamiento.fromJson(e))
                .toList();
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_entrenamientos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Aún no hay entrenamientos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Crea el primer plan para este cliente'),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final auth = Provider.of<AuthService>(context, listen: false);
                if (auth.isClient) return const SizedBox.shrink();
                return ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to Create Training
                    context.push(
                      '/clientes/${widget.clienteId}/crear-entrenamiento',
                    );
                  },
                  icon: const Icon(Icons.fitness_center),
                  label: const Text('Crear entrenamiento'),
                );
              },
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Entrenamientos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Builder(
                builder: (context) {
                  final auth = Provider.of<AuthService>(context, listen: false);
                  if (auth.isClient) return const SizedBox.shrink();
                  return ElevatedButton.icon(
                    onPressed: () {
                      context.push(
                        '/clientes/${widget.clienteId}/crear-entrenamiento',
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo plan'),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_entrenamientos.length == 1)
            SizedBox(
              height: 170,
              width: double.infinity,
              child: _buildCard(_entrenamientos.first),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _entrenamientos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 240,
                    child: _buildCard(_entrenamientos[index]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(Entrenamiento ent) {
    // Calculate stats
    int weeks = ent.semanas.length;
    int days = ent.semanas.fold(0, (sum, s) => sum + s.dias.length);
    int exercises = ent.semanas.fold(
      0,
      (sum, s) => sum + s.dias.fold(0, (dSum, d) => dSum + d.items.length),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (ent.id != null) {
            // Navigate to detail
            context.push('/entrenamientos/${ent.id}');
          }
        },
        child: Column(
          children: [
            Container(height: 6, color: Colors.blue.shade300),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ent.titulo,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildChip(Icons.calendar_view_week, '$weeks sem'),
                          const SizedBox(width: 4),
                          _buildChip(Icons.today, '$days días'),
                          const SizedBox(width: 4),
                          _buildChip(Icons.fitness_center, '$exercises ej'),
                          if (!ent.activo) ...[
                            const SizedBox(width: 4),
                            Chip(
                              label: const Text(
                                'Inactivo',
                                style: TextStyle(fontSize: 10),
                              ),
                              backgroundColor: Colors.grey.shade200,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      avatar: Icon(icon, size: 14, color: Colors.blueGrey),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
