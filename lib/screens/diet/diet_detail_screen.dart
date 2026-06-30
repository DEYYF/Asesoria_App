import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../models/dieta_model.dart';
import '../../models/macros_model.dart';
import '../../services/api_service.dart';
import '../../services/settings_service.dart';
import '../../providers/settings_provider.dart';
import '../../models/settings_model.dart';
import '../../utils/diet_pdf_generator.dart';
import '../../services/offline_sync_service.dart';
import '../../widgets/revisions_dialog.dart';
import 'create_diet_screen.dart';
import 'create_calendar_diet_screen.dart';
import 'daily_diet_viewer_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DietDetailScreen extends StatefulWidget {
  final String dietaId;
  const DietDetailScreen({super.key, required this.dietaId});

  @override
  State<DietDetailScreen> createState() => _DietDetailScreenState();
}

class _DietDetailScreenState extends State<DietDetailScreen> {
  late Future<Dieta?> _dietFuture;

  @override
  void initState() {
    super.initState();
    _dietFuture = _fetchDiet();
  }

  Future<Dieta?> _fetchDiet() async {
    final api = Provider.of<ApiService>(context, listen: false);

    try {
      final res = await api.get('/dietas/${widget.dietaId}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final dieta = Dieta.fromJson(data);

        // Update single diet cache
        final prefs = await SharedPreferences.getInstance();
        final cacheKey = 'offline_diets_detail_${widget.dietaId}';
        await prefs.setString(
          cacheKey,
          jsonEncode({
            'timestamp': DateTime.now().toIso8601String(),
            'data': data,
          }),
        );

        return dieta;
      }
    } catch (e) {
      debugPrint('DietDetailScreen: Error fetching diet, trying cache: $e');
    }

    // Fallback to cache
    final prefs = await SharedPreferences.getInstance();
    // We don't have a specific key for single diet detail in the plan yet,
    // but we can check the offline_diets cache if it's there.
    // However, for now, let's just use the current diet list cache as a proxy if possible.
    final cacheKey = 'offline_diets_detail_${widget.dietaId}';
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      final Map<String, dynamic> cacheMap = jsonDecode(cached);
      return Dieta.fromJson(cacheMap['data']);
    }

    throw Exception('No se pudo cargar la dieta (Offline y sin caché)');
  }

  Future<void> _handleDelete() async {
    final api = Provider.of<ApiService>(context, listen: false);
    final syncService = Provider.of<OfflineSyncService>(context, listen: false);
    final isOffline = await syncService.isOffline();

    if (isOffline) {
      await syncService.queueUpdate(
        {},
        endpoint: '/dietas/${widget.dietaId}',
        method: 'DELETE',
      );
      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eliminación encolada (Offline)')),
        );
      }
      return;
    }

    try {
      final res = await api.delete('/dietas/${widget.dietaId}');
      if (res.statusCode == 200 && mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dieta eliminada')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  Future<void> _handleExportPDF(Dieta dieta) async {
    try {
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      PdfSettings pdfSettings;

      // If we already have settings and they belong to the advisor (or we are the advisor)
      if (settingsProvider.settings != null) {
        pdfSettings = settingsProvider.settings!.pdfSettings;
      } else {
        // Fallback: Fetch them specifically if needed, or use defaults
        // For now, let's try to get them from the service if we want to be very precise
        final settingsService = SettingsService(
          Provider.of<ApiService>(context, listen: false),
        );
        final settings = await settingsService.getSettings(
          userId: dieta.asesorId,
        );
        pdfSettings = settings.pdfSettings;
      }

      await DietPdfGenerator.generatePDF(dieta, pdfSettings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al exportar PDF: $e')));
      }
    }
  }

  Future<void> _handleSaveVersion() async {
    final noteController = TextEditingController();

    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Guardar Versión'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(labelText: 'Nota de la versión'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, noteController.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (note != null) {
      final api = Provider.of<ApiService>(context, listen: false);
      final syncService = Provider.of<OfflineSyncService>(
        context,
        listen: false,
      );
      final isOffline = await syncService.isOffline();

      final payload = {'note': note.isEmpty ? 'Snapshot manual' : note};

      if (isOffline) {
        await syncService.queueUpdate(
          payload,
          endpoint: '/dietas/${widget.dietaId}/revision',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Revisión encolada (Offline)')),
          );
        }
        return;
      }

      try {
        final res = await api.post(
          '/dietas/${widget.dietaId}/revision',
          payload,
        );
        if (res.statusCode == 201) {
          final data = jsonDecode(res.body);
          final newId = data['dieta']['_id'];
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Versión guardada con éxito')),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DietDetailScreen(dietaId: newId),
              ),
            );
          }
        } else {
          throw Exception(res.body);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar versión: $e')),
          );
        }
      }
    }
  }

  void _handleHistory() {
    showDialog(
      context: context,
      builder: (ctx) => RevisionsDialog(
        dietaId: widget.dietaId,
        onRestored: (newId) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => DietDetailScreen(dietaId: newId)),
          );
        },
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar dieta'),
        content: const Text(
          'Esta acción no se puede deshacer. ¿Seguro que quieres eliminar esta dieta?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: _handleDelete,
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Detalle de la Dieta'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: FutureBuilder<Dieta?>(
        future: _dietFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: 'Error al cargar la dieta',
              detail: '${snapshot.error}',
              onRetry: () => setState(() => _dietFuture = _fetchDiet()),
            );
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return _ErrorView(
              message: 'No se recibieron datos de la dieta.',
              onRetry: () => setState(() => _dietFuture = _fetchDiet()),
            );
          }

          final dieta = snapshot.data!;
          return SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      _HeaderCard(
                        dieta: dieta,
                        onExport: () => _handleExportPDF(dieta),
                        onSaveVersion: _handleSaveVersion,
                        onHistory: _handleHistory,
                        onEdit: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => dieta.tipo.trim().toLowerCase() == 'calendario'
                                  ? CreateCalendarDietScreen(
                                      clienteId: dieta.clienteId,
                                      dietaId: dieta.id,
                                      initialDieta: dieta,
                                    )
                                  : CreateDietScreen(
                                      clienteId: dieta.clienteId,
                                      dietaId: dieta.id,
                                    ),
                            ),
                          );
                          if (mounted) {
                            setState(() => _dietFuture = _fetchDiet());
                          }
                        },
                        onDelete: _showDeleteDialog,
                      ),
                      const SizedBox(height: 16),
                      _InfoAndMacros(dieta: dieta),
                      const SizedBox(height: 16),
                      dieta.tipo.trim().toLowerCase() == 'calendario'
                          ? _CalendarDietPlanCard(dieta: dieta)
                          : _MealsCard(dieta: dieta),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final Dieta dieta;
  final VoidCallback onExport;
  final VoidCallback onSaveVersion;
  final VoidCallback onHistory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HeaderCard({
    required this.dieta,
    required this.onExport,
    required this.onSaveVersion,
    required this.onHistory,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateStr = dieta.createdAt != null
        ? DateFormat('dd MMMM, yyyy').format(dieta.createdAt!)
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dieta.nombre,
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
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: theme.hintColor.withOpacity(0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (dieta.tipo.trim().toLowerCase() == 'calendario')
                    _HeaderBadge(
                      label: 'DIETA POR CALENDARIO',
                      icon: Icons.view_week_rounded,
                      color: theme.primaryColor,
                    ),
                  if (dieta.objetivo != null)
                    _HeaderBadge(
                      label: dieta.objetivo!.toUpperCase(),
                      color: theme.primaryColor,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ActionButton(
                  icon: Icons.picture_as_pdf_rounded,
                  label: 'PDF',
                  onTap: onExport,
                  isPrimary: true,
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
                          icon: Icons.save_as_rounded,
                          label: 'Revisión',
                          onTap: onSaveVersion,
                        ),
                        const SizedBox(width: 10),
                        _ActionButton(
                          icon: Icons.history_rounded,
                          label: 'Historial',
                          onTap: onHistory,
                        ),
                        const SizedBox(width: 10),
                        _ActionButton(
                          icon: Icons.edit_rounded,
                          label: 'Editar',
                          onTap: onEdit,
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


class _HeaderBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;

  const _HeaderBadge({
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoAndMacros extends StatelessWidget {
  final Dieta dieta;
  const _InfoAndMacros({required this.dieta});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final macs = dieta.macros;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _macroItem('Kcal', macs.kcal.round(), theme),
          _macroItem('Prot', '${macs.proteinas.round()}g', theme),
          _macroItem('Carb', '${macs.carbohidratos.round()}g', theme),
          _macroItem('Gras', '${macs.grasas.round()}g', theme),
        ],
      ),
    );
  }

  Widget _macroItem(String label, dynamic val, ThemeData theme) {
    return Column(
      children: [
        Text(
          val.toString(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}



class _CalendarDietPlanCard extends StatefulWidget {
  final Dieta dieta;
  const _CalendarDietPlanCard({required this.dieta});

  @override
  State<_CalendarDietPlanCard> createState() => _CalendarDietPlanCardState();
}

class _CalendarDietPlanCardState extends State<_CalendarDietPlanCard> {
  int _selectedDay = 0;

  static const _days = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  DiaCalendario? _dayData(int index) {
    final normalized = _normalize(_days[index]);
    for (final dia in widget.dieta.diasSemana) {
      if (_normalize(dia.dia) == normalized) return dia;
    }
    return null;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .trim();
  }

  Macros _sumDayMacros(DiaCalendario? dia) {
    if (dia == null) return Macros();
    return dia.comidas.fold<Macros>(
      Macros(),
      (acc, comida) => Macros(
        kcal: acc.kcal + comida.totales.kcal,
        proteinas: acc.proteinas + comida.totales.proteinas,
        carbohidratos: acc.carbohidratos + comida.totales.carbohidratos,
        grasas: acc.grasas + comida.totales.grasas,
      ),
    );
  }

  DateTime _dateForSelectedDay() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day + _selectedDay);
  }

  void _openDayViewer(DiaCalendario dia) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyDietViewerScreen(
          dieta: widget.dieta,
          dia: dia,
          fecha: _dateForSelectedDay(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.dieta.tipo.trim().toLowerCase() != 'calendario') {
      return _MealsCard(dieta: widget.dieta);
    }

    if (widget.dieta.diasSemana.isEmpty) {
      return _EmptyCalendarDietCard(theme: theme);
    }

    final selected = _dayData(_selectedDay);
    final macros = _sumDayMacros(selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          'CALENDARIO DE DIETA',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: theme.hintColor.withOpacity(0.5),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        _WeekSummaryGrid(
          days: _days,
          selectedDay: _selectedDay,
          dayData: _dayData,
          sumDayMacros: _sumDayMacros,
          onSelected: (index) => setState(() => _selectedDay = index),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _days[_selectedDay],
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${selected?.comidas.length ?? 0} comidas · ${macros.kcal.round()} kcal · P ${macros.proteinas.round()}g · C ${macros.carbohidratos.round()}g · G ${macros.grasas.round()}g',
                          style: TextStyle(
                            color: theme.hintColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected != null)
                    TextButton.icon(
                      onPressed: () => _openDayViewer(selected),
                      icon: const Icon(Icons.visibility_rounded, size: 18),
                      label: const Text('Ver día'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (selected == null || selected.comidas.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'Sin comidas asignadas para este día.',
                    style: TextStyle(color: theme.hintColor),
                  ),
                )
              else
                ...selected.comidas.map((comida) => _MealItem(comida: comida)),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyCalendarDietCard extends StatelessWidget {
  final ThemeData theme;
  const _EmptyCalendarDietCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.calendar_month_outlined, size: 42, color: theme.hintColor),
          const SizedBox(height: 12),
          Text(
            'Esta dieta calendario no tiene días configurados',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Pulsa Editar para añadir comidas por día de la semana.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

class _WeekSummaryGrid extends StatelessWidget {
  final List<String> days;
  final int selectedDay;
  final DiaCalendario? Function(int index) dayData;
  final Macros Function(DiaCalendario? dia) sumDayMacros;
  final ValueChanged<int> onSelected;

  const _WeekSummaryGrid({
    required this.days,
    required this.selectedDay,
    required this.dayData,
    required this.sumDayMacros,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final itemWidth = isWide ? (constraints.maxWidth - 72) / 4 : 170.0;

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
            children: List.generate(days.length, (index) {
              final dia = dayData(index);
              final macros = sumDayMacros(dia);
              final isSelected = index == selectedDay;
              final hasMeals = dia != null && dia.comidas.isNotEmpty;

              return Padding(
                padding: EdgeInsets.only(right: index == days.length - 1 ? 0 : 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: itemWidth,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.primaryColor.withOpacity(0.12)
                          : theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? theme.primaryColor.withOpacity(0.45)
                            : theme.dividerColor.withOpacity(0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                days[index],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: isSelected ? theme.primaryColor : null,
                                ),
                              ),
                            ),
                            Icon(
                              hasMeals ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: hasMeals ? theme.primaryColor : theme.hintColor.withOpacity(0.45),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${dia?.comidas.length ?? 0} comidas',
                          style: TextStyle(
                            color: theme.hintColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${macros.kcal.round()} kcal',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'P ${macros.proteinas.round()} · C ${macros.carbohidratos.round()} · G ${macros.grasas.round()}',
                          style: TextStyle(
                            color: theme.hintColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              }),
            ),
          ),
        );
      },
    );
  }
}

class _MealsCard extends StatelessWidget {
  final Dieta dieta;
  const _MealsCard({required this.dieta});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (dieta.comidas.isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(child: Text('Sin comidas registradas')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          'ESTRUCTURA DE COMIDAS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: theme.hintColor.withOpacity(0.5),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        ...dieta.comidas.map((comida) => _MealItem(comida: comida)),
      ],
    );
  }
}

class _MealItem extends StatelessWidget {
  final Comida comida;
  const _MealItem({required this.comida});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final k = comida.totales.kcal > 0 ? comida.totales.kcal : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.restaurant_rounded,
                    size: 16,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    comida.titulo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
              if (k > 0)
                Text(
                  '${k.round()} kcal',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.hintColor.withOpacity(0.8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        if (comida.opciones.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Sin alimentos',
              style: TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ),
          )
        else
          ...comida.opciones.map((op) => _OptionRow(op: op)),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _OptionRow extends StatefulWidget {
  final OpcionDieta op;
  const _OptionRow({required this.op});

  @override
  State<_OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<_OptionRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final op = widget.op;
    final hasIngredients = op.items != null && op.items!.isNotEmpty;

    return Column(
      children: [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getIconColor(op.tipo).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getIconData(op.tipo),
              size: 18,
              color: _getIconColor(op.tipo),
            ),
          ),
          title: Text(
            op.nombre ?? op.tipo,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          subtitle: Text(
            _getSubtitle(op),
            style: TextStyle(color: theme.hintColor, fontSize: 12),
          ),
          trailing: hasIngredients
              ? IconButton(
                  icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: theme.hintColor,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                )
              : null,
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: op.items!
                  .map(
                    (it) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '- ${it.nombre ?? "Ingrediente"}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          Text(
                            '${it.gramos} g',
                            style: TextStyle(
                              color: theme.hintColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (op.notas != null && op.notas!.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.primaryColor.withOpacity(0.1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 14,
                  color: theme.primaryColor.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    op.notas!,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.hintColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  IconData _getIconData(String tipo) {
    switch (tipo) {
      case 'receta':
        return Icons.restaurant_menu_rounded;
      case 'combinacion':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.local_dining_rounded;
    }
  }

  Color _getIconColor(String tipo) {
    switch (tipo) {
      case 'receta':
        return Colors.orange;
      case 'combinacion':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  String _getSubtitle(OpcionDieta op) {
    final macs = op.macrosTotales ?? Macros();
    final parts = [
      if (macs.kcal > 0) '${macs.kcal.round()} kcal',
      if (op.gramos != null && op.gramos! > 0) '${op.gramos} g',
    ];
    return parts.join(' · ');
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
    final isDark = theme.brightness == Brightness.dark;

    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      );
    }

    final c = color ?? (isDark ? Colors.white70 : Colors.black54);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: c),
      label: Text(label, style: TextStyle(color: c)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: c.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final String? detail;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, this.detail, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.hintColor, fontSize: 13),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
