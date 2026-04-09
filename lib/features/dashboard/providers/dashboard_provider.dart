import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/constants/api_constants.dart';

class DashboardSummary {
  final int activePours;
  final double totalRevenue;
  final int activeAlerts;
  final int onlineDevices;
  final List<Map<String, dynamic>> recentPours;

  const DashboardSummary({
    required this.activePours,
    required this.totalRevenue,
    required this.activeAlerts,
    required this.onlineDevices,
    required this.recentPours,
  });
}

final dashboardProvider =
    FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final dio = ref.watch(dioProvider);
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day);

  final results = await Future.wait([
    dio.get('${ApiConstants.pourEvents}/summary', queryParameters: {
      'from': from.toIso8601String(),
      'to': now.toIso8601String(),
    }),
    dio.get(ApiConstants.alerts),
    dio.get(ApiConstants.devices),
    dio.get(ApiConstants.pourEvents,
        queryParameters: {'page': 1, 'pageSize': 5}),
  ]);

  final summary = results[0].data as Map<String, dynamic>;
  final alertData = results[1].data as List;
  final devicesData = results[2].data as List;
  final recentData = results[3].data;

  final unacknowledged =
      alertData.where((a) => a['isAcknowledged'] == false).length;

  return DashboardSummary(
    activePours: (summary['totalPours'] as num?)?.toInt() ?? 0,
    totalRevenue: (summary['totalRevenue'] as num?)?.toDouble() ?? 0.0,
    activeAlerts: unacknowledged,
    onlineDevices: devicesData.length,
    recentPours:
        recentData is List ? recentData.cast<Map<String, dynamic>>() : [],
  );
});
