import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import './api_service.dart';

class TaskService extends ChangeNotifier {
  final ApiService _api;
  List<Tarea> _tasks = [];
  bool _isLoading = false;

  TaskService(this._api);

  List<Tarea> get tasks => _tasks;
  bool get isLoading => _isLoading;

  Future<void> loadTasks({
    String? status,
    String? assigneeId,
    String? clientId,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final params = <String, dynamic>{};
      if (status != null) params['status'] = status;
      if (assigneeId != null) params['assigneeId'] = assigneeId;
      if (clientId != null) params['clientId'] = clientId;

      final res = await _api.get('/tareas', params: params);
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        _tasks = data.map((json) => Tarea.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error loading tasks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Tarea?> createTask(Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/tareas', data);
      if (res.statusCode == 201) {
        final newTask = Tarea.fromJson(jsonDecode(res.body));
        _tasks.insert(0, newTask);
        notifyListeners();
        return newTask;
      }
    } catch (e) {
      debugPrint('Error creating task: $e');
    }
    return null;
  }

  Future<bool> updateTask(String id, Map<String, dynamic> data) async {
    try {
      final res = await _api.patch(
        '/tareas/$id',
        data,
      ); // TasksRoutes uses PATCH, but ApiService.put usually works or I might need to add patch to ApiService
      if (res.statusCode == 200) {
        final index = _tasks.indexWhere((t) => t.id == id);
        if (index != -1) {
          _tasks[index] = Tarea.fromJson(jsonDecode(res.body));
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error updating task: $e');
    }
    return false;
  }

  // Helper for status updates (Kanban drag)
  Future<bool> updateStatus(String id, String newStatus) async {
    // Optimistic update
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) return false;

    final oldTask = _tasks[index];
    _tasks[index] = oldTask.copyWith(status: newStatus);
    notifyListeners();

    try {
      final res = await _api.patch('/tareas/$id', {'status': newStatus});
      if (res.statusCode != 200) {
        // Rollback
        _tasks[index] = oldTask;
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      // Rollback
      _tasks[index] = oldTask;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTask(String id) async {
    try {
      final res = await _api.delete('/tareas/$id');
      if (res.statusCode == 200) {
        _tasks.removeWhere((t) => t.id == id);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
    return false;
  }
}
