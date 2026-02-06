import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/offline_sync_service.dart';
import '../../models/entrenamiento_model.dart';
import '../../widgets/video_player_dialog.dart';

class LiveSessionScreen extends StatefulWidget {
  final String entrenamientoId;
  const LiveSessionScreen({super.key, required this.entrenamientoId});

  @override
  State<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends State<LiveSessionScreen> {
  Entrenamiento? _ent;
  bool _isLoading = true;
  bool _isOffline = false;

  // Configuration Phase
  int _selectedWeekIdx = 0;
  int _selectedDayIdx = 0;
  int _startExerciseIdx = 0;
  bool _sessionStarted = false;

  // Running Phase
  int _currentExIdx = 0;
  int _currentSetIdx = 0;
  final TextEditingController _pesoController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _rirController = TextEditingController();

  // Timer
  Timer? _timer;
  int _timerSeconds = 0;
  bool _isResting = false;

  // Session Duration Timer
  final Stopwatch _sessionStopwatch = Stopwatch();
  Timer? _durationRefreshTimer;

  // Data storage
  final Map<int, List<Map<String, dynamic>>> _loggedData = {};
  Set<String> _completedDayNames = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _durationRefreshTimer?.cancel();
    _pesoController.dispose();
    _repsController.dispose();
    _rirController.dispose();
    super.dispose();
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
          await prefs.setString(cacheKey, res.body);

          setState(() {
            _ent = ent;
            _isOffline = false;
          });
          await _loadHistory();
          setState(() => _isLoading = false);
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
      setState(() {
        _ent = Entrenamiento.fromJson(jsonDecode(cached));
        _isOffline = true;
        _isLoading = false;
      });
      // Try to load history if possible, but it might fail offline
      await _loadHistory();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHistory() async {
    if (_ent == null) return;
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.get(
        '/entrenamientos/registros/cliente/${_ent!.clienteId}/sesiones',
      );
      if (res.statusCode == 200) {
        final List<dynamic> sessions = jsonDecode(res.body);
        final currentWeekNum = _ent!.semanas[_selectedWeekIdx].numero;
        setState(() {
          _completedDayNames = sessions
              .where(
                (s) =>
                    s['entrenamientoId'] == _ent!.id &&
                    s['semanaNumero'] == currentWeekNum,
              )
              .map((s) => s['diaNombre'] as String)
              .toSet();

          // If current selected day is completed, try to find an uncompleted one
          if (_completedDayNames.contains(
            _ent!.semanas[_selectedWeekIdx].dias[_selectedDayIdx].nombre,
          )) {
            final dias = _ent!.semanas[_selectedWeekIdx].dias;
            for (int i = 0; i < dias.length; i++) {
              if (!_completedDayNames.contains(dias[i].nombre)) {
                _selectedDayIdx = i;
                break;
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  void _startSession() {
    final dia = _ent!.semanas[_selectedWeekIdx].dias[_selectedDayIdx];
    if (_completedDayNames.contains(dia.nombre)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este día ya ha sido completado esta semana.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _sessionStarted = true;
      _currentExIdx = _startExerciseIdx;
      _currentSetIdx = 0;
      _sessionStopwatch.start();
      _durationRefreshTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) {
        if (mounted) setState(() {});
      });
    });
  }

  void _logSet() {
    if (_pesoController.text.isEmpty || _repsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, anota peso y repeticiones'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final dia = _ent!.semanas[_selectedWeekIdx].dias[_selectedDayIdx];
    final item = dia.items[_currentExIdx];
    final restTime = item.esquema?.descanso ?? 60;

    setState(() {
      _loggedData.putIfAbsent(_currentExIdx, () => []);
      _loggedData[_currentExIdx]!.add({
        'peso': num.tryParse(_pesoController.text) ?? 0,
        'reps': num.tryParse(_repsController.text) ?? 0,
        'rir': num.tryParse(_rirController.text) ?? 0,
      });

      _pesoController.clear();
      _repsController.clear();
      _rirController.clear();

      _isResting = true;
      _timerSeconds = restTime;
      _startTimer();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        _timer?.cancel();
        _onRestComplete();
      }
    });
  }

  void _onRestComplete() {
    setState(() {
      _isResting = false;
      final dia = _ent!.semanas[_selectedWeekIdx].dias[_selectedDayIdx];
      final item = dia.items[_currentExIdx];
      final targetSeries = item.esquema?.series ?? 3;

      if (_currentSetIdx + 1 < targetSeries) {
        _currentSetIdx++;
      } else {
        // Exercise finished!
        _pesoController.clear();
        _repsController.clear();
        _currentSetIdx = 0;

        if (_loggedData.length >= dia.items.length) {
          _showFinishPrompt();
        } else {
          _sessionStarted = false; // Choose next exercise
          _startExerciseIdx = (_currentExIdx + 1) % dia.items.length;
        }
      }
    });
  }

  void _showFinishPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '¡Sesión Terminada!',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Has completado todos tus ejercicios de hoy. ¿Deseas guardar el progreso?',
        ),
        actions: [
          ElevatedButton(
            onPressed: _finishAndSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF34C759),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'GUARDAR Y FINALIZAR',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finishAndSave() async {
    Navigator.pop(context); // Close dialog
    final api = Provider.of<ApiService>(context, listen: false);
    final dia = _ent!.semanas[_selectedWeekIdx].dias[_selectedDayIdx];

    final ejerciciosPayload = <Map<String, dynamic>>[];
    _loggedData.forEach((idx, series) {
      final item = dia.items[idx];
      ejerciciosPayload.add({
        'ejercicio': item.ejercicioId ?? item.ejercicio?.id,
        'ejercicioNombre': item.ejercicioNombre ?? item.ejercicio?.nombre,
        'series': series,
      });
    });

    final payload = {
      'entrenamientoId': _ent!.id,
      'clienteId': _ent!.clienteId,
      'semanaNumero': _ent!.semanas[_selectedWeekIdx].numero,
      'diaNombre': dia.nombre,
      'ejercicios': ejerciciosPayload,
    };

    try {
      await api.post('/entrenamientos/registros', payload);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF34C759),
            content: Text('¡Excelente trabajo! Sesión guardada con éxito.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final syncService = Provider.of<OfflineSyncService>(
          context,
          listen: false,
        );
        await syncService.queueUpdate(payload);

        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange,
            content: Text('📴 Sin conexión. Sesión guardada localmente.'),
          ),
        );
      }
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

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _sessionStarted ? 'Sesión en Vivo' : 'Entrenamiento',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (_sessionStarted)
              Text(
                'Tiempo: ${_sessionStopwatch.elapsed.inMinutes.toString().padLeft(2, '0')}:${(_sessionStopwatch.elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 12,
                  color: _isOffline ? Colors.orange : theme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          if (_isOffline)
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Icon(Icons.cloud_off_rounded, color: Colors.orange),
            ),
          if (_loggedData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: _showFinishPrompt,
                child: const Text(
                  'FINALIZAR',
                  style: TextStyle(
                    color: Color(0xFF34C759),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _sessionStarted ? _buildRunningUI(theme) : _buildSetupUI(theme),
      ),
    );
  }

  Widget _buildSetupUI(ThemeData theme) {
    final semanas = _ent!.semanas;
    final currentSemana = semanas[_selectedWeekIdx];
    final dias = currentSemana.dias;
    final currentDia = dias[_selectedDayIdx];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          _loggedData.isEmpty
              ? 'Prepárate para entrenar'
              : 'Siguiente ejercicio',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _loggedData.isEmpty
              ? 'Selecciona tu rutina de hoy'
              : 'Elige el próximo movimiento',
          style: TextStyle(color: theme.hintColor, fontSize: 16),
        ),
        const SizedBox(height: 32),

        if (_loggedData.isEmpty) ...[
          _setupCard(
            theme,
            'Semana',
            DropdownButton<int>(
              value: _selectedWeekIdx,
              isExpanded: true,
              underline: const SizedBox(),
              items: List.generate(
                semanas.length,
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text('Semana ${semanas[i].numero}'),
                ),
              ),
              onChanged: (v) {
                setState(() => _selectedWeekIdx = v!);
                _loadHistory();
              },
            ),
          ),
          const SizedBox(height: 16),
          _setupCard(
            theme,
            'Día de Entrenamiento',
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: dias.asMap().entries.map((e) {
                  final isCompleted = _completedDayNames.contains(
                    e.value.nombre,
                  );
                  final isSelected = _selectedDayIdx == e.key;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Opacity(
                      opacity: isCompleted && !isSelected ? 0.6 : 1.0,
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCompleted)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            Text(e.value.nombre),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (s) {
                          if (isCompleted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Día ya completado'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                            return;
                          }
                          setState(() => _selectedDayIdx = e.key);
                        },
                        selectedColor: theme.primaryColor,
                        disabledColor: theme.dividerColor.withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isCompleted
                                    ? theme.hintColor
                                    : theme.textTheme.bodyMedium?.color),
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],

        Text(
          'ELIGE POR QUÉ EJERCICIO EMPEZAR',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: theme.hintColor,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 16),
        ...currentDia.items.asMap().entries.map((e) {
          final isLogged = _loggedData.containsKey(e.key);
          return Opacity(
            opacity: isLogged ? 0.6 : 1.0,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _startExerciseIdx == e.key
                      ? theme.primaryColor
                      : theme.dividerColor.withOpacity(0.1),
                  width: _startExerciseIdx == e.key ? 2 : 1,
                ),
              ),
              child: RadioListTile<int>(
                value: e.key,
                groupValue: _startExerciseIdx,
                onChanged: isLogged
                    ? null
                    : (v) => setState(() => _startExerciseIdx = v!),
                activeColor: theme.primaryColor,
                title: Text(
                  e.value.ejercicioNombre ??
                      e.value.ejercicio?.nombre ??
                      'Ejercicio',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${e.value.esquema?.series} series • ${e.value.esquema?.descanso}s descanso',
                ),
                secondary: isLogged
                    ? const Icon(Icons.check_circle, color: Color(0xFF34C759))
                    : null,
              ),
            ),
          );
        }),

        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: _startSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: theme.primaryColor.withOpacity(0.4),
            ),
            child: Text(
              _loggedData.isEmpty
                  ? 'COMIENZA LA SESIÓN'
                  : 'CONTINUAR ENTRENAMIENTO',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _setupCard(ThemeData theme, String label, Widget content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildRunningUI(ThemeData theme) {
    final dia = _ent!.semanas[_selectedWeekIdx].dias[_selectedDayIdx];
    final item = dia.items[_currentExIdx];
    final esquema = item.esquema;

    return Column(
      children: [
        LinearProgressIndicator(
          value: (_loggedData.length) / dia.items.length,
          backgroundColor: theme.primaryColor.withOpacity(0.1),
          valueColor: AlwaysStoppedAnimation(theme.primaryColor),
          minHeight: 4,
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildExerciseHeader(item, theme),
              const SizedBox(height: 40),
              _buildSetIndicator(esquema, theme),
              const SizedBox(height: 48),
              _buildInputs(theme),
              const SizedBox(height: 80),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isResting
                    ? _buildRestUI(theme)
                    : _buildActionButton(theme),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseHeader(ItemEntrenamiento item, ThemeData theme) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.primaryColor.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.fitness_center_rounded,
                    color: theme.primaryColor,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  item.ejercicioNombre ?? item.ejercicio?.nombre ?? 'Ejercicio',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (item.ejercicio?.urlVideo != null &&
                    item.ejercicio!.urlVideo!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => VideoPlayerDialog(
                          videoUrl: item.ejercicio!.urlVideo!,
                          title:
                              item.ejercicioNombre ??
                              item.ejercicio?.nombre ??
                              'Ejercicio',
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.2),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'VER TÉCNICA',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        if (item.ejercicio?.grupo != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              item.ejercicio!.grupo!,
              style: TextStyle(
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSetIndicator(EsquemaSerie? esquema, ThemeData theme) {
    final total = esquema?.series ?? 0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SERIE ',
              style: TextStyle(
                fontSize: 14,
                color: theme.hintColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${_currentSetIdx + 1}',
              style: TextStyle(
                fontSize: 18,
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              ' de $total',
              style: TextStyle(
                fontSize: 14,
                color: theme.hintColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(total, (index) {
            final isDone = index < _currentSetIdx;
            final isCurrent = index == _currentSetIdx;
            return Expanded(
              child: Container(
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isDone
                      ? const Color(0xFF34C759)
                      : (isCurrent
                            ? theme.primaryColor
                            : theme.dividerColor.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.4),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildInputs(ThemeData theme) {
    return Row(
      children: [
        Expanded(child: _liveInput('PESO', _pesoController, theme, '0.0')),
        const SizedBox(width: 12),
        Expanded(child: _liveInput('REPS', _repsController, theme, '0')),
        const SizedBox(width: 12),
        Expanded(child: _liveInput('RIR', _rirController, theme, '0')),
      ],
    );
  }

  Widget _liveInput(
    String label,
    TextEditingController controller,
    ThemeData theme,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
        TextField(
          controller: controller,
          enabled: !_isResting,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            if (label == 'PESO')
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
            else
              FilteringTextInputFormatter.digitsOnly,
          ],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            color: _isResting ? theme.disabledColor : null,
          ),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: _isResting
                ? theme.dividerColor.withOpacity(0.05)
                : theme.cardTheme.color,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _logSet,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
        ),
        child: const Text(
          'SERIE COMPLETADA',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildRestUI(ThemeData theme) {
    final minutes = (_timerSeconds / 60).floor();
    final seconds = _timerSeconds % 60;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9500),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9500).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'TIEMPO DE DESCANSO',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () {
                _timer?.cancel();
                _onRestComplete();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'SALTAR DESCANSO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
