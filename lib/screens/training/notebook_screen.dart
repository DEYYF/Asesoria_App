import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/offline_sync_service.dart';
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
  bool _isOffline = false;

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
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'offline_training_${widget.entrenamientoId}';

    try {
      final res = await api.get('/entrenamientos/${widget.entrenamientoId}');
      if (mounted) {
        if (res.statusCode == 200) {
          final ent = Entrenamiento.fromJson(jsonDecode(res.body));
          // Cache the specific workout structure
          await prefs.setString(cacheKey, res.body);

          setState(() {
            _ent = ent;
            _isLoading = false;
            _isOffline = false;
            _initFormData(ent, 0, 0);
          });
        } else {
          await _loadOfflineData(prefs, cacheKey);
        }
      }
    } catch (e) {
      if (mounted) await _loadOfflineData(prefs, cacheKey);
    }
  }

  Future<void> _loadOfflineData(SharedPreferences prefs, String key) async {
    final cached = prefs.getString(key);
    if (cached != null) {
      final ent = Entrenamiento.fromJson(jsonDecode(cached));
      setState(() {
        _ent = ent;
        _isOffline = true;
        _isLoading = false;
        _initFormData(ent, 0, 0);
      });
    } else {
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
          // If server error, we don't queue (it might be invalid data)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error del servidor: ${res.body}')),
          );
        }
      }
    } catch (e) {
      // Network error or timeout, queue it
      if (mounted) {
        // Recalculate or use local final to ensure it's available
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
              .map(
                (s) => {
                  'peso': num.tryParse(s['peso']) ?? 0,
                  'reps': num.tryParse(s['reps']) ?? 0,
                  'rir': num.tryParse(s['rir']) ?? 0,
                },
              )
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

        final offlinePayload = {
          'entrenamientoId': _ent!.id,
          'clienteId': _ent!.clienteId,
          'semanaNumero': _ent!.semanas[_selectedWeekIdx].numero,
          'diaNombre': dia.nombre,
          'ejercicios': ejerciciosPayload,
          'comentarios': _comentarios,
        };

        final syncService = Provider.of<OfflineSyncService>(
          context,
          listen: false,
        );
        await syncService.queueUpdate(offlinePayload);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📴 Sin conexión. Sesión guardada localmente.'),
            backgroundColor: Colors.orange,
          ),
        );
        context.pop();
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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Registrar Sesión',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_isOffline)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.cloud_off_rounded, color: Colors.orange),
            ),
        ],
      ),
      body: Column(
        children: [
          // Selector Area
          Container(
            color: theme.scaffoldBackgroundColor,
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                // Week Selector
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: semanas.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, idx) {
                      final sem = semanas[idx];
                      final isSelected = idx == _selectedWeekIdx;
                      return _buildCapsuleTab(
                        context,
                        label: 'Semana ${sem.numero}',
                        isSelected: isSelected,
                        onTap: () => _handleWeekChange(idx),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Day Selector
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: dias.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, idx) {
                      final dia = dias[idx];
                      final isSelected = idx == _selectedDayIdx;
                      return _buildCapsuleTab(
                        context,
                        label: dia.nombre,
                        isSelected: isSelected,
                        onTap: () => _handleDayChange(idx),
                        isSecondary: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Content List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: currentDia.items.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
          ),
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Finalizar y Guardar Sesión',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCapsuleTab(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isSecondary = false,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? (isSecondary ? primaryColor.withOpacity(0.1) : primaryColor)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isSecondary ? primaryColor : Colors.transparent)
                : theme.dividerColor.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (isSecondary ? primaryColor : Colors.white)
                : theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
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
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Notas Finales',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: theme.textTheme.titleMedium?.color,
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
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.fitness_center_rounded,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.titleMedium?.color,
                        ),
                      ),
                      if (item.ejercicio?.grupo != null)
                        Text(
                          item.ejercicio!.grupo!.toUpperCase(),
                          style: TextStyle(
                            color: theme.hintColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),

          // Table Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Center(child: Text('#', style: _headerStyle(theme))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'PESO (KG)',
                    textAlign: TextAlign.center,
                    style: _headerStyle(theme),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'REPS',
                    textAlign: TextAlign.center,
                    style: _headerStyle(theme),
                  ),
                ),
                const SizedBox(width: 8),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: seriesData.asMap().entries.map((entry) {
                final sIdx = entry.key;
                final sData = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: theme.scaffoldBackgroundColor,
                          child: Text(
                            '${sIdx + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.hintColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ModernInput(
                          value: sData['peso'],
                          hint: '-',
                          onChanged: (v) =>
                              _updateSerie(exerciseIndex, sIdx, 'peso', v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ModernInput(
                          value: sData['reps'],
                          hint: '-',
                          onChanged: (v) =>
                              _updateSerie(exerciseIndex, sIdx, 'reps', v),
                        ),
                      ),
                      const SizedBox(width: 8),
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
      color: theme.hintColor.withOpacity(0.7),
      fontSize: 10,
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
      height: 40,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextFormField(
        initialValue: value,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: theme.textTheme.bodyLarge?.color,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: theme.hintColor.withOpacity(0.3),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(bottom: 8),
          isDense: false,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
