import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddCategories extends StatefulWidget {
  /// Если [categoryId] == null → создаём новую категорию
  /// Если [categoryId] != null → редактируем существующую категорию
  final String? categoryId;

  const AddCategories({super.key, this.categoryId});

  @override
  State<AddCategories> createState() => _AddCategoriesState();
}

class _AddCategoriesState extends State<AddCategories> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.categoryId != null) {
      _isEditMode = true;
      _loadCategoryData();
    }
  }

  /// Загружаем данные категории для редактирования
  Future<void> _loadCategoryData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('categories')
          .doc(widget.categoryId)
          .get();
      if (doc.exists) {
        _nameController.text = doc['name'] ?? '';
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка загрузки категории: $e')));
    }
  }

  /// Добавление или обновление категории
  Future<void> _saveCategory() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название категории')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final collection = FirebaseFirestore.instance.collection('categories');

      if (_isEditMode) {
        // 🔄 Редактирование
        await collection.doc(widget.categoryId).update({'name': name});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Категория успешно обновлена')),
        );
      } else {
        // 🆕 Добавление
        await collection.add({
          'name': name,
          'createdAt': FieldValue.serverTimestamp(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Категория успешно добавлена')),
        );
        _nameController.clear();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Редактировать категорию' : 'Добавить категорию',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Название категории:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Введите название категории',
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveCategory,
                icon: _isEditMode
                    ? const Icon(Icons.save)
                    : const Icon(Icons.add),
                label: Text(
                  _isEditMode ? 'Сохранить изменения' : 'Добавить категорию',
                ),
              ),
            ),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
