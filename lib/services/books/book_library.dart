import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/services/utils/constants.dart';
import 'package:path_provider/path_provider.dart';

/// Books stored on the phone for offline reading.
///
/// Layout in the app documents folder:
///   `mbooks/reader.html`, reader.css, reader.js, fonts/   (from the app assets)
///   `mbooks/{bookId}/book.js`, manifest.json, images/, .version   (bought books)
///   `mbooks/p{bookId}/book.js`   (free sample)
///
/// The reader page sits next to the books, so the WebView loads
/// `./{bookId}/book.js` with plain file access on Android and iOS.
class BookLibrary {
  BookLibrary._();
  static final BookLibrary instance = BookLibrary._();

  final Dio _dio = Dio();
  Directory? _root;

  static const _readerFonts = [
    'Inter-400.ttf', 'Inter-600.ttf',
    'Literata-400.ttf', 'Literata-400Italic.ttf', 'Literata-700.ttf',
    'Lora-400.ttf', 'Lora-400Italic.ttf', 'Lora-700.ttf',
    'PTSerif-400.ttf', 'PTSerif-400Italic.ttf', 'PTSerif-700.ttf',
  ];

  Future<Directory> root() async {
    if (_root != null) return _root!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/mbooks');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _root = dir;
  }

  /// Copies the bundled reader engine (always, so app updates ship new reader code).
  Future<File> readerFile() async {
    final dir = await root();
    for (final name in ['reader.html', 'reader.css', 'reader.js']) {
      final data = await rootBundle.load('assets/reader/$name');
      await File('${dir.path}/$name').writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    final fonts = Directory('${dir.path}/fonts');
    await fonts.create(recursive: true);
    for (final f in _readerFonts) {
      final out = File('${fonts.path}/$f');
      if (await out.exists()) continue;
      final data = await rootBundle.load('assets/fonts/$f');
      await out.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return File('${dir.path}/reader.html');
  }

  Future<Directory> bookDir(String id) async => Directory('${(await root()).path}/$id');

  /// Version of the downloaded package, or null when the book is not on the phone.
  Future<int?> localVersion(String id) async {
    final dir = await bookDir(id);
    if (!await File('${dir.path}/book.js').exists()) return null;
    final v = File('${dir.path}/.version');
    if (!await v.exists()) return 0;
    return int.tryParse((await v.readAsString()).trim()) ?? 0;
  }

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
      await _downloadAuthed('/api/books/$id/package.zip', zipFile.path, onProgress);
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
      await tmpDir.create(recursive: true);
      final input = InputFileStream(zipFile.path);
      await extractArchiveToDisk(ZipDecoder().decodeStream(input), tmpDir.path);
      await input.close();
      if (!await File('${tmpDir.path}/book.js').exists()) throw ApiException("Kitob fayli buzilgan. Qayta yuklab ko'ring");
      await File('${tmpDir.path}/.version').writeAsString('${book['package_version'] ?? 1}');
      // Card data for the library when there is no internet.
      await File('${tmpDir.path}/.meta.json').writeAsString(jsonEncode(book));
      final target = await bookDir(id);
      if (await target.exists()) await target.delete(recursive: true);
      await tmpDir.rename(target.path);
    } finally {
      if (await zipFile.exists()) await zipFile.delete();
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
    }
  }

  /// Free sample: the first chapters, readable without buying.
  Future<String> downloadPreview(Map book) async {
    final id = book['id'].toString();
    final dir = Directory('${(await root()).path}/p$id');
    await dir.create(recursive: true);
    await _downloadAuthed('/api/books/$id/preview.js', '${dir.path}/book.js', null);
    return 'p$id';
  }

  /// Books on the phone, newest download first (used offline).
  Future<List<Map>> offlineBooks() async {
    final out = <(DateTime, Map)>[];
    await for (final d in (await root()).list()) {
      final meta = File('${d.path}/.meta.json');
      if (d is! Directory || !await meta.exists()) continue;
      try {
        out.add((await meta.lastModified(), Map.from(jsonDecode(await meta.readAsString()))));
      } catch (_) {}
    }
    out.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final e in out) e.$2];
  }

  Future<void> remove(String id) async {
    final dir = await bookDir(id);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Bytes used by downloaded books.
  Future<int> usedBytes() async {
    var total = 0;
    final dir = await root();
    await for (final f in dir.list(recursive: true)) {
      if (f is File && !f.path.contains('${Platform.pathSeparator}fonts')) total += await f.length();
    }
    return total;
  }

  Future<void> _downloadAuthed(String path, String savePath, void Function(double)? onProgress, {bool retry = true}) async {
    try {
      await _dio.download(
        '${Constants.baseUrl}$path',
        savePath,
        options: Options(headers: {if (api.accessToken != null) 'Authorization': 'Bearer ${api.accessToken}'}),
        onReceiveProgress: (r, t) => t > 0 && onProgress != null ? onProgress(r / t) : null,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 && retry) {
        // Let the API client refresh the token, then try once more.
        try {
          await api.get('/api/me');
          return await _downloadAuthed(path, savePath, onProgress, retry: false);
        } catch (_) {}
      }
      if (status == 403) throw ApiException("Bu kitobni o'qish uchun avval sotib oling", status: 403);
      if (status == 404) throw ApiException('Kitob topilmadi', status: 404);
      throw ApiException("Yuklab bo'lmadi. Internetni tekshiring", status: status);
    }
  }

  // ---- reading progress sync -------------------------------------------

  Future<Map<String, dynamic>?> fetchReading(String id) async {
    try {
      final r = await api.get('/api/books/$id/reading');
      return r is Map ? Map<String, dynamic>.from(r) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> pushReading(String id, Map<String, dynamic> state) async {
    try {
      await api.put('/api/books/$id/reading', state);
    } catch (_) {
      // Offline: the reader keeps everything locally and sends it next time.
    }
  }
}
