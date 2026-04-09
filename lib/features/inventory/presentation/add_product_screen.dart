import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/dio_provider.dart';
import '../providers/inventory_provider.dart';
import 'barcode_scanner_screen.dart';

/// Create a new product. If [prefillBarcode] is provided (scanned upstream),
/// the barcode field is pre-filled and the scan step is skipped.
class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key, this.prefillBarcode});

  final String? prefillBarcode;

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  bool _barcodeChecked = false;

  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _barcode;
  late final TextEditingController _emptyWeight;
  late final TextEditingController _fullWeight;
  late final TextEditingController _standardPour;
  late final TextEditingController _sellingPrice;
  late final TextEditingController _costPrice;
  String _currency = 'NGN';

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _category = TextEditingController();
    _barcode = TextEditingController(text: widget.prefillBarcode ?? '');
    _emptyWeight = TextEditingController();
    _fullWeight = TextEditingController();
    _standardPour = TextEditingController();
    _sellingPrice = TextEditingController();
    _costPrice = TextEditingController();

    if (widget.prefillBarcode != null) _barcodeChecked = true;
  }

  @override
  void dispose() {
    for (final c in [
      _name, _category, _barcode, _emptyWeight, _fullWeight,
      _standardPour, _sellingPrice, _costPrice
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result == null || !mounted) return;
    _barcode.text = result;
    await _checkBarcode(result);
  }

  Future<void> _checkBarcode(String barcode) async {
    final dio = ref.read(dioProvider);
    setState(() => _submitting = true);
    try {
      final existing = await lookupBarcode(dio, barcode);
      if (!mounted) return;
      if (existing != null) {
        // Product already exists — offer to go straight to bottle registration
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Product Found'),
            content: Text(
                '"${existing['name']}" already exists in the catalogue.\n\nDo you want to register a bottle for this product instead?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Create New')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Register Bottle')),
            ],
          ),
        );
        if (go == true && mounted) {
          context.pushReplacement(
            '/inventory/register-bottle?productId=${existing['id']}&productName=${Uri.encodeComponent(existing['name'] as String)}',
          );
          return;
        }
        // Pre-fill known fields from existing product as starting point
        _name.text = existing['name'] as String? ?? '';
        _category.text = existing['category'] as String? ?? '';
      }
      setState(() => _barcodeChecked = true);
    } catch (_) {
      setState(() => _barcodeChecked = true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final dio = ref.read(dioProvider);
      final product = await createProduct(dio, {
        'name': _name.text.trim(),
        'category': _category.text.trim(),
        'barcode': _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
        'emptyWeightG': double.parse(_emptyWeight.text),
        'fullWeightG': double.parse(_fullWeight.text),
        'standardPourMl': double.parse(_standardPour.text),
        'sellingPricePerShot': double.parse(_sellingPrice.text),
        'costPricePerBottle': _costPrice.text.trim().isEmpty
            ? null
            : double.parse(_costPrice.text),
        'currency': _currency,
      });
      if (!mounted) return;

      // Offer to register a bottle immediately
      final register = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Product Created'),
          content: Text(
              '"${product['name']}" has been added to the catalogue.\n\nWould you like to register a bottle for it now?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not Now')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Register Bottle')),
          ],
        ),
      );

      if (!mounted) return;
      if (register == true) {
        context.pushReplacement(
          '/inventory/register-bottle?productId=${product['id']}&productName=${Uri.encodeComponent(product['name'] as String)}',
        );
      } else {
        context.pop();
      }
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Barcode ──────────────────────────────────────────────
                const Text('Barcode', style: AppTextStyles.label),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _barcode,
                        decoration: const InputDecoration(
                          hintText: 'Scan or enter manually',
                          prefixIcon: Icon(Icons.qr_code),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          if (v.isNotEmpty) {
                            setState(() => _barcodeChecked = false);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary),
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      onPressed: _submitting ? null : _scanBarcode,
                      tooltip: 'Scan barcode',
                    ),
                    if (!_barcodeChecked && _barcode.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.search),
                        color: AppColors.primaryDark,
                        onPressed: _submitting
                            ? null
                            : () => _checkBarcode(_barcode.text),
                        tooltip: 'Look up barcode',
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Basic details ─────────────────────────────────────────
                _Field(
                  label: 'Product Name',
                  controller: _name,
                  hint: 'e.g. Jack Daniels',
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                _Field(
                  label: 'Category',
                  controller: _category,
                  hint: 'e.g. Whiskey',
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),

                // ── Weights ───────────────────────────────────────────────
                const SizedBox(height: 4),
                const Text('Weights (grams)', style: AppTextStyles.label),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        label: 'Empty (g)',
                        controller: _emptyWeight,
                        hint: '420',
                        numeric: true,
                        validator: _requiredNumber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(
                        label: 'Full (g)',
                        controller: _fullWeight,
                        hint: '1200',
                        numeric: true,
                        validator: _requiredNumber,
                      ),
                    ),
                  ],
                ),

                // ── Pour & pricing ────────────────────────────────────────
                _Field(
                  label: 'Standard Pour (ml)',
                  controller: _standardPour,
                  hint: '30',
                  numeric: true,
                  validator: _requiredNumber,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        label: 'Selling Price / Shot',
                        controller: _sellingPrice,
                        hint: '8.50',
                        numeric: true,
                        validator: _requiredNumber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(
                        label: 'Cost / Bottle (optional)',
                        controller: _costPrice,
                        hint: '120.00',
                        numeric: true,
                      ),
                    ),
                  ],
                ),

                // ── Currency ──────────────────────────────────────────────
                const SizedBox(height: 4),
                const Text('Currency', style: AppTextStyles.label),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: const InputDecoration(),
                  items: const ['NGN', 'USD', 'GBP', 'EUR', 'ZAR']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _currency = v!),
                ),

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Create Product'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _requiredNumber(String? v) {
    if (v == null || v.isEmpty) return 'Required';
    if (double.tryParse(v) == null) return 'Enter a valid number';
    return null;
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.numeric = false,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool numeric;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.label),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(hintText: hint),
            keyboardType:
                numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            validator: validator,
          ),
        ],
      ),
    );
  }
}
