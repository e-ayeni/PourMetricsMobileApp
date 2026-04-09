import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/error_view.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          // Alerts bell — badge shows unacknowledged count
          async.maybeWhen(
            data: (data) => data.activeAlerts > 0
                ? Badge(
                    label: Text(data.activeAlerts.toString()),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_active),
                      color: AppColors.error,
                      onPressed: () => context.push('/alerts'),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => context.push('/alerts'),
                  ),
            orElse: () => IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.push('/alerts'),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dashboardProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: 'Failed to load dashboard',
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _greeting(context),
              const SizedBox(height: 20),
              _statsGrid(context, data, currency),
              const SizedBox(height: 24),
              const Text('Recent Pours', style: AppTextStyles.title),
              const SizedBox(height: 12),
              if (data.recentPours.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No pours today', style: AppTextStyles.caption),
                  ),
                )
              else
                ...data.recentPours.map((p) => _PourTile(pour: p)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _greeting(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return Text(
      greeting,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
    );
  }

  Widget _statsGrid(
      BuildContext context, DashboardSummary data, NumberFormat currency) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _StatCard(
          label: "Today's Revenue",
          value: currency.format(data.totalRevenue),
          icon: Icons.attach_money,
          color: AppColors.success,
        ),
        _StatCard(
          label: 'Pours Today',
          value: data.activePours.toString(),
          icon: Icons.local_drink,
          color: AppColors.primaryDark,
        ),
        _StatCard(
          label: 'Active Alerts',
          value: data.activeAlerts.toString(),
          icon: Icons.notifications_active,
          color:
              data.activeAlerts > 0 ? AppColors.error : AppColors.textMuted,
        ),
        _StatCard(
          label: 'Devices Online',
          value: data.onlineDevices.toString(),
          icon: Icons.sensors,
          color: AppColors.info,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                        )),
                Text(label, style: AppTextStyles.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PourTile extends StatelessWidget {
  const _PourTile({required this.pour});

  final Map<String, dynamic> pour;

  @override
  Widget build(BuildContext context) {
    final productName = pour['productName'] as String? ?? 'Unknown';
    final volumeMl = (pour['volumeMl'] as num?)?.toDouble() ?? 0.0;
    final revenue = (pour['estimatedRevenue'] as num?)?.toDouble() ?? 0.0;
    final timestamp = pour['timestamp'] as String?;
    final time = timestamp != null
        ? DateFormat.Hm().format(DateTime.parse(timestamp).toLocal())
        : '--:--';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          child: Icon(Icons.local_drink, color: AppColors.primaryDark),
        ),
        title: Text(productName, style: AppTextStyles.body),
        subtitle: Text('${volumeMl.toStringAsFixed(0)} ml · $time',
            style: AppTextStyles.caption),
        trailing: Text('\$${revenue.toStringAsFixed(2)}',
            style: AppTextStyles.amount),
      ),
    );
  }
}
