import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../models/entrenamiento_model.dart';

class NotebookScreen extends StatefulWidget {
  final String entrenamientoId;
  const NotebookScreen({super.key, required this.entrenamientoId});

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  Entrenamiento? _ent;
  bool _isLoading = true;

  int _selectedWeekIdx = 0;
  int _selectedDayIdx = 0;

  // Session Data: Map<ExerciseIndex, List<Map<String, dynamic>>>
  // Using dynamic maps for flexibility in form state
  Map<int, List<Map<String, dynamic>>> _formData = {};
  String _comentarios = "";
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get('/entrenamientos/${widget.entrenamientoId}');
      if (mounted) {
        if (res.statusCode == 200) {
          final ent = Entrenamiento.fromJson(jsonDecode(res.body));
          setState(() {
            _ent = ent;
            _isLoading = false;
            // Initialize form data for the default selection
            _initFormData(ent, 0, 0);
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initFormData(Entrenamiento ent, int wIdx, int dIdx) {
    if (ent.semanas.isEmpty || ent.semanas[wIdx].dias.length <= dIdx) return;

    final dia = ent.semanas[wIdx].dias[dIdx];
    final newMap = <int, List<Map<String, dynamic>>>{};

    for (int i = 0; i < dia.items.length; i++) {
      final item = dia.items[i];
      final seriesCount = item.esquema?.series ?? 3;
      final seriesList = <Map<String, dynamic>>[];
      for (int s = 0; s < seriesCount; s++) {
        seriesList.add({'peso': '', 'reps': '', 'rir': ''});
      }
      newMap[i] = seriesList;
    }

    setState(() {
      _formData = newMap;
    });
  }

  void _handleWeekChange(int? val) {
    if (val == null) return;
    setState(() {
      _selectedWeekIdx = val;
      _selectedDayIdx = 0; // Reset day
      if (_ent != null) _initFormData(_ent!, val, 0);
    });
  }

  void _handleDayChange(int? val) {
    if (val == null) return;
    setState(() {
      _selectedDayIdx = val;
      if (_ent != null) _initFormData(_ent!, _selectedWeekIdx, val);
    });
  }

  void _updateSerie(int exIdx, int sIdx, String field, String val) {
    setState(() {
      final list = _formData[exIdx]!;
      list[sIdx][field] = val; // Store as string for input
      _formData[exIdx] = list; // trigger update
    });
  }

  Future<void> _handleSave() async {
    if (_ent == null) return;
    setState(() => _isSaving = true);
    final api = Provider.of<ApiService>(context, listen: false);

    try {
      final dia = _ent!.semanas[_selectedWeekIdx].dias[_selectedDayIdx];

      final ejerciciosPayload = <Map<String, dynamic>>[];

      for (int i = 0; i < dia.items.length; i++) {
        final item = dia.items[i];
        final seriesData = _formData[i] ?? [];

        // Filter out empty rows (where weight AND reps are empty)
        final validSeries = seriesData
            .where(
              (s) =>
                  s['peso'].toString().isNotEmpty &&
                  s['reps'].toString().isNotEmpty,
            )
            .map((s) {
              return {
                'peso': num.tryParse(s['peso']) ?? 0,
                'reps': num.tryParse(s['reps']) ?? 0,
                'rir': num.tryParse(s['rir']) ?? 0,
              };
            })
            .toList();

        ejerciciosPayload.add({
          'ejercicio': item.ejercicioId ?? item.ejercicio?.id, // ID
          'ejercicioNombre':
              item.ejercicioNombre ?? item.ejercicio?.nombre ?? 'Ejercicio',
          'series': validSeries,
          'notas':
              '', // Should add notes field per exercise? React has generic comments or exercise notes.
        });
      }

      final payload = {
        'entrenamientoId': _ent!.id,
        'clienteId': _ent!.clienteId,
        'semanaNumero': _ent!.semanas[_selectedWeekIdx].numero,
        'diaNombre': dia.nombre,
        'ejercicios': ejerciciosPayload,
        'comentarios': _comentarios,
      };

      final res = await api.post('/entrenamientos/registros', payload);

      if (mounted) {
        if (res.statusCode == 201 || res.statusCode == 200) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Sesión registrada')));
          context.pop();
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${res.body}')));
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_ent == null)
      return const Scaffold(body: Center(child: Text('Error al cargar')));

    final semanas = _ent!.semanas;
    final currentSemana = semanas[_selectedWeekIdx];
    final dias = currentSemana.dias;
    final currentDia = dias.length > _selectedDayIdx
        ? dias[_selectedDayIdx]
        : null;

    if (currentDia == null)
      return const Scaffold(
        body: Center(child: Text('Configuración inválida')),
      );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Sesión'),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _handleSave,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check),
          ),
        ],
      ),
      body: Column(
        children: [
          // Selectors
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<int>(
                    value: _selectedWeekIdx,
                    isExpanded: true,
                    items: List.generate(
                      semanas.length,
                      (index) => DropdownMenuItem(
                        value: index,
                        child: Text('Semana ${semanas[index].numero}'),
                      ),
                    ),
                    onChanged: _handleWeekChange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<int>(
                    value: _selectedDayIdx,
                    isExpanded: true,
                    items: List.generate(
                      dias.length,
                      (index) => DropdownMenuItem(
                        value: index,
                        child: Text(dias[index].nombre),
                      ),
                    ),
                    onChanged: _handleDayChange,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: currentDia.items.length + 1, // +1 for comment section
              separatorBuilder: (_, __) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                if (index == currentDia.items.length) {
                  // Comments Section
                  return TextField(
                    decoration: const InputDecoration(
                      labelText: 'Comentarios de la sesión',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    onChanged: (v) => _comentarios = v,
                  );
                }

                final item = currentDia.items[index];
                final seriesData = _formData[index] ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.ejercicioNombre ??
                          item.ejercicio?.nombre ??
                          'Ejercicio',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Header
                    Row(
                      children: const [
                        SizedBox(
                          width: 40,
                          child: Text(
                            'Serie',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Peso (kg)',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Reps',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'RIR',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Inputs
                    ...seriesData.asMap().entries.map((entry) {
                      final sIdx = entry.key;
                      final sData = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Center(
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${sIdx + 1}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: _TableInput(
                                hint: 'kg',
                                value: sData['peso'],
                                onChanged: (v) =>
                                    _updateSerie(index, sIdx, 'peso', v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TableInput(
                                hint: 'reps',
                                value: sData['reps'],
                                onChanged: (v) =>
                                    _updateSerie(index, sIdx, 'reps', v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TableInput(
                                hint: 'rir',
                                value: sData['rir'],
                                onChanged: (v) =>
                                    _updateSerie(index, sIdx, 'rir', v),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TableInput extends StatelessWidget {
  final String hint;
  final String value;
  final Function(String) onChanged;
  const _TableInput({
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }
}
