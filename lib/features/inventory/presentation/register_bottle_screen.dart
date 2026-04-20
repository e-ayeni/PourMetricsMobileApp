import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/queue_status_notifier.dart';
import '../../devices/providers/devices_provider.dart';
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
  bool _showManualTagEntry = false;

  late final TextEditingController _rfidCtrl;
  String? _selectedProductId;
  String? _selectedProductName;
  String? _selectedVenueId;
  String? _selectedVenueName;
  String? _selectedDeviceName;

  bool get _tagCaptured => _rfidCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _rfidCtrl = TextEditingController(text: widget.prefillRfidTag ?? '');
    _selectedProductId = widget.prefillProductId;
    _selectedProductName = widget.prefillProductName;
    _selectedVenueId = widget.prefillVenueId;
    _selectedVenueName = widget.prefillVenueName;
    _selectedDeviceName = widget.prefillDeviceName;
    _showManualTagEntry = widget.prefillRfidTag != null;
    _rfidCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _rfidCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_tagCaptured) {
      _showSnack('Capture or enter the RFID tag first.', AppColors.error);
      return;
    }
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
    final devicesAsync = ref.watch(devicesListProvider);

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
                  'Start by capturing the bottle tag. Once the RFID is known, the rest of the registration details open up.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 20),
                _StepCard(
                  step: 'Step 1',
                  title: 'Capture the bottle tag',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedDeviceName != null)
                        _ContextCard(
                          icon: Icons.sensors,
                          title: 'Using coaster',
                          subtitle: _selectedDeviceName!,
                        )
                      else
                        devicesAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const Text(
                            'Failed to load coasters',
                            style: AppTextStyles.caption,
                          ),
                          data: (devices) => DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Coaster (optional)',
                              hintText:
                                  'Choose the coaster reading this bottle',
                            ),
                            items: devices
                                .map(
                                  (device) => DropdownMenuItem<String>(
                                    value: device['id'] as String,
                                    child: Text(
                                      '${device['coasterName'] ?? device['barLocation'] ?? 'Device'}${device['venueName'] != null ? ' · ${device['venueName']}' : ''}',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              final match = devices
                                  .cast<Map<String, dynamic>>()
                                  .firstWhere(
                                    (device) => device['id'] == value,
                                    orElse: () => <String, dynamic>{},
                                  );
                              setState(() {
                                _selectedDeviceName =
                                    match['coasterName'] as String?;
                                _selectedVenueId =
                                    match['venueId']?.toString() ??
                                        _selectedVenueId;
                                _selectedVenueName =
                                    match['venueName'] as String? ??
                                        _selectedVenueName;
                              });
                            },
                          ),
                        ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _tagCaptured ? Icons.check_circle : Icons.nfc,
                                  color: _tagCaptured
                                      ? AppColors.success
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _tagCaptured
                                        ? 'RFID tag detected'
                                        : 'Place the bottle with its RFID tag on the coaster to continue.',
                                    style: AppTextStyles.label,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _tagCaptured
                                  ? _rfidCtrl.text.trim()
                                  : 'When the tag is known, the product and venue details below become available.',
                              style: _tagCaptured
                                  ? AppTextStyles.mono
                                  : AppTextStyles.caption,
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () => setState(() {
                                _showManualTagEntry = !_showManualTagEntry;
                              }),
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(_showManualTagEntry
                                  ? 'Hide manual entry'
                                  : 'Enter tag manually instead'),
                            ),
                            if (_showManualTagEntry) ...[
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _rfidCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. RF1042',
                                  prefixIcon: Icon(Icons.nfc),
                                  labelText: 'RFID tag',
                                ),
                                validator: (value) =>
                                    (value == null || value.isEmpty)
                                        ? 'Required'
                                        : null,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: !_tagCaptured
                      ? _WaitingCard(
                          key: const ValueKey('waiting'),
                          venueName: _selectedVenueName,
                          deviceName: _selectedDeviceName,
                        )
                      : _StepCard(
                          key: const ValueKey('details'),
                          step: 'Step 2',
                          title: 'Confirm bottle details',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_selectedVenueName != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _ContextCard(
                                    icon: Icons.place_outlined,
                                    title: 'Venue',
                                    subtitle: _selectedVenueName!,
                                  ),
                                ),
                              const Text('Bottle', style: AppTextStyles.label),
                              const SizedBox(height: 8),
                              if (_selectedProductId != null)
                                _SelectedChip(
                                  label: _selectedProductName ??
                                      _selectedProductId!,
                                  onClear: () => setState(() {
                                    _selectedProductId = null;
                                    _selectedProductName = null;
                                  }),
                                )
                              else
                                productsAsync.when(
                                  loading: () =>
                                      const LinearProgressIndicator(),
                                  error: (_, __) => const Text(
                                    'Failed to load products',
                                    style: AppTextStyles.caption,
                                  ),
                                  data: (products) =>
                                      DropdownButtonFormField<String>(
                                    decoration: const InputDecoration(
                                      hintText: 'Select a product',
                                    ),
                                    items: products
                                        .map(
                                          (product) => DropdownMenuItem<String>(
                                            value: product['id'] as String,
                                            child: Text(
                                                product['name'] as String? ??
                                                    ''),
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
                                        _selectedProductName =
                                            product['name'] as String?;
                                      });
                                    },
                                  ),
                                ),
                              const SizedBox(height: 20),
                              const Text('Location',
                                  style: AppTextStyles.label),
                              const SizedBox(height: 8),
                              venuesAsync.when(
                                loading: () => const LinearProgressIndicator(),
                                error: (_, __) => const Text(
                                  'Failed to load venues',
                                  style: AppTextStyles.caption,
                                ),
                                data: (venues) =>
                                    DropdownButtonFormField<String>(
                                  initialValue: _selectedVenueId,
                                  decoration: const InputDecoration(
                                    hintText: 'Select a venue',
                                  ),
                                  items: venues
                                      .map(
                                        (venue) => DropdownMenuItem<String>(
                                          value: venue['id'] as String,
                                          child: Text(
                                              venue['name'] as String? ?? ''),
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
                                      _selectedVenueName =
                                          venue['name'] as String?;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                              _ReviewCard(
                                product: _selectedProductName,
                                tag: _rfidCtrl.text.trim(),
                                venue: _selectedVenueName,
                              ),
                            ],
                          ),
                        ),
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
                        onPressed:
                            _submitting || !_tagCaptured ? null : _submit,
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

class _StepCard extends StatelessWidget {
  const _StepCard({
    super.key,
    required this.step,
    required this.title,
    required this.child,
  });

  final String step;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step.toUpperCase(), style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Text(title, style: AppTextStyles.title),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({
    super.key,
    this.venueName,
    this.deviceName,
  });

  final String? venueName;
  final String? deviceName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Waiting for bottle tag', style: AppTextStyles.title),
          const SizedBox(height: 8),
          Text(
            deviceName != null
                ? 'Place the bottle on $deviceName. If the tag has already been read elsewhere, you can enter it manually above.'
                : 'Choose the coaster you are working with, or enter the tag manually if you already know it.',
            style: AppTextStyles.caption,
          ),
          if (venueName != null) ...[
            const SizedBox(height: 12),
            Text('Suggested venue: $venueName', style: AppTextStyles.label),
          ],
        ],
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
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.label),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.label)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({this.product, this.tag, this.venue});

  final String? product;
  final String? tag;
  final String? venue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ready to register', style: AppTextStyles.title),
          const SizedBox(height: 12),
          _ReviewRow(label: 'Product', value: product ?? 'Choose a product'),
          _ReviewRow(label: 'RFID', value: tag ?? 'Capture the tag first'),
          _ReviewRow(label: 'Venue', value: venue ?? 'Choose a venue'),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: AppTextStyles.caption),
          ),
          Expanded(child: Text(value, style: AppTextStyles.label)),
        ],
      ),
    );
  }
}
