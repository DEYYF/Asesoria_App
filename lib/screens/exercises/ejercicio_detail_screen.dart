import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../models/ejercicio_model.dart';
import '../../services/api_service.dart';
import '../../widgets/dialogs/add_edit_ejercicio_dialog.dart';

class EjercicioDetailScreen extends StatefulWidget {
  final Ejercicio ejercicio;

  const EjercicioDetailScreen({super.key, required this.ejercicio});

  @override
  State<EjercicioDetailScreen> createState() => _EjercicioDetailScreenState();
}

class _EjercicioDetailScreenState extends State<EjercicioDetailScreen> {
  late Ejercicio _ejercicio;
  YoutubePlayerController? _youtubeController;

  @override
  void initState() {
    super.initState();
    _ejercicio = widget.ejercicio;
    _initializeYoutubePlayer();
  }

  void _initializeYoutubePlayer() {
    _youtubeController?.dispose();
    _youtubeController = null;

    if (_ejercicio.urlVideo != null && _ejercicio.urlVideo!.isNotEmpty) {
      final videoId = YoutubePlayer.convertUrlToId(_ejercicio.urlVideo!);
      if (videoId != null) {
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
        );
      }
    }
  }

  Future<void> _deleteEjercicio() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Ejercicio'),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${_ejercicio.nombre}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final api = Provider.of<ApiService>(context, listen: false);
      try {
        await api.delete('/ejercicios/${_ejercicio.id}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ejercicio eliminado correctamente')),
          );
          Navigator.pop(context, true); // Pop with true to indicate deletion
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
        }
      }
    }
  }

  void _editEjercicio() {
    showDialog(
      context: context,
      builder: (context) => AddEditEjercicioDialog(
        ejercicio: _ejercicio,
        onSuccess: () async {
          // Re-fetch exercise details or simply update state if dialog returns updated object
          // For now, let's re-fetch from API to be sure
          final api = Provider.of<ApiService>(context, listen: false);
          try {
            final res = await api.get('/ejercicios/${_ejercicio.id}');
            if (res.statusCode == 200) {
              final data = await api.parseJsonResponse(res);
              setState(() {
                _ejercicio = Ejercicio.fromJson(data);
                _initializeYoutubePlayer();
              });
            }
          } catch (e) {
            debugPrint('Error updating detail view: $e');
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_ejercicio.nombre),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editEjercicio,
            tooltip: 'Editar',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteEjercicio,
            tooltip: 'Eliminar',
          ),
        ],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with chips
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: theme.primaryColor.withOpacity(0.1),
                        child: Icon(
                          Icons.fitness_center,
                          color: theme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _ejercicio.nombre,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_ejercicio.grupo != null)
                        Chip(
                          label: Text(_ejercicio.grupo!),
                          backgroundColor: theme.colorScheme.primaryContainer
                              .withOpacity(0.5),
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          side: BorderSide.none,
                        ),
                      if (_ejercicio.equipo != null)
                        Chip(
                          label: Text(_ejercicio.equipo!),
                          backgroundColor: theme.colorScheme.secondaryContainer
                              .withOpacity(0.5),
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                          side: BorderSide.none,
                        ),
                      if (_ejercicio.nivel != null)
                        Chip(
                          label: Text(_ejercicio.nivel!),
                          backgroundColor: theme.colorScheme.tertiaryContainer
                              .withOpacity(0.5),
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                          side: BorderSide.none,
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
                    progressIndicatorColor: theme.primaryColor,
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _ejercicio.instrucciones ?? '—',
                      style: theme.textTheme.bodyMedium,
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          context,
                          'Grupo muscular',
                          _ejercicio.grupo ?? '—',
                        ),
                        Divider(height: 24, color: theme.dividerColor),
                        _buildDetailRow(
                          context,
                          'Equipo necesario',
                          _ejercicio.equipo ?? '—',
                        ),
                        Divider(height: 24, color: theme.dividerColor),
                        _buildDetailRow(
                          context,
                          'Nivel',
                          _ejercicio.nivel ?? '—',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.hintColor,
            ),
          ),
        ),
        Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
