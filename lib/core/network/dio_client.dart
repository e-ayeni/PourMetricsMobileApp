import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';
import 'mock_interceptor.dart';

// TODO: remove before release — keep in sync with auth_provider.dart
const _bypassAuth = true;

Dio createDioClient() {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  if (_bypassAuth) {
    // MockInterceptor runs first and short-circuits all requests with fake data.
    dio.interceptors.add(MockInterceptor());
  } else {
    dio.interceptors.add(_AuthInterceptor(dio));
  }

  return dio;
}

class _AuthInterceptor extends QueuedInterceptorsWrapper {
  _AuthInterceptor(this._dio);

  final Dio _dio;
  // A separate plain Dio instance used only for token refresh — avoids recursion.
  final Dio _refreshDio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SecureStorage.instance.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final refreshToken = await SecureStorage.instance.getRefreshToken();
    if (refreshToken == null) {
      await _handleLogout(handler, err);
      return;
    }

    try {
      final response = await _refreshDio.post(
        ApiConstants.refresh,
        data: {'refreshToken': refreshToken},
      );

      final newAccess = response.data['accessToken'] as String;
      final newRefresh = response.data['refreshToken'] as String;
      final role = await SecureStorage.instance.getRole() ?? '';

      await SecureStorage.instance.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
        role: role,
      );

      // Retry original request with new token
      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer $newAccess';
      final retried = await _dio.fetch(opts);
      handler.resolve(retried);
    } on DioException {
      await _handleLogout(handler, err);
    }
  }

  Future<void> _handleLogout(
      ErrorInterceptorHandler handler, DioException err) async {
    await SecureStorage.instance.clear();
    handler.next(err);
  }
}
