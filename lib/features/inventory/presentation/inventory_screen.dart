import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/bottle_fill_widget.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/services/queue_status_notifier.dart';
import '../providers/inventory_provider.dart';

enum _BottleFilter { all, low, unassigned, recent }

enum _ProductFilter { all, ready, needsSetup }

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  _BottleFilter _bottleFilter = _BottleFilter.all;
  _ProductFilter _productFilter = _ProductFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onFabTapped() {
    if (_tabController.index == 0) {
      context.push('/inventory/register-bottle');
    } else {
      context.push('/inventory/add-product');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBottlesTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: const [_QueueBadge()],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Bottles'), Tab(text: 'Products')],
          labelColor: AppColors.primaryDark,
          indicatorColor: AppColors.primaryDark,
          unselectedLabelColor: AppColors.textMuted,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BottlesTab(
            filter: _bottleFilter,
            onFilterChanged: (filter) => setState(() => _bottleFilter = filter),
          ),
          _ProductsTab(
            filter: _productFilter,
            onFilterChanged: (filter) =>
                setState(() => _productFilter = filter),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: Icon(
          isBottlesTab ? Icons.nfc_rounded : Icons.inventory_2_outlined,
        ),
        label: Text(isBottlesTab ? 'Register Bottle' : 'Add Product'),
        onPressed: _onFabTapped,
      ),
    );
  }
}

class _BottlesTab extends ConsumerWidget {
  const _BottlesTab({required this.filter, required this.onFilterChanged});

  final _BottleFilter filter;
  final ValueChanged<_BottleFilter> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bottlesListProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: 'Failed to load bottles',
        onRetry: () => ref.read(bottlesListProvider.notifier).refresh(),
      ),
      data: (bottles) {
        final filtered = _filterBottles(bottles.cast<Map<String, dynamic>>());
        return Column(
          children: [
            _FilterBar<_BottleFilter>(
              value: filter,
              options: const [
                (_BottleFilter.all, 'All'),
                (_BottleFilter.low, 'Low'),
                (_BottleFilter.unassigned, 'Not on coaster'),
                (_BottleFilter.recent, 'Recent'),
              ],
              onChanged: onFilterChanged,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(bottlesListProvider.notifier).refresh(),
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('No bottles match this view',
                            style: AppTextStyles.caption),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _BottleTile(data: filtered[i]),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _filterBottles(
      List<Map<String, dynamic>> bottles) {
    switch (filter) {
      case _BottleFilter.low:
        return bottles.where((b) {
          final weight = (b['currentWeightG'] as num?)?.toDouble() ?? 0;
          final full = (b['fullWeightG'] as num?)?.toDouble() ?? 1;
          final empty = (b['emptyWeightG'] as num?)?.toDouble() ?? 0;
          final pct = full > empty ? (weight - empty) / (full - empty) : 0;
          return pct <= 0.2;
        }).toList();
      case _BottleFilter.unassigned:
        return bottles.where((b) => b['coasterName'] == null).toList();
      case _BottleFilter.recent:
        return bottles.reversed.take(6).toList();
      case _BottleFilter.all:
        return bottles;
    }
  }
}

class _BottleTile extends StatelessWidget {
  const _BottleTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final id = data['id'] as String? ?? '';
    final product = data['productName'] as String? ?? 'Unknown';
    final rfid = data['rfidTag'] as String? ?? '';
    final venue = data['venueName'] as String? ?? '';
    final coaster = data['coasterName'] as String?;
    final barLocation = data['barLocation'] as String?;
    final weightG = (data['currentWeightG'] as num?)?.toDouble() ?? 0;
    final fullG = (data['fullWeightG'] as num?)?.toDouble() ?? 1;
    final emptyG = (data['emptyWeightG'] as num?)?.toDouble() ?? 0;
    final isRetired = data['isRetired'] as bool? ?? false;

    final fillPct = fullG > emptyG
        ? ((weightG - emptyG) / (fullG - emptyG)).clamp(0.0, 1.0)
        : 0.0;
    final isLow = fillPct <= 0.2;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/inventory/bottle/$id'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BottleFillWidget(
                width: 32,
                height: 72,
                fillPercent: fillPct,
                isRetired: isRetired,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(product, style: AppTextStyles.title)),
                        if (isRetired)
                          const _StatusChip(
                            label: 'Retired',
                            color: AppColors.error,
                          )
                        else if (isLow)
                          const _StatusChip(
                            label: 'Low',
                            color: AppColors.warning,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('RFID: $rfid', style: AppTextStyles.caption),
                    Text(venue, style: AppTextStyles.caption),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          coaster != null ? Icons.sensors : Icons.sensors_off,
                          size: 13,
                          color: coaster != null
                              ? AppColors.success
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            coaster != null
                                ? '$coaster${barLocation != null ? ' · $barLocation' : ''}'
                                : 'Not on a coaster',
                            style: AppTextStyles.caption.copyWith(
                              color: coaster != null
                                  ? AppColors.success
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductsTab extends ConsumerWidget {
  const _ProductsTab({required this.filter, required this.onFilterChanged});

  final _ProductFilter filter;
  final ValueChanged<_ProductFilter> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productsListProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: 'Failed to load products',
        onRetry: () => ref.read(productsListProvider.notifier).refresh(),
      ),
      data: (products) {
        final filtered = _filterProducts(products.cast<Map<String, dynamic>>());
        return Column(
          children: [
            _FilterBar<_ProductFilter>(
              value: filter,
              options: const [
                (_ProductFilter.all, 'All'),
                (_ProductFilter.ready, 'Ready'),
                (_ProductFilter.needsSetup, 'Needs setup'),
              ],
              onChanged: onFilterChanged,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(productsListProvider.notifier).refresh(),
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'No products in this view',
                              style: AppTextStyles.caption,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.inventory_2_outlined),
                              label: const Text('Add Product'),
                              onPressed: () =>
                                  context.push('/inventory/add-product'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _ProductTile(data: filtered[i]),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _filterProducts(
      List<Map<String, dynamic>> products) {
    switch (filter) {
      case _ProductFilter.ready:
        return products.where(_isReady).toList();
      case _ProductFilter.needsSetup:
        return products.where((p) => !_isReady(p)).toList();
      case _ProductFilter.all:
        return products;
    }
  }

  bool _isReady(Map<String, dynamic> product) {
    final empty = (product['emptyWeightG'] as num?)?.toDouble() ?? 0;
    final full = (product['fullWeightG'] as num?)?.toDouble() ?? 0;
    final bottleVolume = (product['bottleVolumeMl'] as num?)?.toDouble() ?? 0;
    return empty > 0 && full > empty && bottleVolume > 0;
  }
}

class _QueueBadge extends ConsumerWidget {
  const _QueueBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(queueStatusProvider).valueOrNull ?? 0;
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Tooltip(
        message: '$count change${count == 1 ? '' : 's'} pending sync',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_upload_outlined,
                color: AppColors.warning, size: 18),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: const TextStyle(
                  color: AppColors.warning, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final id = data['id'] as String? ?? '';
    final name = data['name'] as String? ?? 'Unknown';
    final category = data['category'] as String? ?? '';
    final barcode = data['barcode'] as String?;
    final bottleVolume = (data['bottleVolumeMl'] as num?)?.toDouble() ?? 0;
    final standardPourMl = (data['standardPourMl'] as num?)?.toDouble() ?? 0;
    final price = (data['sellingPricePerShot'] as num?)?.toDouble() ?? 0;
    final ready = (data['emptyWeightG'] as num?) != null &&
        (data['fullWeightG'] as num?) != null &&
        ((data['fullWeightG'] as num?)?.toDouble() ?? 0) >
            ((data['emptyWeightG'] as num?)?.toDouble() ?? 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/inventory/product/$id'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(name, style: AppTextStyles.body)),
                        _StatusChip(
                          label: ready ? 'Ready' : 'Needs setup',
                          color: ready ? AppColors.success : AppColors.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$category · ${bottleVolume.toStringAsFixed(0)} ml bottle',
                      style: AppTextStyles.caption,
                    ),
                    Text(
                      '${standardPourMl.toStringAsFixed(0)} ml shot',
                      style: AppTextStyles.caption,
                    ),
                    if (barcode != null)
                      Text('Barcode: $barcode', style: AppTextStyles.caption),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${price.toStringAsFixed(2)}',
                      style: AppTextStyles.amount),
                  const Text('/ shot', style: AppTextStyles.caption),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBar<T> extends StatelessWidget {
  const _FilterBar({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: options.map((option) {
          final selected = option.$1 == value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(option.$2),
              selected: selected,
              onSelected: (_) => onChanged(option.$1),
              selectedColor: AppColors.primaryLight,
              labelStyle: TextStyle(
                color: selected ? AppColors.primaryDark : AppColors.textMuted,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.tag.copyWith(color: color),
      ),
    );
  }
}
