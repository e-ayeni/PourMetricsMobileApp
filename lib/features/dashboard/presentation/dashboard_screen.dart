import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/error_view.dart';
import '../../devices/providers/devices_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardProvider);
    final devicesAsync = ref.watch(devicesListProvider);
    final bottlesAsync = ref.watch(bottlesListProvider);
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(dashboardProvider);
              ref.invalidate(devicesListProvider);
              ref.invalidate(bottlesListProvider);
            },
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: 'Failed to load home screen',
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (summary) {
          final devices =
              devicesAsync.valueOrNull?.cast<Map<String, dynamic>>() ??
                  const [];
          final bottles =
              bottlesAsync.valueOrNull?.cast<Map<String, dynamic>>() ??
                  const [];
          final offlineCount =
              devices.where((device) => !_isOnline(device)).length;
          final lowCount = bottles.where(_isLowBottle).length;
          final unassignedCount =
              bottles.where((bottle) => bottle['coasterName'] == null).length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardProvider);
              ref.invalidate(devicesListProvider);
              ref.invalidate(bottlesListProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text('What needs attention?', style: AppTextStyles.heading),
                const SizedBox(height: 8),
                const Text(
                  'Start with the tasks that need action now, then review today\'s numbers below.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 16),
                _AttentionCard(
                  title: '$offlineCount coasters offline',
                  subtitle: offlineCount == 0
                      ? 'All your coasters are online.'
                      : 'Check device power, Wi-Fi, and placement.',
                  icon: Icons.sensors_off,
                  color:
                      offlineCount == 0 ? AppColors.success : AppColors.error,
                  onTap: () => context.go('/devices'),
                ),
                const SizedBox(height: 10),
                _AttentionCard(
                  title: '$lowCount bottles running low',
                  subtitle: lowCount == 0
                      ? 'No bottles are close to empty right now.'
                      : 'Review low-stock bottles and replace them before service slips.',
                  icon: Icons.warning_amber_rounded,
                  color: lowCount == 0 ? AppColors.success : AppColors.warning,
                  onTap: () => context.go('/inventory'),
                ),
                const SizedBox(height: 10),
                _AttentionCard(
                  title: '$unassignedCount bottles not on a coaster',
                  subtitle: unassignedCount == 0
                      ? 'Every tracked bottle is currently assigned.'
                      : 'Bring these back into live tracking or retire them.',
                  icon: Icons.inventory_2_outlined,
                  color:
                      unassignedCount == 0 ? AppColors.success : AppColors.info,
                  onTap: () => context.go('/inventory'),
                ),
                const SizedBox(height: 10),
                _AttentionCard(
                  title: '${summary.activeAlerts} active alerts',
                  subtitle: summary.activeAlerts == 0
                      ? 'No active alerts at the moment.'
                      : 'Open alerts to review unusual pours and device issues.',
                  icon: Icons.notifications_active_outlined,
                  color: summary.activeAlerts == 0
                      ? AppColors.success
                      : AppColors.error,
                  onTap: () => context.push('/alerts'),
                ),
                const SizedBox(height: 24),
                const Text('Quick actions', style: AppTextStyles.title),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _QuickAction(
                      label: 'Add product',
                      icon: Icons.inventory_2_outlined,
                      onTap: () => context.push('/inventory/add-product'),
                    ),
                    _QuickAction(
                      label: 'Register bottle',
                      icon: Icons.nfc_rounded,
                      onTap: () => context.push('/inventory/register-bottle'),
                    ),
                    _QuickAction(
                      label: 'Set up coaster',
                      icon: Icons.add_circle_outline,
                      onTap: () => context.push('/devices/setup'),
                    ),
                    _QuickAction(
                      label: 'View alerts',
                      icon: Icons.notifications_none_outlined,
                      onTap: () => context.push('/alerts'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Today\'s performance', style: AppTextStyles.title),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Revenue',
                        value: currency.format(summary.totalRevenue),
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricTile(
                        label: 'Shots',
                        value: summary.activePours.toString(),
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricTile(
                        label: 'Avg pour',
                        value:
                            '${summary.averageVolumeMl.toStringAsFixed(0)} ml',
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Recent activity', style: AppTextStyles.title),
                    TextButton(
                      onPressed: () => context.push('/pours'),
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (summary.recentPours.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No pours yet today',
                          style: AppTextStyles.caption),
                    ),
                  )
                else
                  ...summary.recentPours.take(4).map(
                        (pour) => _ActivityTile(data: pour),
                      ),
                if (summary.topProducts.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('Top products today', style: AppTextStyles.title),
                  const SizedBox(height: 12),
                  ...summary.topProducts.take(4).map(
                        (product) => _TopProductTile(product: product),
                      ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  bool _isOnline(Map<String, dynamic> device) {
    final lastSeen = device['lastSeenAt'] as String?;
    if (lastSeen == null) return false;
    final diff = DateTime.now().difference(DateTime.parse(lastSeen));
    return diff.inMinutes < 10;
  }

  bool _isLowBottle(Map<String, dynamic> bottle) {
    final weight = (bottle['currentWeightG'] as num?)?.toDouble() ?? 0;
    final full = (bottle['fullWeightG'] as num?)?.toDouble() ?? 1;
    final empty = (bottle['emptyWeightG'] as num?)?.toDouble() ?? 0;
    if (full <= empty) return false;
    return ((weight - empty) / (full - empty)) <= 0.2;
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(20),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 158,
      height: 84,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primaryDark),
              const SizedBox(height: 10),
              Text(label, style: AppTextStyles.body, maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(
      {required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = data['productName'] as String? ?? 'Unknown product';
    final volume = (data['volumeMl'] as num?)?.toDouble() ?? 0;
    final venue = data['venueName'] as String? ?? '';
    final time = data['timestamp'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.primaryLight,
            child:
                Icon(Icons.local_drink_outlined, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w700)),
                Text('$venue · ${volume.toStringAsFixed(0)} ml',
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(_relativeTime(time), style: AppTextStyles.caption),
        ],
      ),
    );
  }

  String _relativeTime(String? value) {
    if (value == null) return '—';
    final dt = DateTime.parse(value);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return DateFormat('d MMM').format(dt);
  }
}

class _TopProductTile extends StatelessWidget {
  const _TopProductTile({required this.product});

  final TopProduct product;

  @override
  Widget build(BuildContext context) {
    final revenue = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w700)),
                Text('${product.pourCount} shots today',
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(revenue.format(product.revenue), style: AppTextStyles.amount),
        ],
      ),
    );
  }
}
