import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/constants/api_constants.dart';
import '../providers/alerts_provider.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(alertsListProvider),
          ),
        ],
      ),
      body: alertsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: 'Failed to load alerts',
          onRetry: () => ref.invalidate(alertsListProvider),
        ),
        data: (alerts) => alerts.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 56, color: AppColors.success),
                    SizedBox(height: 12),
                    Text('No active alerts', style: AppTextStyles.caption),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(alertsListProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: alerts.length,
                  itemBuilder: (context, i) => _AlertTile(
                      data: alerts[i] as Map<String, dynamic>, ref: ref),
                ),
              ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.data, required this.ref});

  final Map<String, dynamic> data;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? 'Alert';
    final message = data['message'] as String? ?? '';
    final isAcknowledged = data['isAcknowledged'] as bool? ?? false;
    final ts = data['triggeredAt'] as String?;
    final time = ts != null
        ? DateFormat('d MMM HH:mm').format(DateTime.parse(ts).toLocal())
        : '';

    final typeColor = _typeColor(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: typeColor.withAlpha(25),
          child: Icon(_typeIcon(type), color: typeColor, size: 20),
        ),
        title: Text(type,
            style: AppTextStyles.title.copyWith(color: typeColor)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: AppTextStyles.body),
            Text(time, style: AppTextStyles.caption),
          ],
        ),
        trailing: isAcknowledged
            ? const Icon(Icons.check_circle, color: AppColors.success)
            : TextButton(
                onPressed: () =>
                    _acknowledge(context, data['id'] as String?),
                child: const Text('ACK'),
              ),
      ),
    );
  }

  Color _typeColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('oversize')) return AppColors.warning;
    if (t.contains('after')) return Colors.purple;
    if (t.contains('battery')) return AppColors.error;
    return AppColors.primaryDark;
  }

  IconData _typeIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('battery')) return Icons.battery_alert;
    if (t.contains('oversize')) return Icons.warning_amber;
    return Icons.notifications;
  }

  Future<void> _acknowledge(BuildContext context, String? id) async {
    if (id == null) return;
    try {
      final dio = ref.read(dioProvider);
      await dio.post('${ApiConstants.alerts}/$id/acknowledge');
      ref.invalidate(alertsListProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to acknowledge alert')),
        );
      }
    }
  }
}
