import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../models/entrenamiento_model.dart';
import '../../models/ejercicio_model.dart';
import '../training/notebook_screen.dart';

class TrainingDetailScreen extends StatefulWidget {
  final String entrenamientoId;
  const TrainingDetailScreen({super.key, required this.entrenamientoId});

  @override
  State<TrainingDetailScreen> createState() => _TrainingDetailScreenState();
}

class _TrainingDetailScreenState extends State<TrainingDetailScreen> {
  Entrenamiento? _ent;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get('/entrenamientos/${widget.entrenamientoId}');
      if (mounted) {
        if (res.statusCode == 200) {
          setState(() {
            _ent = Entrenamiento.fromJson(jsonDecode(res.body));
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

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Plan'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este entrenamiento?',
        ),
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
      await api.delete('/entrenamientos/${widget.entrenamientoId}');
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _launchVideo(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      // ignore
    }
  }

  String _getYoutubeThumbnail(String? url) {
    if (url == null || url.isEmpty) return '';
    try {
      final uri = Uri.parse(url);
      String? videoId;
      if (uri.host.contains('youtube.com')) {
        videoId = uri.queryParameters['v'];
      } else if (uri.host.contains('youtu.be')) {
        videoId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      }
      if (videoId != null) {
        return 'https://img.youtube.com/vi/$videoId/0.jpg';
      }
    } catch (_) {}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_ent == null)
      return const Scaffold(
        body: Center(child: Text('Entrenamiento no encontrado')),
      );

    // Date formatting
    final updatedStr = _ent!.updatedAt != null
        ? '${_ent!.updatedAt!.day}/${_ent!.updatedAt!.month}/${_ent!.updatedAt!.year}'
        : '-';

    return Scaffold(
      backgroundColor: Colors.white, // Match clean white background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(
          color: Colors.black,
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.fitness_center, color: Colors.black),
            const SizedBox(width: 8),
            Text(
              'Rutina entrenamiento',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Actions Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Volver'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF007AFF),
                      side: const BorderSide(color: Color(0xFF007AFF)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Editar: Pendiente')),
                      );
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Editar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF007AFF),
                      side: const BorderSide(color: Color(0xFF007AFF)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Duplicar: Pendiente')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Duplicar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF007AFF),
                      side: const BorderSide(color: Color(0xFF007AFF)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _handleDelete,
                    icon: const Icon(Icons.delete_forever, size: 16),
                    label: const Text('Eliminar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Exportar PDF: Pendiente'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('Exportar PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0056B3), // Dark Blue
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.push(
                        '/entrenamientos/cuaderno/${widget.entrenamientoId}',
                      );
                    },
                    icon: const Icon(Icons.edit_calendar, size: 16),
                    label: const Text('Registrar Sesión'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0), // Purple
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats Row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  Icons.calendar_today,
                  'Actualizado: $updatedStr',
                ),
                _buildInfoChip(Icons.flag, '${_ent!.semanas.length} semana'),
                _buildInfoChip(
                  Icons.calendar_view_day,
                  '${_ent!.semanas.fold(0, (s, w) => s + w.dias.length)} días',
                ),
                _buildInfoChip(
                  Icons.fitness_center,
                  '${_ent!.semanas.fold(0, (s, w) => s + w.dias.fold(0, (d, day) => d + day.items.length))} ejercicios',
                ),
              ],
            ),
            const Divider(height: 32),

            // Content
            ..._ent!.semanas.map((sem) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Semana ${sem.numero}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${sem.dias.length} día(s)',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...sem.dias.map((dia) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Day Header
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  dia.nombre,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        '${dia.items.length} ejercicio(s)',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.keyboard_arrow_up,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          // Table Header
                          _buildTableHeader(),
                          // Table Body
                          ...dia.items
                              .map((item) => _buildExerciseRow(item))
                              .toList(),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Expanded(
            flex: 3,
            child: Text(
              'Ejercicio',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          _buildHeaderCell('Series'),
          _buildHeaderCell('Reps'),
          _buildHeaderCell('RIR'),
          _buildHeaderCell('Desc (s)'),
          const Expanded(
            flex: 1,
            child: Text(
              'Video',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label) {
    return Expanded(
      flex: 1,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildExerciseRow(ItemEntrenamiento item) {
    final s = item.esquema ?? EsquemaSerie();
    final thumb = _getYoutubeThumbnail(
      item.urlVideo ?? item.ejercicio?.urlVideo,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Ejercicio + Chips
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.ejercicioNombre ?? item.ejercicio?.nombre ?? 'Ejercicio',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: [
                    if (item.ejercicio?.grupo != null)
                      _buildTag(item.ejercicio!.grupo!),
                    if (item.ejercicio?.equipo != null)
                      _buildTag(item.ejercicio!.equipo!),
                  ],
                ),
                if (item.grupoId != null && item.grupoId!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Grupo: ${item.grupoId}',
                      style: const TextStyle(fontSize: 10, color: Colors.blue),
                    ),
                  ),
              ],
            ),
          ),
          _buildDataCell('${s.series}'),
          _buildDataCell('${s.repsMin}-${s.repsMax}'),
          _buildDataCell('${s.rir ?? '-'}'),
          _buildDataCell('${s.descanso ?? '-'}'),

          // Video
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () =>
                  _launchVideo(item.urlVideo ?? item.ejercicio?.urlVideo),
              child: thumb.isNotEmpty
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            thumb,
                            height: 40,
                            width: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(),
                          ),
                        ),
                        const Icon(
                          Icons.play_circle_fill,
                          color: Colors.red,
                          size: 20,
                        ),
                      ],
                    )
                  : const Icon(Icons.play_circle_outline, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCell(String text) {
    return Expanded(
      flex: 1,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Colors.black87),
      ),
    );
  }
}
