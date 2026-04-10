import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';

/// Thin SQLite wrapper providing two tables:
///   - response_cache   : SWR key → JSON blob
///   - pending_mutations: ordered queue of offline write operations
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath${Platform.pathSeparator}pour_metrics.db';
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE response_cache (
            cache_key TEXT PRIMARY KEY,
            data_json TEXT NOT NULL,
            cached_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_mutations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mutation_id TEXT NOT NULL,
            method TEXT NOT NULL,
            path TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // ── Cache ─────────────────────────────────────────────────────────────────

  Future<String?> cacheRead(String key) async {
    final db = await _database;
    final rows = await db.query(
      'response_cache',
      columns: ['data_json'],
      where: 'cache_key = ?',
      whereArgs: [key],
    );
    return rows.isNotEmpty ? rows.first['data_json'] as String : null;
  }

  Future<void> cacheWrite(String key, String dataJson) async {
    final db = await _database;
    await db.insert(
      'response_cache',
      {
        'cache_key': key,
        'data_json': dataJson,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> cacheDelete(String key) async {
    final db = await _database;
    await db.delete('response_cache',
        where: 'cache_key = ?', whereArgs: [key]);
  }

  // ── Pending mutations ─────────────────────────────────────────────────────

  Future<void> enqueue({
    required String mutationId,
    required String method,
    required String path,
    required String payloadJson,
  }) async {
    final db = await _database;
    await db.insert('pending_mutations', {
      'mutation_id': mutationId,
      'method': method,
      'path': path,
      'payload_json': payloadJson,
      'retry_count': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> pendingAll() async {
    final db = await _database;
    return db.query('pending_mutations', orderBy: 'id ASC');
  }

  Future<int> pendingCount() async {
    final db = await _database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as c FROM pending_mutations');
    return result.first['c'] as int;
  }

  Future<void> dequeue(int id) async {
    final db = await _database;
    await db.delete('pending_mutations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementRetry(int id) async {
    final db = await _database;
    await db.rawUpdate(
        'UPDATE pending_mutations SET retry_count = retry_count + 1 WHERE id = ?',
        [id]);
  }
}
