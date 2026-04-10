import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/db/db_provider.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/services/cache_store.dart';
import '../../../core/services/offline_queue.dart';
import '../../../core/services/queue_status_notifier.dart';

// ── Bottles ───────────────────────────────────────────────────────────────────

class BottlesNotifier extends AsyncNotifier<List<dynamic>> {
  static const _cacheKey = 'bottles_list';

  CacheStore get _cache => CacheStore.of(ref.read(dbProvider));
  OfflineQueue get _queue => OfflineQueue.of(ref.read(dbProvider));
  Dio get _dio => ref.read(dioProvider);

  @override
  Future<List<dynamic>> build() async {
    // SWR: serve cache immediately, refresh in background.
    final cached = await _cache.read(_cacheKey);
    if (cached != null) {
      Future.microtask(_backgroundRefresh);
      return (cached as List).cast<dynamic>();
    }
    return _fetch();
  }

  Future<List<dynamic>> _fetch() async {
    final response = await _dio.get(ApiConstants.bottles);
    final data = response.data as List<dynamic>;
    await _cache.write(_cacheKey, data);
    return data;
  }

  Future<void> _backgroundRefresh() async {
    try {
      final fresh = await _fetch();
      if (state.hasValue) state = AsyncData(fresh);
    } catch (_) {
      // Silently ignore — stale cache remains visible.
    }
  }

  /// Forces a full foreground refresh (e.g. pull-to-refresh).
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Optimistically adds a bottle; falls back to offline queue if unreachable.
  Future<Map<String, dynamic>> addBottle(Map<String, dynamic> payload) async {
    final snapshot = state.valueOrNull ?? [];
    final tempId =
        'optimistic_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = {...payload, 'id': tempId};

    state = AsyncData([...snapshot, optimistic]);

    try {
      final res = await _dio.post(ApiConstants.bottles, data: payload);
      final server = res.data as Map<String, dynamic>;
      // Replace temp entry with real server data.
      final updated = [
        ...snapshot.where((b) => b['id'] != tempId),
        server,
      ];
      state = AsyncData(updated);
      await _cache.write(_cacheKey, updated);
      return server;
    } catch (e) {
      if (isOfflineError(e)) {
        await _queue.enqueue(
          mutationId: 'post_bottle_$tempId',
          method: 'POST',
          path: ApiConstants.bottles,
          payload: payload,
        );
        ref.read(queueStatusProvider.notifier).refresh();
        return optimistic;
      }
      // Server rejected it — roll back.
      state = AsyncData(snapshot);
      rethrow;
    }
  }

  /// Optimistically updates bottle fields.
  Future<void> updateBottle(String id, Map<String, dynamic> changes) async {
    final snapshot = state.valueOrNull ?? [];
    state = AsyncData(snapshot.map((b) {
      if (b['id'] == id) return {...b as Map<String, dynamic>, ...changes};
      return b;
    }).toList());

    try {
      await _dio.put('${ApiConstants.bottles}/$id', data: changes);
      await _cache.write(_cacheKey, state.value!);
    } catch (e) {
      if (isOfflineError(e)) {
        await _queue.enqueue(
          mutationId: 'put_bottle_$id',
          method: 'PUT',
          path: '${ApiConstants.bottles}/$id',
          payload: changes,
        );
        ref.read(queueStatusProvider.notifier).refresh();
      } else {
        state = AsyncData(snapshot);
        rethrow;
      }
    }
  }

  /// Optimistically removes a bottle (retire).
  Future<void> retireBottle(String id) async {
    final snapshot = state.valueOrNull ?? [];
    state = AsyncData(snapshot.where((b) => b['id'] != id).toList());

    try {
      await _dio.delete('${ApiConstants.bottles}/$id');
      await _cache.write(_cacheKey, state.value!);
    } catch (e) {
      if (isOfflineError(e)) {
        await _queue.enqueue(
          mutationId: 'delete_bottle_$id',
          method: 'DELETE',
          path: '${ApiConstants.bottles}/$id',
          payload: {},
        );
        ref.read(queueStatusProvider.notifier).refresh();
      } else {
        state = AsyncData(snapshot);
        rethrow;
      }
    }
  }
}

final bottlesListProvider =
    AsyncNotifierProvider<BottlesNotifier, List<dynamic>>(BottlesNotifier.new);

// ── Products ──────────────────────────────────────────────────────────────────

class ProductsNotifier extends AsyncNotifier<List<dynamic>> {
  static const _cacheKey = 'products_list';

  CacheStore get _cache => CacheStore.of(ref.read(dbProvider));
  OfflineQueue get _queue => OfflineQueue.of(ref.read(dbProvider));
  Dio get _dio => ref.read(dioProvider);

  @override
  Future<List<dynamic>> build() async {
    final cached = await _cache.read(_cacheKey);
    if (cached != null) {
      Future.microtask(_backgroundRefresh);
      return (cached as List).cast<dynamic>();
    }
    return _fetch();
  }

  Future<List<dynamic>> _fetch() async {
    final response = await _dio.get(ApiConstants.products);
    final data = response.data as List<dynamic>;
    await _cache.write(_cacheKey, data);
    return data;
  }

  Future<void> _backgroundRefresh() async {
    try {
      final fresh = await _fetch();
      if (state.hasValue) state = AsyncData(fresh);
    } catch (_) {}
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Optimistically adds a product. Returns the server product (or optimistic
  /// placeholder when offline) so callers can chain bottle registration.
  Future<Map<String, dynamic>> addProduct(
      Map<String, dynamic> payload) async {
    final snapshot = state.valueOrNull ?? [];
    final tempId =
        'optimistic_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = {...payload, 'id': tempId};

    state = AsyncData([...snapshot, optimistic]);

    try {
      final res = await _dio.post(ApiConstants.products, data: payload);
      final server = res.data as Map<String, dynamic>;
      final updated = [
        ...snapshot.where((p) => p['id'] != tempId),
        server,
      ];
      state = AsyncData(updated);
      await _cache.write(_cacheKey, updated);
      return server;
    } catch (e) {
      if (isOfflineError(e)) {
        await _queue.enqueue(
          mutationId: 'post_product_$tempId',
          method: 'POST',
          path: ApiConstants.products,
          payload: payload,
        );
        ref.read(queueStatusProvider.notifier).refresh();
        return optimistic;
      }
      state = AsyncData(snapshot);
      rethrow;
    }
  }

  /// Optimistically updates product fields.
  Future<void> updateProduct(String id, Map<String, dynamic> changes) async {
    final snapshot = state.valueOrNull ?? [];
    state = AsyncData(snapshot.map((p) {
      if (p['id'] == id) return {...p as Map<String, dynamic>, ...changes};
      return p;
    }).toList());

    try {
      await _dio.put('${ApiConstants.products}/$id', data: changes);
      await _cache.write(_cacheKey, state.value!);
    } catch (e) {
      if (isOfflineError(e)) {
        await _queue.enqueue(
          mutationId: 'put_product_$id',
          method: 'PUT',
          path: '${ApiConstants.products}/$id',
          payload: changes,
        );
        ref.read(queueStatusProvider.notifier).refresh();
      } else {
        state = AsyncData(snapshot);
        rethrow;
      }
    }
  }
}

final productsListProvider =
    AsyncNotifierProvider<ProductsNotifier, List<dynamic>>(
        ProductsNotifier.new);

// ── Venues ────────────────────────────────────────────────────────────────────

class VenuesNotifier extends AsyncNotifier<List<dynamic>> {
  static const _cacheKey = 'venues_list';

  CacheStore get _cache => CacheStore.of(ref.read(dbProvider));
  Dio get _dio => ref.read(dioProvider);

  @override
  Future<List<dynamic>> build() async {
    final cached = await _cache.read(_cacheKey);
    if (cached != null) {
      Future.microtask(_backgroundRefresh);
      return (cached as List).cast<dynamic>();
    }
    return _fetch();
  }

  Future<List<dynamic>> _fetch() async {
    final response = await _dio.get(ApiConstants.venues);
    final data = response.data as List<dynamic>;
    await _cache.write(_cacheKey, data);
    return data;
  }

  Future<void> _backgroundRefresh() async {
    try {
      final fresh = await _fetch();
      if (state.hasValue) state = AsyncData(fresh);
    } catch (_) {}
  }
}

final venuesListProvider =
    AsyncNotifierProvider<VenuesNotifier, List<dynamic>>(VenuesNotifier.new);

// ── Standalone helpers (used by screens that build their own optimistic flow) ──

/// Returns the product map if found, null if 404, throws on other errors.
Future<Map<String, dynamic>?> lookupBarcode(Dio dio, String barcode) async {
  try {
    final response =
        await dio.get('${ApiConstants.products}/barcode/$barcode');
    return response.data as Map<String, dynamic>;
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return null;
    rethrow;
  }
}

/// Legacy direct-call helpers kept for screens that haven't migrated yet.
Future<Map<String, dynamic>> createProduct(
    Dio dio, Map<String, dynamic> payload) async {
  final response = await dio.post(ApiConstants.products, data: payload);
  return response.data as Map<String, dynamic>;
}

Future<Map<String, dynamic>> registerBottle(
    Dio dio, Map<String, dynamic> payload) async {
  final response = await dio.post(ApiConstants.bottles, data: payload);
  return response.data as Map<String, dynamic>;
}
