import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/queue_status_notifier.dart';
import '../providers/inventory_provider.dart';

/// Register a physical bottle: link an RFID tag to a product and venue.
/// [prefillProductId] and [prefillRfidTag] can come from the device RFID
/// placement event (firmware reports an unknown tag → app registers it).
class RegisterBottleScreen extends ConsumerStatefulWidget {
  const RegisterBottleScreen({
    super.key,
    this.prefillProductId,
    this.prefillProductName,
    this.prefillRfidTag,
  });

  final String? prefillProductId;
  final String? prefillProductName;
  final String? prefillRfidTag;

  @override
  ConsumerState<RegisterBottleScreen> createState() =>
      _RegisterBottleScreenState();
}

class _RegisterBottleScreenState extends ConsumerState<RegisterBottleScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  late final TextEditingController _rfidCtrl;
  String? _selectedProductId;
  String? _selectedProductName;
  String? _selectedVenueId;

  @override
  void initState() {
    super.initState();
    _rfidCtrl =
        TextEditingController(text: widget.prefillRfidTag ?? '');
    _selectedProductId = widget.prefillProductId;
    _selectedProductName = widget.prefillProductName;
  }

  @override
  void dispose() {
    _rfidCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product')),
      );
      return;
    }
    if (_selectedVenueId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a venue')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final payload = {
        'productId': _selectedProductId,
        'venueId': _selectedVenueId,
        'rfidTag': _rfidCtrl.text.trim(),
      };
      // Use the notifier so the optimistic update + offline queue are applied.
      await ref.read(bottlesListProvider.notifier).addBottle(payload);
      if (!mounted) return;
      final pendingCount =
          ref.read(queueStatusProvider).valueOrNull ?? 0;
      final isQueued = pendingCount > 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isQueued
              ? 'Saved locally — will sync when online'
              : 'Bottle registered successfully'),
          backgroundColor:
              isQueued ? AppColors.warning : AppColors.success,
        ),
      );
      context.pop();
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsListProvider);
    final venuesAsync = ref.watch(venuesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Register Bottle')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── RFID tag ──────────────────────────────────────────────
                const Text('RFID Tag', style: AppTextStyles.label),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _rfidCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. RF1042',
                    prefixIcon: Icon(Icons.nfc),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),

                // ── Product selector ──────────────────────────────────────
                const Text('Product', style: AppTextStyles.label),
                const SizedBox(height: 6),
                if (_selectedProductId != null)
                  _SelectedChip(
                    label: _selectedProductName ?? _selectedProductId!,
                    onClear: () => setState(() {
                      _selectedProductId = null;
                      _selectedProductName = null;
                    }),
                  )
                else
                  productsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) =>
                        const Text('Failed to load products',
                            style: AppTextStyles.caption),
                    data: (products) => DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                          hintText: 'Select a product'),
                      items: products
                          .map((p) => DropdownMenuItem<String>(
                                value: p['id'] as String,
                                child: Text(p['name'] as String? ?? ''),
                              ))
                          .toList(),
                      onChanged: (v) {
                        final p = products.firstWhere(
                            (x) => x['id'] == v,
                            orElse: () => {});
                        setState(() {
                          _selectedProductId = v;
                          _selectedProductName = p['name'] as String?;
                        });
                      },
                      validator: (v) =>
                          v == null ? 'Select a product' : null,
                    ),
                  ),
                const SizedBox(height: 20),

                // ── Venue selector ────────────────────────────────────────
                const Text('Venue', style: AppTextStyles.label),
                const SizedBox(height: 6),
                venuesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Failed to load venues',
                      style: AppTextStyles.caption),
                  data: (venues) => DropdownButtonFormField<String>(
                    decoration:
                        const InputDecoration(hintText: 'Select a venue'),
                    items: venues
                        .map((v) => DropdownMenuItem<String>(
                              value: v['id'] as String,
                              child: Text(v['name'] as String? ?? ''),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedVenueId = v),
                    validator: (v) =>
                        v == null ? 'Select a venue' : null,
                  ),
                ),

                const SizedBox(height: 32),

                // ── Info callout ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primary.withAlpha(80)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AppColors.primaryDark, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'The RFID tag is read from the bottle cap. '
                          'Place the bottle on a Smart Coaster to obtain the tag.',
                          style: AppTextStyles.caption,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Register Bottle'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2,
              color: AppColors.primaryDark, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark)),
          ),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close,
                color: AppColors.primaryDark, size: 18),
          ),
        ],
      ),
    );
  }
}
