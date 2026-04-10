import 'dart:convert';
import '../db/app_database.dart';

/// Thin wrapper around AppDatabase cache table.
/// Serialises / deserialises JSON automatically.
class CacheStore {
  const CacheStore._(this._db);

  factory CacheStore.of(AppDatabase db) => CacheStore._(db);

  final AppDatabase _db;

  /// Returns the decoded value or null if not cached.
  Future<dynamic> read(String key) async {
    final raw = await _db.cacheRead(key);
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  /// Writes any JSON-serialisable [value] to the cache.
  Future<void> write(String key, dynamic value) async {
    await _db.cacheWrite(key, jsonEncode(value));
  }

  Future<void> delete(String key) => _db.cacheDelete(key);
}
