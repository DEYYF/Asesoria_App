import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/tarifa_model.dart';
import '../../models/extra_model.dart';

class AddClientDialog extends StatefulWidget {
  final VoidCallback onSuccess;

  const AddClientDialog({super.key, required this.onSuccess});

  @override
  State<AddClientDialog> createState() => _AddClientDialogState();
}

class _AddClientDialogState extends State<AddClientDialog> {
  final _formKey = GlobalKey<FormState>();

  // Basic Info
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();
  String _sexo = 'Hombre';

  // Objectivesr
  final _objCtrl = TextEditingController();
  List<String> _objetivos = [];
  final List<String> _sugerencias = [
    "Pérdida de peso",
    "Ganar masa muscular",
    "Mantenimiento",
    "Definición",
    "Aumentar fuerza",
    "Mejorar salud",
  ];

  // Financials
  List<Tarifa> _tarifas = [];
  List<Extra> _extras = [];
  String? _selectedTarifaId;
  final List<String> _selectedExtrasIds = [];

  bool _isLoading = false;
  bool _loadingData = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final tRes = await api.get('/tarifas');
      final eRes = await api.get('/extras');

      if (tRes.statusCode == 200 && eRes.statusCode == 200) {
        setState(() {
          _tarifas = (jsonDecode(tRes.body) as List)
              .map((i) => Tarifa.fromJson(i))
              .toList();
          _extras = (jsonDecode(eRes.body) as List)
              .map((i) => Extra.fromJson(i))
              .toList();
          _loadingData = false;
        });
      } else {
        throw Exception('Error loading data');
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = 'Error: $e';
          _loadingData = false;
        });
    }
  }

  void _addObjetivo() {
    final val = _objCtrl.text.trim();
    if (val.isNotEmpty && !_objetivos.contains(val)) {
      setState(() {
        _objetivos.add(val);
        _objCtrl.clear();
      });
    }
  }

  // Calculations
  double get _totalBase => _tarifas
      .firstWhere(
        (t) => t.id == _selectedTarifaId,
        orElse: () => Tarifa(
          id: '',
          nombre: '',
          precio: 0,
          duracionDias: 0,
          tipoServicio: '',
        ),
      )
      .precio;
  int get _meses => _selectedTarifaId == null
      ? 0
      : (_tarifas.firstWhere((t) => t.id == _selectedTarifaId).duracionDias /
                30)
            .ceil();

  double get _totalExtras {
    if (_meses == 0) return 0;
    double sum = 0;
    for (var id in _selectedExtrasIds) {
      final e = _extras.firstWhere((x) => x.id == id);
      sum += (e.precio * _meses);
    }
    return sum;
  }

  double get _totalFinal => _totalBase + _totalExtras;

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_objetivos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade al menos un objetivo')),
      );
      return;
    }
    if (_selectedTarifaId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona una tarifa')));
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);
      final asesorId = auth.user?['_id'];

      if (asesorId == null) {
        throw Exception(
          'No se ha podido identificar al asesor. Reinicia sesión.',
        );
      }

      final tarifa = _tarifas.firstWhere((t) => t.id == _selectedTarifaId);

      final clientBody = {
        'nombre': _nombreCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'edad': int.tryParse(_edadCtrl.text),
        'sexo': _sexo,
        'objetivos': _objetivos,
        'fechaInicio': DateTime.now().toIso8601String(),
        'Tarifa': tarifa.nombre,
        'tipoServicio': tarifa.tipoServicio,
        'Tiempo_Tarifa': '$_meses Meses',
        'asesorId': asesorId,
      };

      final resC = await api.post('/clientes', clientBody);
      if (resC.statusCode != 200 && resC.statusCode != 201)
        throw Exception('Error creando cliente: ${resC.body}');

      final clientId = jsonDecode(resC.body)['_id'];

      // 2. Create Presupuesto
      final budgetBody = {
        'clienteId': clientId,
        'usuarioId': asesorId, // asesorId is user id
        'tarifaId': _selectedTarifaId,
        'extras': _selectedExtrasIds,
        'fechaInicio': DateTime.now().toIso8601String(),
      };

      await api.post('/presupuestos', budgetBody);

      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nuevo Cliente',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  color: theme.iconTheme.color,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(8),
                color: isDark
                    ? Colors.red.withOpacity(0.2)
                    : Colors.red.shade100,
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: isDark ? Colors.redAccent : Colors.red.shade900,
                  ),
                ),
              ),

            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // --- Basic Info ---
                    Text(
                      'Datos Básicos',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.textTheme.titleMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nombreCtrl,
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Nombre',
                              labelStyle: TextStyle(color: theme.hintColor),
                              border: const OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.dividerColor,
                                ),
                              ),
                            ),
                            validator: (v) => v!.isEmpty ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _emailCtrl,
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Email',
                              labelStyle: TextStyle(color: theme.hintColor),
                              border: const OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.dividerColor,
                                ),
                              ),
                            ),
                            validator: (v) =>
                                !v!.contains('@') ? 'Inválido' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _telefonoCtrl,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Teléfono',
                        labelStyle: TextStyle(color: theme.hintColor),
                        border: const OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _edadCtrl,
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Edad',
                              labelStyle: TextStyle(color: theme.hintColor),
                              border: const OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.dividerColor,
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _sexo,
                            dropdownColor: theme.colorScheme.surface,
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Sexo',
                              labelStyle: TextStyle(color: theme.hintColor),
                              border: const OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.dividerColor,
                                ),
                              ),
                            ),
                            items: ['Hombre', 'Mujer', 'Otro']
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _sexo = v!),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // --- Objectives ---
                    Text(
                      'Objetivos',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.textTheme.titleMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _objCtrl,
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Escribe y pulsa +',
                              hintStyle: TextStyle(color: theme.hintColor),
                              isDense: true,
                              border: const OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.dividerColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.add_circle,
                            color: theme.primaryColor,
                          ),
                          onPressed: _addObjetivo,
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: _objetivos
                          .map(
                            (o) => Chip(
                              label: Text(o),
                              backgroundColor: isDark
                                  ? theme.scaffoldBackgroundColor
                                  : null,
                              labelStyle: TextStyle(
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                              deleteIcon: Icon(
                                Icons.close,
                                size: 16,
                                color: theme.iconTheme.color,
                              ),
                              onDeleted: () =>
                                  setState(() => _objetivos.remove(o)),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _sugerencias
                          .map(
                            (s) => ActionChip(
                              label: Text(
                                s,
                                style: const TextStyle(fontSize: 10),
                              ),
                              backgroundColor: isDark
                                  ? theme.scaffoldBackgroundColor
                                  : null,
                              labelStyle: TextStyle(
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                              onPressed: () {
                                if (!_objetivos.contains(s))
                                  setState(() => _objetivos.add(s));
                              },
                            ),
                          )
                          .toList(),
                    ),

                    const SizedBox(height: 24),

                    // --- Plan & Extras ---
                    Text(
                      'Plan y Extras',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.textTheme.titleMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedTarifaId,
                      dropdownColor: theme.colorScheme.surface,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Tarifa',
                        labelStyle: TextStyle(color: theme.hintColor),
                        border: const OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                      ),
                      items: _tarifas
                          .map(
                            (t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                '${t.nombre} - ${t.precio}€ (${t.duracionDias}d)',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedTarifaId = v),
                      validator: (v) => v == null ? 'Selecciona tarifa' : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Extras Mensuales:',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: _extras.map((e) {
                        final isSel = _selectedExtrasIds.contains(e.id);
                        return FilterChip(
                          label: Text('${e.nombre} (+${e.precio}€)'),
                          selected: isSel,
                          checkmarkColor: theme.colorScheme.surface,
                          labelStyle: TextStyle(
                            color: isSel
                                ? Colors.white
                                : theme.textTheme.bodyMedium?.color,
                          ),
                          selectedColor: theme.primaryColor,
                          backgroundColor: isDark
                              ? theme.scaffoldBackgroundColor
                              : null,
                          onSelected: (sel) {
                            setState(() {
                              if (sel)
                                _selectedExtrasIds.add(e.id);
                              else
                                _selectedExtrasIds.remove(e.id);
                            });
                          },
                        );
                      }).toList(),
                    ),

                    if (_selectedTarifaId != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? theme.scaffoldBackgroundColor
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resumen',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.titleMedium?.color,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Tarifa Base:',
                                  style: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                ),
                                Text(
                                  '${_totalBase.toStringAsFixed(2)} €',
                                  style: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Extras ($_meses meses):',
                                  style: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                ),
                                Text(
                                  '${_totalExtras.toStringAsFixed(2)} €',
                                  style: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ],
                            ),
                            Divider(color: theme.dividerColor),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.textTheme.titleMedium?.color,
                                  ),
                                ),
                                Text(
                                  '${_totalFinal.toStringAsFixed(2)} €',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: theme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Crear Cliente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
