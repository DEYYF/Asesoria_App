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
import '../../widgets/revisions_dialog.dart';
import 'create_diet_screen.dart';

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
    final res = await api.get('/dietas/${widget.dietaId}');
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    return Dieta.fromJson(data);
  }

  Future<void> _handleDelete() async {
    final api = Provider.of<ApiService>(context, listen: false);
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
      try {
        final res = await api.post('/dietas/${widget.dietaId}/revision', {
          'note': note.isEmpty ? 'Snapshot manual' : note,
        });
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
                              builder: (_) => CreateDietScreen(
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
                      _MealsCard(dieta: dieta),
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
              if (dieta.objetivo != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.primaryColor.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    dieta.objetivo!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
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
