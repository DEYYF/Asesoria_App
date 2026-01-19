import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SuperAdminProvider with ChangeNotifier {
  final ApiService _api;
  List<dynamic> _advisors = [];
  String? _selectedAdvisorId; // null means "Global / All"
  bool _isLoading = false;

  SuperAdminProvider(this._api);

  List<dynamic> get advisors => _advisors;
  String? get selectedAdvisorId => _selectedAdvisorId;
  bool get isLoading => _isLoading;

  Future<void> loadAdvisors() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.get('/users');
      if (res.statusCode == 200) {
        _advisors = jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint('Error loading advisors: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectAdvisor(String? id) {
    if (_selectedAdvisorId == id) return;
    _selectedAdvisorId = id;
    notifyListeners();
  }

  // Clear state on logout
  void clear() {
    _advisors = [];
    _selectedAdvisorId = null;
    notifyListeners();
  }
}
