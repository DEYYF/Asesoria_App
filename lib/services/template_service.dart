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

  Future<void> loadTemplates() async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _api.get('/templates');
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        _templates = data
            .map((json) => MessageTemplate.fromJson(json))
            .toList();
      }
    } catch (e) {
      print('Error loading templates: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createTemplate(MessageTemplate t) async {
    try {
      final res = await _api.post('/templates', t.toJson());
      if (res.statusCode == 201) {
        final newT = MessageTemplate.fromJson(jsonDecode(res.body));
        _templates.insert(0, newT);
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Error creating template: $e');
    }
    return false;
  }

  Future<bool> updateTemplate(String id, Map<String, dynamic> updates) async {
    try {
      final res = await _api.put('/templates/$id', updates);
      if (res.statusCode == 200) {
        final updated = MessageTemplate.fromJson(jsonDecode(res.body));
        final index = _templates.indexWhere((t) => t.id == id);
        if (index != -1) {
          _templates[index] = updated;
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      print('Error updating template: $e');
    }
    return false;
  }

  Future<bool> deleteTemplate(String id) async {
    try {
      final res = await _api.delete('/templates/$id');
      if (res.statusCode == 200) {
        _templates.removeWhere((t) => t.id == id);
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Error deleting template: $e');
    }
    return false;
  }
}
