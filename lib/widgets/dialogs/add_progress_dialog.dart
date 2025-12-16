import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/progreso_model.dart'; // For structure reference if needed

const musculosBase = [
  "Brazo",
  "Espalda",
  "Pecho",
  "Hombro",
  "Trapecio",
  "Antebrazo",
  "Glúteo",
  "Cuádriceps",
  "Femoral",
  "Gemelo",
  "CINTURA ANCHA",
  "CINTURA ESTRECHA",
];

class AddProgressDialog extends StatefulWidget {
  final String clienteId;
  final VoidCallback onSuccess;

  const AddProgressDialog({
    super.key,
    required this.clienteId,
    required this.onSuccess,
  });

  @override
  State<AddProgressDialog> createState() => _AddProgressDialogState();
}

class _AddProgressDialogState extends State<AddProgressDialog> {
  final _pesoController = TextEditingController();
  final _grasaController = TextEditingController();
  final Map<String, TextEditingController> _muscleControllers = {};
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (var m in musculosBase) {
      _muscleControllers[m] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _pesoController.dispose();
    _grasaController.dispose();
    for (var c in _muscleControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() {
      _error = null;
    });

    final peso = _pesoController.text.trim();
    final grasa = _grasaController.text.trim();
    final muscles = <Map<String, dynamic>>[];

    bool hasData = peso.isNotEmpty || grasa.isNotEmpty;

    _muscleControllers.forEach((name, ctrl) {
      final val = ctrl.text.trim();
      if (val.isNotEmpty) {
        hasData = true;
        muscles.add({"nombre": name, "medida": double.tryParse(val) ?? 0.0});
      }
    });

    if (!hasData) {
      setState(() {
        _error = "Debes ingresar al menos un dato.";
      });
      return;
    }

    if (peso.isNotEmpty && (double.tryParse(peso) ?? 0) <= 0) {
      setState(() {
        _error = "El peso debe ser mayor a 0.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final body = {
        "fecha": DateTime.now().toIso8601String(),
        if (peso.isNotEmpty) "peso": double.parse(peso),
        if (grasa.isNotEmpty) "grasaCorporal": double.parse(grasa),
        "musculo": muscles,
      };

      await api.put('/clientes/${widget.clienteId}/historial', body);
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = "Error al guardar: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Añadir Progreso'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 16),
                  color: Colors.red.shade50,
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pesoController,
                      decoration: const InputDecoration(labelText: 'Peso (kg)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _grasaController,
                      decoration: const InputDecoration(labelText: 'Grasa (%)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    for (var c in _muscleControllers.values) {
                      c.clear();
                    }
                  },
                  child: const Text('Limpiar medidas'),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: musculosBase.map((m) {
                  return SizedBox(
                    width: 120, // Approximate width
                    child: TextField(
                      controller: _muscleControllers[m],
                      decoration: InputDecoration(labelText: m, isDense: true),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
