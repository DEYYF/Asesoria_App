import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/entrenamiento_model.dart';
import '../../models/ejercicio_model.dart';
import '../training/notebook_screen.dart';
import '../../utils/training_pdf_generator.dart';

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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _handleExportPDF() async {
    if (_ent == null) return;
    try {
      await TrainingPdfGenerator.generatePDF(_ent!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF generado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al generar PDF: $e')));
      }
    }
  }

  Future<void> _handleDuplicate() async {
    if (_ent == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplicar Plan'),
        content: Text('¿Deseas crear una copia de "${_ent!.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Duplicar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final copy = Entrenamiento(
        clienteId: _ent!.clienteId,
        asesorId: _ent!.asesorId,
        titulo: '${_ent!.titulo} (Copia)',
        objetivo: _ent!.objetivo,
        semanas: _ent!.semanas,
      );

      final res = await api.post('/entrenamientos', copy.toJson());
      if (res.statusCode == 201 || res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entrenamiento duplicado correctamente'),
            ),
          );
          context.pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${res.body}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Excepción: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD700)),
        ),
      );
    }
    if (_ent == null) {
      return const Scaffold(
        body: Center(child: Text('Entrenamiento no encontrado')),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          color: theme.iconTheme.color,
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Detalle de Rutina',
          style: TextStyle(
            color: theme.textTheme.titleLarge?.color,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: theme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Card
              _TrainingHeaderCard(
                ent: _ent!,
                onExport: _handleExportPDF,
                onDuplicate: _handleDuplicate,
                onDelete: _handleDelete,
                onRegister: () => context.push(
                  '/entrenamientos/cuaderno/${widget.entrenamientoId}',
                ),
              ),
              const SizedBox(height: 24),

              // 2. Stats
              _TrainingStatsCards(ent: _ent!),
              const SizedBox(height: 32),

              // 3. Content
              Text(
                'ESTRUCTURA DE ENTRENAMIENTO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: theme.hintColor.withOpacity(0.5),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              ..._ent!.semanas.map((sem) => _WeekSection(sem: sem)),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainingHeaderCard extends StatelessWidget {
  final Entrenamiento ent;
  final VoidCallback onExport;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onRegister;

  const _TrainingHeaderCard({
    required this.ent,
    required this.onExport,
    required this.onDuplicate,
    required this.onDelete,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final updatedStr = ent.updatedAt != null
        ? DateFormat('dd MMM, yyyy').format(ent.updatedAt!)
        : '-';

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ent.titulo,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: theme.textTheme.headlineSmall?.color,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.update_rounded,
                          size: 14,
                          color: theme.hintColor.withOpacity(0.5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Actualizado $updatedStr',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.hintColor.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (ent.activo ? Colors.green : Colors.grey).withOpacity(
                    0.1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  ent.activo ? 'ACTIVO' : 'INACTIVO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: ent.activo ? Colors.green : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ActionButton(
                  icon: Icons.edit_calendar_rounded,
                  label: 'Sesión',
                  onTap: onRegister,
                  isPrimary: true,
                  color: Colors.purple.shade600,
                ),
                const SizedBox(width: 10),
                _ActionButton(
                  icon: Icons.picture_as_pdf_rounded,
                  label: 'PDF',
                  onTap: onExport,
                  isPrimary: true,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 10),
                Builder(
                  builder: (context) {
                    final auth = Provider.of<AuthService>(
                      context,
                      listen: false,
                    );
                    if (auth.isClient) return const SizedBox.shrink();
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ActionButton(
                          icon: Icons.edit_rounded,
                          label: 'Editar',
                          onTap: () {
                            context
                                .push('/entrenamientos/${ent.id}/editar')
                                .then((_) => (context as dynamic)._loadData());
                          },
                        ),
                        const SizedBox(width: 10),
                        _ActionButton(
                          icon: Icons.copy_rounded,
                          label: 'Copiar',
                          onTap: onDuplicate,
                        ),
                        const SizedBox(width: 10),
                        _ActionButton(
                          icon: Icons.delete_outline_rounded,
                          label: 'Borrar',
                          color: Colors.redAccent,
                          onTap: onDelete,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingStatsCards extends StatelessWidget {
  final Entrenamiento ent;
  const _TrainingStatsCards({required this.ent});

  @override
  Widget build(BuildContext context) {
    int weeks = ent.semanas.length;
    int days = ent.semanas.fold(0, (sum, s) => sum + s.dias.length);
    int exercises = ent.semanas.fold(
      0,
      (sum, s) => sum + s.dias.fold(0, (dSum, d) => dSum + d.items.length),
    );

    return Row(
      children: [
        Expanded(
          child: _StatBox(
            label: 'Semanas',
            value: '$weeks',
            icon: Icons.calendar_view_week_rounded,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            label: 'Días/Sem',
            value: '${(days / weeks).toStringAsFixed(0)}',
            icon: Icons.event_repeat_rounded,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            label: 'Ejercicios',
            value: '$exercises',
            icon: Icons.fitness_center_rounded,
            color: Colors.purple,
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: theme.hintColor.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekSection extends StatelessWidget {
  final SemanaEntrenamiento sem;
  const _WeekSection({required this.sem});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Semana ${sem.numero}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        ...sem.dias.map((dia) => _DaySection(dia: dia)),
      ],
    );
  }
}

class _DaySection extends StatefulWidget {
  final DiaEntrenamiento dia;
  const _DaySection({required this.dia});

  @override
  State<_DaySection> createState() => _DaySectionState();
}

class _DaySectionState extends State<_DaySection> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.flash_on_rounded,
                      color: theme.primaryColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.dia.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.dia.items.length} ejercicios',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.hintColor.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: theme.hintColor,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            Divider(height: 1, color: theme.dividerColor.withOpacity(0.05)),
            _buildTableHeader(theme),
            ...widget.dia.items.map((item) => _buildExerciseRow(item, theme)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildTableHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: theme.hintColor.withOpacity(0.02),
      child: Row(
        children: [
          const Expanded(
            flex: 3,
            child: Text(
              'EJERCICIO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
          _headerCell('SET'),
          _headerCell('REPS'),
          _headerCell('RIR'),
          _headerCell('D.(s)'),
          const Expanded(flex: 1, child: SizedBox()),
        ],
      ),
    );
  }

  Widget _headerCell(String label) {
    return Expanded(
      flex: 1,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildExerciseRow(ItemEntrenamiento item, ThemeData theme) {
    final s = item.esquema ?? EsquemaSerie();
    final thumb = _getYoutubeThumbnail(
      item.urlVideo ?? item.ejercicio?.urlVideo,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.ejercicioNombre ?? item.ejercicio?.nombre ?? 'Ejercicio',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (item.ejercicio?.grupo != null)
                  Text(
                    item.ejercicio!.grupo!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: theme.primaryColor,
                    ),
                  ),
              ],
            ),
          ),
          _dataCell('${s.series}'),
          _dataCell('${s.repsMin}-${s.repsMax}'),
          _dataCell('${s.rir ?? '-'}'),
          _dataCell('${s.descanso ?? '-'}'),
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () =>
                  _launchVideo(item.urlVideo ?? item.ejercicio?.urlVideo),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: thumb.isNotEmpty
                      ? Colors.red.withOpacity(0.1)
                      : theme.hintColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  thumb.isNotEmpty
                      ? Icons.play_arrow_rounded
                      : Icons.videocam_off_outlined,
                  size: 16,
                  color: thumb.isNotEmpty ? Colors.red : theme.hintColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataCell(String val) {
    return Expanded(
      flex: 1,
      child: Text(
        val,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _launchVideo(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
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
      if (videoId != null) return 'https://img.youtube.com/vi/$videoId/0.jpg';
    } catch (_) {}
    return '';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = color ?? theme.primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary ? accentColor : accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isPrimary ? Colors.white : accentColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isPrimary ? Colors.white : accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
