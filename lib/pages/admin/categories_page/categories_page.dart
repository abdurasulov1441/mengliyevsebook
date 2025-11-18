import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mengliyevsebook/pages/admin/categories_page/add_categories.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/style/app_colors.dart';
import 'package:mengliyevsebook/services/style/app_style.dart';
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
        backgroundColor: AppColors.backgroundColor,
        title: Text('Kategoriyani o\'chirish'),
        content: Text(
          'Siz ushbu kategoriyani o\'chirishga ishonchingiz komilmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Bekor qilish', style: AppStyle.fontStyle.copyWith()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'O\'chirish',
              style: AppStyle.fontStyle.copyWith(
                color: AppColors.backgroundColor,
              ),
            ),
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

      fetchCategories();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при удалении: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.grade1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCategories()),
          );
          fetchCategories();
        },
        child: Icon(Icons.add, color: AppColors.backgroundColor),
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
                    child: Text(
                      '  Qayta urinib ko\'rish',
                      style: AppStyle.fontStyle.copyWith(),
                    ),
                  ),
                ],
              ),
            );
          }

          if (categories.isEmpty) {
            return Center(
              child: Text(
                'Kategoriya mavjud emas',
                style: AppStyle.fontStyle.copyWith(),
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.grade1,
            backgroundColor: AppColors.backgroundColor,
            onRefresh: fetchCategories,
            child: ListView.separated(
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final id = cat['id'];
                final name = cat['name'] ?? {};
                final nameUz = name['uz'] ?? '';
                final nameRu = name['ru'] ?? '';
                final nameOz = name['oz'] ?? '';

                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.ui,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: SvgPicture.asset(
                      'assets/icons/notebooks.svg',
                      color: AppColors.grade1,
                      width: 32,
                      height: 32,
                    ),
                    title: Text(nameUz),
                    subtitle: Text(
                      'RU: $nameRu\nOZ: $nameOz',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: SvgPicture.asset(
                            'assets/icons/edit.svg',
                            color: AppColors.grade1,
                            width: 24,
                            height: 24,
                          ),
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
                          icon: SvgPicture.asset(
                            'assets/icons/trash.svg',
                            color: Colors.red,
                            width: 24,
                            height: 24,
                          ),
                          onPressed: () => deleteCategory(id),
                        ),
                      ],
                    ),
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
