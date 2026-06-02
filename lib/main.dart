import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/db/app_database.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/notifications/notification_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Eagerly open SQLite so the first cache read is fast.
  await AppDatabase.instance.pendingCount();

  // Initialise Firebase + push notifications. Guarded so a missing
  // google-services.json / GoogleService-Info.plist (e.g. local dev before
  // Firebase is configured) doesn't crash launch — notifications simply stay
  // off until the config is added.
  var notificationsReady = false;
  try {
    await Firebase.initializeApp();
    notificationsReady = true;
  } catch (e) {
    debugPrint('[Startup] Firebase not configured; notifications disabled: $e');
  }

  runApp(ProviderScope(
    child: PourMetricsApp(notificationsReady: notificationsReady),
  ));
}

class PourMetricsApp extends ConsumerStatefulWidget {
  const PourMetricsApp({super.key, this.notificationsReady = false});

  final bool notificationsReady;

  @override
  ConsumerState<PourMetricsApp> createState() => _PourMetricsAppState();
}

class _PourMetricsAppState extends ConsumerState<PourMetricsApp> {
  @override
  void initState() {
    super.initState();
    if (widget.notificationsReady) {
      // Fire-and-forget; the controller handles auth timing + token refresh.
      ref.read(notificationControllerProvider).init();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'PourMetrics',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
