import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/error_view.dart';
import '../providers/pours_provider.dart';

class PoursScreen extends ConsumerWidget {
  const PoursScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(poursPageProvider);
    final poursAsync = ref.watch(poursListProvider(page));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pour Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(poursListProvider),
          ),
        ],
      ),
      body: poursAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: 'Failed to load pours',
          onRetry: () => ref.invalidate(poursListProvider),
        ),
        data: (pours) => Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(poursListProvider),
                child: pours.isEmpty
                    ? const Center(
                        child: Text('No pours found',
                            style: AppTextStyles.caption))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: pours.length,
                        itemBuilder: (context, i) => _PourEventTile(
                            data: pours[i] as Map<String, dynamic>),
                      ),
              ),
            ),
            _Pagination(page: page, hasMore: pours.length == 20),
          ],
        ),
      ),
    );
  }
}

class _PourEventTile extends StatelessWidget {
  const _PourEventTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final product = data['productName'] as String? ?? 'Unknown';
    final venue = data['venueName'] as String? ?? '';
    final volume = (data['volumeMl'] as num?)?.toDouble() ?? 0.0;
    final revenue = (data['estimatedRevenue'] as num?)?.toDouble() ?? 0.0;
    final isOversize = data['isOversize'] as bool? ?? false;
    final isAfterHours = data['isAfterHours'] as bool? ?? false;
    final ts = data['timestamp'] as String?;
    final time = ts != null
        ? DateFormat('d MMM · HH:mm').format(DateTime.parse(ts).toLocal())
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.local_drink, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product, style: AppTextStyles.title),
                  const SizedBox(height: 2),
                  Text(venue.isNotEmpty ? '$venue · $time' : time,
                      style: AppTextStyles.caption),
                  if (isOversize || isAfterHours) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (isOversize)
                          _Tag('OVERSIZE', AppColors.warning),
                        if (isAfterHours)
                          _Tag('AFTER HOURS', Colors.purple),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${volume.toStringAsFixed(0)} ml',
                    style: AppTextStyles.caption),
                Text('\$${revenue.toStringAsFixed(2)}',
                    style: AppTextStyles.amount),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Text(label,
            style: AppTextStyles.tag.copyWith(color: color)),
      );
}

class _Pagination extends ConsumerWidget {
  const _Pagination({required this.page, required this.hasMore});

  final int page;
  final bool hasMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: page > 1
                ? () => ref.read(poursPageProvider.notifier).state = page - 1
                : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Prev'),
          ),
          Text('Page $page', style: AppTextStyles.caption),
          TextButton.icon(
            onPressed: hasMore
                ? () => ref.read(poursPageProvider.notifier).state = page + 1
                : null,
            icon: const Icon(Icons.chevron_right),
            label: const Text('Next'),
          ),
        ],
      ),
    );
  }
}
