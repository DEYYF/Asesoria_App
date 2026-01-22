import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../models/extra_model.dart';
import '../../utils/notification_helper.dart';

class ExtrasScreen extends StatefulWidget {
  const ExtrasScreen({super.key});

  @override
  State<ExtrasScreen> createState() => _ExtrasScreenState();
}

class _ExtrasScreenState extends State<ExtrasScreen> {
  List<Extra> _extras = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchExtras();
  }

  Future<void> _fetchExtras() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get('/extras');
      if (mounted) {
        setState(() {
          _extras = (jsonDecode(res.body) as List)
              .map((i) => Extra.fromJson(i))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching extras: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddEditDialog({Extra? extra}) async {
    final isEditing = extra != null;
    final nameCtrl = TextEditingController(text: extra?.nombre ?? '');
    final priceCtrl = TextEditingController(
      text: extra?.precio.toString() ?? '',
    );
    final descCtrl = TextEditingController(text: extra?.descripcion ?? '');

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
                    isEditing ? 'Editar Extra' : 'Nuevo Extra',
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
                      labelText: 'Nombre del Servicio',
                      hintText: 'Ej: Dieta Personalizada',
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
                  // Price Input
                  TextFormField(
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
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Description Input
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Descripción (Opcional)',
                      hintText: 'Detalles del servicio...',
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
                          if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) {
                            NotificationHelper.showError(
                              ctx,
                              'Rellena los campos obligatorios',
                            );
                            return;
                          }

                          final api = Provider.of<ApiService>(
                            context,
                            listen: false,
                          );
                          final body = {
                            'nombre': nameCtrl.text.trim(),
                            'precio': double.tryParse(priceCtrl.text) ?? 0,
                            'descripcion': descCtrl.text.trim(),
                          };

                          try {
                            if (isEditing) {
                              await api.put('/extras/${extra.id}', body);
                            } else {
                              await api.post('/extras', body);
                            }
                            if (mounted) {
                              Navigator.pop(ctx);
                              _fetchExtras();
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

  Future<void> _deleteExtra(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Extra?'),
        content: const Text(
          'Esta acción ocultará el extra de futuros clientes.',
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
        await api.delete('/extras/$id');
        _fetchExtras();
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
      appBar: AppBar(title: const Text('Extras')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _extras.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.extension_outlined,
                    size: 64,
                    color: theme.disabledColor,
                  ),
                  const SizedBox(height: 16),
                  const Text('No hay extras configurados'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _extras.length,
              itemBuilder: (context, index) {
                final e = _extras[index];
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
                      e.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(e.descripcion ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${e.precio}€',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'edit') {
                              _showAddEditDialog(extra: e);
                            } else if (val == 'delete') {
                              _deleteExtra(e.id);
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
                    onTap: () => _showAddEditDialog(extra: e),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        label: const Text('Nuevo Extra'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
