import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/ejercicio_model.dart';

class AddEditEjercicioDialog extends StatefulWidget {
  final Ejercicio? ejercicio;
  final VoidCallback onSuccess;

  const AddEditEjercicioDialog({
    super.key,
    this.ejercicio,
    required this.onSuccess,
  });

  @override
  State<AddEditEjercicioDialog> createState() => _AddEditEjercicioDialogState();
}

class _AddEditEjercicioDialogState extends State<AddEditEjercicioDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _urlVideoController = TextEditingController();
  final _instruccionesController = TextEditingController();

  String? _selectedGrupo;
  String? _selectedEquipo;
  String? _selectedNivel;
  bool _isLoading = false;

  final List<String> _grupos = [
    "Pecho Superior",
    "Pecho Inferior",
    "Pecho Medio",
    "Trapecio",
    "Dorsal",
    "Espalda Baja",
    "Cuello",
    "Cuadriceps",
    "Isquiotibiales",
    "Gluteos",
    "Gemelos",
    "Hombros",
    "Bíceps",
    "Tríceps",
    "Abdominales",
    "Cardio",
    "Otro",
  ];

  final List<String> _equipos = [
    "Mancuernas",
    "Barra",
    "Máquinas",
    "Cuerpo libre",
    "Bandas elásticas",
    "TRX",
    "Balón medicinal",
    "Rueda abdominal",
    "Comba",
    "Peso corporal",
    "Poleas",
  ];

  final List<String> _niveles = ["Principiante", "Intermedio", "Avanzado"];

  @override
  void initState() {
    super.initState();
    if (widget.ejercicio != null) {
      _nombreController.text = widget.ejercicio!.nombre;
      _urlVideoController.text = widget.ejercicio!.urlVideo ?? '';
      _instruccionesController.text = widget.ejercicio!.instrucciones ?? '';
      _selectedGrupo = widget.ejercicio!.grupo;
      _selectedEquipo = widget.ejercicio!.equipo;
      _selectedNivel = widget.ejercicio!.nivel;
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _urlVideoController.dispose();
    _instruccionesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final api = Provider.of<ApiService>(context, listen: false);
    final payload = {
      "nombre": _nombreController.text.trim(),
      "grupo": _selectedGrupo,
      "equipo": _selectedEquipo,
      "nivel": _selectedNivel,
      "urlVideo": _urlVideoController.text.trim(),
      "instrucciones": _instruccionesController.text.trim(),
    };

    try {
      if (widget.ejercicio == null) {
        await api.post('/ejercicios', payload);
      } else {
        await api.put('/ejercicios/${widget.ejercicio!.id}', payload);
      }
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.ejercicio != null;

    return AlertDialog(
      title: Text(isEdit ? 'Editar Ejercicio' : 'Nuevo Ejercicio'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    hintText: 'Ej: Sentadillas con barra',
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedGrupo,
                  decoration: const InputDecoration(labelText: 'Grupo'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('—')),
                    ..._grupos.map(
                      (g) => DropdownMenuItem(value: g, child: Text(g)),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedGrupo = val),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedEquipo,
                  decoration: const InputDecoration(labelText: 'Equipo'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('—')),
                    ..._equipos.map(
                      (e) => DropdownMenuItem(value: e, child: Text(e)),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedEquipo = val),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedNivel,
                  decoration: const InputDecoration(labelText: 'Nivel'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('—')),
                    ..._niveles.map(
                      (n) => DropdownMenuItem(value: n, child: Text(n)),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedNivel = val),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _urlVideoController,
                  decoration: const InputDecoration(
                    labelText: 'URL Video',
                    hintText: 'Ej: https://youtube.com/...',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _instruccionesController,
                  decoration: const InputDecoration(labelText: 'Instrucciones'),
                  maxLines: 4,
                ),
              ],
            ),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isEdit ? 'Guardar Cambios' : 'Crear Ejercicio'),
        ),
      ],
    );
  }
}
