import 'dart:convert';
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

  /// Call once from main() after Firebase.initializeApp().
  Future<void> initialise({
    /// Called when the user taps a notification while the app is open or
    /// in the background. Use [payload] to navigate to the relevant screen.
    void Function(String? payload)? onTap,
  }) async {
    if (_initialised) return;
    _initialised = true;

    // ── Local notifications setup ─────────────────────────────────────────
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
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

    // Log the FCM token so you can send test pushes from Firebase console
    final token = await messaging.getToken();
    debugPrint('[Notifications] FCM token: $token');

    // TODO: POST token to backend so the server can target this device
    // await dio.post('/devices/fcm-token', data: {'token': token});
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
          icon: '@mipmap/ic_launcher',
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
