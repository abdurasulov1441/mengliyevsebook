import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mengliyevsebook/services/db/cache.dart';
import 'package:mengliyevsebook/services/utils/constants.dart';
import 'package:path_provider/path_provider.dart';

/// Offline book storage.
///
/// Layout inside the app documents folder:
///   mbooks/reader.html, reader.css, reader.js   (copied from assets/reader)
///   `mbooks/{bookId}/book.js`, manifest.json, images/, .version
///
/// The reader page lives next to the books so the WebView can load
/// `./{bookId}/book.js` with plain file access on Android and iOS.
class BookLibrary {
  BookLibrary._();
  static final BookLibrary instance = BookLibrary._();

  final Dio _dio = Dio();
  Directory? _root;

  Future<Directory> root() async {
    if (_root != null) return _root!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/mbooks');
    if (!await dir.exists()) await dir.create(recursive: true);
    _root = dir;
    return dir;
  }

  /// Copies the bundled reader engine (always, so app updates ship new reader code).
  Future<File> readerFile() async {
    final dir = await root();
    for (final name in ['reader.html', 'reader.css', 'reader.js']) {
      final data = await rootBundle.load('assets/reader/$name');
      await File('${dir.path}/$name').writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return File('${dir.path}/reader.html');
  }

  Future<Directory> bookDir(String id) async => Directory('${(await root()).path}/$id');

  /// Version of the downloaded package, or null when the book is not on the device.
  Future<int?> localVersion(String id) async {
    final dir = await bookDir(id);
    final js = File('${dir.path}/book.js');
    if (!await js.exists()) return null;
    final v = File('${dir.path}/.version');
    if (!await v.exists()) return 0;
    return int.tryParse((await v.readAsString()).trim()) ?? 0;
  }

  /// True when the book is downloaded and matches the server version.
  Future<bool> isUpToDate(Map book) async {
    final local = await localVersion(book['id'].toString());
    if (local == null) return false;
    final remote = book['package_version'];
    return remote == null || local >= (remote as num).toInt();
  }

  /// Downloads `/api/books/{id}/package.zip` with the user's token and unpacks it.
  Future<void> download(Map book, {void Function(double progress)? onProgress}) async {
    final id = book['id'].toString();
    final dir = await root();
    final zipFile = File('${dir.path}/$id.download.zip');
    final tmpDir = Directory('${dir.path}/$id.tmp');
    try {
      await _downloadWithAuth('${Constants.baseUrl}/api/books/$id/package.zip', zipFile.path, onProgress);
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
      await tmpDir.create(recursive: true);
      final input = InputFileStream(zipFile.path);
      final archive = ZipDecoder().decodeStream(input);
      await extractArchiveToDisk(archive, tmpDir.path);
      await input.close();
      if (!await File('${tmpDir.path}/book.js').exists()) {
        throw Exception("Kitob fayli buzilgan. Qayta yuklab ko'ring");
      }
      await File('${tmpDir.path}/.version').writeAsString('${book['package_version'] ?? 1}');
      final target = await bookDir(id);
      if (await target.exists()) await target.delete(recursive: true);
      await tmpDir.rename(target.path);
    } finally {
      if (await zipFile.exists()) await zipFile.delete();
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
    }
  }

  Future<void> remove(String id) async {
    final dir = await bookDir(id);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<void> _downloadWithAuth(String url, String savePath, void Function(double)? onProgress, {bool retry = true}) async {
    final token = cache.getString('user_token');
    try {
      await _dio.download(
        url,
        savePath,
        options: Options(headers: {if (token != null) 'Authorization': 'Bearer $token'}),
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) onProgress(received / total);
        },
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 && retry && await _refresh()) {
        return _downloadWithAuth(url, savePath, onProgress, retry: false);
      }
      if (status == 403) throw Exception("Bu kitobni o'qish uchun avval sotib oling");
      if (status == 404) throw Exception('Kitob topilmadi');
      throw Exception("Yuklab bo'lmadi. Internetni tekshiring");
    }
  }

  Future<bool> _refresh() async {
    final refresh = cache.getString('refresh_token');
    if (refresh == null) return false;
    try {
      final r = await _dio.post('${Constants.baseUrl}/api/auth/refresh', data: {'refreshToken': refresh});
      final token = r.data['accessToken'];
      if (token == null) return false;
      await cache.setString('user_token', token);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---- reading progress sync -------------------------------------------

  Future<Map<String, dynamic>?> fetchReading(String id) async {
    try {
      final r = await _authed('GET', '/api/books/$id/reading');
      return r is Map<String, dynamic> ? r : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> pushReading(String id, Map<String, dynamic> state) async {
    try {
      await _authed('PUT', '/api/books/$id/reading', body: state);
    } catch (_) {
      // Offline: the reader keeps everything locally and sends it next time.
    }
  }

  Future<dynamic> _authed(String method, String path, {Object? body, bool retry = true}) async {
    final token = cache.getString('user_token');
    try {
      final r = await _dio.request(
        '${Constants.baseUrl}$path',
        data: body == null ? null : jsonEncode(body),
        options: Options(method: method, headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        }),
      );
      return r.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 && retry && await _refresh()) {
        return _authed(method, path, body: body, retry: false);
      }
      rethrow;
    }
  }
}
