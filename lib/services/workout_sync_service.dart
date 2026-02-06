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

  Future<void> queueSession(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_queueKey) ?? '[]';
    final List<dynamic> queue = jsonDecode(queueJson);

    // Add timestamp to the payload to track when it was recorded locally
    payload['recordedAt'] = DateTime.now().toIso8601String();
    queue.add(payload);

    await prefs.setString(_queueKey, jsonEncode(queue));
    debugPrint(
      'WorkoutSyncService: Session queued offline. Total in queue: ${queue.length}',
    );
  }

  Future<void> syncPendingSessions() async {
    if (await isOffline()) return;

    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_queueKey) ?? '[]';
    final List<dynamic> queue = jsonDecode(queueJson);

    if (queue.isEmpty) return;

    debugPrint(
      'WorkoutSyncService: Starting synchronization of ${queue.length} sessions...',
    );

    final List<dynamic> remainingQueue = [];

    for (var session in queue) {
      try {
        final res = await _api.post('/entrenamientos/registros', session);
        if (res.statusCode != 200 && res.statusCode != 201) {
          debugPrint('WorkoutSyncService: Failed to sync session: ${res.body}');
          remainingQueue.add(
            session,
          ); // Keep in queue if server rejected but not a network error
        }
      } catch (e) {
        debugPrint('WorkoutSyncService: Error syncing session: $e');
        remainingQueue.add(session); // Keep in queue to retry later
      }
    }

    await prefs.setString(_queueKey, jsonEncode(remainingQueue));
    debugPrint(
      'WorkoutSyncService: Synchronization finished. Remaining in queue: ${remainingQueue.length}',
    );
  }

  Future<int> getQueueCount() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_queueKey) ?? '[]';
    return jsonDecode(queueJson).length;
  }
}
