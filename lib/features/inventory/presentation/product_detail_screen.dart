import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/providers/dio_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import 'detail_widgets.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  bool _editing = false;
  bool _saving = false;
  Map<String, dynamic>? _data;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _emptyWeightCtrl;
  late final TextEditingController _fullWeightCtrl;
  late final TextEditingController _bottleVolumeCtrl;
  late final TextEditingController _densityCtrl;
  late final TextEditingController _referenceTemperatureCtrl;
  late final TextEditingController _standardPourCtrl;
  late final TextEditingController _toleranceMlCtrl;
  late final TextEditingController _tolerancePercentCtrl;
  late final TextEditingController _sellingPriceCtrl;
  late final TextEditingController _costPriceCtrl;
  String _currency = 'NGN';
  String _toleranceMode = 'Hybrid';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _categoryCtrl = TextEditingController();
    _barcodeCtrl = TextEditingController();
    _emptyWeightCtrl = TextEditingController();
    _fullWeightCtrl = TextEditingController();
    _bottleVolumeCtrl = TextEditingController();
    _densityCtrl = TextEditingController();
    _referenceTemperatureCtrl = TextEditingController();
    _standardPourCtrl = TextEditingController();
    _toleranceMlCtrl = TextEditingController();
    _tolerancePercentCtrl = TextEditingController();
    _sellingPriceCtrl = TextEditingController();
    _costPriceCtrl = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _categoryCtrl,
      _barcodeCtrl,
      _emptyWeightCtrl,
      _fullWeightCtrl,
      _bottleVolumeCtrl,
      _densityCtrl,
      _referenceTemperatureCtrl,
      _standardPourCtrl,
      _toleranceMlCtrl,
      _tolerancePercentCtrl,
      _sellingPriceCtrl,
      _costPriceCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _populate(Map<String, dynamic> d) {
    _data = d;
    _nameCtrl.text = d['name'] as String? ?? '';
    _categoryCtrl.text = d['category'] as String? ?? '';
    _barcodeCtrl.text = d['barcode'] as String? ?? '';
    _emptyWeightCtrl.text = (d['emptyWeightG'] as num?)?.toString() ?? '';
    _fullWeightCtrl.text = (d['fullWeightG'] as num?)?.toString() ?? '';
    _bottleVolumeCtrl.text = (d['bottleVolumeMl'] as num?)?.toString() ?? '700';
    _densityCtrl.text =
        (d['liquidDensityGPerMl'] as num?)?.toString() ?? '0.789';
    _referenceTemperatureCtrl.text =
        (d['referenceTemperatureC'] as num?)?.toString() ?? '';
    _standardPourCtrl.text = (d['standardPourMl'] as num?)?.toString() ?? '';
    _toleranceMlCtrl.text = (d['pourToleranceMl'] as num?)?.toString() ?? '3';
    _tolerancePercentCtrl.text =
        (d['pourTolerancePercent'] as num?)?.toString() ?? '0.1';
    _sellingPriceCtrl.text =
        (d['sellingPricePerShot'] as num?)?.toString() ?? '';
    _costPriceCtrl.text = d['costPricePerBottle']?.toString() ?? '';
    _currency = d['currency'] as String? ?? 'NGN';
    _toleranceMode = normalizePourToleranceMode(d['pourToleranceMode']);
  }

  Future<void> _save() async {
    final empty = double.tryParse(_emptyWeightCtrl.text);
    final full = double.tryParse(_fullWeightCtrl.text);
    if (empty == null || full == null || full <= empty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Full weight must be greater than empty weight.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final changes = {
        'name': _nameCtrl.text.trim(),
        'category': _categoryCtrl.text.trim(),
        'barcode':
            _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
        'emptyWeightG': empty,
        'fullWeightG': full,
        'bottleVolumeMl': double.tryParse(_bottleVolumeCtrl.text) ?? 700.0,
        'liquidDensityGPerMl': double.tryParse(_densityCtrl.text) ?? 0.789,
        'referenceTemperatureC': _referenceTemperatureCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(_referenceTemperatureCtrl.text),
        'standardPourMl': double.tryParse(_standardPourCtrl.text) ?? 25.0,
        'pourToleranceMode': pourToleranceModeToApiValue(_toleranceMode),
        'pourToleranceMl': double.tryParse(_toleranceMlCtrl.text) ?? 3.0,
        'pourTolerancePercent':
            double.tryParse(_tolerancePercentCtrl.text) ?? 0.1,
        'sellingPricePerShot': double.tryParse(_sellingPriceCtrl.text) ?? 0.0,
        'costPricePerBottle': double.tryParse(_costPriceCtrl.text),
        'currency': _currency,
      };
      await ref
          .read(productsListProvider.notifier)
          .updateProduct(widget.productId, changes);
      if (!mounted) return;
      setState(() => _editing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Product updated'),
            backgroundColor: AppColors.success),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to save'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authProvider).valueOrNull?.role == 'Admin';

    return FutureBuilder<Response<dynamic>>(
      future: ref
          .read(dioProvider)
          .get('${ApiConstants.products}/${widget.productId}'),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || snap.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Product')),
            body: const Center(child: Text('Failed to load product')),
          );
        }

        final d = snap.data!.data as Map<String, dynamic>;
        if (_data == null) _populate(d);

        final name = d['name'] as String? ?? 'Unknown';
        final category = d['category'] as String? ?? '';
        final barcode = d['barcode'] as String? ?? '—';
        final emptyG = (d['emptyWeightG'] as num?)?.toDouble() ?? 0;
        final fullG = (d['fullWeightG'] as num?)?.toDouble() ?? 0;
        final bottleVolume = (d['bottleVolumeMl'] as num?)?.toDouble() ?? 700;
        final density = (d['liquidDensityGPerMl'] as num?)?.toDouble() ?? 0.789;
        final referenceTemp = (d['referenceTemperatureC'] as num?)?.toDouble();
        final pourMl = (d['standardPourMl'] as num?)?.toDouble() ?? 0;
        final toleranceMode =
            normalizePourToleranceMode(d['pourToleranceMode']);
        final toleranceMl = (d['pourToleranceMl'] as num?)?.toDouble() ?? 0;
        final tolerancePercent =
            (d['pourTolerancePercent'] as num?)?.toDouble() ?? 0;
        final price = (d['sellingPricePerShot'] as num?)?.toDouble() ?? 0;
        final costRaw = d['costPricePerBottle'];
        final cost =
            costRaw != null ? '\$${(costRaw as num).toStringAsFixed(2)}' : '—';
        final currency = d['currency'] as String? ?? 'NGN';

        return Scaffold(
          appBar: AppBar(
            title: Text(name),
            actions: [
              if (isAdmin)
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
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 30,
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(child: Text(category, style: AppTextStyles.caption)),
              const SizedBox(height: 28),
              InfoSection(title: 'Product Info', rows: [
                if (_editing) ...[
                  EditRow(
                      label: 'Name',
                      child: TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration())),
                  EditRow(
                      label: 'Category',
                      child: TextFormField(
                          controller: _categoryCtrl,
                          decoration: const InputDecoration())),
                  EditRow(
                      label: 'Barcode',
                      child: TextFormField(
                          controller: _barcodeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration())),
                ] else ...[
                  InfoRow(label: 'Name', value: name),
                  InfoRow(label: 'Category', value: category),
                  InfoRow(label: 'Barcode', value: barcode, mono: true),
                ],
              ]),
              const SizedBox(height: 16),
              InfoSection(title: 'Weights', rows: [
                if (_editing) ...[
                  EditRow(
                      label: 'Empty (g)',
                      child: TextFormField(
                          controller: _emptyWeightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration())),
                  EditRow(
                      label: 'Full (g)',
                      child: TextFormField(
                          controller: _fullWeightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration())),
                ] else ...[
                  InfoRow(
                      label: 'Empty Weight',
                      value: '${emptyG.toStringAsFixed(0)} g'),
                  InfoRow(
                      label: 'Full Weight',
                      value: '${fullG.toStringAsFixed(0)} g'),
                ],
              ]),
              const SizedBox(height: 16),
              InfoSection(title: 'Calibration Model', rows: [
                if (_editing) ...[
                  EditRow(
                      label: 'Bottle Volume (ml)',
                      child: TextFormField(
                          controller: _bottleVolumeCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration())),
                  EditRow(
                      label: 'Density (g/ml)',
                      child: TextFormField(
                          controller: _densityCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration())),
                  EditRow(
                      label: 'Reference Temp (C)',
                      child: TextFormField(
                          controller: _referenceTemperatureCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration())),
                ] else ...[
                  InfoRow(
                      label: 'Bottle Volume',
                      value: '${bottleVolume.toStringAsFixed(0)} ml'),
                  InfoRow(label: 'Density', value: density.toStringAsFixed(3)),
                  InfoRow(
                      label: 'Reference Temp',
                      value: referenceTemp == null
                          ? '—'
                          : '${referenceTemp.toStringAsFixed(1)} C'),
                ],
              ]),
              const SizedBox(height: 16),
              InfoSection(title: 'Pour & Tolerance', rows: [
                if (_editing) ...[
                  EditRow(
                      label: 'Standard Pour (ml)',
                      child: TextFormField(
                          controller: _standardPourCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration())),
                  EditRow(
                    label: 'Tolerance Mode',
                    child: DropdownButtonFormField<String>(
                      initialValue: _toleranceMode,
                      decoration: const InputDecoration(),
                      items: pourToleranceModeOptions
                          .map((mode) => DropdownMenuItem(
                                value: mode,
                                child: Text(mode),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _toleranceMode = value!),
                    ),
                  ),
                  EditRow(
                      label: 'Tolerance (ml)',
                      child: TextFormField(
                          controller: _toleranceMlCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration())),
                  EditRow(
                      label: 'Tolerance (%)',
                      child: TextFormField(
                          controller: _tolerancePercentCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration())),
                ] else ...[
                  InfoRow(
                      label: 'Standard Pour',
                      value: '${pourMl.toStringAsFixed(0)} ml'),
                  InfoRow(label: 'Tolerance Mode', value: toleranceMode),
                  InfoRow(
                      label: 'Tolerance (ml)',
                      value: toleranceMl.toStringAsFixed(1)),
                  InfoRow(
                      label: 'Tolerance (%)',
                      value: '${(tolerancePercent * 100).toStringAsFixed(0)}%'),
                ],
              ]),
              const SizedBox(height: 16),
              InfoSection(title: 'Pricing', rows: [
                if (_editing) ...[
                  EditRow(
                      label: 'Selling Price / Shot',
                      child: TextFormField(
                          controller: _sellingPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration())),
                  EditRow(
                      label: 'Cost / Bottle (optional)',
                      child: TextFormField(
                          controller: _costPriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration())),
                  EditRow(
                    label: 'Currency',
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: const InputDecoration(),
                      items: const ['NGN', 'USD', 'GBP', 'EUR', 'ZAR']
                          .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _currency = v!),
                    ),
                  ),
                ] else ...[
                  InfoRow(
                      label: 'Selling Price',
                      value: '\$${price.toStringAsFixed(2)} / shot'),
                  InfoRow(label: 'Cost / Bottle', value: cost),
                  InfoRow(label: 'Currency', value: currency),
                ],
              ]),
            ],
          ),
        );
      },
    );
  }
}
