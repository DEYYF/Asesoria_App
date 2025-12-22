import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/ejercicio_model.dart';
import '../models/cliente_model.dart';

/// Isolate utility functions for offloading heavy computations
/// from the UI thread to improve app performance.

// ============================================================================
// JSON PARSING ISOLATES
// ============================================================================

/// Parse JSON string to dynamic in an isolate
/// Use for large JSON responses to avoid blocking UI
Future<dynamic> parseJsonInIsolate(String jsonString) async {
  return compute(_parseJson, jsonString);
}

dynamic _parseJson(String jsonString) {
  return jsonDecode(jsonString);
}

// ============================================================================
// EJERCICIOS ISOLATES
// ============================================================================

/// Parse and convert JSON to list of Ejercicio models in isolate
Future<List<Ejercicio>> parseEjerciciosInIsolate(String jsonString) async {
  return compute(_parseEjercicios, jsonString);
}

List<Ejercicio> _parseEjercicios(String jsonString) {
  final data = jsonDecode(jsonString);
  final List<dynamic> items = data is List ? data : (data['items'] ?? []);
  return items.map((e) => Ejercicio.fromJson(e)).toList();
}

/// Filter ejercicios by search term and filters in isolate
Future<List<Ejercicio>> filterEjerciciosInIsolate(
  EjercicioFilterParams params,
) async {
  return compute(_filterEjercicios, params);
}

List<Ejercicio> _filterEjercicios(EjercicioFilterParams params) {
  return params.ejercicios.where((ejercicio) {
    final matchesSearch =
        params.searchTerm.isEmpty ||
        ejercicio.nombre.toLowerCase().contains(
          params.searchTerm.toLowerCase(),
        );
    final matchesGrupo =
        params.grupo == null || ejercicio.grupo == params.grupo;
    final matchesEquipo =
        params.equipo == null || ejercicio.equipo == params.equipo;
    final matchesNivel =
        params.nivel == null || ejercicio.nivel == params.nivel;

    return matchesSearch && matchesGrupo && matchesEquipo && matchesNivel;
  }).toList();
}

/// Parameters for filtering ejercicios
class EjercicioFilterParams {
  final List<Ejercicio> ejercicios;
  final String searchTerm;
  final String? grupo;
  final String? equipo;
  final String? nivel;

  EjercicioFilterParams({
    required this.ejercicios,
    required this.searchTerm,
    this.grupo,
    this.equipo,
    this.nivel,
  });
}

// ============================================================================
// CLIENTES ISOLATES
// ============================================================================

/// Parse and convert JSON to list of Cliente models in isolate
Future<List<Cliente>> parseClientesInIsolate(String jsonString) async {
  return compute(_parseClientes, jsonString);
}

List<Cliente> _parseClientes(String jsonString) {
  final List<dynamic> data = jsonDecode(jsonString) as List;
  return data.map((c) => Cliente.fromJson(c)).toList();
}

/// Filter clientes by search term in isolate
Future<List<Cliente>> filterClientesInIsolate(
  ClienteFilterParams params,
) async {
  return compute(_filterClientes, params);
}

List<Cliente> _filterClientes(ClienteFilterParams params) {
  if (params.searchTerm.isEmpty) return params.clientes;

  final searchLower = params.searchTerm.toLowerCase();
  return params.clientes.where((cliente) {
    return cliente.nombre.toLowerCase().contains(searchLower) ||
        cliente.email.toLowerCase().contains(searchLower);
  }).toList();
}

/// Parameters for filtering clientes
class ClienteFilterParams {
  final List<Cliente> clientes;
  final String searchTerm;

  ClienteFilterParams({required this.clientes, required this.searchTerm});
}

// ============================================================================
// GENERIC LIST PROCESSING
// ============================================================================

/// Sort a list in an isolate
/// Useful for large lists that take time to sort
Future<List<T>> sortListInIsolate<T>(SortParams<T> params) async {
  return compute(_sortList, params);
}

List<T> _sortList<T>(SortParams<T> params) {
  final list = List<T>.from(params.list);
  list.sort(params.comparator);
  return list;
}

/// Parameters for sorting
class SortParams<T> {
  final List<T> list;
  final int Function(T, T) comparator;

  SortParams({required this.list, required this.comparator});
}

/// Process session history data in isolate
/// Builds month and session maps for journal display
Future<SessionHistoryResult> processSessionHistoryInIsolate(
  String jsonString,
) async {
  return compute(_processSessionHistory, jsonString);
}

SessionHistoryResult _processSessionHistory(String jsonString) {
  final List<dynamic> sessions = jsonDecode(jsonString);

  // Use string keys for isolate compatibility
  final Map<String, Map<String, dynamic>> sessionsMap = {};
  final Map<String, List<String>> monthsMap = {};

  for (var session in sessions) {
    final dateStr = session['fecha'] as String?;
    if (dateStr == null) continue;

    final rawDate = DateTime.parse(dateStr);
    final dateKey = DateTime(rawDate.year, rawDate.month, rawDate.day);
    final dateKeyStr = dateKey.toIso8601String();

    sessionsMap[dateKeyStr] = {
      'ejercicios': session['ejercicios'] ?? [],
      'comentarios': session['comentarios'] ?? '',
      'semanaNumero': session['semanaNumero'],
      'diaNombre': session['diaNombre'],
    };

    // Extract YYYY-MM for month grouping
    final monthKey = DateTime(rawDate.year, rawDate.month);
    final monthKeyStr = monthKey.toIso8601String();

    if (!monthsMap.containsKey(monthKeyStr)) {
      monthsMap[monthKeyStr] = [];
    }
    if (!monthsMap[monthKeyStr]!.contains(dateKeyStr)) {
      monthsMap[monthKeyStr]!.add(dateKeyStr);
    }
  }

  // Sort days within months (descending)
  for (var key in monthsMap.keys) {
    monthsMap[key]!.sort((a, b) => b.compareTo(a));
  }

  // Sort months descending
  final sortedMonths = monthsMap.keys.toList()..sort((a, b) => b.compareTo(a));

  return SessionHistoryResult(
    monthsMap: monthsMap,
    sessionsMap: sessionsMap,
    sortedMonths: sortedMonths,
  );
}

/// Result from session history processing
class SessionHistoryResult {
  final Map<String, List<String>> monthsMap;
  final Map<String, Map<String, dynamic>> sessionsMap;
  final List<String> sortedMonths;

  SessionHistoryResult({
    required this.monthsMap,
    required this.sessionsMap,
    required this.sortedMonths,
  });
}
