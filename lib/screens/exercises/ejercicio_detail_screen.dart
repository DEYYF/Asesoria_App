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
  bool _hideYoutubeForDialog = false;
  bool _isDeleting = false;

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
    if (_isDeleting) return;

    // youtube_player_flutter usa una vista nativa/WebView. En algunos Android esa
    // vista se queda por encima del AlertDialog y bloquea los taps de Cancelar/Eliminar.
    // Ocultamos temporalmente el reproductor antes de abrir el diálogo.
    if (mounted) {
      setState(() => _hideYoutubeForDialog = true);
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: !_isDeleting,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar ejercicio'),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${_ejercicio.nombre}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed != true) {
      setState(() => _hideYoutubeForDialog = false);
      return;
    }

    setState(() => _isDeleting = true);

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.delete('/ejercicios/${_ejercicio.id}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ejercicio eliminado correctamente')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _hideYoutubeForDialog = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
    }
  }

  void _editEjercicio() {
    showDialog(
      context: context,
      builder: (context) => AddEditEjercicioDialog(
        ejercicio: _ejercicio,
        onSuccess: () async {
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_rounded, color: theme.primaryColor),
            onPressed: _editEjercicio,
            tooltip: 'Editar',
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: theme.colorScheme.error,
            ),
            onPressed: _isDeleting ? null : _deleteEjercicio,
            tooltip: 'Eliminar',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and Tags
              Text(
                _ejercicio.nombre,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_ejercicio.grupo != null)
                    _buildTag(
                      theme,
                      isDark,
                      _ejercicio.grupo!,
                      Icons.fitness_center_rounded,
                    ),
                  if (_ejercicio.equipo != null)
                    _buildTag(
                      theme,
                      isDark,
                      _ejercicio.equipo!,
                      Icons.construction_rounded,
                    ),
                  if (_ejercicio.nivel != null)
                    _buildTag(
                      theme,
                      isDark,
                      _ejercicio.nivel!,
                      Icons.signal_cellular_alt_rounded,
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Video Player
              if (_youtubeController != null && !_hideYoutubeForDialog) ...[
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: YoutubePlayer(
                      controller: _youtubeController!,
                      showVideoProgressIndicator: true,
                      progressIndicatorColor: theme.primaryColor,
                      bottomActions: [
                        CurrentPosition(),
                        ProgressBar(isExpanded: true),
                        RemainingDuration(),
                        FullScreenButton(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // Instructions Section
              _buildSectionHeader(theme, "INSTRUCCIONES"),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(theme, isDark),
                child: Text(
                  _ejercicio.instrucciones ?? 'Sin instrucciones detalladas.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.9),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Details Card
              _buildSectionHeader(theme, "DETALLES TÉCNICOS"),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(theme, isDark),
                child: Column(
                  children: [
                    _buildDetailRow(
                      context,
                      'Grupo Muscular',
                      _ejercicio.grupo ?? '—',
                    ),
                    Divider(
                      height: 24,
                      color: theme.dividerColor.withOpacity(0.1),
                    ),
                    _buildDetailRow(
                      context,
                      'Material',
                      _ejercicio.equipo ?? '—',
                    ),
                    Divider(
                      height: 24,
                      color: theme.dividerColor.withOpacity(0.1),
                    ),
                    _buildDetailRow(
                      context,
                      'Dificultad',
                      _ejercicio.nivel ?? '—',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(ThemeData theme, bool isDark, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.primaryColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: theme.hintColor,
      ),
    );
  }

  BoxDecoration _cardDecoration(ThemeData theme, bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      boxShadow: [
        if (!isDark)
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
      ],
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.hintColor,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
