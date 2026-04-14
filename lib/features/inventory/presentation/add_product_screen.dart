import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/dio_provider.dart';
import '../../devices/providers/devices_provider.dart';
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
  bool _requireManualWeights = true;

  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _barcode;
  late final TextEditingController _emptyWeight;
  late final TextEditingController _fullWeight;
  late final TextEditingController _bottleVolume;
  late final TextEditingController _liquidDensity;
  late final TextEditingController _referenceTemperature;
  late final TextEditingController _standardPour;
  late final TextEditingController _toleranceMl;
  late final TextEditingController _tolerancePercent;
  late final TextEditingController _sellingPrice;
  late final TextEditingController _costPrice;
  String _currency = 'NGN';
  String _toleranceMode = 'Hybrid';

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _category = TextEditingController();
    _barcode = TextEditingController(text: widget.prefillBarcode ?? '');
    _emptyWeight = TextEditingController();
    _fullWeight = TextEditingController();
    _bottleVolume = TextEditingController(text: '700');
    _liquidDensity = TextEditingController(text: '0.789');
    _referenceTemperature = TextEditingController();
    _standardPour = TextEditingController(text: '25');
    _toleranceMl = TextEditingController(text: '3');
    _tolerancePercent = TextEditingController(text: '0.1');
    _sellingPrice = TextEditingController();
    _costPrice = TextEditingController();

    if (widget.prefillBarcode != null) _barcodeChecked = true;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _category,
      _barcode,
      _emptyWeight,
      _fullWeight,
      _bottleVolume,
      _liquidDensity,
      _referenceTemperature,
      _standardPour,
      _toleranceMl,
      _tolerancePercent,
      _sellingPrice,
      _costPrice,
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
        _populateFromProduct(existing);
      }
      setState(() => _barcodeChecked = true);
    } catch (_) {
      setState(() => _barcodeChecked = true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _populateFromProduct(Map<String, dynamic> existing) {
    _name.text = existing['name'] as String? ?? '';
    _category.text = existing['category'] as String? ?? '';
    _bottleVolume.text =
        (existing['bottleVolumeMl'] as num?)?.toString() ?? _bottleVolume.text;
    _liquidDensity.text =
        (existing['liquidDensityGPerMl'] as num?)?.toString() ??
            _liquidDensity.text;
    _referenceTemperature.text =
        (existing['referenceTemperatureC'] as num?)?.toString() ?? '';
    _standardPour.text =
        (existing['standardPourMl'] as num?)?.toString() ?? _standardPour.text;
    _toleranceMl.text =
        (existing['pourToleranceMl'] as num?)?.toString() ?? _toleranceMl.text;
    _tolerancePercent.text =
        (existing['pourTolerancePercent'] as num?)?.toString() ??
            _tolerancePercent.text;
    _toleranceMode = normalizePourToleranceMode(existing['pourToleranceMode']);
  }

  bool _validateForm({required bool requireWeights}) {
    setState(() => _requireManualWeights = requireWeights);
    final isValid = _formKey.currentState!.validate();
    if (!isValid) return false;

    if (requireWeights) {
      final empty = double.tryParse(_emptyWeight.text);
      final full = double.tryParse(_fullWeight.text);
      if (empty == null || full == null || full <= empty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Full weight must be greater than empty weight.'),
            backgroundColor: AppColors.error,
          ),
        );
        return false;
      }
    }

    return true;
  }

  Map<String, dynamic> _buildBasePayload() {
    return {
      'name': _name.text.trim(),
      'category': _category.text.trim(),
      'barcode': _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      'bottleVolumeMl': double.parse(_bottleVolume.text),
      'liquidDensityGPerMl': double.parse(_liquidDensity.text),
      'referenceTemperatureC': _referenceTemperature.text.trim().isEmpty
          ? null
          : double.parse(_referenceTemperature.text),
      'standardPourMl': double.parse(_standardPour.text),
      'pourToleranceMode': pourToleranceModeToApiValue(_toleranceMode),
      'pourToleranceMl': double.parse(_toleranceMl.text),
      'pourTolerancePercent': double.parse(_tolerancePercent.text),
      'sellingPricePerShot': double.parse(_sellingPrice.text),
      'costPricePerBottle':
          _costPrice.text.trim().isEmpty ? null : double.parse(_costPrice.text),
      'currency': _currency,
    };
  }

  Future<void> _submit() async {
    if (!_validateForm(requireWeights: true)) return;

    setState(() => _submitting = true);
    try {
      final dio = ref.read(dioProvider);
      final product = await createProduct(dio, {
        ..._buildBasePayload(),
        'emptyWeightG': double.parse(_emptyWeight.text),
        'fullWeightG': double.parse(_fullWeight.text),
      });
      if (!mounted) return;
      await _offerRegisterBottle(product);
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

  Future<void> _startGuidedCalibration() async {
    if (!_validateForm(requireWeights: false)) return;

    final product = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CalibrationSessionDialog(
        draftPayload: _buildBasePayload(),
      ),
    );

    if (product == null || !mounted) return;
    await _offerRegisterBottle(product);
  }

  Future<void> _offerRegisterBottle(Map<String, dynamic> product) async {
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
                _Field(
                  label: 'Product Name',
                  controller: _name,
                  hint: 'e.g. Jack Daniels',
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                _Field(
                  label: 'Category',
                  controller: _category,
                  hint: 'e.g. Whiskey',
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                _GuidedCalibrationCard(
                  busy: _submitting,
                  onPressed: _startGuidedCalibration,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Manual weights (optional when using guided calibration)',
                  style: AppTextStyles.label,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        label: 'Empty (g)',
                        controller: _emptyWeight,
                        hint: '420',
                        numeric: true,
                        validator: (value) => _requiredNumber(value,
                            required: _requireManualWeights),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(
                        label: 'Full (g)',
                        controller: _fullWeight,
                        hint: '1200',
                        numeric: true,
                        validator: (value) => _requiredNumber(value,
                            required: _requireManualWeights),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Calibration Model', style: AppTextStyles.label),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        label: 'Bottle Volume (ml)',
                        controller: _bottleVolume,
                        hint: '700',
                        numeric: true,
                        validator: _requiredPositiveNumber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(
                        label: 'Density (g/ml)',
                        controller: _liquidDensity,
                        hint: '0.789',
                        numeric: true,
                        validator: _requiredPositiveNumber,
                      ),
                    ),
                  ],
                ),
                _Field(
                  label: 'Reference Temperature (C, optional)',
                  controller: _referenceTemperature,
                  hint: '20',
                  numeric: true,
                  validator: _optionalNumber,
                ),
                const SizedBox(height: 8),
                const Text('Pour & Tolerance', style: AppTextStyles.label),
                const SizedBox(height: 8),
                _Field(
                  label: 'Standard Pour (ml)',
                  controller: _standardPour,
                  hint: '25',
                  numeric: true,
                  validator: _requiredPositiveNumber,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _toleranceMode,
                  decoration:
                      const InputDecoration(labelText: 'Tolerance Mode'),
                  items: pourToleranceModeOptions
                      .map((mode) => DropdownMenuItem(
                            value: mode,
                            child: Text(mode),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _toleranceMode = value!),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        label: 'Tolerance (ml)',
                        controller: _toleranceMl,
                        hint: '3',
                        numeric: true,
                        validator: _requiredNonNegativeNumber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(
                        label: 'Tolerance (%)',
                        controller: _tolerancePercent,
                        hint: '0.1',
                        numeric: true,
                        validator: _percentValidator,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        label: 'Selling Price / Shot',
                        controller: _sellingPrice,
                        hint: '8.50',
                        numeric: true,
                        validator: _requiredPositiveNumber,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(
                        label: 'Cost / Bottle (optional)',
                        controller: _costPrice,
                        hint: '120.00',
                        numeric: true,
                        validator: _optionalNumber,
                      ),
                    ),
                  ],
                ),
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
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : _startGuidedCalibration,
                        icon: const Icon(Icons.sensors),
                        label: const Text('Guided Calibration'),
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
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text('Create Product'),
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

  String? _requiredNumber(String? value, {bool required = true}) {
    if (!required && (value == null || value.trim().isEmpty)) return null;
    if (value == null || value.trim().isEmpty) return 'Required';
    if (double.tryParse(value) == null) return 'Enter a valid number';
    return null;
  }

  String? _requiredPositiveNumber(String? value) {
    final base = _requiredNumber(value);
    if (base != null) return base;
    if ((double.tryParse(value!) ?? 0) <= 0) return 'Must be greater than zero';
    return null;
  }

  String? _requiredNonNegativeNumber(String? value) {
    final base = _requiredNumber(value);
    if (base != null) return base;
    if ((double.tryParse(value!) ?? -1) < 0) return 'Cannot be negative';
    return null;
  }

  String? _optionalNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (double.tryParse(value) == null) return 'Enter a valid number';
    return null;
  }

  String? _percentValidator(String? value) {
    final base = _requiredNonNegativeNumber(value);
    if (base != null) return base;
    final parsed = double.tryParse(value!);
    if (parsed == null || parsed > 1) return 'Use a value between 0 and 1';
    return null;
  }
}

class _GuidedCalibrationCard extends StatelessWidget {
  const _GuidedCalibrationCard({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors, color: AppColors.primaryDark),
              const SizedBox(width: 10),
              Text('Coaster-assisted calibration',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  )),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Use a live device to capture the empty bottle first and the full bottle second. This creates the product with measured calibration weights instead of typed ones.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: busy ? null : onPressed,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Guided Calibration'),
          ),
        ],
      ),
    );
  }
}

class _CalibrationSessionDialog extends ConsumerStatefulWidget {
  const _CalibrationSessionDialog({required this.draftPayload});

  final Map<String, dynamic> draftPayload;

  @override
  ConsumerState<_CalibrationSessionDialog> createState() =>
      _CalibrationSessionDialogState();
}

class _CalibrationSessionDialogState
    extends ConsumerState<_CalibrationSessionDialog> {
  bool _busy = false;
  String? _selectedDeviceId;
  Map<String, dynamic>? _session;
  String? _error;

  Future<void> _start() async {
    if (_selectedDeviceId == null) {
      setState(() => _error = 'Choose a device to start calibration.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final session = await startProductCalibration(
        ref.read(dioProvider),
        {...widget.draftPayload, 'deviceId': _selectedDeviceId},
      );
      if (!mounted) return;
      setState(() => _session = session);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    final sessionId = _session?['id'] as String?;
    if (sessionId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final session =
          await getProductCalibrationSession(ref.read(dioProvider), sessionId);
      if (!mounted) return;
      setState(() => _session = session);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _captureEmpty() async {
    final sessionId = _session?['id'] as String?;
    if (sessionId == null) return;
    await _runSessionAction(
      () => captureProductCalibrationEmpty(ref.read(dioProvider), sessionId),
    );
  }

  Future<void> _captureFull() async {
    final sessionId = _session?['id'] as String?;
    if (sessionId == null) return;
    await _runSessionAction(
      () => captureProductCalibrationFull(ref.read(dioProvider), sessionId),
    );
  }

  Future<void> _complete() async {
    final sessionId = _session?['id'] as String?;
    if (sessionId == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final product =
          await completeProductCalibration(ref.read(dioProvider), sessionId);
      if (!mounted) return;
      Navigator.of(context).pop(product);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final sessionId = _session?['id'] as String?;
    if (sessionId != null) {
      setState(() {
        _busy = true;
        _error = null;
      });

      try {
        await cancelProductCalibration(ref.read(dioProvider), sessionId);
      } catch (_) {
        // Best effort — we still close the dialog locally.
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _runSessionAction(
      Future<Map<String, dynamic>> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final session = await action();
      if (!mounted) return;
      setState(() => _session = session);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesListProvider);
    final status = _session?['status'] as String?;
    final emptyWeight = (_session?['emptyWeightG'] as num?)?.toDouble();
    final fullWeight = (_session?['fullWeightG'] as num?)?.toDouble();

    return AlertDialog(
      title: const Text('Guided Calibration'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1. Pick a live coaster.\n2. Place the empty bottle and capture it.\n3. Place the full bottle and capture again.\n4. Complete the session to create the product.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 16),
              if (_session == null) ...[
                devicesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text(
                    'Failed to load devices',
                    style: AppTextStyles.caption,
                  ),
                  data: (devices) => DropdownButtonFormField<String>(
                    initialValue: _selectedDeviceId,
                    decoration: const InputDecoration(
                      labelText: 'Calibration Device',
                    ),
                    items: devices
                        .map((device) => DropdownMenuItem<String>(
                              value: device['id'] as String,
                              child: Text(
                                '${device['coasterName'] ?? device['barLocation'] ?? 'Device'}'
                                '${device['venueName'] != null ? ' · ${device['venueName']}' : ''}',
                              ),
                            ))
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _selectedDeviceId = value),
                  ),
                ),
              ] else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusPill(label: calibrationStatusLabel(status)),
                    if (emptyWeight != null)
                      _MetricPill(
                          label: 'Empty',
                          value: '${emptyWeight.toStringAsFixed(1)} g'),
                    if (fullWeight != null)
                      _MetricPill(
                          label: 'Full',
                          value: '${fullWeight.toStringAsFixed(1)} g'),
                  ],
                ),
                const SizedBox(height: 16),
                if (status == 'Started')
                  const Text(
                    'Place the empty bottle on the selected coaster and wait for the weight to settle, then capture empty.',
                    style: AppTextStyles.caption,
                  ),
                if (status == 'EmptyCaptured')
                  const Text(
                    'Now place the full bottle on the same coaster and capture the stable full weight.',
                    style: AppTextStyles.caption,
                  ),
                if (status == 'FullCaptured')
                  const Text(
                    'Both weights are captured. Complete the session to create the calibrated product.',
                    style: AppTextStyles.caption,
                  ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AppTextStyles.caption.copyWith(color: AppColors.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _cancel,
          child: Text(_session == null ? 'Close' : 'Cancel Session'),
        ),
        if (_session == null)
          ElevatedButton(
            onPressed: _busy ? null : _start,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Start'),
          )
        else ...[
          TextButton(
            onPressed: _busy ? null : _refresh,
            child: const Text('Refresh'),
          ),
          if (status == 'Started')
            ElevatedButton(
              onPressed: _busy ? null : _captureEmpty,
              child: const Text('Capture Empty'),
            ),
          if (status == 'EmptyCaptured')
            ElevatedButton(
              onPressed: _busy ? null : _captureFull,
              child: const Text('Capture Full'),
            ),
          if (status == 'FullCaptured')
            ElevatedButton(
              onPressed: _busy ? null : _complete,
              child: const Text('Complete'),
            ),
        ],
      ],
    );
  }

  String _extractErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return error.message ?? 'Request failed';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w700,
          )),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text('$label: $value', style: AppTextStyles.caption),
    );
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
            keyboardType: numeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            validator: validator,
          ),
        ],
      ),
    );
  }
}
