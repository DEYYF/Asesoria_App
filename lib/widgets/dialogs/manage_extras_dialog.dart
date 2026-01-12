import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../models/extra_model.dart';
import '../../models/presupuesto_model.dart';

class ManageExtrasDialog extends StatefulWidget {
  final String clienteId;
  final VoidCallback onSuccess;

  const ManageExtrasDialog({
    super.key,
    required this.clienteId,
    required this.onSuccess,
  });

  @override
  State<ManageExtrasDialog> createState() => _ManageExtrasDialogState();
}

class _ManageExtrasDialogState extends State<ManageExtrasDialog> {
  List<Extra> _extrasDisponibles = [];
  List<String> _extrasSeleccionados = [];
  Presupuesto? _presupuestoActivo;
  bool _isLoading = true;
  String? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      // 1. Get Extras
      final resExtras = await api.get('/extras');
      if (resExtras.statusCode != 200) throw Exception('Error fetching extras');
      final listExtras = (jsonDecode(resExtras.body) as List)
          .map((i) => Extra.fromJson(i))
          .toList();

      // 2. Get Presupuestos
      final resBudgets = await api.get(
        '/presupuestos',
        params: {'clienteId': widget.clienteId},
      );
      if (resBudgets.statusCode != 200) {
        throw Exception('Error fetching budgets');
      }
      final listBudgets = (jsonDecode(resBudgets.body) as List)
          .map((i) => Presupuesto.fromJson(i))
          .toList();

      // Sort desc (assuming backend does it, but good to ensure)
      // Actually backend usually returns sorted, logic is listBudgets[0]
      Presupuesto? activeBudget;
      if (listBudgets.isNotEmpty) {
        activeBudget = listBudgets[0]; // Assuming most recent first
      }

      List<String> selected = [];
      if (activeBudget != null) {
        selected = activeBudget.extras.map((e) => e.extraId).toList();
      }

      setState(() {
        _extrasDisponibles = listExtras;
        _presupuestoActivo = activeBudget;
        _extrasSeleccionados = selected;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _handleToggle(String id) {
    setState(() {
      if (_extrasSeleccionados.contains(id)) {
        _extrasSeleccionados.remove(id);
      } else {
        _extrasSeleccionados.add(id);
      }
    });
  }

  Future<void> _handleSave() async {
    if (_presupuestoActivo == null) return;
    setState(() {
      _isSaving = true;
    });

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.put('/presupuestos/${_presupuestoActivo!.id}/extras', {
        'extras': _extrasSeleccionados,
      });
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = "Error al guardar: $e";
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      title: Text(
        'Gestionar Extras',
        style: TextStyle(color: theme.textTheme.titleLarge?.color),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
            ? Text(_error!, style: const TextStyle(color: Colors.red))
            : _presupuestoActivo == null
            ? const Text(
                'No hay presupuesto activo para este cliente.',
                style: TextStyle(color: Colors.red),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),

                  if (_extrasDisponibles.isEmpty)
                    Text(
                      'No hay extras disponibles.',
                      style: TextStyle(color: theme.hintColor),
                    ),

                  ..._extrasDisponibles.map((extra) {
                    return CheckboxListTile(
                      title: Text(
                        '${extra.nombre} (+${extra.precio}€/mes)',
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                      value: _extrasSeleccionados.contains(extra.id),
                      activeColor: theme.primaryColor,
                      checkColor: Colors.white,
                      onChanged: (val) => _handleToggle(extra.id),
                    );
                  }),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: (_presupuestoActivo == null || _isSaving)
              ? null
              : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Guardar Cambios'),
        ),
      ],
    );
  }
}
