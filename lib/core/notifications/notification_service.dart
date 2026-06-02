import 'dart:convert';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ── Background message handler (top-level, required by FCM) ──────────────────

/// Must be a top-level function — FCM runs it in an isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised before this runs.
  await NotificationService.instance.showLocal(
    title: message.notification?.title ?? 'PourMetrics Alert',
    body: message.notification?.body ?? '',
    payload: jsonEncode(message.data),
  );
}

// ── Notification channel ──────────────────────────────────────────────────────

const _alertChannel = AndroidNotificationChannel(
  'pourmetrics_alerts',
  'PourMetrics Alerts',
  description: 'Oversize pours, after-hours events, and device warnings.',
  importance: Importance.high,
  playSound: true,
);

// ── Service ───────────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  /// The most recent FCM token, available after [initialise].
  String? latestToken;

  void Function(String token)? _onToken;

  /// Call once from main() after Firebase.initializeApp().
  Future<void> initialise({
    /// Called when the user taps a notification while the app is open or
    /// in the background. Use [payload] to navigate to the relevant screen.
    void Function(String? payload)? onTap,

    /// Called with the FCM token on first acquisition and on every refresh.
    /// Wire this to POST the token to the backend once authenticated.
    void Function(String token)? onToken,
  }) async {
    if (_initialised) return;
    _initialised = true;
    _onToken = onToken;

    // ── Local notifications setup ─────────────────────────────────────────
    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const iOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: iOS),
      onDidReceiveNotificationResponse: (details) =>
          onTap?.call(details.payload),
    );

    // Create high-importance channel on Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_alertChannel);

    // ── FCM setup ─────────────────────────────────────────────────────────
    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS + Android 13+)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[Notifications] Permission denied');
      return;
    }

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground messages — show as local notification
    FirebaseMessaging.onMessage.listen((message) {
      showLocal(
        title: message.notification?.title ?? 'PourMetrics Alert',
        body: message.notification?.body ?? '',
        payload: jsonEncode(message.data),
      );
    });

    // Notification tap while app is terminated / background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onTap?.call(jsonEncode(message.data));
    });

    // Acquire the token and surface it for backend registration.
    final token = await messaging.getToken();
    if (token != null) {
      latestToken = token;
      _onToken?.call(token);
    }

    // Re-register whenever FCM rotates the token.
    messaging.onTokenRefresh.listen((t) {
      latestToken = t;
      _onToken?.call(t);
    });
  }

  /// Shows an immediate local notification (used for foreground + background).
  Future<void> showLocal({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _alertChannel.id,
          _alertChannel.name,
          channelDescription: _alertChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
          color: const Color(0xFFC17D2B),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }
}
