import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/constants/api_constants.dart';

final poursPageProvider = StateProvider.autoDispose<int>((ref) => 1);

final poursListProvider =
    FutureProvider.autoDispose.family<List<dynamic>, int>((ref, page) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    ApiConstants.pourEvents,
    queryParameters: {'page': page, 'pageSize': 20},
  );
  return response.data as List<dynamic>;
});

final poursSummaryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final now = DateTime.now();
  final from = now.subtract(const Duration(days: 7));
  final response = await dio.get(
    '${ApiConstants.pourEvents}/summary',
    queryParameters: {
      'from': from.toIso8601String(),
      'to': now.toIso8601String(),
    },
  );
  return response.data as Map<String, dynamic>;
});
