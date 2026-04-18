import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/queue_status_notifier.dart';
import '../providers/inventory_provider.dart';

class RegisterBottleScreen extends ConsumerStatefulWidget {
  const RegisterBottleScreen({
    super.key,
    this.prefillProductId,
    this.prefillProductName,
    this.prefillRfidTag,
    this.prefillVenueId,
    this.prefillVenueName,
    this.prefillDeviceId,
    this.prefillDeviceName,
  });

  final String? prefillProductId;
  final String? prefillProductName;
  final String? prefillRfidTag;
  final String? prefillVenueId;
  final String? prefillVenueName;
  final String? prefillDeviceId;
  final String? prefillDeviceName;

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
  String? _selectedVenueName;

  @override
  void initState() {
    super.initState();
    _rfidCtrl = TextEditingController(text: widget.prefillRfidTag ?? '');
    _selectedProductId = widget.prefillProductId;
    _selectedProductName = widget.prefillProductName;
    _selectedVenueId = widget.prefillVenueId;
    _selectedVenueName = widget.prefillVenueName;
  }

  @override
  void dispose() {
    _rfidCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductId == null) {
      _showSnack('Please choose a product.', AppColors.error);
      return;
    }
    if (_selectedVenueId == null) {
      _showSnack('Please choose a venue.', AppColors.error);
      return;
    }

    setState(() => _submitting = true);
    try {
      final payload = {
        'productId': _selectedProductId,
        'venueId': _selectedVenueId,
        'rfidTag': _rfidCtrl.text.trim(),
      };
      await ref.read(bottlesListProvider.notifier).addBottle(payload);
      if (!mounted) return;
      final pendingCount = ref.read(queueStatusProvider).valueOrNull ?? 0;
      final isQueued = pendingCount > 0;
      _showSnack(
        isQueued
            ? 'Saved locally and will sync when you are back online.'
            : 'Bottle registered successfully.',
        isQueued ? AppColors.warning : AppColors.success,
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString(), AppColors.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
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
                Text('Register a bottle', style: AppTextStyles.heading),
                const SizedBox(height: 8),
                const Text(
                  'Confirm the product, tag, and location. When you launch this from a coaster or new product, most of the details are already filled in.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 20),
                if (widget.prefillDeviceName != null)
                  _ContextCard(
                    icon: Icons.sensors,
                    title: 'Working from coaster',
                    subtitle: widget.prefillDeviceName!,
                  ),
                if (widget.prefillDeviceName != null)
                  const SizedBox(height: 12),
                if (_selectedVenueName != null)
                  _ContextCard(
                    icon: Icons.place_outlined,
                    title: 'Suggested venue',
                    subtitle: _selectedVenueName!,
                  ),
                if (_selectedVenueName != null) const SizedBox(height: 20),
                const Text('Bottle', style: AppTextStyles.label),
                const SizedBox(height: 8),
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
                    error: (_, __) => const Text(
                      'Failed to load products',
                      style: AppTextStyles.caption,
                    ),
                    data: (products) => DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        hintText: 'Select a product',
                      ),
                      items: products
                          .map(
                            (product) => DropdownMenuItem<String>(
                              value: product['id'] as String,
                              child: Text(product['name'] as String? ?? ''),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        final product = products.firstWhere(
                          (item) => item['id'] == value,
                          orElse: () => {},
                        );
                        setState(() {
                          _selectedProductId = value;
                          _selectedProductName = product['name'] as String?;
                        });
                      },
                    ),
                  ),
                const SizedBox(height: 20),
                const Text('Tag', style: AppTextStyles.label),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _rfidCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. RF1042',
                    prefixIcon: Icon(Icons.nfc),
                  ),
                  validator: (value) =>
                      (value == null || value.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                const Text('Location', style: AppTextStyles.label),
                const SizedBox(height: 8),
                venuesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text(
                    'Failed to load venues',
                    style: AppTextStyles.caption,
                  ),
                  data: (venues) => DropdownButtonFormField<String>(
                    initialValue: _selectedVenueId,
                    decoration: const InputDecoration(
                      hintText: 'Select a venue',
                    ),
                    items: venues
                        .map(
                          (venue) => DropdownMenuItem<String>(
                            value: venue['id'] as String,
                            child: Text(venue['name'] as String? ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      final venue = venues.firstWhere(
                        (item) => item['id'] == value,
                        orElse: () => {},
                      );
                      setState(() {
                        _selectedVenueId = value;
                        _selectedVenueName = venue['name'] as String?;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),
                _ReviewCard(
                  product: _selectedProductName,
                  tag: _rfidCtrl.text.trim().isEmpty
                      ? null
                      : _rfidCtrl.text.trim(),
                  venue: _selectedVenueName,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : () => context.pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Register bottle'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w700)),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard(
      {required this.product, required this.tag, required this.venue});

  final String? product;
  final String? tag;
  final String? venue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ready to register', style: AppTextStyles.title),
          const SizedBox(height: 10),
          Text('Product: ${product ?? 'Choose a product'}',
              style: AppTextStyles.caption),
          Text('Tag: ${tag ?? 'Add the RFID tag'}',
              style: AppTextStyles.caption),
          Text('Venue: ${venue ?? 'Choose a venue'}',
              style: AppTextStyles.caption),
        ],
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
          const Icon(Icons.inventory_2, color: AppColors.primaryDark, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child:
                const Icon(Icons.close, color: AppColors.primaryDark, size: 18),
          ),
        ],
      ),
    );
  }
}
