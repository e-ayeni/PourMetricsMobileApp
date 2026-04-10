import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/db/app_database.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Eagerly open the SQLite database so the first cache read is fast.
  await AppDatabase.instance.pendingCount();
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
