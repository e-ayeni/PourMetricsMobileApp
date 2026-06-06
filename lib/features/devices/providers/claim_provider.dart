import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/providers/dio_provider.dart';

/// Outcome of a coaster-claim attempt. Keeps the screen layer free of HTTP
/// status-code knowledge — the UI just maps these to user-facing messages.
enum ClaimResultStatus {
  success,
  invalidQrCode,
  noVenue,
  alreadyRegistered,
  alreadyClaimed,
  unauthorized,
  networkError,
}

class ClaimResult {
  ClaimResult(this.status, {this.venueName, this.message});

  final ClaimResultStatus status;
  final String? venueName;
  final String? message;
}

class ClaimController {
  ClaimController(this._dio);

  final Dio _dio;

  /// POST /api/v1/devices/claim. The QR code encodes a UUID; `venueId` is
  /// optional — the backend auto-assigns to the org's first active venue when
  /// it's null (the zero-tap path for single-venue customers).
  Future<ClaimResult> claim({
    required String deviceId,
    String? venueId,
    String? barLocation,
  }) async {
    // Reject obviously-malformed payloads before the round-trip — a stray
    // barcode caught by the scanner shouldn't make it to the backend.
    if (!_looksLikeUuid(deviceId)) {
      return ClaimResult(ClaimResultStatus.invalidQrCode);
    }

    try {
      final response = await _dio.post(
        ApiConstants.deviceClaim,
        data: {
          'deviceId': deviceId,
          if (venueId != null) 'venueId': venueId,
          if (barLocation != null && barLocation.isNotEmpty)
            'barLocation': barLocation,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return ClaimResult(
        ClaimResultStatus.success,
        venueName: data['venueName'] as String?,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final msg = body is Map<String, dynamic> ? body['message'] as String? : null;
      return switch (status) {
        400 => ClaimResult(ClaimResultStatus.noVenue, message: msg),
        401 || 403 => ClaimResult(ClaimResultStatus.unauthorized, message: msg),
        409 when msg?.contains('already been registered') ?? false =>
          ClaimResult(ClaimResultStatus.alreadyRegistered, message: msg),
        409 => ClaimResult(ClaimResultStatus.alreadyClaimed, message: msg),
        _ => ClaimResult(ClaimResultStatus.networkError, message: e.message),
      };
    }
  }

  static bool _looksLikeUuid(String s) {
    // Standard 8-4-4-4-12 UUID, case-insensitive. Looser than a strict regex
    // on purpose — we still let the backend be the final authority.
    final r = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return r.hasMatch(s.trim());
  }
}

final claimControllerProvider = Provider<ClaimController>((ref) {
  return ClaimController(ref.watch(dioProvider));
});
