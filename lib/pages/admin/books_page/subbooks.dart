import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/admin/books_page/add_subbooks.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/utils/errors.dart';

class SubBooksPage extends StatefulWidget {
  final int bookId;

  const SubBooksPage({super.key, required this.bookId});

  @override
  State<SubBooksPage> createState() => _SubBooksPageState();
}

class _SubBooksPageState extends State<SubBooksPage> {
  List<dynamic> subBooks = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchSubBooks();
  }

  Future<void> fetchSubBooks() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await requestHelper.getWithAuth(
        '/api/sub-books/get-sub-book/${widget.bookId}',
        log: true,
      );

      if (response is Map && response['id'] != null) {
        subBooks = [response];
      } else if (response is List) {
        subBooks = response;
      }

      setState(() => isLoading = false);
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

  Future<void> deleteSubBook(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление файла'),
        content: const Text('Вы уверены, что хотите удалить этот файл?'),
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
        '/api/sub-books/delete-sub-book/$id',
        log: true,
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Файл успешно удалён')));
      fetchSubBooks();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Файлы книги')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddSubBookPage(bookId: widget.bookId),
            ),
          );
          fetchSubBooks();
        },
        child: const Icon(Icons.add),
      ),
      body: Builder(
        builder: (context) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (errorMessage != null) {
            return Center(child: Text(errorMessage!));
          }
          if (subBooks.isEmpty) {
            return const Center(child: Text('Файлов пока нет'));
          }

          return RefreshIndicator(
            onRefresh: fetchSubBooks,
            child: ListView.builder(
              itemCount: subBooks.length,
              itemBuilder: (context, i) {
                final s = subBooks[i];
                final photoUrl =
                    'https://etimolog.uz/_files${s['photo'] ?? ''}';
                return ListTile(
                  leading: Image.network(photoUrl),
                  title: Text(s['title'] ?? 'Без названия'),
                  subtitle: Text('Язык ID: ${s['lang_id']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.grey),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddSubBookPage(
                                bookId: widget.bookId,
                                existingData: s,
                              ),
                            ),
                          );
                          fetchSubBooks();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => deleteSubBook(s['id']),
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
