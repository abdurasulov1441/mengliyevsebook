import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/admin/authors_page/add_authors_page.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/utils/errors.dart';

class AuthorsPage extends StatefulWidget {
  const AuthorsPage({super.key});

  @override
  State<AuthorsPage> createState() => _AuthorsPageState();
}

class _AuthorsPageState extends State<AuthorsPage> {
  List<dynamic> authors = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchAuthors();
  }

  Future<void> fetchAuthors() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await requestHelper.getWithAuth(
        '/api/authors/get-authors?page=1&limit=50',
        log: true,
      );

      if (response is Map && response['authors'] is List) {
        setState(() {
          authors = response['authors'];
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

  Future<void> deleteAuthor(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление автора'),
        content: const Text('Вы уверены, что хотите удалить этого автора?'),
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
        '/api/authors/delete-author/$id',
        log: true,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Автор успешно удалён')),
      );

      fetchAuthors(); // 🔁 обновляем список
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при удалении: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Авторы')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddAuthorPage()),
          );
          fetchAuthors(); // 🔁 обновим после добавления
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
                    onPressed: fetchAuthors,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          if (authors.isEmpty) {
            return const Center(child: Text('Авторов пока нет'));
          }

          return RefreshIndicator(
            onRefresh: fetchAuthors,
            child: ListView.separated(
              itemCount: authors.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final author = authors[index];
                final id = author['id'];
                final name = author['name'] ?? {};
                final about = author['about'] ?? {};
                final photo = author['photo'];

                final nameUz = name['uz'] ?? '';
                final nameRu = name['ru'] ?? '';
                final nameEn = name['en'] ?? '';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: photo != null
                        ? NetworkImage('https://etimolog.uz$photo')
                        : null,
                    child: photo == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  title: Text(nameUz),
                  subtitle: Text(
                    'RU: $nameRu\nEN: $nameEn\n${about['uz'] ?? ''}',
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
                              builder: (_) => AddAuthorPage(
                                authorId: id,
                                existingData: author,
                              ),
                            ),
                          ).then((_) => fetchAuthors());
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => deleteAuthor(id),
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
