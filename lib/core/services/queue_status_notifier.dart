import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/db_provider.dart';
import '../providers/dio_provider.dart';
import 'offline_queue.dart';

/// Tracks how many mutations are waiting in the offline queue.
/// Automatically drains the queue whenever connectivity is restored.
class QueueStatusNotifier extends AsyncNotifier<int> {
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  Future<int> build() async {
    final db = ref.watch(dbProvider);
    final queue = OfflineQueue.of(db);

    // Listen for connectivity changes.
    _sub?.cancel();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results
          .any((r) => r != ConnectivityResult.none);
      if (online) _drainQueue();
    });

    ref.onDispose(() => _sub?.cancel());

    return queue.pendingCount();
  }

  Future<void> _drainQueue() async {
    final db = ref.read(dbProvider);
    final dio = ref.read(dioProvider);
    final queue = OfflineQueue.of(db);
    await queue.processAll(dio);
    // Refresh the count after draining.
    state = AsyncData(await queue.pendingCount());
  }

  Future<void> refresh() async {
    final db = ref.read(dbProvider);
    final queue = OfflineQueue.of(db);
    state = AsyncData(await queue.pendingCount());
  }
}

final queueStatusProvider =
    AsyncNotifierProvider<QueueStatusNotifier, int>(QueueStatusNotifier.new);
