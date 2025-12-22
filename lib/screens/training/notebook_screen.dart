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

  // Map<ExerciseIndex, List<Map<String, dynamic>>>
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
      _selectedDayIdx = 0;
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
      list[sIdx][field] = val;
      _formData[exIdx] = list;
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

        if (validSeries.isNotEmpty) {
          ejerciciosPayload.add({
            'ejercicio': item.ejercicioId ?? item.ejercicio?.id,
            'ejercicioNombre':
                item.ejercicioNombre ?? item.ejercicio?.nombre ?? 'Ejercicio',
            'series': validSeries,
            'notas': '',
          });
        }
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesión registrada correctamente')),
          );
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Registrar Sesión',
          style: TextStyle(
            color: theme.textTheme.titleLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: BackButton(
          color: theme.iconTheme.color,
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Selectors
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedWeekIdx,
                        isExpanded: true,
                        dropdownColor: theme.cardColor,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: theme.primaryColor,
                        ),
                        items: List.generate(
                          semanas.length,
                          (index) => DropdownMenuItem(
                            value: index,
                            child: Text(
                              'Semana ${semanas[index].numero}',
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        ),
                        onChanged: _handleWeekChange,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedDayIdx,
                        isExpanded: true,
                        dropdownColor: theme.cardColor,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: theme.primaryColor,
                        ),
                        items: List.generate(
                          dias.length,
                          (index) => DropdownMenuItem(
                            value: index,
                            child: Text(
                              dias[index].nombre,
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        ),
                        onChanged: _handleDayChange,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: currentDia.items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                // Comment Card
                if (index == currentDia.items.length) {
                  return Card(
                    color: theme.cardColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.dividerColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Comentarios finales',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: theme.textTheme.titleLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            decoration: InputDecoration(
                              hintText: '¿Cómo te sentiste? ¿Alguna molestia?',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: theme.dividerColor,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: theme.dividerColor,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                              filled: true,
                              fillColor: theme.scaffoldBackgroundColor,
                              hintStyle: TextStyle(color: theme.hintColor),
                            ),
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                            maxLines: 3,
                            onChanged: (v) => _comentarios = v,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Exercise Card
                final item = currentDia.items[index];
                final seriesData = _formData[index] ?? [];

                return Card(
                  color: theme.cardColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.dividerColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.fitness_center,
                                color: theme.primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.ejercicioNombre ??
                                        item.ejercicio?.nombre ??
                                        'Ejercicio',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: theme.textTheme.titleLarge?.color,
                                    ),
                                  ),
                                  if (item.ejercicio?.grupo != null)
                                    Text(
                                      item.ejercicio!.grupo!,
                                      style: TextStyle(
                                        color: theme.hintColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Header Row
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                child: Center(
                                  child: Text(
                                    '#',
                                    style: TextStyle(
                                      color: theme.hintColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'PESO (KG)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: theme.hintColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'REPS',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: theme.hintColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'RIR',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: theme.hintColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Inputs
                        ...seriesData.asMap().entries.map((entry) {
                          final sIdx = entry.key;
                          final sData = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 32,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.scaffoldBackgroundColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${sIdx + 1}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: theme.hintColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _TableInput(
                                    value: sData['peso'],
                                    onChanged: (v) =>
                                        _updateSerie(index, sIdx, 'peso', v),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _TableInput(
                                    value: sData['reps'],
                                    onChanged: (v) =>
                                        _updateSerie(index, sIdx, 'reps', v),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _TableInput(
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
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 16,
                  ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  elevation: 0,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Finalizar y Guardar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableInput extends StatelessWidget {
  final String value;
  final Function(String) onChanged;
  const _TableInput({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: TextFormField(
        initialValue: value,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: theme.textTheme.bodyMedium?.color,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
