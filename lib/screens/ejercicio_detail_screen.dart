import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/ejercicio_model.dart';

class EjercicioDetailScreen extends StatefulWidget {
  final Ejercicio ejercicio;

  const EjercicioDetailScreen({super.key, required this.ejercicio});

  @override
  State<EjercicioDetailScreen> createState() => _EjercicioDetailScreenState();
}

class _EjercicioDetailScreenState extends State<EjercicioDetailScreen> {
  YoutubePlayerController? _youtubeController;

  @override
  void initState() {
    super.initState();
    _initializeYoutubePlayer();
  }

  void _initializeYoutubePlayer() {
    if (widget.ejercicio.urlVideo != null &&
        widget.ejercicio.urlVideo!.isNotEmpty) {
      final videoId = YoutubePlayer.convertUrlToId(widget.ejercicio.urlVideo!);
      if (videoId != null) {
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
        );
      }
    }
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.ejercicio.nombre), elevation: 0),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with chips
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(
                      context,
                    ).colorScheme.surfaceVariant.withOpacity(0.7),
                    Theme.of(context).colorScheme.surface,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        child: const Icon(Icons.fitness_center),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.ejercicio.nombre,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.ejercicio.grupo != null)
                        Chip(
                          label: Text(widget.ejercicio.grupo!),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                        ),
                      if (widget.ejercicio.equipo != null)
                        Chip(
                          label: Text(widget.ejercicio.equipo!),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                        ),
                      if (widget.ejercicio.nivel != null)
                        Chip(
                          label: Text(widget.ejercicio.nivel!),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Video player
            if (_youtubeController != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: YoutubePlayer(
                    controller: _youtubeController!,
                    showVideoProgressIndicator: true,
                    progressIndicatorColor: Theme.of(
                      context,
                    ).colorScheme.primary,
                  ),
                ),
              ),

            // Instructions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instrucciones',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.ejercicio.instrucciones ?? '—',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),

            // Details section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalles',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Grupo muscular',
                    widget.ejercicio.grupo ?? '—',
                  ),
                  _buildDetailRow(
                    'Equipo necesario',
                    widget.ejercicio.equipo ?? '—',
                  ),
                  _buildDetailRow('Nivel', widget.ejercicio.nivel ?? '—'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
