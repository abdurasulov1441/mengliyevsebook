import 'dart:io';
import 'dart:typed_data';
import 'package:epub_pro/epub_pro.dart';

class EpubReaderService {
  // Читаем книгу (полная загрузка)
  static Future<EpubBook> readBook(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('EPUB fayl topilmadi: $filePath');
      }

      final bytes = await file.readAsBytes();
      return await EpubReader.readBook(bytes);
    } catch (e) {
      print('EPUB reading error: $e');
      rethrow;
    }
  }

  // Открываем книгу для ленивой загрузки (быстрее)
  static Future<EpubBookRef> openBook(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('EPUB fayl topilmadi: $filePath');
      }

      final bytes = await file.readAsBytes();
      return await EpubReader.openBook(bytes);
    } catch (e) {
      print('EPUB lazy loading error: $e');
      rethrow;
    }
  }

  // Читаем книгу с разделением глав
  static Future<EpubBook> readBookWithSplitChapters(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      return await EpubReader.readBookWithSplitChapters(bytes);
    } catch (e) {
      print('EPUB with split chapters error: $e');
      rethrow;
    }
  }

  // Получаем информацию о книге
  static Future<Map<String, dynamic>> getBookInfo(String filePath) async {
    try {
      final bookRef = await openBook(filePath);

      return {
        'title': bookRef.title ?? 'Noma\'lum',
        'author': bookRef.author ?? 'Muallif',
        'authors': bookRef.authors?.join(', ') ?? '',
        'coverImage': await _getCoverImage(bookRef),
        'chapterCount': (await bookRef.getChapters()).length,
        'success': true,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Получаем обложку книги
  static Future<Uint8List?> _getCoverImage(EpubBookRef bookRef) async {
    try {
      final cover = bookRef.title;
      if (cover != null) {}
      return null;
    } catch (e) {
      print('Cover image error: $e');
      return null;
    }
  }

  // Проверяем валидность EPUB файла
  static Future<bool> validateEpubFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final bytes = await file.readAsBytes();
      await EpubReader.openBook(bytes);
      return true;
    } catch (e) {
      print('EPUB validation error: $e');
      return false;
    }
  }

  // Получаем главы с ленивой загрузкой
  static Future<List<EpubChapterRef>> getChapters(String filePath) async {
    try {
      final bookRef = await openBook(filePath);
      return await bookRef.getChapters();
    } catch (e) {
      print('Get chapters error: $e');
      return [];
    }
  }

  // Получаем HTML контент главы
  static Future<String?> getChapterContent(EpubChapterRef chapterRef) async {
    try {
      return await chapterRef.readHtmlContent();
    } catch (e) {
      print('Chapter content error: $e');
      return null;
    }
  }
}
