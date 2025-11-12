import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/user_page/books/authors_list.dart';
import 'package:mengliyevsebook/pages/user_page/books/geners_list.dart';
import 'package:mengliyevsebook/pages/user_page/books/new_arrivals.dart';
import 'package:mengliyevsebook/pages/user_page/books/top_reads_list.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/utils/errors.dart';
import 'package:mengliyevsebook/services/style/app_colors.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  bool isLoading = true;
  String? errorMessage;

  List<dynamic> genres = [];
  List<dynamic> authors = [];
  List<Map<String, dynamic>> books = [];

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // 🔹 Запрашиваем жанры, авторов и книги
      final catsResp = await requestHelper.getWithAuth(
        '/api/categories/categories',
      );
      final authResp = await requestHelper.getWithAuth(
        '/api/authors/get-authors?page=1&limit=20',
      );
      final booksResp = await requestHelper.getWithAuth('/api/books/get-books');

      if (catsResp is List) genres = catsResp;
      if (authResp is Map && authResp['authors'] is List) {
        authors = authResp['authors'];
      }

      // 🔹 Для каждой книги получаем sub-book (обложку, описание, файл)
      List<Map<String, dynamic>> enrichedBooks = [];
      if (booksResp is List) {
        for (final book in booksResp) {
          final bookId = book['id'];
          if (bookId == null) continue;

          try {
            final subResp = await requestHelper.getWithAuth(
              '/api/sub-books/get-sub-book/$bookId',
              log: false,
            );

            if (subResp is Map && subResp['id'] != null) {
              // Одиночный sub-book
              enrichedBooks.add({
                'id': bookId.toString(),
                'title': subResp['title'] ?? book['slug'] ?? 'No title',
                'author': book['author']?['uz'] ?? '',
                'image':
                    subResp['photo'] != null &&
                        subResp['photo'].toString().isNotEmpty
                    ? 'https://etimolog.uz/_files${subResp['photo']}'
                    : null,
              });
            } else if (subResp is List && subResp.isNotEmpty) {
              // Если несколько языков, берём первый
              final sub = subResp.first;
              enrichedBooks.add({
                'id': bookId.toString(),
                'title': sub['title'] ?? book['slug'] ?? 'No title',
                'author': book['author']?['uz'] ?? '',
                'image':
                    sub['photo'] != null && sub['photo'].toString().isNotEmpty
                    ? 'https://etimolog.uz/_files${sub['photo']}'
                    : null,
              });
            } else {
              // Книга без субов
              enrichedBooks.add({
                'id': bookId.toString(),
                'title': book['slug'] ?? 'No title',
                'author': book['author']?['uz'] ?? '',
                'image': null,
              });
            }
          } catch (_) {
            // если sub-book не найден, пропускаем
          }
        }
      }

      books = enrichedBooks;

      setState(() => isLoading = false);
    } on UnauthenticatedError {
      setState(() {
        errorMessage = 'Ошибка авторизации. Перезайдите в систему.';
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Ошибка загрузки данных: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ui,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(child: Text(errorMessage!))
            : RefreshIndicator(
                onRefresh: _fetchAll,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔍 Поисковая строка
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: "Qidiruv: kitob, muallif yoki janr",
                                  hintStyle: TextStyle(color: Colors.grey[500]),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            const Icon(Icons.mic_none, color: Colors.grey),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 🎭 Жанры
                      if (genres.isNotEmpty)
                        GenresList(
                          genres: genres
                              .map<String>(
                                (g) =>
                                    g['name']?['uz'] ??
                                    g['name']?['ru'] ??
                                    g['name']?['en'] ??
                                    'No name',
                              )
                              .toList(),
                        ),

                      const SizedBox(height: 20),

                      // 📚 Новые книги
                      if (books.isNotEmpty)
                        NewArrivals(
                          books: books
                              .map<Map<String, String>>(
                                (b) => {
                                  'id': b['id'] ?? '',
                                  'title': b['title'] ?? 'No title',
                                  'author': b['author'] ?? '',
                                  'image': b['image'] ?? '',
                                },
                              )
                              .toList(),
                        ),

                      const SizedBox(height: 20),

                      // ✍️ Авторы
                      if (authors.isNotEmpty)
                        AuthorsList(
                          authors: authors
                              .map<Map<String, String>>(
                                (a) => {
                                  'name':
                                      a['name']?['uz'] ??
                                      a['name']?['ru'] ??
                                      a['name']?['en'] ??
                                      'No name',
                                  'image': a['photo'] != null
                                      ? 'https://etimolog.uz/_files${a['photo']}'
                                      : '',
                                },
                              )
                              .toList(),
                        ),

                      const SizedBox(height: 20),

                      // 🌟 Top Reads (пока заглушка)
                      const TopReadsList(topReads: []),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
