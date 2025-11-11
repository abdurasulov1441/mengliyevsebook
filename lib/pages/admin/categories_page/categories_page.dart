import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/admin/categories_page/add_categories.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/utils/errors.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<dynamic> categories = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await requestHelper.getWithAuth(
        '/api/categories/categories',
        log: true,
      );

      if (response is List) {
        setState(() {
          categories = response;
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

  Future<void> deleteCategory(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление категории'),
        content: const Text('Вы уверены, что хотите удалить эту категорию?'),
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
        '/api/categories/delete-category/$id',
        log: true,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Категория успешно удалена')),
      );

      fetchCategories(); // 🔁 обновляем список
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при удалении: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Категории')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCategories()),
          );
          fetchCategories(); // 🔁 Обновим после добавления
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
                    onPressed: fetchCategories,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          if (categories.isEmpty) {
            return const Center(child: Text('Категорий пока нет'));
          }

          return RefreshIndicator(
            onRefresh: fetchCategories,
            child: ListView.separated(
              itemCount: categories.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final id = cat['id'];
                final name = cat['name'] ?? {};
                final nameUz = name['uz'] ?? '';
                final nameRu = name['ru'] ?? '';
                final nameOz = name['oz'] ?? '';

                return ListTile(
                  leading: const Icon(Icons.category, color: Colors.blueAccent),
                  title: Text(nameUz),
                  subtitle: Text(
                    'RU: $nameRu\nOZ: $nameOz',
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
                              builder: (_) => AddCategories(
                                categoryId: id,
                                existingData: {
                                  'name1': nameOz,
                                  'name2': nameRu,
                                  'name3': nameUz,
                                },
                              ),
                            ),
                          ).then((_) => fetchCategories());
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => deleteCategory(id),
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
