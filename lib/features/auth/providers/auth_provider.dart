import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/auth_repository.dart';
import '../domain/auth_state.dart';

// TODO: remove before release — keep in sync with core/network/dio_client.dart
// false → real login flow; user must authenticate against the backend.
// true  → auto-signs in as a fake Admin and skips the login screen.
const _bypassAuth = false;

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    if (_bypassAuth) {
      return const AuthState(status: AuthStatus.authenticated, role: 'Admin');
    }
    // Load role cache so the router redirect can run synchronously
    await SecureStorage.instance.loadCache();
    final role = SecureStorage.instance.cachedRole;
    if (role != null) {
      return AuthState(status: AuthStatus.authenticated, role: role);
    }
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> login(String email, String password) async {
    if (_bypassAuth) {
      state = const AsyncData(
          AuthState(status: AuthStatus.authenticated, role: 'Admin'));
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).login(email, password);
      await SecureStorage.instance.loadCache();
      final role = SecureStorage.instance.cachedRole ?? 'Viewer';
      return AuthState(status: AuthStatus.authenticated, role: role);
    });
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
