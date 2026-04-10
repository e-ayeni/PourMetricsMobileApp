import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/pours/presentation/pours_screen.dart';
import '../../features/alerts/presentation/alerts_screen.dart';
import '../../features/alerts/presentation/alert_config_screen.dart';
import '../../features/devices/presentation/devices_screen.dart'
import '../../features/devices/presentation/device_setup_screen.dart'
import '../../features/devices/presentation/device_setup_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/inventory/presentation/add_product_screen.dart';
import '../../features/inventory/presentation/register_bottle_screen.dart';
import '../../features/inventory/presentation/bottle_detail_screen.dart';
import '../../features/inventory/presentation/product_detail_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/users/presentation/users_screen.dart';
import '../widgets/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authAsync = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final auth = authAsync.valueOrNull;
      final isAuthenticated = auth?.status == AuthStatus.authenticated;
      final isGoingToLogin = state.matchedLocation == '/login';

      if (authAsync.isLoading) return null;

      if (!isAuthenticated && !isGoingToLogin) return '/login';
      if (isAuthenticated && isGoingToLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/pours',
            builder: (context, state) => const PoursScreen(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      // Full-screen routes outside the shell (no bottom nav)
      GoRoute(
        path: '/alerts',
        builder: (context, state) => const AlertsScreen(),
      ),
      GoRoute(
        path: '/alerts/config',
        builder: (context, state) => const AlertConfigScreen(),
      ),
      GoRoute(
        path: '/devices',
        builder: (context, state) => const DevicesScreen(),
      ),
      GoRoute(
        path: '/devices/setup',
        builder: (context, state) => const DeviceSetupScreen(),
      ),
      GoRoute(
        path: '/users',
        builder: (context, state) => const UsersScreen(),
      ),
      GoRoute(
        path: '/inventory/add-product',
        builder: (context, state) {
          final barcode = state.uri.queryParameters['barcode'];
          return AddProductScreen(prefillBarcode: barcode);
        },
      ),
      GoRoute(
        path: '/inventory/bottle/:id',
        builder: (context, state) =>
            BottleDetailScreen(bottleId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/inventory/product/:id',
        builder: (context, state) =>
            ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/inventory/register-bottle',
        builder: (context, state) {
          final productId = state.uri.queryParameters['productId'];
          final productName = state.uri.queryParameters['productName'];
          final rfidTag = state.uri.queryParameters['rfidTag'];
          return RegisterBottleScreen(
            prefillProductId: productId,
            prefillProductName: productName,
            prefillRfidTag: rfidTag,
          );
        },
      ),
    ],
  );
});
