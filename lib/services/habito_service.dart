import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habito_model.dart';
import 'api_service.dart';
import 'offline_sync_service.dart';

class HabitoService extends ChangeNotifier {
  final ApiService _api;
  final OfflineSyncService? _sync;
  List<Habito> _habitos = [];
  List<HabitoRegistro> _logs = [];
  List<HabitoRegistro> _historyLogs = [];
  bool _isLoading = false;

  HabitoService(this._api, [this._sync]);

  List<Habito> get habitos => _habitos;
  List<HabitoRegistro> get logs => _logs;
  List<HabitoRegistro> get historyLogs => _historyLogs;
  bool get isLoading => _isLoading;

  Future<void> fetchHabitos(String clienteId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.get('/habitos?clienteId=$clienteId');
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        _habitos = data.map((item) => Habito.fromJson(item)).toList();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cache_habitos_$clienteId', res.body);
      }
    } catch (e) {
      debugPrint('HabitoService: Error fetching habits, trying cache: $e');
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cache_habitos_$clienteId');
      if (cached != null) {
        final List<dynamic> data = jsonDecode(cached);
        _habitos = data.map((item) => Habito.fromJson(item)).toList();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchLogs(
    String clienteId, {
    DateTime? start,
    DateTime? end,
  }) async {
    final cacheKey =
        'cache_logs_${clienteId}_${start?.toIso8601String()}_${end?.toIso8601String()}';
    try {
      String query = 'clienteId=$clienteId';
      if (start != null) query += '&startDate=${start.toIso8601String()}';
      if (end != null) query += '&endDate=${end.toIso8601String()}';

      final res = await _api.get('/habitos/logs?$query');
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        _logs = data.map((item) => HabitoRegistro.fromJson(item)).toList();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, res.body);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('HabitoService: Error fetching logs, trying cache: $e');
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final List<dynamic> data = jsonDecode(cached);
        _logs = data.map((item) => HabitoRegistro.fromJson(item)).toList();
        notifyListeners();
      }
    }
  }

  Future<void> fetchHistoryLogs(
    String clienteId, {
    String? habitoId,
    int? month,
    int? year,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      String query = 'clienteId=$clienteId';
      if (habitoId != null && habitoId.isNotEmpty)
        query += '&habitoId=$habitoId';
      if (month != null) query += '&month=$month';
      if (year != null) query += '&year=$year';

      final res = await _api.get('/habitos/logs?$query');
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        _historyLogs = data
            .map((item) => HabitoRegistro.fromJson(item))
            .toList();
        _historyLogs.sort((a, b) => b.fecha.compareTo(a.fecha));
      }
    } catch (e) {
      debugPrint('HabitoService: Error fetching history logs: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createHabito(Habito habito) async {
    try {
      final res = await _api.post('/habitos', habito.toJson());
      if (res.statusCode == 200 || res.statusCode == 201) {
        _habitos.add(Habito.fromJson(jsonDecode(res.body)));
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('HabitoService: Error creating habit: $e');
    }
    return false;
  }

  Future<bool> updateHabito(Habito habito) async {
    try {
      final res = await _api.put('/habitos/${habito.id}', habito.toJson());
      if (res.statusCode == 200) {
        final updated = Habito.fromJson(jsonDecode(res.body));
        final index = _habitos.indexWhere((h) => h.id == updated.id);
        if (index != -1) {
          _habitos[index] = updated;
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint('HabitoService: Error updating habit: $e');
    }
    return false;
  }

  Future<bool> deleteHabito(String id) async {
    try {
      final res = await _api.delete('/habitos/$id');
      if (res.statusCode == 200) {
        _habitos.removeWhere((h) => h.id == id);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('HabitoService: Error deleting habit: $e');
    }
    return false;
  }

  Future<void> logHabit({
    required String habitoId,
    required String clienteId,
    required DateTime fecha,
    bool completado = false,
    double? valor,
    String? notas,
  }) async {
    final payload = {
      'habitoId': habitoId,
      'clienteId': clienteId,
      'fecha': fecha.toIso8601String(),
      'completado': completado,
      'valor': valor,
      'notas': notas,
    };

    if (_sync != null && await _sync.isOffline()) {
      await _sync.queueUpdate(
        payload,
        endpoint: '/habitos/logs',
        method: 'POST',
      );
      // Optimistic UI update
      final optimisticLog = HabitoRegistro(
        id: 'offline_${DateTime.now().millisecondsSinceEpoch}',
        habitoId: habitoId,
        clienteId: clienteId,
        fecha: fecha,
        completado: completado,
        valor: valor,
        notas: notas,
      );
      final index = _logs.indexWhere(
        (l) =>
            l.habitoId == habitoId &&
            l.fecha.day == optimisticLog.fecha.day &&
            l.fecha.month == optimisticLog.fecha.month &&
            l.fecha.year == optimisticLog.fecha.year,
      );

      if (index != -1) {
        _logs[index] = optimisticLog;
      } else {
        _logs.add(optimisticLog);
      }
      notifyListeners();
      return;
    }

    try {
      final res = await _api.post('/habitos/logs', payload);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final newLog = HabitoRegistro.fromJson(jsonDecode(res.body));
        final index = _logs.indexWhere(
          (l) =>
              l.habitoId == habitoId &&
              l.fecha.day == newLog.fecha.day &&
              l.fecha.month == newLog.fecha.month &&
              l.fecha.year == newLog.fecha.year,
        );

        if (index != -1) {
          _logs[index] = newLog;
        } else {
          _logs.add(newLog);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('HabitoService: Error logging habit: $e');
    }
  }

  Future<Map<String, dynamic>> fetchWeightKcalAnalytics(
    String clienteId,
  ) async {
    try {
      final res = await _api.get('/clientes/$clienteId/analytics/weight-kcal');
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint('HabitoService: Error fetching analytics: $e');
    }
    return {'weight': [], 'kcal': []};
  }
}
