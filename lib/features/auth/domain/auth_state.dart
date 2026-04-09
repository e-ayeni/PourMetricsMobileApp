enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String? role;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.role,
    this.error,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({AuthStatus? status, String? role, String? error}) =>
      AuthState(
        status: status ?? this.status,
        role: role ?? this.role,
        error: error,
      );
}
