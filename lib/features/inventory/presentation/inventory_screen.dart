import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/bottle_fill_widget.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/services/queue_status_notifier.dart';
import '../providers/inventory_provider.dart';
import 'barcode_scanner_screen.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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

  Future<void> _onFabTapped() async {
    if (_tabController.index == 0) {
      context.push('/inventory/register-bottle');
    } else {
      final barcode = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
      );
      if (!mounted) return;
      context.push(
        barcode != null && barcode.isNotEmpty
            ? '/inventory/add-product?barcode=${Uri.encodeComponent(barcode)}'
            : '/inventory/add-product',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBottlesTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [_QueueBadge()],
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
        children: const [_BottlesTab(), _ProductsTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: Icon(isBottlesTab ? Icons.nfc : Icons.inventory_2_outlined),
        label: Text(isBottlesTab ? 'Register Bottle' : 'Add Product'),
        onPressed: _onFabTapped,
      ),
    );
  }
}

// ── Bottles tab ───────────────────────────────────────────────────────────────

class _BottlesTab extends ConsumerWidget {
  const _BottlesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bottlesListProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: 'Failed to load bottles',
        onRetry: () => ref.read(bottlesListProvider.notifier).refresh(),
      ),
      data: (bottles) => RefreshIndicator(
        onRefresh: () => ref.read(bottlesListProvider.notifier).refresh(),
        child: bottles.isEmpty
            ? const Center(
                child: Text('No bottles', style: AppTextStyles.caption))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                itemCount: bottles.length,
                itemBuilder: (_, i) =>
                    _BottleTile(data: bottles[i] as Map<String, dynamic>),
              ),
      ),
    );
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
              // Bottle visualisation
              BottleFillWidget(
                  width: 32,
                  height: 72,
                  fillPercent: fillPct,
                  isRetired: isRetired),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(product, style: AppTextStyles.title)),
                        if (isRetired)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('RETIRED',
                                style: AppTextStyles.tag
                                    .copyWith(color: AppColors.error)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('RFID: $rfid · $venue', style: AppTextStyles.caption),
                    const SizedBox(height: 3),
                    // Coaster info — key addition
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
                        Text(
                          coaster != null
                              ? '$coaster${barLocation != null ? ' · $barLocation' : ''}'
                              : 'Not on a coaster',
                          style: AppTextStyles.caption.copyWith(
                            color: coaster != null
                                ? AppColors.success
                                : AppColors.textMuted,
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

// ── Products tab ──────────────────────────────────────────────────────────────

class _ProductsTab extends ConsumerWidget {
  const _ProductsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productsListProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: 'Failed to load products',
        onRetry: () => ref.read(productsListProvider.notifier).refresh(),
      ),
      data: (products) => RefreshIndicator(
        onRefresh: () => ref.read(productsListProvider.notifier).refresh(),
        child: products.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No products yet', style: AppTextStyles.caption),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Add Product'),
                      onPressed: () => context.push('/inventory/add-product'),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                itemCount: products.length,
                itemBuilder: (_, i) =>
                    _ProductTile(data: products[i] as Map<String, dynamic>),
              ),
      ),
    );
  }
}

// ── Offline queue badge ───────────────────────────────────────────────────────

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

// ────────────────────────────────────────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final id = data['id'] as String? ?? '';
    final name = data['name'] as String? ?? 'Unknown';
    final category = data['category'] as String? ?? '';
    final barcode = data['barcode'] as String?;
    final standardPourMl = (data['standardPourMl'] as num?)?.toDouble() ?? 0;
    final price = (data['sellingPricePerShot'] as num?)?.toDouble() ?? 0;

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
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.body),
                    Text(
                      '$category · ${standardPourMl.toStringAsFixed(0)} ml pour',
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
