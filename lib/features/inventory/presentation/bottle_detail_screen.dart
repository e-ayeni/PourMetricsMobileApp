import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/widgets/bottle_fill_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import 'detail_widgets.dart';

class BottleDetailScreen extends ConsumerStatefulWidget {
  const BottleDetailScreen({super.key, required this.bottleId});
  final String bottleId;

  @override
  ConsumerState<BottleDetailScreen> createState() => _BottleDetailScreenState();
}

class _BottleDetailScreenState extends ConsumerState<BottleDetailScreen> {
  bool _editing = false;
  bool _saving = false;
  Map<String, dynamic>? _data;

  late final TextEditingController _rfidCtrl;
  String? _selectedVenueId;

  @override
  void initState() {
    super.initState();
    _rfidCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _rfidCtrl.dispose();
    super.dispose();
  }

  void _populate(Map<String, dynamic> d) {
    _data = d;
    _rfidCtrl.text = d['rfidTag'] as String? ?? '';
    _selectedVenueId = d['venueId'] as String?;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.put(
        '${ApiConstants.bottles}/${widget.bottleId}',
        data: {'rfidTag': _rfidCtrl.text.trim(), 'venueId': _selectedVenueId},
      );
      if (!mounted) return;
      ref.invalidate(bottlesListProvider);
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bottle updated'),
            backgroundColor: AppColors.success),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to save'),
            backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _retire(Map<String, dynamic> d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retire Bottle'),
        content: const Text(
            'This bottle will be marked retired and removed from active service.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Retire',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(dioProvider)
          .delete('${ApiConstants.bottles}/${widget.bottleId}');
      if (!mounted) return;
      ref.invalidate(bottlesListProvider);
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to retire bottle'),
            backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authProvider).valueOrNull?.role == 'Admin';

    return FutureBuilder(
      future: ref
          .read(dioProvider)
          .get('${ApiConstants.bottles}/${widget.bottleId}'),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || snap.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Bottle')),
            body: const Center(child: Text('Failed to load bottle')),
          );
        }

        final d = snap.data!.data as Map<String, dynamic>;
        if (_data == null) _populate(d);

        final product = d['productName'] as String? ?? 'Unknown';
        final rfid = d['rfidTag'] as String? ?? '';
        final venue = d['venueName'] as String? ?? '';
        final coaster = d['coasterName'] as String?;
        final barLocation = d['barLocation'] as String?;
        final weightG = (d['currentWeightG'] as num?)?.toDouble() ?? 0;
        final fullG = (d['fullWeightG'] as num?)?.toDouble() ?? 1;
        final emptyG = (d['emptyWeightG'] as num?)?.toDouble() ?? 0;
        final isRetired = d['isRetired'] as bool? ?? false;
        final fillPct = fullG > emptyG
            ? ((weightG - emptyG) / (fullG - emptyG)).clamp(0.0, 1.0)
            : 0.0;

        return Scaffold(
          appBar: AppBar(
            title: Text(product),
            actions: [
              if (isAdmin && !isRetired)
                _editing
                    ? TextButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryDark))
                            : const Text('Save',
                                style: TextStyle(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w700)),
                      )
                    : IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => setState(() => _editing = true),
                      ),
              if (_editing)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _editing = false;
                    _populate(d);
                  }),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Column(
                  children: [
                    BottleFillWidget(
                        width: 70,
                        height: 150,
                        fillPercent: fillPct,
                        isRetired: isRetired),
                    const SizedBox(height: 10),
                    Text(product,
                        style: AppTextStyles.heading,
                        textAlign: TextAlign.center),
                    if (isRetired)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.error.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('RETIRED',
                            style: AppTextStyles.tag
                                .copyWith(color: AppColors.error)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              InfoSection(title: 'Bottle Details', rows: [
                if (_editing) ...[
                  EditRow(
                    label: 'RFID Tag',
                    child: TextFormField(
                      controller: _rfidCtrl,
                      decoration:
                          const InputDecoration(prefixIcon: Icon(Icons.nfc)),
                    ),
                  ),
                ] else ...[
                  InfoRow(label: 'RFID Tag', value: rfid, mono: true),
                ],
                InfoRow(label: 'Product', value: product),
                InfoRow(
                  label: 'Fill Level',
                  value:
                      '${(fillPct * 100).toStringAsFixed(0)}%  (${weightG.toStringAsFixed(0)} g)',
                ),
              ]),

              const SizedBox(height: 16),
              InfoSection(title: 'Location', rows: [
                if (_editing) ...[
                  EditRow(
                    label: 'Venue',
                    child: _VenueDropdown(
                      currentId: _selectedVenueId,
                      onChanged: (v) =>
                          setState(() => _selectedVenueId = v),
                    ),
                  ),
                ] else ...[
                  InfoRow(label: 'Venue', value: venue),
                ],
                InfoRow(
                  label: 'Smart Coaster',
                  value: coaster != null
                      ? '$coaster${barLocation != null ? ' · $barLocation' : ''}'
                      : 'Not on a coaster',
                  valueColor:
                      coaster != null ? AppColors.success : AppColors.textMuted,
                ),
              ]),

              const SizedBox(height: 16),
              InfoSection(title: 'Weights', rows: [
                InfoRow(
                    label: 'Current',
                    value: '${weightG.toStringAsFixed(0)} g'),
                InfoRow(
                    label: 'Full', value: '${fullG.toStringAsFixed(0)} g'),
                InfoRow(
                    label: 'Empty', value: '${emptyG.toStringAsFixed(0)} g'),
              ]),

              if (isAdmin && !isRetired) ...[
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.archive_outlined,
                      color: AppColors.error),
                  label: const Text('Retire Bottle',
                      style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  onPressed: () => _retire(d),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _VenueDropdown extends ConsumerWidget {
  const _VenueDropdown({required this.currentId, required this.onChanged});
  final String? currentId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(venuesListProvider);
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) =>
          const Text('Failed to load venues', style: AppTextStyles.caption),
      data: (venues) => DropdownButtonFormField<String>(
        initialValue: currentId,
        decoration: const InputDecoration(),
        items: venues
            .map((v) => DropdownMenuItem<String>(
                  value: v['id'] as String,
                  child: Text(v['name'] as String? ?? ''),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
