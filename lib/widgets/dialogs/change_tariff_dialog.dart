import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../utils/notification_helper.dart';

const opcionesDuracion = ["1 Mes", "3 Meses", "6 Meses", "12 Meses"];

class ChangeTariffDialog extends StatefulWidget {
  final String clienteId;
  final String
  currentDuration; // Kept for interface compatibility but we'll select based on Tarifa name if possible or just show list
  final VoidCallback onSuccess;

  const ChangeTariffDialog({
    super.key,
    required this.clienteId,
    required this.currentDuration,
    required this.onSuccess,
  });

  @override
  State<ChangeTariffDialog> createState() => _ChangeTariffDialogState();
}

class _ChangeTariffDialogState extends State<ChangeTariffDialog> {
  String? _selectedTarifa;
  List<dynamic> _tarifas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTarifas();
  }

  Future<void> _loadTarifas() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get('/tarifas');
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          _tarifas = data;
          _isLoading = false;
          // Try to match current? Or just default to empty.
          if (data.isNotEmpty) {
            // _selectedTarifa = data[0]['nombre']; // Optional default
          }
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading tarifas: $e');
    }
  }

  Future<void> _handleSave() async {
    if (_selectedTarifa == null) return;

    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      await api.put('/clientes/${widget.clienteId}/tarifa', {
        'Tarifa': _selectedTarifa,
      });
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        NotificationHelper.showError(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      title: Text(
        'Actualizar tarifa del cliente',
        style: TextStyle(color: theme.textTheme.titleLarge?.color),
      ),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: double.maxFinite,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedTarifa,
                dropdownColor: theme.colorScheme.surface,
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                items: _tarifas.map<DropdownMenuItem<String>>((t) {
                  return DropdownMenuItem(
                    value: t['nombre'],
                    child: Text(
                      '${t['nombre']} - ${t['duracionDias']} días (\$${t['precio']})',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedTarifa = val),
                decoration: InputDecoration(
                  labelText: 'Tarifa',
                  labelStyle: TextStyle(color: theme.hintColor),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                ),
                hint: Text(
                  'Seleccionar tarifa',
                  style: TextStyle(color: theme.hintColor),
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading || _selectedTarifa == null ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Guardar cambios'),
        ),
      ],
    );
  }
}
