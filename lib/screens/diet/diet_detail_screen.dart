import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../models/dieta_model.dart';
import '../../models/macros_model.dart';
import '../../services/api_service.dart';
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
    if (res.statusCode != 200)
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
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
      await DietPdfGenerator.generatePDF(dieta);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la Dieta')),
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
                          if (mounted)
                            setState(() => _dietFuture = _fetchDiet());
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
    final dateStr = dieta.createdAt != null
        ? DateFormat('dd/MM/yyyy').format(dieta.createdAt!)
        : '-';

    return Card(
      color: Colors.blue.shade50.withOpacity(0.3),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detalle de la Dieta',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _iconText(Icons.calendar_month, dateStr),
                          _iconText(
                            Icons.local_fire_department,
                            '${dieta.macros.kcal.round()} kcal objetivo',
                          ),
                          _iconText(
                            Icons.flag,
                            dieta.objetivo?.toUpperCase() ?? '-',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                _ActionButton(
                  icon: Icons.picture_as_pdf,
                  label: 'Exportar',
                  onTap: onExport,
                  isPrimary: true,
                ),
                Builder(
                  builder: (context) {
                    final auth = Provider.of<AuthService>(
                      context,
                      listen: false,
                    );
                    if (auth.isClient) return const SizedBox.shrink();

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ActionButton(
                          icon: Icons.save_as,
                          label: 'Guardar versión',
                          onTap: onSaveVersion,
                        ),
                        _ActionButton(
                          icon: Icons.history,
                          label: 'Historial',
                          onTap: onHistory,
                        ),
                        _ActionButton(
                          icon: Icons.edit,
                          label: 'Editar',
                          onTap: onEdit,
                        ),
                        _ActionButton(
                          icon: Icons.delete_outline,
                          label: 'Eliminar',
                          color: Colors.red,
                          onTap: onDelete,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconText(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _InfoAndMacros extends StatelessWidget {
  final Dieta dieta;
  const _InfoAndMacros({required this.dieta});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isWide = constraints.maxWidth > 720;
        final info = Expanded(
          flex: isWide ? 5 : 0,
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Información general',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 24),
                  _InfoRow(
                    'Fecha de creación:',
                    dieta.createdAt != null
                        ? DateFormat('dd/MM/yyyy').format(dieta.createdAt!)
                        : '-',
                  ),
                  _InfoRow(
                    'Calorías totales:',
                    '${dieta.macros.kcal.round()} kcal',
                  ),
                  _InfoRow('Objetivo:', dieta.objetivo?.toUpperCase() ?? '-'),
                  _InfoRow('Estado:', dieta.estado.toUpperCase()),
                ],
              ),
            ),
          ),
        );

        final macros = Expanded(
          flex: isWide ? 7 : 0,
          child: Row(
            children: [
              Expanded(
                child: _MacroCard(
                  label: 'Proteínas',
                  val: dieta.macros.proteinas,
                  icon: Icons.egg_alt,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroCard(
                  label: 'Carbohidratos',
                  val: dieta.macros.carbohidratos,
                  icon: Icons.breakfast_dining,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MacroCard(
                  label: 'Grasas',
                  val: dieta.macros.grasas,
                  icon: Icons.water_drop,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [info, const SizedBox(width: 16), macros],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [info, const SizedBox(height: 12), macros],
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
    if (dieta.comidas.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('Sin comidas')),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Comidas',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            ...dieta.comidas.map((comida) => _MealItem(comida: comida)),
          ],
        ),
      ),
    );
  }
}

class _MealItem extends StatelessWidget {
  final Comida comida;
  const _MealItem({required this.comida});

  @override
  Widget build(BuildContext context) {
    final k = comida.totales.kcal > 0 ? comida.totales.kcal : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                comida.titulo,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (k > 0)
                Text(
                  '${k.round()} kcal',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
        if (comida.opciones.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Sin alimentos',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          )
        else
          ...comida.opciones.map((op) => _OptionRow(op: op)),
        const SizedBox(height: 16),
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
    final op = widget.op;
    final hasIngredients = op.items != null && op.items!.isNotEmpty;

    return Column(
      children: [
        ListTile(
          dense: true,
          leading: _getIcon(op.tipo),
          title: Text(op.nombre ?? op.tipo),
          subtitle: Text(_getSubtitle(op)),
          trailing: hasIngredients
              ? IconButton(
                  icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                )
              : null,
        ),
        if (_expanded)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: op.items!
                  .map(
                    (it) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('- ${it.nombre ?? "Ingrediente"}'),
                          Text(
                            '${it.gramos} g',
                            style: const TextStyle(color: Colors.grey),
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

  Icon _getIcon(String tipo) {
    switch (tipo) {
      case 'receta':
        return const Icon(
          Icons.restaurant_menu,
          size: 20,
          color: Colors.orange,
        );
      case 'combinacion':
        return const Icon(
          Icons.emoji_food_beverage,
          size: 20,
          color: Colors.brown,
        );
      default:
        return const Icon(Icons.local_dining, size: 20, color: Colors.green);
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
    final c = color ?? (isPrimary ? Colors.blue : Colors.grey.shade700);
    return isPrimary
        ? ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18, color: c),
            label: Text(label, style: TextStyle(color: c)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.withOpacity(0.5)),
            ),
          );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final double val;
  final IconData icon;
  final Color color;

  const _MacroCard({
    required this.label,
    required this.val,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    overflow: .ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${val.round()} g',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RetryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.refresh, size: 16),
      label: const Text('Reintentar'),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            _RetryButton(onTap: onRetry),
          ],
        ),
      ),
    );
  }
}
