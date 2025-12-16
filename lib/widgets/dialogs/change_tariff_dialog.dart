import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/api_service.dart';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Actualizar tarifa del cliente'),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: double.maxFinite,
              child: DropdownButtonFormField<String>(
                value: _selectedTarifa,
                items: _tarifas.map<DropdownMenuItem<String>>((t) {
                  return DropdownMenuItem(
                    value: t['nombre'],
                    child: Text(
                      '${t['nombre']} - ${t['duracionDias']} días (\$${t['precio']})',
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedTarifa = val),
                decoration: const InputDecoration(labelText: 'Tarifa'),
                hint: const Text('Seleccionar tarifa'),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading || _selectedTarifa == null ? null : _handleSave,
          child: const Text('Guardar cambios'),
        ),
      ],
    );
  }
}
