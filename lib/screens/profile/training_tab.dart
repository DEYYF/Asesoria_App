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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_entrenamientos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Aún no hay entrenamientos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea el primer plan para este cliente',
              style: TextStyle(color: theme.hintColor),
            ),
            const SizedBox(height: 16),
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
                  icon: const Icon(Icons.fitness_center),
                  label: const Text('Crear entrenamiento'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
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
              Text(
                'Entrenamientos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleLarge?.color,
                ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_entrenamientos.length == 1)
            SizedBox(
              height: 140,
              width: double.infinity,
              child: _buildCard(_entrenamientos.first),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: _entrenamientos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 260,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    int weeks = ent.semanas.length;
    int days = ent.semanas.fold(0, (sum, s) => sum + s.dias.length);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            if (ent.id != null) {
              context.push('/entrenamientos/${ent.id}');
            }
          },
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF34C759),
                        const Color(0xFF34C759).withOpacity(0.5),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ent.titulo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _StatusChip(
                          icon: Icons.calendar_view_week_rounded,
                          label: '$weeks semanas',
                          color: theme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(
                          icon: Icons.fitness_center_rounded,
                          label: '$days días',
                          color: Colors.blueAccent,
                        ),
                      ],
                    ),
                    if (!ent.activo) ...[
                      const SizedBox(height: 8),
                      Text(
                        'PLAN INACTIVO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: theme.hintColor.withOpacity(0.5),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}
