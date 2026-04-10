import 'package:dio/dio.dart';
import 'offline_queue.dart';

/// Performs an optimistic mutation with automatic offline fallback.
///
/// Flow:
///   1. [optimisticApply] — update in-memory state immediately (no await).
///   2. Attempt the real HTTP call.
///   3a. Success  → done; server state matches optimistic.
///   3b. Offline  → keep optimistic state + enqueue for later replay.
///   3c. Server error (4xx/5xx) → [rollback] in-memory state and rethrow.
Future<void> performMutation({
  required Dio dio,
  required OfflineQueue queue,
  required String method,
  required String path,
  required Map<String, dynamic> payload,
  required void Function() optimisticApply,
  required void Function() rollback,
  /// Stable ID used to prevent duplicate queue entries (UUID recommended).
  String? mutationId,
}) async {
  optimisticApply();

  try {
    await _dispatch(dio, method, path, payload);
  } catch (e) {
    if (isOfflineError(e)) {
      // Keep optimistic state and persist for later.
      await queue.enqueue(
        mutationId:
            mutationId ?? '${method}_${path}_${DateTime.now().millisecondsSinceEpoch}',
        method: method,
        path: path,
        payload: payload,
      );
    } else {
      rollback();
      rethrow;
    }
  }
}

Future<Response<dynamic>> _dispatch(
  Dio dio,
  String method,
  String path,
  Map<String, dynamic> payload,
) {
  switch (method.toUpperCase()) {
    case 'POST':
      return dio.post(path, data: payload);
    case 'PUT':
      return dio.put(path, data: payload);
    case 'PATCH':
      return dio.patch(path, data: payload);
    case 'DELETE':
      return dio.delete(path, data: payload);
    default:
      throw ArgumentError('Unsupported method: $method');
  }
}
