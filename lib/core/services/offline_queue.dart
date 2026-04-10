import 'dart:convert';
import 'package:dio/dio.dart';
import '../db/app_database.dart';

const _maxRetries = 3;

/// Determines whether an error is a network connectivity failure
/// (i.e. safe to queue and retry) vs a server rejection (4xx — don't retry).
bool isOfflineError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return true;
      default:
        // A null response also means we never reached the server.
        return error.response == null;
    }
  }
  return false;
}

class OfflineQueue {
  const OfflineQueue._(this._db);

  factory OfflineQueue.of(AppDatabase db) => OfflineQueue._(db);

  final AppDatabase _db;

  Future<void> enqueue({
    required String mutationId,
    required String method,
    required String path,
    required Map<String, dynamic> payload,
  }) =>
      _db.enqueue(
        mutationId: mutationId,
        method: method,
        path: path,
        payloadJson: jsonEncode(payload),
      );

  Future<int> pendingCount() => _db.pendingCount();

  /// Drains the queue in insertion order. Each item is attempted once per
  /// [processAll] call. Items that permanently fail (4xx or exceed
  /// [_maxRetries]) are dropped; transient failures leave the item in place.
  Future<void> processAll(Dio dio) async {
    final rows = await _db.pendingAll();
    for (final row in rows) {
      final id = row['id'] as int;
      final method = row['method'] as String;
      final path = row['path'] as String;
      final payload =
          jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
      final retries = row['retry_count'] as int;

      if (retries >= _maxRetries) {
        await _db.dequeue(id);
        continue;
      }

      try {
        await _dispatch(dio, method, path, payload);
        await _db.dequeue(id);
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status != null && status >= 400 && status < 500) {
          // Client error — drop it, won't recover.
          await _db.dequeue(id);
        } else {
          // Server / network error — increment and leave for next attempt.
          await _db.incrementRetry(id);
        }
      } catch (_) {
        await _db.incrementRetry(id);
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
        throw ArgumentError('Unsupported queue method: $method');
    }
  }
}
