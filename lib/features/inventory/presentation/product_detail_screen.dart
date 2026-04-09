import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/constants/api_constants.dart';
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
  late final TextEditingController _standardPourCtrl;
  late final TextEditingController _sellingPriceCtrl;
  late final TextEditingController _costPriceCtrl;
  String _currency = 'NGN';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _categoryCtrl = TextEditingController();
    _barcodeCtrl = TextEditingController();
    _emptyWeightCtrl = TextEditingController();
    _fullWeightCtrl = TextEditingController();
    _standardPourCtrl = TextEditingController();
    _sellingPriceCtrl = TextEditingController();
    _costPriceCtrl = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _categoryCtrl, _barcodeCtrl, _emptyWeightCtrl,
      _fullWeightCtrl, _standardPourCtrl, _sellingPriceCtrl, _costPriceCtrl,
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
    _standardPourCtrl.text = (d['standardPourMl'] as num?)?.toString() ?? '';
    _sellingPriceCtrl.text =
        (d['sellingPricePerShot'] as num?)?.toString() ?? '';
    _costPriceCtrl.text = d['costPricePerBottle']?.toString() ?? '';
    _currency = d['currency'] as String? ?? 'NGN';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.put(
        '${ApiConstants.products}/${widget.productId}',
        data: {
          'name': _nameCtrl.text.trim(),
          'category': _categoryCtrl.text.trim(),
          'barcode': _barcodeCtrl.text.trim().isEmpty
              ? null
              : _barcodeCtrl.text.trim(),
          'emptyWeightG': double.tryParse(_emptyWeightCtrl.text) ?? 420.0,
          'fullWeightG': double.tryParse(_fullWeightCtrl.text) ?? 1200.0,
          'standardPourMl': double.tryParse(_standardPourCtrl.text) ?? 30.0,
          'sellingPricePerShot':
              double.tryParse(_sellingPriceCtrl.text) ?? 0.0,
          'costPricePerBottle': double.tryParse(_costPriceCtrl.text),
          'currency': _currency,
        },
      );
      if (!mounted) return;
      ref.invalidate(productsListProvider);
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
            content: Text('Failed to save'),
            backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authProvider).valueOrNull?.role == 'Admin';

    return FutureBuilder(
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
        final pourMl = (d['standardPourMl'] as num?)?.toDouble() ?? 0;
        final price = (d['sellingPricePerShot'] as num?)?.toDouble() ?? 0;
        final costRaw = d['costPricePerBottle'];
        final cost = costRaw != null
            ? '\$${(costRaw as num).toStringAsFixed(2)}'
            : '—';
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
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration())),
                  EditRow(
                      label: 'Full (g)',
                      child: TextFormField(
                          controller: _fullWeightCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
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
              InfoSection(title: 'Pricing & Pour', rows: [
                if (_editing) ...[
                  EditRow(
                      label: 'Standard Pour (ml)',
                      child: TextFormField(
                          controller: _standardPourCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration())),
                  EditRow(
                      label: 'Selling Price / Shot',
                      child: TextFormField(
                          controller: _sellingPriceCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration())),
                  EditRow(
                      label: 'Cost / Bottle (optional)',
                      child: TextFormField(
                          controller: _costPriceCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration())),
                  EditRow(
                    label: 'Currency',
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: const InputDecoration(),
                      items: const ['NGN', 'USD', 'GBP', 'EUR', 'ZAR']
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _currency = v!),
                    ),
                  ),
                ] else ...[
                  InfoRow(
                      label: 'Standard Pour',
                      value: '${pourMl.toStringAsFixed(0)} ml'),
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
