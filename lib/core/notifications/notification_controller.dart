import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dio_provider.dart';
import '../router/app_router.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'notification_service.dart';

final notificationControllerProvider =
    Provider<NotificationController>((ref) => NotificationController(ref));

/// Ties [NotificationService] to the rest of the app: routes notification taps,
/// and registers the FCM token with the backend whenever the user is
/// authenticated (initial token, token refresh, or a fresh login).
class NotificationController {
  NotificationController(this._ref) {
    // Re-register the token after a login so a newly signed-in user receives
    // alerts on this device.
    _ref.listen<AsyncValue<AuthState>>(authProvider, (_, next) {
      if (next.valueOrNull?.status == AuthStatus.authenticated) {
        _registerToken(NotificationService.instance.latestToken);
      }
    });
  }

  final Ref _ref;

  Future<void> init() async {
    await NotificationService.instance.initialise(
      onTap: _handleTap,
      onToken: _registerToken,
    );
  }

  void _handleTap(String? payload) {
    // Payload carries alertId/alertType/venueId; for now route to the alerts
    // list. Granular deep-links can branch on the decoded type here.
    if (payload != null) {
      try {
        jsonDecode(payload);
      } catch (_) {/* tolerate non-JSON payloads */}
    }
    try {
      _ref.read(routerProvider).go('/alerts');
    } catch (e) {
      debugPrint('[Notifications] navigation on tap failed: $e');
    }
  }

  Future<void> _registerToken(String? token) async {
    if (token == null || token.isEmpty) return;
    if (_ref.read(authProvider).valueOrNull?.status !=
        AuthStatus.authenticated) {
      return; // will retry on the auth listener when the user logs in
    }
    try {
      await _ref.read(dioProvider).post(
        '/users/me/fcm-token',
        data: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );
    } catch (e) {
      debugPrint('[Notifications] token registration failed: $e');
    }
  }
}
