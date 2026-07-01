import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';
import '../models/template_model.dart';

class TemplateService extends ChangeNotifier {
  final ApiService _api;

  TemplateService(this._api);

  List<MessageTemplate> _templates = [];
  List<MessageTemplate> get templates => _templates;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _lastError;
  String? get lastError => _lastError;

  List<dynamic> _extractList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      final candidates = [
        decoded['templates'],
        decoded['plantillas'],
        decoded['data'],
        decoded['items'],
        decoded['results'],
      ];
      for (final candidate in candidates) {
        if (candidate is List) return candidate;
      }
    }
    return [];
  }

  Future<void> loadTemplates() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final res = await _api.get('/templates');
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final data = _extractList(decoded);
        _templates = data
            .whereType<Map<String, dynamic>>()
            .map((json) => MessageTemplate.fromJson(json))
            .where((template) => template.id.isNotEmpty && template.content.trim().isNotEmpty)
            .toList();
      } else {
        _lastError = 'Error ${res.statusCode} cargando plantillas';
      }
    } catch (e) {
      _lastError = 'Error loading templates: $e';
      debugPrint(_lastError);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTemplate(MessageTemplate t) async {
    try {
      final res = await _api.post('/templates', t.toJson());
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final newT = MessageTemplate.fromJson(jsonDecode(res.body));
        _templates.removeWhere((template) => template.id == newT.id);
        _templates.insert(0, newT);
        notifyListeners();
        return true;
      }
      _lastError = 'Error ${res.statusCode} creando plantilla';
    } catch (e) {
      _lastError = 'Error creating template: $e';
      debugPrint(_lastError);
    }
    return false;
  }

  Future<bool> updateTemplate(String id, Map<String, dynamic> updates) async {
    try {
      final normalizedUpdates = Map<String, dynamic>.from(updates);
      if (normalizedUpdates.containsKey('type')) {
        normalizedUpdates['type'] = MessageTemplate.normalizeType(normalizedUpdates['type']);
      }

      final res = await _api.put('/templates/$id', normalizedUpdates);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final updated = MessageTemplate.fromJson(jsonDecode(res.body));
        final index = _templates.indexWhere((t) => t.id == id);
        if (index != -1) {
          _templates[index] = updated;
        } else {
          _templates.insert(0, updated);
        }
        notifyListeners();
        return true;
      }
      _lastError = 'Error ${res.statusCode} actualizando plantilla';
    } catch (e) {
      _lastError = 'Error updating template: $e';
      debugPrint(_lastError);
    }
    return false;
  }

  Future<bool> deleteTemplate(String id) async {
    try {
      final res = await _api.delete('/templates/$id');
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _templates.removeWhere((t) => t.id == id);
        notifyListeners();
        return true;
      }
      _lastError = 'Error ${res.statusCode} eliminando plantilla';
    } catch (e) {
      _lastError = 'Error deleting template: $e';
      debugPrint(_lastError);
    }
    return false;
  }
}
