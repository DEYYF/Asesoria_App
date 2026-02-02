import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/entrenamiento_model.dart';
import '../../widgets/training/muscle_heatmap_widget.dart';

class TrainingTab extends StatefulWidget {
  final String clienteId;
  const TrainingTab({super.key, required this.clienteId});

  @override
  State<TrainingTab> createState() => _TrainingTabState();
}

class _TrainingTabState extends State<TrainingTab> {
  List<Entrenamiento> _entrenamientos = [];
  bool _isLoading = true;
  bool _showFront = true;
  Map<String, double> _muscleIntensity = {};

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
            _calculateIntensities();
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
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFD700)),
      );
    }

    final theme = Theme.of(context);

    if (_entrenamientos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center_rounded,
              size: 64,
              color: theme.hintColor.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            Text(
              'Aún no hay rutinas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: theme.hintColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Diseña el primer plan de entrenamiento',
              style: TextStyle(
                color: theme.hintColor.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final auth = Provider.of<AuthService>(context, listen: false);
                if (auth.isClient) return const SizedBox.shrink();
                return ElevatedButton.icon(
                  onPressed: () => context.push(
                    '/clientes/${widget.clienteId}/crear-entrenamiento',
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Comenzar Rutina'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    final currentPlan = _entrenamientos.first;

    return RefreshIndicator(
      onRefresh: _loadEntrenamientos,
      color: theme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Title & Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu Entrenamiento',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: theme.textTheme.headlineMedium?.color,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Progreso de tu plan actual',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.hintColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
                Builder(
                  builder: (context) {
                    final auth = Provider.of<AuthService>(
                      context,
                      listen: false,
                    );
                    if (auth.isClient) return const SizedBox.shrink();
                    return _buildAddButton(theme);
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),

            // 2. Heatmap & Intensity
            _buildHeatmapSection(theme),
            const SizedBox(height: 30),

            // 3. Training Dashboard
            _buildTrainingDashboard(currentPlan, theme),
            const SizedBox(height: 40),

            // 3. Plans List
            Text(
              'Planes de Entrenamiento',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: theme.textTheme.titleLarge?.color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _entrenamientos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return _buildCard(_entrenamientos[index]);
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(ThemeData theme) {
    return GestureDetector(
      onTap: () =>
          context.push('/clientes/${widget.clienteId}/crear-entrenamiento'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.add_rounded, color: theme.primaryColor),
      ),
    );
  }

  Widget _buildTrainingDashboard(Entrenamiento? ent, ThemeData theme) {
    if (ent == null) return const SizedBox.shrink();

    final isDark = theme.brightness == Brightness.dark;
    int weeks = ent.semanas.length;
    int days = ent.semanas.fold(0, (sum, s) => sum + s.dias.length);
    int exercises = ent.semanas.fold(
      0,
      (sum, s) => sum + s.dias.fold(0, (dSum, d) => dSum + d.items.length),
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Semanas',
                '$weeks',
                Icons.calendar_view_week_rounded,
                Colors.blue,
              ),
              _buildStatItem(
                'Días/Sem',
                '${(days / weeks).toStringAsFixed(0)}',
                Icons.event_repeat_rounded,
                Colors.orange,
              ),
              _buildStatItem(
                'Ejercicios',
                '$exercises',
                Icons.fitness_center_rounded,
                Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 30),
          Divider(color: theme.dividerColor.withOpacity(0.05)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  ent.titulo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'ACTIVO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.green,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(Entrenamiento ent) {
    final theme = Theme.of(context);
    int weeks = ent.semanas.length;
    int days = ent.semanas.fold(0, (sum, s) => sum + s.dias.length);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () {
            if (ent.id != null) {
              context.push('/entrenamientos/${ent.id}');
            }
          },
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor,
                        theme.primaryColor.withOpacity(0.5),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                ent.titulo,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: theme.textTheme.titleMedium?.color,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (ent.objetivo != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  ent.objetivo!.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: theme.primaryColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _CompactInfo(
                              icon: Icons.calendar_view_week_rounded,
                              label: '$weeks sem',
                              color: theme.primaryColor,
                            ),
                            const SizedBox(width: 16),
                            _CompactInfo(
                              icon: Icons.fitness_center_rounded,
                              label: '$days días',
                              color: Colors.blueAccent,
                            ),
                            if (!ent.activo) ...[
                              const SizedBox(width: 16),
                              _CompactInfo(
                                icon: Icons.pause_circle_outline_rounded,
                                label: 'Inactivo',
                                color: theme.hintColor.withOpacity(0.6),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.dividerColor),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _calculateIntensities() {
    final Map<String, int> counts = {};
    int total = 0;

    for (var ent in _entrenamientos) {
      if (!ent.activo) continue;
      for (var sem in ent.semanas) {
        for (var dia in sem.dias) {
          for (var item in dia.items) {
            final grupo = item.ejercicio?.grupo ?? item.ejercicioNombre ?? '';
            final normalized = _normalizeMuscleGroup(grupo);
            if (normalized != null) {
              counts[normalized] = (counts[normalized] ?? 0) + 1;
              total++;
            }
          }
        }
      }
    }

    if (total == 0) {
      setState(() {
        _muscleIntensity = {};
      });
      return;
    }

    int maxCount = 0;
    counts.values.forEach((v) {
      if (v > maxCount) maxCount = v;
    });

    setState(() {
      _muscleIntensity = counts.map(
        (key, value) => MapEntry(key, value / (maxCount > 0 ? maxCount : 1)),
      );
    });
  }

  String? _normalizeMuscleGroup(String group) {
    group = group.toLowerCase();
    if (group.contains('pecho')) return 'Pecho';
    if (group.contains('abdo') || group.contains('core')) return 'Abdominales';
    if (group.contains('pierna') || group.contains('cuad')) return 'Cuádriceps';
    if (group.contains('bicep')) return 'Bíceps';
    if (group.contains('hombro') || group.contains('delto')) return 'Hombros';
    if (group.contains('espalda') || group.contains('dorsal')) return 'Espalda';
    if (group.contains('gluteo')) return 'Glúteos';
    if (group.contains('isquio') || group.contains('femoral')) return 'Isquios';
    if (group.contains('tricep')) return 'Tríceps';
    if (group.contains('gemelo') || group.contains('pantorrilla')) {
      return 'Gemelos';
    }
    return null;
  }

  Widget _buildHeatmapSection(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MAPA DE CALOR',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Distribución de Carga',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => setState(() => _showFront = !_showFront),
                  icon: Icon(
                    Icons.flip_camera_android_rounded,
                    color: theme.primaryColor,
                  ),
                  tooltip: 'Rotar Vista',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Center(
                  child: MuscleHeatmapWidget(
                    muscleIntensity: _muscleIntensity,
                    showFront: _showFront,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumen de Intensidad',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._buildIntensityList(theme),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildIntensityList(ThemeData theme) {
    final sorted = _muscleIntensity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty) {
      return [
        Text(
          'Registra entrenamientos para ver el mapa de calor muscular.',
          style: TextStyle(color: theme.hintColor, fontSize: 12),
        ),
      ];
    }

    return sorted.take(4).map((e) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  e.key,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(e.value * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: e.value,
                backgroundColor: theme.primaryColor.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                minHeight: 4,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _CompactInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CompactInfo({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}
