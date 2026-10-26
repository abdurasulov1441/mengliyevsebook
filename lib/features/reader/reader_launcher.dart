import 'package:flutter/material.dart';
import 'package:mengliyevsebook/features/reader/book_reader_page.dart';
import 'package:mengliyevsebook/services/books/book_events.dart';
import 'package:mengliyevsebook/services/books/book_library.dart';
import 'package:mengliyevsebook/widgets/common.dart';

/// Opens an owned book: downloads (or updates) it first if needed.
Future<void> openBook(BuildContext context, Map book, {void Function(double)? onProgress}) async {
  final library = BookLibrary.instance;
  final id = book['id'].toString();
  if (!await library.isUpToDate(book)) {
    final hadOld = await library.localVersion(id) != null;
    try {
      await library.download(book, onProgress: onProgress);
      notifyBooksChanged();
    } catch (e) {
      // An older copy is still readable offline.
      if (!hadOld) rethrow;
    }
  }
  if (!context.mounted) return;
  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => BookReaderPage(folder: id, bookId: id, title: (book['title'] ?? '').toString())));
  notifyBooksChanged();
  if (result == 'redownload' && context.mounted) await openBook(context, book, onProgress: onProgress);
}

/// Opens the free sample. Returns true if the reader asked to buy the book.
Future<bool> openPreview(BuildContext context, Map book) async {
  try {
    final folder = await BookLibrary.instance.downloadPreview(book);
    if (!context.mounted) return false;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookReaderPage(folder: folder, bookId: book['id'].toString(), title: (book['title'] ?? '').toString(), preview: true)),
    );
    return result == 'buy';
  } catch (e) {
    if (context.mounted) toast(context, errorText(e), error: true);
    return false;
  }
}
