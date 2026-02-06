import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class OfflineSyncService {
  final ApiService _api;
  static const String _queueKey = 'offline_sync_queue';

  OfflineSyncService(this._api);

  Future<bool> isOffline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult == ConnectivityResult.none;
  }

  /// Queues an update or session for offline synchronization.
  /// [payload] should be the map of data.
  /// [endpoint] is the API path where the POST request should be sent.
  Future<void> queueUpdate(
    Map<String, dynamic> payload, {
    String endpoint = '/entrenamientos/registros',
    String method = 'POST',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_queueKey) ?? '[]';
    final List<dynamic> queue = jsonDecode(queueJson);

    // Wrap the payload with metadata
    final item = {
      'endpoint': endpoint,
      'method': method,
      'payload': payload,
      'recordedAt': DateTime.now().toIso8601String(),
    };

    queue.add(item);

    await prefs.setString(_queueKey, jsonEncode(queue));
    debugPrint(
      'OfflineSyncService: Update queued offline for $endpoint. Total in queue: ${queue.length}',
    );
  }

  Future<void> syncPendingSessions() async {
    if (await isOffline()) return;

    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_queueKey) ?? '[]';
    final List<dynamic> queue = jsonDecode(queueJson);

    if (queue.isEmpty) return;

    debugPrint(
      'OfflineSyncService: Starting synchronization of ${queue.length} items...',
    );

    final List<dynamic> remainingQueue = [];

    for (var item in queue) {
      try {
        final String endpoint = item['endpoint'] ?? '/entrenamientos/registros';
        final String method = item['method'] ?? 'POST';
        final dynamic payload = item['payload'] ?? item;

        final res = method == 'PUT'
            ? await _api.put(endpoint, payload)
            : method == 'DELETE'
            ? await _api.delete(endpoint)
            : await _api.post(endpoint, payload);
        if (res.statusCode != 200 && res.statusCode != 201) {
          debugPrint(
            'OfflineSyncService: Failed to sync item ($endpoint): ${res.body}',
          );
          remainingQueue.add(item);
        }
      } catch (e) {
        debugPrint('OfflineSyncService: Error syncing item: $e');
        remainingQueue.add(item);
      }
    }

    await prefs.setString(_queueKey, jsonEncode(remainingQueue));
    debugPrint(
      'OfflineSyncService: Synchronization finished. Remaining in queue: ${remainingQueue.length}',
    );
  }

  Future<int> getQueueCount() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_queueKey) ?? '[]';
    return jsonDecode(queueJson).length;
  }
}
