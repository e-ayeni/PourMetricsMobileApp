import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/error_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);
    final isAdmin = ref.watch(authProvider).valueOrNull?.role == 'Admin';
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _Greeting(),
              const SizedBox(height: 20),

              // ── 3 compact stat tiles ──────────────────────────────────────
              _StatRow(data: data, currency: currency),
              const SizedBox(height: 24),

              // ── Admin-only analytics ─────────────────────────────────────
              if (isAdmin) ...[
                _SectionHeader(
                  title: 'Shots per Hour',
                  subtitle: 'Today',
                ),
                const SizedBox(height: 12),
                _HourlyChart(buckets: data.hourlyPours),
                const SizedBox(height: 24),

                _SectionHeader(
                  title: 'Top Products',
                  subtitle: 'Today by shots',
                ),
                const SizedBox(height: 12),
                _TopProductsList(products: data.topProducts),
                const SizedBox(height: 24),
              ],

              // ── Recent pours ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Pours', style: AppTextStyles.title),
                  TextButton(
                    onPressed: () => context.go('/pours'),
                    child: const Text('See all'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (data.recentPours.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No pours today', style: AppTextStyles.caption),
                  ),
                )
              else
                // Show at most 4 recent pours to keep it compact
                ...data.recentPours
                    .take(4)
                    .map((p) => _PourTile(pour: p)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Greeting ──────────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
}

// ── 3-tile stat row ───────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  const _StatRow({required this.data, required this.currency});

  final DashboardSummary data;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: "Revenue",
            value: currency.format(data.totalRevenue),
            icon: Icons.attach_money,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'Shots',
            value: data.activePours.toString(),
            icon: Icons.local_drink,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: 'Avg Vol',
            value: '${data.averageVolumeMl.toStringAsFixed(0)} ml',
            icon: Icons.science_outlined,
            color: AppColors.info,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title, style: AppTextStyles.title),
        const SizedBox(width: 8),
        Text(subtitle, style: AppTextStyles.caption),
      ],
    );
  }
}

// ── Hourly bar chart ──────────────────────────────────────────────────────────

class _HourlyChart extends StatelessWidget {
  const _HourlyChart({required this.buckets});

  final List<HourlyBucket> buckets;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(child: Text('No data yet', style: AppTextStyles.caption)),
      );
    }

    final maxCount = buckets.map((b) => b.count).reduce((a, b) => a > b ? a : b);

    final bars = buckets.map((b) {
      return BarChartGroupData(
        x: b.hour,
        barRods: [
          BarChartRodData(
            toY: b.count.toDouble(),
            color: AppColors.primary,
            width: 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
        child: SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              maxY: (maxCount * 1.25).ceilToDouble(),
              barGroups: bars,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                      BarTooltipItem(
                    '${rod.toY.toInt()} shots',
                    const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final h = value.toInt();
                      // Show label only every 2 hours to avoid crowding
                      if (h % 2 != 0) return const SizedBox.shrink();
                      final label = h == 0
                          ? '12a'
                          : h < 12
                              ? '${h}a'
                              : h == 12
                                  ? '12p'
                                  : '${h - 12}p';
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(label,
                            style: const TextStyle(
                                fontSize: 9, color: AppColors.textMuted)),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Top products ──────────────────────────────────────────────────────────────

class _TopProductsList extends StatelessWidget {
  const _TopProductsList({required this.products});

  final List<TopProduct> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SizedBox(
        height: 60,
        child: Center(child: Text('No data yet', style: AppTextStyles.caption)),
      );
    }

    final maxCount = products.map((p) => p.pourCount).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: products.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final p = entry.value;
            final fraction = maxCount > 0 ? p.pourCount / maxCount : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  // Rank number
                  SizedBox(
                    width: 20,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: rank == 1
                            ? AppColors.primaryDark
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Name + fill bar
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 5,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              rank == 1
                                  ? AppColors.primary
                                  : AppColors.primary.withAlpha(160),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Pour count
                  Text(
                    '${p.pourCount}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Recent pour tile ──────────────────────────────────────────────────────────

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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: const CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primaryLight,
          child: Icon(Icons.local_drink,
              color: AppColors.primaryDark, size: 18),
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
