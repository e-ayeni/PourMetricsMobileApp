import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/constants/api_constants.dart';

// ── List providers ────────────────────────────────────────────────────────────

final bottlesListProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiConstants.bottles);
  return response.data as List<dynamic>;
});

final productsListProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiConstants.products);
  return response.data as List<dynamic>;
});

final venuesListProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiConstants.venues);
  return response.data as List<dynamic>;
});

// ── Barcode lookup ────────────────────────────────────────────────────────────

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

// ── Create product ────────────────────────────────────────────────────────────

Future<Map<String, dynamic>> createProduct(
    Dio dio, Map<String, dynamic> payload) async {
  final response = await dio.post(ApiConstants.products, data: payload);
  return response.data as Map<String, dynamic>;
}

// ── Register bottle ───────────────────────────────────────────────────────────

Future<Map<String, dynamic>> registerBottle(
    Dio dio, Map<String, dynamic> payload) async {
  final response = await dio.post(ApiConstants.bottles, data: payload);
  return response.data as Map<String, dynamic>;
}
