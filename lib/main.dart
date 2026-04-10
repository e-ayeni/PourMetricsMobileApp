import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/db/app_database.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
// ignore: unused_import — uncomment when Firebase is configured:
// import 'package:firebase_core/firebase_core.dart';
// import 'core/notifications/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Eagerly open SQLite so the first cache read is fast.
  await AppDatabase.instance.pendingCount();

  // TODO: Add google-services.json (Android) and GoogleService-Info.plist (iOS)
  // from your Firebase project, then uncomment the two lines below.
  //
  // await Firebase.initializeApp();
  // await NotificationService.instance.initialise(
  //   onTap: (payload) {
  //     // Navigate based on payload — e.g. push '/alerts' for alert payloads.
  //   },
  // );

  runApp(const ProviderScope(child: PourMetricsApp()));
}

class PourMetricsApp extends ConsumerWidget {
  const PourMetricsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'PourMetrics',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
