import 'dart:convert';
import 'dart:developer';
import 'package:mengliyevsebook/app/router.dart';
import 'package:mengliyevsebook/services/db/cache.dart';
import 'package:mengliyevsebook/services/utils/constants.dart';
import 'package:mengliyevsebook/services/utils/errors.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

final class RequestHelper {
  final logger = Logger();
  final baseUrl = Constants.baseUrl;
  final dio = Dio();

  void logMethod(String message) {
    log(message);
  }

  String get token {
    final token = cache.getString("user_token");
    if (token == null) {
      // router.go(Routes.loginScreen);
    }
    if (token != null) return token;

    throw UnauthenticatedError();
  }

  Map<String, String> _buildHeaders(
    String token, {
    String? languageCode,
    bool isMultipart = false,
  }) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': isMultipart ? 'multipart/form-data' : 'application/json',
      'Accept': 'application/json',
      if (languageCode != null) 'Accept-Language': languageCode,
    };
  }

  Future<String> _refreshAccessToken(
    String refreshToken, {
    String? languageCode,
  }) async {
    try {
      final refreshResponse = await dio.post(
        '$baseUrl/api/services/zyber/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (languageCode != null) 'Accept-Language': languageCode,
          },
        ),
      );

      final newAccessToken = refreshResponse.data['accessToken'];
      if (newAccessToken == null || newAccessToken.split('.').length != 3) {
        router.go(Routes.loginScreen);
        throw UnauthenticatedError();
      }

      cache.setString('user_token', newAccessToken);
      return newAccessToken;
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          print('Invalid refresh token: $e');
          router.go(Routes.loginScreen);
          throw UnauthenticatedError();
        } else {
          print('Failed to refresh token: $e');
          throw Exception('Failed to refresh token: ${e.message}');
        }
      }
      print('Unexpected error during token refresh: $e');
      router.go(Routes.loginScreen);
      throw UnauthenticatedError();
    }
  }

  void _handleError(DioException e, String? languageCode) {
    logger.d([
      'ERROR',
      e.response?.statusCode,
      e.response?.statusMessage,
      e.response?.data,
    ]);

    final errorData = e.response?.data;
    switch (languageCode) {
      case 'ru':
        throw errorData?['translates']?['ru'] ??
            errorData?['message'] ??
            'Неизвестная ошибка';
      case 'uz':
        throw errorData?['translates']?['uz'] ??
            errorData?['message'] ??
            'Nomaʼlum xatolik';
      case 'uk':
        throw errorData?['translates']?['oz'] ??
            errorData?['message'] ??
            'Невідома помилка';
      default:
        throw errorData?['message'] ?? 'Nomaʼlum xatolik';
    }
  }

  Future<dynamic> get(
    String path, {
    bool log = false,
    CancelToken? cancelToken,
    String? languageCode,
  }) async {
    final response = await dio.get(baseUrl + path, cancelToken: cancelToken);

    if (log) {
      logger.d([
        'GET',
        path,
        response.statusCode,
        response.statusMessage,
        response.data,
      ]);

      logMethod(jsonEncode(response.data));
    }

    return response.data;
  }

  Future<dynamic> getWithAuth(
    String path, {
    bool log = false,
    CancelToken? cancelToken,
    String? languageCode,
  }) async {
    String? accessToken = cache.getString('user_token');
    String? refreshToken = cache.getString('refresh_token');

    Map<String, String> buildHeaders(String token) {
      return {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (languageCode != null) 'Accept-Language': languageCode,
      };
    }

    Future<Response> performRequest(String token) {
      return dio.get(
        baseUrl + path,
        cancelToken: cancelToken,
        options: Options(headers: buildHeaders(token)),
      );
    }

    try {
      final response = await performRequest(accessToken!);

      if (log) {
        logger.d([
          'GET',
          path,
          buildHeaders(accessToken),
          response.statusCode,
          response.statusMessage,
          response.data,
        ]);
        logMethod(jsonEncode(response.data));
      }

      return response.data;
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      if (status == 401 || status == 403) {
        print('Access token expired or invalid: asd $status');

        try {
          final refreshResponse = await dio.post(
            '$baseUrl/api/services/zyber/auth/refresh',
            data: {'refreshToken': refreshToken},
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                if (languageCode != null) 'Accept-Language': languageCode,
              },
            ),
          );
          print(
            'refreshResponse: from server refresh token send $refreshResponse',
          );
          final newAccessToken = refreshResponse.data['accessToken'];
          if (newAccessToken == null) {
            print('Invalid new access token: $newAccessToken');
            router.go(Routes.loginScreen);
            throw UnauthenticatedError();
          }
          print('newAccessToken: $newAccessToken');

          cache.setString('user_token', newAccessToken);

          print('new access token saved: $newAccessToken');

          final retryResponse = await performRequest(newAccessToken);

          if (log) {
            logger.d([
              'GET (retry)',
              path,
              buildHeaders(newAccessToken),
              retryResponse.statusCode,
              retryResponse.statusMessage,
              retryResponse.data,
            ]);
            logMethod(jsonEncode(retryResponse.data));
          }

          return retryResponse.data;
        } catch (_) {
          print('Error during token refresh: go to login screen');
          router.go(Routes.loginScreen);
          throw UnauthenticatedError();
        }
      }

      logger.d([
        'GET ERROR',
        path,
        buildHeaders(accessToken ?? ''),
        e.response?.statusCode,
        e.response?.statusMessage,
        e.response?.data,
      ]);

      final errorData = e.response?.data;
      switch (languageCode) {
        case 'ru':
          throw errorData?['translates']?['ru'] ?? errorData?['message'];
        case 'uz':
          throw errorData?['translates']?['uz'] ?? errorData?['message'];
        case 'uk':
          throw errorData?['translates']?['oz'] ?? errorData?['message'];
        default:
          throw errorData?['message'] ?? 'Nomaʼlum xatolik';
      }
    } catch (_) {
      rethrow;
    }
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool log = false,
    CancelToken? cancelToken,
    String? languageCode,
  }) async {
    try {
      final response = await dio.post(
        baseUrl + path,
        cancelToken: cancelToken,
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (languageCode != null) 'Accept-Language': languageCode,
          },
        ),
      );

      if (log) {
        logger.d([
          'POST',
          path,
          body,
          response.statusCode,
          response.statusMessage,
          response.data,
        ]);

        logMethod(jsonEncode(response.data));
      }

      return response.data;
    } on DioException catch (e) {
      logger.d([
        'POST',
        path,
        body,
        e.response?.statusCode,
        e.response?.statusMessage,
        e.response?.data,
      ]);

      if (e.response?.statusCode == 400) {
        throw e.response?.data['response']?['message'];
      }

      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        router.go(Routes.homeScreen);
        if (path == "/api/services/zyber/auth/refresh") {
          router.go(Routes.loginScreen);
          throw Unauthenticated();
        }
        throw UnauthenticatedError();
      }

      throw e.response?.data['message'];
    } catch (_) {
      rethrow;
    }
  }

  Future<dynamic> postWithAuth(
    String path,
    Map<String, dynamic> body, {
    bool log = false,
    CancelToken? cancelToken,
    String? languageCode,
  }) async {
    String? accessToken = cache.getString('user_token');
    String? refreshToken = cache.getString('refresh_token');

    Map<String, String> buildHeaders(String token) {
      return {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (languageCode != null) 'Accept-Language': languageCode,
      };
    }

    Future<Response> performRequest(String token) {
      return dio.post(
        baseUrl + path,
        cancelToken: cancelToken,
        data: body,
        options: Options(headers: buildHeaders(token)),
      );
    }

    try {
      final response = await performRequest(accessToken!);

      if (log) {
        logger.d([
          'POST',
          path,
          buildHeaders(accessToken),
          body,
          response.statusCode,
          response.statusMessage,
          response.data,
        ]);
        logMethod(jsonEncode(response.data));
      }

      return response.data;
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      if (status == 401 || status == 403) {
        try {
          final refreshResponse = await dio.post(
            '$baseUrl/api/services/zyber/auth/refresh',
            data: {'refreshToken': refreshToken},
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                if (languageCode != null) 'Accept-Language': languageCode,
              },
            ),
          );

          final newAccessToken = refreshResponse.data['accessToken'];
          if (newAccessToken == null) {
            router.go(Routes.loginScreen);
            throw UnauthenticatedError();
          }

          cache.setString('user_token', newAccessToken);

          final retryResponse = await performRequest(newAccessToken);

          if (log) {
            logger.d([
              'POST (retry)',
              path,
              buildHeaders(newAccessToken),
              body,
              retryResponse.statusCode,
              retryResponse.statusMessage,
              retryResponse.data,
            ]);
            logMethod(jsonEncode(retryResponse.data));
          }

          return retryResponse.data;
        } catch (refreshError) {
          router.go(Routes.loginScreen);
          throw UnauthenticatedError();
        }
      }

      logger.d([
        'POST ERROR',
        path,
        buildHeaders(accessToken ?? ''),
        body,
        e.response?.statusCode,
        e.response?.statusMessage,
        e.response?.data,
        languageCode,
      ]);

      final errorData = e.response?.data;
      switch (languageCode) {
        case 'ru':
          throw errorData?['translates']?['ru'] ?? errorData?['message'];
        case 'uz':
          throw errorData?['translates']?['uz'] ?? errorData?['message'];
        case 'uk':
          throw errorData?['translates']?['oz'] ?? errorData?['message'];
        default:
          throw errorData?['message'] ?? 'Nomaʼlum xatolik';
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    bool log = false,
    CancelToken? cancelToken,
    String? languageCode,
  }) async {
    try {
      final response = await dio.put(
        baseUrl + path,
        cancelToken: cancelToken,
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (languageCode != null) 'Accept-Language': languageCode,
          },
        ),
      );

      if (log) {
        logger.d([
          'PUT',
          path,
          body,
          response.statusCode,
          response.statusMessage,
          response.data,
        ]);
      }

      return response.data;
    } on DioException catch (e) {
      logger.d([
        'POST',
        path,
        body,
        e.response?.statusCode,
        e.response?.statusMessage,
        e.response?.data,
      ]);
      return e.response?.data;
    } catch (_) {
      rethrow;
    }
  }

  Future<dynamic> putWithAuth(
    String path,
    Map<String, dynamic> body, {
    bool log = false,
    CancelToken? cancelToken,
    String? languageCode,
  }) async {
    String? accessToken = cache.getString('user_token');
    String? refreshToken = cache.getString('refresh_token');

    Map<String, String> buildHeaders(String token) {
      return {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (languageCode != null) 'Accept-Language': languageCode,
      };
    }

    Future<Response> performRequest(String token) {
      return dio.put(
        baseUrl + path,
        cancelToken: cancelToken,
        data: body,
        options: Options(headers: buildHeaders(token)),
      );
    }

    try {
      final response = await performRequest(accessToken!);

      if (log) {
        logger.d([
          'PUT',
          path,
          buildHeaders(accessToken),
          body,
          response.statusCode,
          response.statusMessage,
          response.data,
        ]);
        logMethod(jsonEncode(response.data));
      }

      return response.data;
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      if (status == 401 || status == 403) {
        try {
          final refreshResponse = await dio.post(
            '$baseUrl/api/services/zyber/auth/refresh',
            data: {'refreshToken': refreshToken},
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                if (languageCode != null) 'Accept-Language': languageCode,
              },
            ),
          );

          final newAccessToken = refreshResponse.data['accessToken'];
          if (newAccessToken == null) {
            router.go(Routes.loginScreen);
            throw UnauthenticatedError();
          }

          cache.setString('user_token', newAccessToken);

          final retryResponse = await performRequest(newAccessToken);

          if (log) {
            logger.d([
              'PUT (retry)',
              path,
              buildHeaders(newAccessToken),
              body,
              retryResponse.statusCode,
              retryResponse.statusMessage,
              retryResponse.data,
            ]);
            logMethod(jsonEncode(retryResponse.data));
          }

          return retryResponse.data;
        } catch (refreshError) {
          router.go(Routes.loginScreen);
          throw UnauthenticatedError();
        }
      }

      logger.d([
        'PUT ERROR',
        path,
        buildHeaders(accessToken ?? ''),
        body,
        e.response?.statusCode,
        e.response?.statusMessage,
        e.response?.data,
      ]);

      final errorData = e.response?.data;
      switch (languageCode) {
        case 'ru':
          throw errorData?['translates']?['ru'] ?? errorData?['message'];
        case 'uz':
          throw errorData?['translates']?['uz'] ?? errorData?['message'];
        case 'uk':
          throw errorData?['translates']?['oz'] ?? errorData?['message'];
        default:
          throw errorData?['message'] ?? 'Nomaʼlum xatolik';
      }
    } catch (_) {
      rethrow;
    }
  }

  Future<dynamic> delete(
    String path, {
    bool log = false,
    CancelToken? cancelToken,
    String? languageCode,
  }) async {
    try {
      final response = await dio.delete(
        baseUrl + path,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (languageCode != null) 'Accept-Language': languageCode,
          },
        ),
      );

      if (log) {
        logger.d([
          'DELETE',
          path,
          response.statusCode,
          response.statusMessage,
          response.data,
        ]);
      }

      return response.data;
    } on DioException catch (e) {
      logger.d([
        'DELETE',
        path,
        e.response?.statusCode,
        e.response?.statusMessage,
        e.response?.data,
      ]);
      return e.response?.data;
    } catch (_) {
      rethrow;
    }
  }

  Future<dynamic> deleteWithAuth(
    String path, {
    bool log = false,
    CancelToken? cancelToken,
    String? languageCode,
  }) async {
    String? accessToken = cache.getString('user_token');
    String? refreshToken = cache.getString('refresh_token');

    Map<String, String> buildHeaders(String token) {
      return {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (languageCode != null) 'Accept-Language': languageCode,
      };
    }

    Future<Response> performRequest(String token) {
      return dio.delete(
        baseUrl + path,
        cancelToken: cancelToken,
        options: Options(headers: buildHeaders(token)),
      );
    }

    try {
      final response = await performRequest(accessToken!);

      if (log) {
        logger.d([
          'DELETE',
          path,
          buildHeaders(accessToken),
          response.statusCode,
          response.statusMessage,
          response.data,
        ]);
        logMethod(jsonEncode(response.data));
      }

      return response.data;
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      if (status == 401 || status == 403) {
        try {
          final refreshResponse = await dio.post(
            '$baseUrl/api/services/zyber/auth/refresh',
            data: {'refreshToken': refreshToken},
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                if (languageCode != null) 'Accept-Language': languageCode,
              },
            ),
          );

          final newAccessToken = refreshResponse.data['accessToken'];
          if (newAccessToken == null) {
            router.go(Routes.loginScreen);
            throw UnauthenticatedError();
          }

          cache.setString('user_token', newAccessToken);

          final retryResponse = await performRequest(newAccessToken);

          if (log) {
            logger.d([
              'DELETE (retry)',
              path,
              buildHeaders(newAccessToken),
              retryResponse.statusCode,
              retryResponse.statusMessage,
              retryResponse.data,
            ]);
            logMethod(jsonEncode(retryResponse.data));
          }

          return retryResponse.data;
        } catch (_) {
          router.go(Routes.loginScreen);
          throw UnauthenticatedError();
        }
      }

      logger.d([
        'DELETE ERROR',
        path,
        buildHeaders(accessToken ?? ''),
        e.response?.statusCode,
        e.response?.statusMessage,
        e.response?.data,
      ]);

      final errorData = e.response?.data;
      switch (languageCode) {
        case 'ru':
          throw errorData?['translates']?['ru'] ?? errorData?['message'];
        case 'uz':
          throw errorData?['translates']?['uz'] ?? errorData?['message'];
        case 'uk':
          throw errorData?['translates']?['oz'] ?? errorData?['message'];
        default:
          throw errorData?['message'] ?? 'Nomaʼlum xatolik';
      }
    } catch (_) {
      rethrow;
    }
  }

  Future<dynamic> putWithAuthMultipart(
    String path,
    FormData body, {
    bool log = false,
    CancelToken? cancelToken,
    String? languageCode,
    Map<String, dynamic>? additionalParams,
  }) async {
    String? accessToken = cache.getString('user_token');
    String? refreshToken = cache.getString('refresh_token');

    String finalPath = path;
    if (additionalParams != null && additionalParams.isNotEmpty) {
      final queryParams = additionalParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      finalPath = '$path?$queryParams';
    }

    Future<Response> performRequest(String token) {
      return dio.put(
        baseUrl + finalPath,
        cancelToken: cancelToken,
        data: body,
        options: Options(
          headers: _buildHeaders(
            token,
            languageCode: languageCode,
            isMultipart: true,
          ),
        ),
      );
    }

    try {
      final response = await performRequest(accessToken!);

      if (log) {
        logger.d([
          'PUT MULTIPART',
          finalPath,
          _buildHeaders(
            accessToken,
            languageCode: languageCode,
            isMultipart: true,
          ),
          body.fields,
          response.statusCode,
          response.statusMessage,
          response.data,
        ]);
        logMethod(jsonEncode(response.data));
      }

      return response.data;
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      if (status == 401 || status == 403) {
        final newAccessToken = await _refreshAccessToken(
          refreshToken!,
          languageCode: languageCode,
        );
        final retryResponse = await performRequest(newAccessToken);

        if (log) {
          logger.d([
            'PUT MULTIPART (retry)',
            finalPath,
            _buildHeaders(
              newAccessToken,
              languageCode: languageCode,
              isMultipart: true,
            ),
            body.fields,
            retryResponse.statusCode,
            retryResponse.statusMessage,
            retryResponse.data,
          ]);
          logMethod(jsonEncode(retryResponse.data));
        }

        return retryResponse.data;
      }

      _handleError(e, languageCode);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> postWithAuthMultipart(
    String path,
    FormData body, {
    bool log = false,
    CancelToken? cancelToken,
    String? languageCode,
    Map<String, dynamic>? additionalParams,
  }) async {
    String? accessToken = cache.getString('user_token');
    String? refreshToken = cache.getString('refresh_token');

    String finalPath = path;
    if (additionalParams != null && additionalParams.isNotEmpty) {
      final queryParams = additionalParams.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      finalPath = '$path?$queryParams';
    }

    Future<Response> performRequest(String token) {
      return dio.post(
        baseUrl + finalPath,
        cancelToken: cancelToken,
        data: body,
        options: Options(
          headers: _buildHeaders(
            token,
            languageCode: languageCode,
            isMultipart: true,
          ),
        ),
      );
    }

    try {
      final response = await performRequest(accessToken!);

      if (log) {
        logger.d([
          'POST MULTIPART',
          finalPath,
          _buildHeaders(
            accessToken,
            languageCode: languageCode,
            isMultipart: true,
          ),
          body.fields,
          response.statusCode,
          response.statusMessage,
          response.data,
        ]);
        logMethod(jsonEncode(response.data));
      }

      return response.data;
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      if (status == 401 || status == 403) {
        final newAccessToken = await _refreshAccessToken(
          refreshToken!,
          languageCode: languageCode,
        );
        final retryResponse = await performRequest(newAccessToken);

        if (log) {
          logger.d([
            'POST MULTIPART (retry)',
            finalPath,
            _buildHeaders(
              newAccessToken,
              languageCode: languageCode,
              isMultipart: true,
            ),
            body.fields,
            retryResponse.statusCode,
            retryResponse.statusMessage,
            retryResponse.data,
          ]);
          logMethod(jsonEncode(retryResponse.data));
        }

        return retryResponse.data;
      }

      _handleError(e, languageCode);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    bool log = false,
    CancelToken? cancelToken,
    String? languageCode,
  }) async {
    try {
      final response = await dio.patch(
        baseUrl + path,
        cancelToken: cancelToken,
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (languageCode != null) 'Accept-Language': languageCode,
          },
        ),
      );

      if (log) {
        logger.d([
          'PATCH',
          path,
          body,
          response.statusCode,
          response.statusMessage,
          response.data,
        ]);
        logMethod(jsonEncode(response.data));
      }

      return response.data;
    } on DioException catch (e) {
      logger.d([
        'PATCH ERROR',
        path,
        body,
        e.response?.statusCode,
        e.response?.statusMessage,
        e.response?.data,
      ]);

      final errorData = e.response?.data;
      switch (languageCode) {
        case 'ru':
          throw errorData?['translates']?['ru'] ??
              errorData?['message'] ??
              'Неизвестная ошибка';
        case 'uz':
          throw errorData?['translates']?['uz'] ??
              errorData?['message'] ??
              'Nomaʼlum xatolik';
        case 'uk':
          throw errorData?['translates']?['oz'] ??
              errorData?['message'] ??
              'Невідома помилка';
        default:
          throw errorData?['message'] ?? 'Nomaʼlum xatolik';
      }
    } catch (_) {
      rethrow;
    }
  }

  Future<dynamic> patchWithAuth(
    String path,
    Map<String, dynamic> body, {
    bool log = false,
    CancelToken? cancelToken,
    String? languageCode,
  }) async {
    String? accessToken = cache.getString('user_token');
    String? refreshToken = cache.getString('refresh_token');

    Map<String, String> buildHeaders(String token) {
      return {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (languageCode != null) 'Accept-Language': languageCode,
      };
    }

    Future<Response> performRequest(String token) {
      return dio.patch(
        baseUrl + path,
        cancelToken: cancelToken,
        data: body,
        options: Options(headers: buildHeaders(token)),
      );
    }

    try {
      final response = await performRequest(accessToken!);

      if (log) {
        logger.d([
          'PATCH',
          path,
          buildHeaders(accessToken),
          body,
          response.statusCode,
          response.statusMessage,
          response.data,
        ]);
        logMethod(jsonEncode(response.data));
      }

      return response.data;
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      if (status == 401 || status == 403) {
        try {
          final refreshResponse = await dio.post(
            '$baseUrl/api/services/zyber/auth/refresh',
            data: {'refreshToken': refreshToken},
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                if (languageCode != null) 'Accept-Language': languageCode,
              },
            ),
          );

          final newAccessToken = refreshResponse.data['accessToken'];
          if (newAccessToken == null) {
            router.go(Routes.loginScreen);
            throw UnauthenticatedError();
          }

          cache.setString('user_token', newAccessToken);

          final retryResponse = await performRequest(newAccessToken);

          if (log) {
            logger.d([
              'PATCH (retry)',
              path,
              buildHeaders(newAccessToken),
              body,
              retryResponse.statusCode,
              retryResponse.statusMessage,
              retryResponse.data,
            ]);
            logMethod(jsonEncode(retryResponse.data));
          }

          return retryResponse.data;
        } catch (_) {
          router.go(Routes.loginScreen);
          throw UnauthenticatedError();
        }
      }

      logger.d([
        'PATCH ERROR',
        path,
        buildHeaders(accessToken ?? ''),
        body,
        e.response?.statusCode,
        e.response?.statusMessage,
        e.response?.data,
      ]);

      final errorData = e.response?.data;
      switch (languageCode) {
        case 'ru':
          throw errorData?['translates']?['ru'] ??
              errorData?['message'] ??
              'Неизвестная ошибка';
        case 'uz':
          throw errorData?['translates']?['uz'] ??
              errorData?['message'] ??
              'Nomaʼlum xatolik';
        case 'uk':
          throw errorData?['translates']?['oz'] ??
              errorData?['message'] ??
              'Невідома помилка';
        default:
          throw errorData?['message'] ?? 'Nomaʼlum xatolik';
      }
    } catch (_) {
      rethrow;
    }
  }
}

final requestHelper = RequestHelper();
