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
    final filter = ref.watch(poursFilterProvider);
    final page = ref.watch(poursPageProvider);
    final query = PoursQuery(filter: filter, page: page);
    final poursAsync = ref.watch(poursListProvider(query));
    final hasActiveFilter =
        filter.preset != DatePreset.today || filter.oversizeOnly || filter.afterHoursOnly;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pour Events'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: hasActiveFilter,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: 'Filter',
            onPressed: () => _showFilterSheet(context, ref, filter),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(poursListProvider);
              ref.read(poursPageProvider.notifier).state = 1;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _ActiveFilterBar(filter: filter, ref: ref),
          Expanded(
            child: poursAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                message: 'Failed to load pour events',
                onRetry: () => ref.invalidate(poursListProvider),
              ),
              data: (pours) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(poursListProvider);
                  ref.read(poursPageProvider.notifier).state = 1;
                },
                child: pours.isEmpty
                    ? const Center(
                        child: Text('No events match your filters',
                            style: AppTextStyles.caption))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        itemCount: pours.length,
                        itemBuilder: (context, i) => _PourEventTile(
                            data: pours[i] as Map<String, dynamic>),
                      ),
              ),
            ),
          ),
          _Pagination(page: page, poursAsync: poursAsync),
        ],
      ),
    );
  }

  void _showFilterSheet(
      BuildContext context, WidgetRef ref, PoursFilter current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FilterSheet(current: current, ref: ref),
    );
  }
}

// ── Active filter summary bar ─────────────────────────────────────────────────

class _ActiveFilterBar extends StatelessWidget {
  const _ActiveFilterBar({required this.filter, required this.ref});

  final PoursFilter filter;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM');
    final dateLabel = switch (filter.preset) {
      DatePreset.today => 'Today',
      DatePreset.yesterday => 'Yesterday',
      DatePreset.sevenDays => 'Last 7 days',
      DatePreset.custom =>
        '${fmt.format(filter.from)} – ${fmt.format(filter.to)}',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 14, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(dateLabel, style: AppTextStyles.caption),
          if (filter.oversizeOnly) ...[
            const SizedBox(width: 8),
            _MiniChip('Oversize', AppColors.warning),
          ],
          if (filter.afterHoursOnly) ...[
            const SizedBox(width: 8),
            _MiniChip('After Hours', Colors.purple),
          ],
          const Spacer(),
          if (filter.oversizeOnly ||
              filter.afterHoursOnly ||
              filter.preset != DatePreset.today)
            GestureDetector(
              onTap: () {
                ref.read(poursFilterProvider.notifier).state =
                    PoursFilter.today();
                ref.read(poursPageProvider.notifier).state = 1;
              },
              child: const Text('Clear',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Text(label,
            style: AppTextStyles.tag.copyWith(color: color)),
      );
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.current, required this.ref});

  final PoursFilter current;
  final WidgetRef ref;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late DatePreset _preset;
  late DateTime _from;
  late DateTime _to;
  late bool _oversizeOnly;
  late bool _afterHoursOnly;

  @override
  void initState() {
    super.initState();
    _preset = widget.current.preset;
    _from = widget.current.from;
    _to = widget.current.to;
    _oversizeOnly = widget.current.oversizeOnly;
    _afterHoursOnly = widget.current.afterHoursOnly;
  }

  void _applyPreset(DatePreset preset) {
    final now = DateTime.now();
    setState(() {
      _preset = preset;
      switch (preset) {
        case DatePreset.today:
          _from = DateTime(now.year, now.month, now.day);
          _to = now;
        case DatePreset.yesterday:
          final y = now.subtract(const Duration(days: 1));
          _from = DateTime(y.year, y.month, y.day);
          _to = DateTime(y.year, y.month, y.day, 23, 59, 59);
        case DatePreset.sevenDays:
          _from = now.subtract(const Duration(days: 7));
          _to = now;
        case DatePreset.custom:
          break; // handled by date picker
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: AppColors.primaryDark),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _preset = DatePreset.custom;
        _from = picked.start;
        _to = DateTime(
            picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  void _apply() {
    widget.ref.read(poursFilterProvider.notifier).state = PoursFilter.today().copyWith(
      preset: _preset,
      from: _from,
      to: _to,
      oversizeOnly: _oversizeOnly,
      afterHoursOnly: _afterHoursOnly,
    );
    widget.ref.read(poursPageProvider.notifier).state = 1;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Date range
          const Text('Date Range', style: AppTextStyles.title),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _PresetChip(
                  label: 'Today',
                  selected: _preset == DatePreset.today,
                  onTap: () => _applyPreset(DatePreset.today)),
              _PresetChip(
                  label: 'Yesterday',
                  selected: _preset == DatePreset.yesterday,
                  onTap: () => _applyPreset(DatePreset.yesterday)),
              _PresetChip(
                  label: 'Last 7 Days',
                  selected: _preset == DatePreset.sevenDays,
                  onTap: () => _applyPreset(DatePreset.sevenDays)),
              _PresetChip(
                  label: _preset == DatePreset.custom
                      ? '${DateFormat('d MMM').format(_from)} – ${DateFormat('d MMM').format(_to)}'
                      : 'Custom…',
                  selected: _preset == DatePreset.custom,
                  onTap: _pickCustomRange),
            ],
          ),

          const SizedBox(height: 24),

          // Flag filters
          const Text('Event Type', style: AppTextStyles.title),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _oversizeOnly,
            onChanged: (v) => setState(() => _oversizeOnly = v),
            title: const Text('Oversize pours only'),
            activeColor: AppColors.warning,
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: _afterHoursOnly,
            onChanged: (v) => setState(() => _afterHoursOnly = v),
            title: const Text('After hours only'),
            activeColor: Colors.purple,
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _apply,
            child: const Text('Apply Filters'),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primaryLight,
        checkmarkColor: AppColors.primaryDark,
        labelStyle: TextStyle(
          color: selected ? AppColors.primaryDark : null,
          fontWeight: selected ? FontWeight.w600 : null,
        ),
      );
}

// ── Pour event tile ───────────────────────────────────────────────────────────

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
              child:
                  Icon(Icons.local_drink, color: AppColors.primaryDark),
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
        child: Text(label, style: AppTextStyles.tag.copyWith(color: color)),
      );
}

// ── Pagination ────────────────────────────────────────────────────────────────

class _Pagination extends ConsumerWidget {
  const _Pagination({required this.page, required this.poursAsync});

  final int page;
  final AsyncValue<List<dynamic>> poursAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMore = poursAsync.valueOrNull?.length == 20;
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
