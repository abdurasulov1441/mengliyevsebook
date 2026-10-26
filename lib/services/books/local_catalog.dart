import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:mengliyevsebook/services/db/cache.dart';

/// Server-less book catalog (Constants.localMode).
///
/// Books live in assets/local_books/ (built with `npm run app-books` in
/// backend/). Purchases and reading progress are kept on the device, so the
/// whole flow — shop, buying, "my books", reading — can be tried without a
/// backend. Maps have the same shape as the server's book objects.
class LocalCatalog {
  LocalCatalog._();

  static List<Map<String, dynamic>>? _books;
  static const _purchasesKey = 'local_purchases';

  static Future<List<Map<String, dynamic>>> _load() async {
    if (_books != null) return _books!;
    final raw = await rootBundle.loadString('assets/local_books/catalog.json');
    _books = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return _books!;
  }

  static Map<String, String> _purchases() {
    final raw = cache.getString(_purchasesKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  static double _progress(String id) => double.tryParse(cache.getString('local_progress_$id') ?? '') ?? 0;

  /// All books with per-user fields filled in (has_access, progress, ...).
  static Future<List<Map<String, dynamic>>> all() async {
    final purchases = _purchases();
    return (await _load()).map((b) {
      final id = b['id'].toString();
      final bought = purchases[id];
      return {
        ...b,
        'is_purchased': bought != null,
        'purchase_date': bought,
        'has_access': b['is_free'] == true || bought != null,
        'progress': _progress(id),
      };
    }).toList();
  }

  /// "Mening kitoblarim": free books and bought ones, last read first.
  static Future<List<Map<String, dynamic>>> myBooks() async {
    final list = (await all()).where((b) => b['has_access'] == true).toList();
    list.sort((a, b) => (cache.getString('local_read_at_${b['id']}') ?? '').compareTo(cache.getString('local_read_at_${a['id']}') ?? ''));
    return list;
  }

  /// Shop: paid books.
  static Future<List<Map<String, dynamic>>> shopBooks() async => (await all()).where((b) => b['is_free'] != true).toList();

  /// Demo purchase: unlocks the book on this device.
  static Future<void> purchase(String id) async {
    final p = _purchases();
    p[id] = DateTime.now().toIso8601String();
    await cache.setString(_purchasesKey, jsonEncode(p));
  }

  static Future<void> resetPurchases() => cache.remove(_purchasesKey);

  static Future<void> saveProgress(String id, num percent) async {
    await cache.setString('local_progress_$id', percent.toString());
    await cache.setString('local_read_at_$id', DateTime.now().toIso8601String());
  }

  /// Files of one bundled book (book.js, manifest.json, images/...).
  static Future<List<String>> files(String id) async {
    final b = (await _load()).firstWhere((x) => x['id'].toString() == id, orElse: () => {});
    return ((b['files'] as List?) ?? const []).cast<String>();
  }
}
