import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../models/tarifa_model.dart';
import '../../utils/notification_helper.dart';

class TarifasScreen extends StatefulWidget {
  const TarifasScreen({super.key});

  @override
  State<TarifasScreen> createState() => _TarifasScreenState();
}

class _TarifasScreenState extends State<TarifasScreen> {
  List<Tarifa> _tarifas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTarifas();
  }

  Future<void> _fetchTarifas() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get('/tarifas');
      if (mounted) {
        setState(() {
          _tarifas = (jsonDecode(res.body) as List)
              .map((i) => Tarifa.fromJson(i))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching tarifas: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddEditDialog({Tarifa? tarifa}) async {
    final isEditing = tarifa != null;
    final nameCtrl = TextEditingController(text: tarifa?.nombre ?? '');
    final priceCtrl = TextEditingController(
      text: tarifa?.precio.toString() ?? '',
    );
    final daysCtrl = TextEditingController(
      text: tarifa?.duracionDias.toString() ?? '',
    );
    final descCtrl = TextEditingController(text: tarifa?.descripcion ?? '');
    String selectedTipo = tarifa?.tipoServicio ?? 'Mensual';

    final tiposServicio = [
      "Mensual",
      "Trimestral",
      "Semestral",
      "Anual",
      "Dieta",
      "Dieta y Asesoramiento",
      "Rutina",
      "Rutina y asesoramiento",
      "Dieta y Rutina",
    ];

    await showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        return Dialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isEditing ? 'Editar Tarifa' : 'Nueva Tarifa',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Name Input
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nombre de la Tarifa',
                      hintText: 'Ej: Plan Trimestral',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.label_outline),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  // Price and Days Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Precio',
                            suffixText: '€',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.euro),
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey[800]
                                : Colors.grey[50],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: daysCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Duración',
                            suffixText: 'días',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.calendar_today),
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey[800]
                                : Colors.grey[50],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Service Type Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedTipo,
                    decoration: InputDecoration(
                      labelText: 'Tipo de Servicio',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.category_outlined),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                    ),
                    items: tiposServicio.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) selectedTipo = val;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Description Input
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Descripción (Opcional)',
                      hintText: 'Detalles del plan...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.description_outlined),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.isEmpty ||
                              priceCtrl.text.isEmpty ||
                              daysCtrl.text.isEmpty) {
                            NotificationHelper.showError(
                              ctx,
                              'Rellena los campos obligatorios',
                            );
                            return;
                          }

                          // Show loading indicator on button or block interactions could be nice,
                          // but direct logic for now:
                          final api = Provider.of<ApiService>(
                            context,
                            listen: false,
                          );
                          final body = {
                            'nombre': nameCtrl.text.trim(),
                            'precio': double.tryParse(priceCtrl.text) ?? 0,
                            'duracionDias': int.tryParse(daysCtrl.text) ?? 30,
                            'tipoServicio': selectedTipo,
                            'descripcion': descCtrl.text.trim(),
                          };

                          try {
                            if (isEditing) {
                              await api.put('/tarifas/${tarifa.id}', body);
                            } else {
                              await api.post('/tarifas', body);
                            }
                            if (mounted) {
                              Navigator.pop(ctx);
                              _fetchTarifas();
                            }
                          } catch (e) {
                            if (mounted) {
                              NotificationHelper.showError(
                                context,
                                'Error: $e',
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text('Guardar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteTarifa(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Tarifa?'),
        content: const Text(
          'Esta acción ocultará la tarifa de futuros clientes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final api = Provider.of<ApiService>(context, listen: false);
      try {
        await api.delete('/tarifas/$id');
        _fetchTarifas();
      } catch (e) {
        if (mounted) {
          NotificationHelper.showError(context, 'Error: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tarifas')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tarifas.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.monetization_on_outlined,
                    size: 64,
                    color: theme.disabledColor,
                  ),
                  const SizedBox(height: 16),
                  const Text('No hay tarifas configuradas'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tarifas.length,
              itemBuilder: (context, index) {
                final t = _tarifas[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    title: Text(
                      t.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${t.tipoServicio} • ${t.duracionDias} días${t.descripcion != null && t.descripcion!.isNotEmpty ? ' • ${t.descripcion}' : ''}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${t.precio}€',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'edit') {
                              _showAddEditDialog(tarifa: t);
                            } else if (val == 'delete') {
                              _deleteTarifa(t.id);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text('Editar'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Eliminar',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () => _showAddEditDialog(tarifa: t),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        label: const Text('Nueva Tarifa'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
