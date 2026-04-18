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

enum _SetupMode { guided, manual }

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({
    super.key,
    this.prefillBarcode,
    this.initialMode,
    this.preselectedDeviceId,
    this.preselectedDeviceName,
    this.preselectedVenueId,
    this.preselectedVenueName,
  });

  final String? prefillBarcode;
  final String? initialMode;
  final String? preselectedDeviceId;
  final String? preselectedDeviceName;
  final String? preselectedVenueId;
  final String? preselectedVenueName;

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  int _step = 0;
  bool _submitting = false;
  bool _barcodeChecked = false;
  _SetupMode? _setupMode;
  Map<String, dynamic>? _session;
  String? _sessionError;

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
  String? _selectedDeviceId;
  String? _selectedDeviceName;
  String? _selectedVenueId;
  String? _selectedVenueName;

  @override
  void initState() {
    super.initState();
    _setupMode = switch (widget.initialMode) {
      'guided' => _SetupMode.guided,
      'manual' => _SetupMode.manual,
      _ => null,
    };
    _selectedDeviceId = widget.preselectedDeviceId;
    _selectedDeviceName = widget.preselectedDeviceName;
    _selectedVenueId = widget.preselectedVenueId;
    _selectedVenueName = widget.preselectedVenueName;

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
    if (_setupMode != null) _step = 1;
  }

  @override
  void dispose() {
    for (final controller in [
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
      controller.dispose();
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
              '"${existing['name']}" already exists in the catalogue.\n\nDo you want to register a bottle for it instead?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep editing'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Register bottle'),
              ),
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

  bool _validateCurrentStep() {
    switch (_step) {
      case 0:
        if (_setupMode == null) {
          _showError('Choose how you want to set up this product.');
          return false;
        }
        return true;
      case 1:
        if (_name.text.trim().isEmpty || _category.text.trim().isEmpty) {
          _showError('Enter the product name and category first.');
          return false;
        }
        final bottleVolume = double.tryParse(_bottleVolume.text);
        if (bottleVolume == null || bottleVolume <= 0) {
          _showError('Enter a valid bottle size.');
          return false;
        }
        return true;
      case 2:
        if (!_positive(_standardPour.text) || !_positive(_sellingPrice.text)) {
          _showError('Enter the shot size and selling price.');
          return false;
        }
        if (!_positive(_liquidDensity.text)) {
          _showError('Enter a valid liquid density.');
          return false;
        }
        final tolerancePercent = double.tryParse(_tolerancePercent.text);
        if (!_nonNegative(_toleranceMl.text) ||
            tolerancePercent == null ||
            tolerancePercent < 0 ||
            tolerancePercent > 1) {
          _showError(
              'Use a pour range between 0 and 1 for the percentage value.');
          return false;
        }
        return true;
      case 3:
        if (_setupMode == _SetupMode.manual) {
          final empty = double.tryParse(_emptyWeight.text);
          final full = double.tryParse(_fullWeight.text);
          if (empty == null || full == null || full <= empty) {
            _showError('Enter valid empty and full bottle weights.');
            return false;
          }
        } else {
          if ((_session?['status'] as String?) != 'FullCaptured') {
            _showError('Capture both the empty and full bottle weights first.');
            return false;
          }
        }
        return true;
      default:
        return true;
    }
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

  Future<void> _save() async {
    if (!_validateCurrentStep()) return;
    setState(() => _submitting = true);
    try {
      final dio = ref.read(dioProvider);
      final product = _setupMode == _SetupMode.manual
          ? await createProduct(dio, {
              ..._buildBasePayload(),
              'emptyWeightG': double.parse(_emptyWeight.text),
              'fullWeightG': double.parse(_fullWeight.text),
            })
          : await completeProductCalibration(dio, _session!['id'] as String);
      if (!mounted) return;
      await _offerRegisterBottle(product);
    } on DioException catch (e) {
      _showError(_extractErrorMessage(e));
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _startMeasurementSession() async {
    if (!_validateStepRange(0, 2)) return;
    if (_selectedDeviceId == null) {
      _showError('Choose a coaster to measure this bottle.');
      return;
    }

    setState(() {
      _submitting = true;
      _sessionError = null;
    });

    try {
      final session = await startProductCalibration(
        ref.read(dioProvider),
        {..._buildBasePayload(), 'deviceId': _selectedDeviceId},
      );
      if (!mounted) return;
      setState(() => _session = session);
    } on DioException catch (e) {
      setState(() => _sessionError = _extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _runSessionAction(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    setState(() {
      _submitting = true;
      _sessionError = null;
    });
    try {
      final session = await action();
      if (!mounted) return;
      setState(() => _session = session);
    } on DioException catch (e) {
      setState(() => _sessionError = _extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _offerRegisterBottle(Map<String, dynamic> product) async {
    final register = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Product Created'),
        content: Text(
          '"${product['name']}" is ready. Would you like to register a bottle for it now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Register bottle'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (register == true) {
      final query = {
        'productId': product['id']?.toString(),
        'productName': product['name']?.toString(),
        'venueId': _selectedVenueId,
        'venueName': _selectedVenueName,
        'deviceId': _selectedDeviceId,
        'deviceName': _selectedDeviceName,
      }..removeWhere((key, value) => value == null || value.isEmpty);
      context.pushReplacement(
          Uri(path: '/inventory/register-bottle', queryParameters: query)
              .toString());
    } else {
      context.pop();
    }
  }

  bool _validateStepRange(int start, int endInclusive) {
    for (var step = start; step <= endInclusive; step++) {
      final current = _step;
      _step = step;
      final valid = _validateCurrentStep();
      _step = current;
      if (!valid) return false;
    }
    return true;
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    setState(() => _step = (_step + 1).clamp(0, 3));
  }

  void _previousStep() {
    setState(() => _step = (_step - 1).clamp(0, 3));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  bool _positive(String value) => (double.tryParse(value) ?? 0) > 0;
  bool _nonNegative(String value) => (double.tryParse(value) ?? -1) >= 0;

  String _extractErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return error.message ?? 'Request failed';
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(devicesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: SafeArea(
        child: Column(
          children: [
            _StepHeader(step: _step),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  switch (_step) {
                    0 => _buildSetupChoice(),
                    1 => _buildDetailsStep(),
                    2 => _buildShotAndPriceStep(),
                    _ => _buildBottleStep(devicesAsync),
                  },
                ],
              ),
            ),
            _FooterActions(
              step: _step,
              isSaving: _submitting,
              canGoBack: _step > 0,
              isFinalStep: _step == 3,
              onBack: _previousStep,
              onNext: _nextStep,
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupChoice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How do you want to set this up?', style: AppTextStyles.heading),
        const SizedBox(height: 8),
        const Text(
          'Choose the setup path first. You can either measure the bottle on a smart coaster or enter the bottle weights yourself.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 24),
        _ModeCard(
          title: 'Measure with coaster',
          subtitle:
              'Capture the empty and full bottle weights on a smart coaster.',
          icon: Icons.sensors,
          selected: _setupMode == _SetupMode.guided,
          onTap: () => setState(() => _setupMode = _SetupMode.guided),
        ),
        const SizedBox(height: 12),
        _ModeCard(
          title: 'Enter weights manually',
          subtitle: 'Type the empty and full bottle weights yourself.',
          icon: Icons.edit_note_rounded,
          selected: _setupMode == _SetupMode.manual,
          onTap: () => setState(() => _setupMode = _SetupMode.manual),
        ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Product details', style: AppTextStyles.heading),
        const SizedBox(height: 8),
        const Text(
          'Start with the bottle basics. Barcode scanning is optional.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _barcode,
                decoration: const InputDecoration(
                  labelText: 'Barcode',
                  hintText: 'Scan or enter manually',
                  prefixIcon: Icon(Icons.qr_code),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    setState(() => _barcodeChecked = false);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: AppColors.primary),
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              onPressed: _submitting ? null : _scanBarcode,
              tooltip: 'Scan barcode',
            ),
            if (!_barcodeChecked && _barcode.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.search),
                onPressed:
                    _submitting ? null : () => _checkBarcode(_barcode.text),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _Field(
          label: 'Product name',
          controller: _name,
          hint: 'e.g. Jack Daniel\'s',
        ),
        _Field(
          label: 'Category',
          controller: _category,
          hint: 'e.g. Whiskey',
        ),
        _Field(
          label: 'Bottle size (ml)',
          controller: _bottleVolume,
          hint: '700',
          numeric: true,
        ),
      ],
    );
  }

  Widget _buildShotAndPriceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Shot and price', style: AppTextStyles.heading),
        const SizedBox(height: 8),
        const Text(
          'Set the standard shot, the allowed pour range, and the commercial values.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _Field(
                label: 'Standard shot (ml)',
                controller: _standardPour,
                hint: '25',
                numeric: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Field(
                label: 'Density (g/ml)',
                controller: _liquidDensity,
                hint: '0.789',
                numeric: true,
              ),
            ),
          ],
        ),
        DropdownButtonFormField<String>(
          initialValue: _toleranceMode,
          decoration:
              const InputDecoration(labelText: 'Allowed pour range uses'),
          items: const [
            DropdownMenuItem(value: 'Hybrid', child: Text('Both ml and %')),
            DropdownMenuItem(value: 'FixedMl', child: Text('Only ml')),
            DropdownMenuItem(value: 'Percentage', child: Text('Only %')),
          ],
          onChanged: (value) => setState(() => _toleranceMode = value!),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _Field(
                label: 'Allowed pour range (ml)',
                controller: _toleranceMl,
                hint: '3',
                numeric: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Field(
                label: 'Allowed pour range (%)',
                controller: _tolerancePercent,
                hint: '0.1',
                numeric: true,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _Field(
                label: 'Selling price / shot',
                controller: _sellingPrice,
                hint: '8.50',
                numeric: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Field(
                label: 'Cost / bottle (optional)',
                controller: _costPrice,
                hint: '120.00',
                numeric: true,
              ),
            ),
          ],
        ),
        _Field(
          label: 'Reference temperature (C, optional)',
          controller: _referenceTemperature,
          hint: '20',
          numeric: true,
        ),
        DropdownButtonFormField<String>(
          initialValue: _currency,
          decoration: const InputDecoration(labelText: 'Currency'),
          items: const ['NGN', 'USD', 'GBP', 'EUR', 'ZAR']
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (value) => setState(() => _currency = value!),
        ),
      ],
    );
  }

  Widget _buildBottleStep(AsyncValue<List<dynamic>> devicesAsync) {
    if (_setupMode == _SetupMode.manual) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bottle weights', style: AppTextStyles.heading),
          const SizedBox(height: 8),
          const Text(
            'Enter the empty and full bottle weights to finish product setup.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: 'Empty bottle weight (g)',
                  controller: _emptyWeight,
                  hint: '420',
                  numeric: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  label: 'Full bottle weight (g)',
                  controller: _fullWeight,
                  hint: '1200',
                  numeric: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SummaryCard(
            title: 'Ready to save',
            lines: [
              '${_name.text.trim().isEmpty ? 'New product' : _name.text.trim()} · ${_bottleVolume.text} ml bottle',
              '${_standardPour.text} ml shot · $_currency ${_sellingPrice.text.isEmpty ? '0' : _sellingPrice.text} / shot',
            ],
          ),
        ],
      );
    }

    final sessionStatus = _session?['status'] as String?;
    final emptyWeight = (_session?['emptyWeightG'] as num?)?.toDouble();
    final fullWeight = (_session?['fullWeightG'] as num?)?.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Measure bottle', style: AppTextStyles.heading),
        const SizedBox(height: 8),
        const Text(
          'Choose a live coaster, capture the empty bottle first, then the full bottle.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 24),
        devicesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text(
            'Unable to load coasters',
            style: AppTextStyles.caption,
          ),
          data: (devices) => DropdownButtonFormField<String>(
            initialValue: _selectedDeviceId,
            decoration: const InputDecoration(labelText: 'Measure on coaster'),
            items: devices
                .map((device) => DropdownMenuItem<String>(
                      value: device['id'] as String,
                      child: Text(
                        '${device['coasterName'] ?? device['barLocation'] ?? 'Device'}${device['venueName'] != null ? ' · ${device['venueName']}' : ''}',
                      ),
                    ))
                .toList(),
            onChanged: _session == null
                ? (value) {
                    final match =
                        devices.cast<Map<String, dynamic>>().firstWhere(
                              (device) => device['id'] == value,
                              orElse: () => <String, dynamic>{},
                            );
                    setState(() {
                      _selectedDeviceId = value;
                      _selectedDeviceName = match['coasterName'] as String?;
                      _selectedVenueId =
                          match['venueId']?.toString() ?? _selectedVenueId;
                      _selectedVenueName =
                          match['venueName'] as String? ?? _selectedVenueName;
                    });
                  }
                : null,
          ),
        ),
        if (_selectedVenueName != null) ...[
          const SizedBox(height: 12),
          _ContextBanner(
            icon: Icons.place_outlined,
            title: 'Venue context',
            subtitle: _selectedVenueName!,
          ),
        ],
        const SizedBox(height: 16),
        if (_session == null)
          ElevatedButton.icon(
            onPressed: _submitting ? null : _startMeasurementSession,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start measuring'),
          )
        else ...[
          _SummaryCard(
            title: 'Measurement session',
            lines: [
              'Status: ${calibrationStatusLabel(sessionStatus)}',
              if (emptyWeight != null)
                'Empty bottle: ${emptyWeight.toStringAsFixed(1)} g',
              if (fullWeight != null)
                'Full bottle: ${fullWeight.toStringAsFixed(1)} g',
            ],
          ),
          const SizedBox(height: 16),
          if (sessionStatus == 'Started')
            _ActionBanner(
              title: 'Step 1',
              message:
                  'Place the empty bottle on ${_selectedDeviceName ?? 'the coaster'} and capture it once the weight settles.',
              buttonLabel: 'Capture empty weight',
              onPressed: _submitting
                  ? null
                  : () => _runSessionAction(
                        () => captureProductCalibrationEmpty(
                          ref.read(dioProvider),
                          _session!['id'] as String,
                        ),
                      ),
            ),
          if (sessionStatus == 'EmptyCaptured') ...[
            _ActionBanner(
              title: 'Step 2',
              message:
                  'Now place the full bottle on ${_selectedDeviceName ?? 'the coaster'} and capture it.',
              buttonLabel: 'Capture full weight',
              onPressed: _submitting
                  ? null
                  : () => _runSessionAction(
                        () => captureProductCalibrationFull(
                          ref.read(dioProvider),
                          _session!['id'] as String,
                        ),
                      ),
            ),
          ],
          if (sessionStatus == 'FullCaptured') ...[
            const _ContextBanner(
              icon: Icons.check_circle_outline,
              title: 'Bottle measured',
              subtitle:
                  'Both weights are captured. Save the product to finish setup.',
            ),
          ],
        ],
        if (_sessionError != null) ...[
          const SizedBox(height: 12),
          Text(
            _sessionError!,
            style: AppTextStyles.caption.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Setup method',
      'Product details',
      'Shot and price',
      'Bottle setup',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step ${step + 1} of ${labels.length}',
              style: AppTextStyles.caption),
          const SizedBox(height: 8),
          Row(
            children: List.generate(labels.length, (index) {
              final active = index <= step;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: index == labels.length - 1 ? 0 : 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : AppColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(labels[index], style: AppTextStyles.caption),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.step,
    required this.isSaving,
    required this.canGoBack,
    required this.isFinalStep,
    required this.onBack,
    required this.onNext,
    required this.onSave,
  });

  final int step;
  final bool isSaving;
  final bool canGoBack;
  final bool isFinalStep;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (canGoBack)
            Expanded(
              child: OutlinedButton(
                onPressed: isSaving ? null : onBack,
                child: const Text('Back'),
              ),
            ),
          if (canGoBack) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: isSaving ? null : (isFinalStep ? onSave : onNext),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isFinalStep ? 'Save product' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primaryDark : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  selected ? AppColors.primary : AppColors.surfaceMuted,
              child: Icon(icon,
                  color: selected ? Colors.white : AppColors.primaryDark),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.title),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? AppColors.primaryDark : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBanner extends StatelessWidget {
  const _ActionBanner({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.title),
          const SizedBox(height: 6),
          Text(message, style: AppTextStyles.caption),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.scale_outlined),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _ContextBanner extends StatelessWidget {
  const _ContextBanner({
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
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.lines});

  final String title;
  final List<String> lines;

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
          Text(title, style: AppTextStyles.title),
          const SizedBox(height: 10),
          for (final line in lines) ...[
            Text(line, style: AppTextStyles.caption),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.numeric = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool numeric;

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
          ),
        ],
      ),
    );
  }
}
