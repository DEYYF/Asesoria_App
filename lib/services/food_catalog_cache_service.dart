import 'dart:async';

import '../models/ingrediente_model.dart';
import '../models/receta_model.dart';
import '../utils/isolate_utils.dart';
import 'api_service.dart';

class FoodCatalogData {
  final List<Ingrediente> ingredientes;
  final List<Receta> recetas;

  const FoodCatalogData({
    required this.ingredientes,
    required this.recetas,
  });
}

class FoodCatalogCacheService {
  FoodCatalogCacheService._();

  static FoodCatalogData? _cache;
  static DateTime? _lastFetch;
  static Future<FoodCatalogData>? _inFlight;

  static const Duration ttl = Duration(minutes: 10);

  static bool get _isFresh {
    final last = _lastFetch;
    if (_cache == null || last == null) return false;
    return DateTime.now().difference(last) < ttl;
  }

  static Future<FoodCatalogData> getCatalog(
    ApiService api, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isFresh) return _cache!;

    if (!forceRefresh && _inFlight != null) return _inFlight!;

    final future = _fetchCatalog(api);
    _inFlight = future;

    try {
      final data = await future;
      _cache = data;
      _lastFetch = DateTime.now();
      return data;
    } finally {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    }
  }

  static Future<FoodCatalogData> refresh(ApiService api) {
    return getCatalog(api, forceRefresh: true);
  }

  static void invalidate() {
    _cache = null;
    _lastFetch = null;
    _inFlight = null;
  }

  static Future<FoodCatalogData> _fetchCatalog(ApiService api) async {
    final results = await Future.wait([
      api.get('/comidas/recetas'),
      api.get('/comidas/ingredientes'),
    ]);

    if (results[0].statusCode != 200) {
      throw Exception('Error cargando recetas: HTTP ${results[0].statusCode}');
    }
    if (results[1].statusCode != 200) {
      throw Exception('Error cargando ingredientes: HTTP ${results[1].statusCode}');
    }

    final recetas = await parseRecetasInIsolate(results[0].body);
    final ingredientes = await parseIngredientesInIsolate(results[1].body);

    ingredientes.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    recetas.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

    return FoodCatalogData(
      ingredientes: ingredientes,
      recetas: recetas,
    );
  }
}
