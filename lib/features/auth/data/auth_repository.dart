import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/storage/secure_storage.dart';

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<void> login(String email, String password) async {
    final response = await _dio.post(
      ApiConstants.login,
      data: {'email': email, 'password': password},
    );
    final data = response.data as Map<String, dynamic>;
    final role = _extractRole(data['accessToken'] as String);
    await SecureStorage.instance.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      role: role,
    );
  }

  Future<void> logout() async {
    try {
      final token = await SecureStorage.instance.getRefreshToken();
      await _dio.post(ApiConstants.logout, data: {'refreshToken': token});
    } catch (_) {
      // Best-effort — clear storage regardless
    } finally {
      await SecureStorage.instance.clear();
    }
  }

  /// Extracts the `role` claim from a JWT payload without a third-party package.
  String _extractRole(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return 'Viewer';
      var payload = parts[1];
      // Base64Url → Base64 padding
      payload = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      return (map['role'] as String?) ?? 'Viewer';
    } catch (_) {
      return 'Viewer';
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider)),
);
