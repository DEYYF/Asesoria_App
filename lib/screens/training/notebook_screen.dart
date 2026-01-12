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

  void _handleDayChange(int val) {
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_ent == null) {
      return const Scaffold(body: Center(child: Text('Error al cargar')));
    }

    final semanas = _ent!.semanas;
    final currentSemana = semanas[_selectedWeekIdx];
    final dias = currentSemana.dias;
    final currentDia = dias.length > _selectedDayIdx
        ? dias[_selectedDayIdx]
        : null;

    if (currentDia == null) {
      return const Scaffold(
        body: Center(child: Text('Configuración inválida')),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Registrar Sesión',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.black.withOpacity(0.9),
                      Colors.black.withOpacity(0.6),
                    ]
                  : [theme.primaryColor, theme.primaryColor.withOpacity(0.8)],
            ),
          ),
        ),
        leading: BackButton(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
        child: Column(
          children: [
            // Header with Gradient and Week Selector
            Container(
              padding: const EdgeInsets.fromLTRB(16, 110, 16, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.black.withOpacity(0.9),
                          Colors.black.withOpacity(0.6),
                        ]
                      : [
                          theme.primaryColor,
                          theme.primaryColor.withOpacity(0.8),
                        ],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Week Selector
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: semanas.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final sem = entry.value;
                        final isSelected = idx == _selectedWeekIdx;
                        return GestureDetector(
                          onTap: () => _handleWeekChange(idx),
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Semana ${sem.numero}',
                              style: TextStyle(
                                color: isSelected
                                    ? theme.primaryColor
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Horizontal Day Selector
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: dias.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final dia = entry.value;
                        final isSelected = idx == _selectedDayIdx;
                        return GestureDetector(
                          onTap: () => _handleDayChange(idx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark
                                        ? theme.colorScheme.secondary
                                        : Colors.white)
                                  : (isDark
                                        ? Colors.grey.shade900
                                        : Colors.white.withOpacity(0.2)),
                              borderRadius: BorderRadius.circular(16),
                              border: !isSelected
                                  ? Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                    )
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Text(
                              dia.nombre,
                              style: TextStyle(
                                color: isSelected
                                    ? (isDark
                                          ? Colors.white
                                          : theme.primaryColor)
                                    : Colors.white.withOpacity(0.9),
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
                itemCount: currentDia.items.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 20),
                itemBuilder: (context, index) {
                  // Comment Card
                  if (index == currentDia.items.length) {
                    return _buildCommentCard(theme, isDark);
                  }

                  // Exercise Card
                  final item = currentDia.items[index];
                  final seriesData = _formData[index] ?? [];
                  return _buildExerciseCard(
                    theme,
                    isDark,
                    item,
                    seriesData,
                    index,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, -4),
              blurRadius: 16,
            ),
          ],
        ),
        child: SafeArea(
          // Ensure button is not behind home indicator
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                elevation: 4,
                shadowColor: theme.primaryColor.withOpacity(0.4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
                      'Finalizar y Guardar Sesión',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded, color: theme.primaryColor, size: 24),
              const SizedBox(width: 12),
              Text(
                'Notas Finales',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: '¿Sensaciones? ¿Molestias? ¿Mejoras?',
              filled: true,
              fillColor: theme.scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            maxLines: 3,
            onChanged: (v) => _comentarios = v,
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(
    ThemeData theme,
    bool isDark,
    ItemEntrenamiento item,
    List<Map<String, dynamic>> seriesData,
    int exerciseIndex,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.fitness_center_rounded,
                    color: theme.primaryColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.ejercicioNombre ??
                            item.ejercicio?.nombre ??
                            'Ejercicio',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.titleLarge?.color,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (item.ejercicio?.grupo != null)
                        Text(
                          item.ejercicio!.grupo!.toUpperCase(),
                          style: TextStyle(
                            color: theme.hintColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)),

          // Table Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Center(child: Text('#', style: _headerStyle(theme))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'PESO (KG)',
                    textAlign: TextAlign.center,
                    style: _headerStyle(theme),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'REPS',
                    textAlign: TextAlign.center,
                    style: _headerStyle(theme),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'RIR',
                    textAlign: TextAlign.center,
                    style: _headerStyle(theme),
                  ),
                ),
              ],
            ),
          ),

          // Series List
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: seriesData.asMap().entries.map((entry) {
                final sIdx = entry.key;
                final sData = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: theme.scaffoldBackgroundColor,
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ModernInput(
                          value: sData['peso'],
                          hint: 'kg',
                          onChanged: (v) =>
                              _updateSerie(exerciseIndex, sIdx, 'peso', v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ModernInput(
                          value: sData['reps'],
                          hint: '0',
                          onChanged: (v) =>
                              _updateSerie(exerciseIndex, sIdx, 'reps', v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ModernInput(
                          value: sData['rir'],
                          hint: '-',
                          onChanged: (v) =>
                              _updateSerie(exerciseIndex, sIdx, 'rir', v),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _headerStyle(ThemeData theme) {
    return TextStyle(
      color: theme.hintColor,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
    );
  }
}

class _ModernInput extends StatelessWidget {
  final String value;
  final String hint;
  final Function(String) onChanged;

  const _ModernInput({
    required this.value,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.transparent,
        ), // Placeholder for active border
      ),
      child: TextFormField(
        initialValue: value,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: theme.textTheme.bodyMedium?.color,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: theme.disabledColor.withOpacity(0.3)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: theme.scaffoldBackgroundColor,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 8,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
