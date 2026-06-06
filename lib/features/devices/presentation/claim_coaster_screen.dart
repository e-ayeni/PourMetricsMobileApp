import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/beep_player.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../providers/claim_provider.dart';
import '../providers/devices_provider.dart';

/// Step 1 of the new coaster onboarding flow. The user scans the QR sticker
/// on the coaster; we POST /devices/claim (auto-assigning to the org's first
/// venue unless they explicitly pick a different one) and then route them on
/// to the Wi-Fi captive-portal instructions.
class ClaimCoasterScreen extends ConsumerStatefulWidget {
  const ClaimCoasterScreen({super.key});

  @override
  ConsumerState<ClaimCoasterScreen> createState() => _ClaimCoasterScreenState();
}

class _ClaimCoasterScreenState extends ConsumerState<ClaimCoasterScreen> {
  final MobileScannerController _scanner = MobileScannerController();
  bool _processing = false;
  String? _scannedDeviceId;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;

    _processing = true;
    await BeepPlayer.instance.playBeep();
    await _scanner.stop();

    if (!mounted) return;
    setState(() => _scannedDeviceId = raw);
    await _resolveVenueAndClaim(raw);
  }

  /// Pick a venue (or auto-resolve to the single one) and POST the claim.
  /// Auto-resolution is the 95% path; the bottom-sheet only opens when the
  /// org has multiple active venues and the user taps "Change venue".
  Future<void> _resolveVenueAndClaim(String deviceId,
      {String? overrideVenueId, String? overrideVenueName}) async {
    final venuesAsync = ref.read(venuesListProvider);
    final venues =
        (venuesAsync.valueOrNull ?? const []).cast<Map<String, dynamic>>();

    String? venueId = overrideVenueId;
    String? venueName = overrideVenueName;

    // If we don't have a venue yet and there's only one, send it explicitly so
    // the success screen can confirm which one was used. (The backend would
    // pick the same one anyway, but echoing it back to the user matters.)
    if (venueId == null && venues.length == 1) {
      venueId = venues.first['id']?.toString();
      venueName = venues.first['name'] as String?;
    }

    final result = await ref
        .read(claimControllerProvider)
        .claim(deviceId: deviceId, venueId: venueId);

    if (!mounted) return;
    await _showResult(result, deviceId, venues, venueName);
  }

  Future<void> _showResult(
    ClaimResult result,
    String deviceId,
    List<Map<String, dynamic>> venues,
    String? fallbackVenueName,
  ) async {
    switch (result.status) {
      case ClaimResultStatus.success:
        // Force the devices list to refetch so the new claim is reflected as
        // soon as the coaster comes online.
        ref.invalidate(devicesListProvider);
        await _showSuccess(result.venueName ?? fallbackVenueName, venues);
      case ClaimResultStatus.invalidQrCode:
        await _showRetryable(
          title: 'Not a coaster QR',
          body:
              'That barcode isn\'t a coaster QR code. Look for the small square sticker on the underside of the coaster.',
        );
      case ClaimResultStatus.noVenue:
        await _showFatal(
          title: 'No venue yet',
          body:
              'Create a venue in the app before claiming a coaster. The coaster needs somewhere to live.',
        );
      case ClaimResultStatus.alreadyRegistered:
        await _showFatal(
          title: 'Already registered',
          body:
              'This coaster is already set up. Check the Devices list — it should appear there.',
        );
      case ClaimResultStatus.alreadyClaimed:
        await _showFatal(
          title: 'Already claimed',
          body:
              'Another admin has already claimed this coaster. Wait for it to come online, or pick a different one.',
        );
      case ClaimResultStatus.unauthorized:
        await _showFatal(
          title: 'Permission needed',
          body:
              'Only Admin and Manager users can claim coasters. Ask your administrator.',
        );
      case ClaimResultStatus.networkError:
        await _showRetryable(
          title: 'Connection problem',
          body:
              'Couldn\'t reach PourMetrics. Check your internet and try again.',
        );
    }
  }

  Future<void> _showSuccess(
      String? venueName, List<Map<String, dynamic>> venues) async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 48),
              const SizedBox(height: 12),
              Text('Coaster claimed', style: AppTextStyles.title),
              const SizedBox(height: 8),
              Text(
                venueName == null
                    ? 'Now connect it to Wi-Fi to bring it online.'
                    : 'Assigned to $venueName. Now connect it to Wi-Fi to bring it online.',
                style: AppTextStyles.caption,
              ),
              if (venues.length > 1) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _changeVenue(venues);
                  },
                  child: const Text('Change venue'),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Hand off to the existing captive-portal instructions screen.
                  context.go('/devices/setup');
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: const Text('Continue to Wi-Fi setup'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// When the org has multiple venues and the user wants a different one. We
  /// re-issue the claim — the unique partial index on the backend means the
  /// old (unconsumed) row blocks us, so we tell the user that scenario isn't
  /// supported here and ask them to undo first. In practice this is rare:
  /// users almost always accept the auto-assigned venue.
  Future<void> _changeVenue(List<Map<String, dynamic>> venues) async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Choose a venue', style: AppTextStyles.title),
            ),
            ...venues.map((v) => ListTile(
                  leading: const Icon(Icons.store_outlined),
                  title: Text(v['name']?.toString() ?? 'Venue'),
                  subtitle: Text(v['address']?.toString() ?? ''),
                  onTap: () => Navigator.of(ctx).pop(v),
                )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;

    await _showFatal(
      title: 'Already assigned',
      body:
          'This coaster is now claimed to the first venue. To re-assign, edit it from the Devices list once it comes online.',
    );
  }

  Future<void> _showRetryable(
      {required String title, required String body}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pop(); // back out of the scanner entirely
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() {
                _processing = false;
                _scannedDeviceId = null;
              });
              await _scanner.start();
            },
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Future<void> _showFatal(
      {required String title, required String body}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _enterManually() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter coaster ID'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: '00000000-0000-0000-0000-000000000000',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Claim')),
        ],
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;

    _processing = true;
    setState(() => _scannedDeviceId = result);
    await _resolveVenueAndClaim(result);
  }

  @override
  Widget build(BuildContext context) {
    final venuesAsync = ref.watch(venuesListProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan coaster QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _scanner.toggleTorch(),
            tooltip: 'Toggle torch',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _scanner, onDetect: _onDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 2.5),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(140),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Hold the QR sticker on the underside of the coaster in the frame.',
                style: TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (_scannedDeviceId != null)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              ),
            ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (venuesAsync.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Loading your venues…',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                TextButton.icon(
                  onPressed: _enterManually,
                  icon: const Icon(Icons.keyboard, color: AppColors.primary),
                  label: const Text('Enter ID manually',
                      style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
