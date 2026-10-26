import 'package:dio/dio.dart';
import 'package:mengliyevsebook/services/db/cache.dart';
import 'package:mengliyevsebook/services/utils/constants.dart';

/// Error with a message that can be shown to the user as is.
class ApiException implements Exception {
  final int? status;
  final String message;
  final dynamic data;

  /// No connection to the server (as opposed to an error answer).
  final bool offline;

  ApiException(this.message, {this.status, this.data, this.offline = false});

  bool get unauthorized => status == 401;

  @override
  String toString() => message;
}

/// HTTP client for the BookHub API: adds the access token, refreshes it once
/// on 401 and turns failures into [ApiException] with the server's message.
class Api {
  Api._() {
    _dio = Dio(BaseOptions(
      baseUrl: Constants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ));
  }

  static final Api instance = Api._();
  late final Dio _dio;

  /// Called when the session cannot be refreshed (user must log in again).
  void Function()? onSessionExpired;

  String? get accessToken => cache.getString('user_token');
  String? get refreshToken => cache.getString('refresh_token');
  bool get hasSession => accessToken != null;

  Future<void> saveTokens(String access, String refresh) async {
    await cache.setString('user_token', access);
    await cache.setString('refresh_token', refresh);
  }

  Future<void> clearTokens() async {
    await cache.remove('user_token');
    await cache.remove('refresh_token');
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Multipart upload with progress (books, covers, avatars).
  Future<dynamic> upload(String method, String path, FormData form, {void Function(double)? onProgress}) =>
      _send(method, path, body: form, onProgress: onProgress);

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, dynamic>? query, void Function(double)? onProgress, bool retry = true}) async {
    try {
      final res = await _dio.request(
        path,
        data: body,
        queryParameters: query,
        onSendProgress: onProgress == null ? null : (s, t) => t > 0 ? onProgress(s / t) : null,
        options: Options(method: method, headers: {if (accessToken != null) 'Authorization': 'Bearer $accessToken'}),
      );
      return res.data;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 && retry && refreshToken != null && !path.startsWith('/api/auth/')) {
        if (await _refresh()) {
          // A FormData stream can only be sent once.
          final again = body is FormData ? body.clone() : body;
          return _send(method, path, body: again, query: query, onProgress: onProgress, retry: false);
        }
        await clearTokens();
        onSessionExpired?.call();
      }
      throw _toException(e);
    }
  }

  Future<bool> _refresh() async {
    try {
      final res = await _dio.post('/api/auth/refresh', data: {'refreshToken': refreshToken});
      final token = res.data is Map ? res.data['accessToken'] : null;
      if (token == null) return false;
      await cache.setString('user_token', token);
      return true;
    } catch (_) {
      return false;
    }
  }

  ApiException _toException(DioException e) {
    final data = e.response?.data;
    final status = e.response?.statusCode;
    if (data is Map && data['message'] != null) return ApiException(data['message'].toString(), status: status, data: data);
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return ApiException("Server javob bermadi. Internetni tekshiring", status: status, offline: true);
      case DioExceptionType.connectionError:
        return ApiException("Internetga ulanib bo'lmadi", status: status, offline: true);
      default:
        return ApiException("Xatolik yuz berdi${status != null ? ' ($status)' : ''}", status: status);
    }
  }
}

final api = Api.instance;
