import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/admin/categories_page/add_categories.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCategories()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('categories')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // Загрузка
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Ошибка
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
          }

          // Нет данных
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Категорий пока нет'));
          }

          // Есть данные
          final categories = snapshot.data!.docs;

          return ListView.separated(
            itemCount: categories.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final doc = categories[index];
              final name = doc['name'] ?? 'Без названия';
              final createdAt = (doc['createdAt'] as Timestamp?)?.toDate();

              return ListTile(
                leading: const Icon(Icons.category, color: Colors.blueAccent),
                title: Text(name),
                subtitle: createdAt != null
                    ? Text(
                        'Создано: ${createdAt.day}.${createdAt.month}.${createdAt.year}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      )
                    : null,
                trailing: const Icon(Icons.edit, color: Colors.grey),
                onTap: () {
                  // 🔄 Переход в режим редактирования
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddCategories(categoryId: doc.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
