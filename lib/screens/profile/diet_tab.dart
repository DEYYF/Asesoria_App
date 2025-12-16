import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../models/dieta_model.dart';
import '../diet/diet_detail_screen.dart';

class DietTab extends StatefulWidget {
  final String clienteId;
  const DietTab({super.key, required this.clienteId});

  @override
  State<DietTab> createState() => _DietTabState();
}

class _DietTabState extends State<DietTab> {
  List<Dieta> _dietas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDietas();
  }

  Future<void> _loadDietas() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      // Assuming GET /dietas?clienteId=... works as per React code
      // React params: { clienteId, isCurrent: "true" }
      // Using query parameters in URL manually since ApiService doesn't support params map yet (oops, simple implementation)
      final res = await api.get(
        '/dietas?clienteId=${widget.clienteId}&isCurrent=true',
      );

      if (mounted) {
        if (res.statusCode == 200) {
          final List list = jsonDecode(res.body);
          setState(() {
            _dietas = list.map((e) => Dieta.fromJson(e)).toList();
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

    if (_dietas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Aún no hay dietas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Crea la primera dieta para este cliente'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push(
                '/clientes/${widget.clienteId}/crear-dieta',
              ), // Ensure route exists
              icon: const Icon(Icons.add),
              label: const Text('Crear dieta'),
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
                'Dietas asignadas',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    context.push('/clientes/${widget.clienteId}/crear-dieta'),
                icon: const Icon(Icons.add),
                label: const Text('Nueva dieta'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_dietas.length == 1)
            SizedBox(
              height: 170, // Constrain height to avoid RenderFlex error
              width: double.infinity,
              child: _buildDietaCard(_dietas.first),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _dietas.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 240,
                    child: _buildDietaCard(_dietas[index]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDietaCard(Dieta dieta) {
    // createdAt isn't in my Dieta model yet? React uses it.
    // I defined Dieta model closely but might have missed createdAt if it wasn't in CreateDieta payload.
    // It usually comes from backend. I'll ignore for now or use fallback.

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (dieta.id != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DietDetailScreen(dietaId: dieta.id!),
              ),
            );
          }
        },
        child: Column(
          children: [
            Container(height: 6, color: Colors.amber.shade200),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dieta.nombre,
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
                          Chip(
                            label: Text(
                              '${dieta.macros.kcal.toInt()} kcal',
                              style: const TextStyle(fontSize: 11),
                            ),
                            avatar: const Icon(
                              Icons.local_fire_department,
                              size: 14,
                              color: Colors.orange,
                            ),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 4),
                          if (dieta.objetivo != null)
                            Chip(
                              label: Text(
                                dieta.objetivo!,
                                style: const TextStyle(fontSize: 11),
                              ),
                              avatar: const Icon(Icons.flag, size: 14),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
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
}
