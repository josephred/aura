import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'db_helper.dart';

/// Replays CRUD requests that failed while offline (outbox pattern).
///
/// Failed mutations are queued in the `offline_outbox` SQLite table by
/// [enqueue]. When connectivity is restored the queue is flushed in the
/// original order. Entries rejected by the server (4xx) are dropped so a
/// bad request can never block the queue; network errors stop the flush
/// and leave the remaining entries for the next attempt.
class OutboxService {
  final ApiService apiService;
  final VoidCallback? onFlushed;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isFlushing = false;

  OutboxService({required this.apiService, this.onFlushed});

  /// Start watching connectivity; flushes as soon as a connection appears.
  void start() {
    _subscription ??= Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) {
        flush();
      }
    });
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> enqueue(String method, String path, String? body) async {
    await DbHelper.instance.enqueueOutbox(method, path, body);
    debugPrint('Outbox: queued $method $path for retry when online.');
  }

  /// Send every queued request in order. Safe to call repeatedly.
  Future<void> flush() async {
    if (_isFlushing) return;
    _isFlushing = true;

    var sentAny = false;
    try {
      final entries = await DbHelper.instance.getOutbox();
      for (final entry in entries) {
        final seq = entry['seq'] as int;
        final method = entry['method'] as String;
        final path = entry['path'] as String;
        final body = entry['body'] as String?;

        final http.Response response;
        try {
          response = switch (method) {
            'POST' => await apiService.post(path, body: body, isRawBody: true),
            'PUT' => await apiService.put(path, body: body, isRawBody: true),
            'DELETE' => await apiService.delete(path),
            _ => throw UnsupportedError('Unknown outbox method: $method'),
          };
        } catch (e) {
          // Still offline (or server unreachable): retry on next connection
          debugPrint('Outbox: flush stopped at $method $path, will retry. Error: $e');
          break;
        }

        if (response.statusCode == 401) {
          // Session revoked; ApiService already triggered the global handler
          break;
        }

        // Success (2xx) clears the entry; a definitive server rejection
        // (4xx) also clears it so it cannot block the rest of the queue.
        if (response.statusCode < 500) {
          await DbHelper.instance.deleteOutboxEntry(seq);
          if (response.statusCode < 300) sentAny = true;
        } else {
          break; // Server error: keep the entry and retry later
        }
      }
    } finally {
      _isFlushing = false;
    }

    if (sentAny) {
      onFlushed?.call();
    }
  }
}
