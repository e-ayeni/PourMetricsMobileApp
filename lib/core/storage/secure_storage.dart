import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage._() : _storage = const FlutterSecureStorage();
  static final SecureStorage instance = SecureStorage._();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _roleKey = 'role';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String role,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
      _storage.write(key: _roleKey, value: role),
    ]);
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);
  Future<String?> getRole() => _storage.read(key: _roleKey);

  // Synchronous role cache — populated at startup for router redirect guard
  String? _cachedRole;

  String? get cachedRole => _cachedRole;

  Future<void> loadCache() async {
    _cachedRole = await _storage.read(key: _roleKey);
  }

  Future<void> updateAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  Future<void> clear() async {
    _cachedRole = null;
    await _storage.deleteAll();
  }
}
