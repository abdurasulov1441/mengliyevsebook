import 'package:flutter/material.dart';

import 'package:mengliyevsebook/pages/admin/books_page/bookd_add_page.dart';
import 'package:mengliyevsebook/pages/admin/books_page/subbooks.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/utils/errors.dart';

class BooksPage extends StatefulWidget {
  const BooksPage({super.key});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
  List<dynamic> books = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchBooks();
  }

  Future<void> fetchBooks() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await requestHelper.getWithAuth(
        '/api/books/get-books',
        log: true,
      );

      if (response is List) {
        setState(() {
          books = response;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Неверный формат данных';
          isLoading = false;
        });
      }
    } on UnauthenticatedError {
      setState(() {
        errorMessage = 'Ошибка авторизации. Перезайдите в систему.';
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Ошибка загрузки: $e';
        isLoading = false;
      });
    }
  }

  Future<void> deleteBook(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление книги'),
        content: const Text('Вы уверены, что хотите удалить эту книгу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await requestHelper.deleteWithAuth(
        '/api/books/delete-book/$id',
        log: true,
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Книга успешно удалена')));

      fetchBooks();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при удалении: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Книги')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddBookPage()),
          );
          fetchBooks();
        },
        child: const Icon(Icons.add),
      ),
      body: Builder(
        builder: (context) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(errorMessage!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: fetchBooks,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          if (books.isEmpty) {
            return const Center(child: Text('Книг пока нет'));
          }

          return RefreshIndicator(
            onRefresh: fetchBooks,
            child: ListView.separated(
              itemCount: books.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final book = books[index];
                final id = book['id'];
                final slug = book['slug'] ?? '';
                final author = book['author']?['uz'] ?? '';
                final category = book['category']?['uz'] ?? '';
                final price = book['price'] ?? '0';
                final isFree = book['is_free'] == true;

                return ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubBooksPage(bookId: id),
                      ),
                    ).then((_) => fetchBooks());
                  },

                  leading: const Icon(Icons.book, color: Colors.blueAccent),
                  title: Text(slug),
                  subtitle: Text(
                    'Автор: $author\nКатегория: $category\nЦена: ${isFree ? 'Бесплатно' : '$price сум'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.grey),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddBookPage(existingData: book),
                            ),
                          ).then((_) => fetchBooks());
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => deleteBook(id),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
