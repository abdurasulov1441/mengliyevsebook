import 'package:flutter/material.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/utils/errors.dart';

class AddCategories extends StatefulWidget {
  /// Если [categoryId] == null → создаём новую категорию
  /// Если [categoryId] != null → редактируем существующую категорию
  final int? categoryId;

  /// Передаём существующие данные для редактирования
  final Map<String, dynamic>? existingData;

  const AddCategories({super.key, this.categoryId, this.existingData});

  @override
  State<AddCategories> createState() => _AddCategoriesState();
}

class _AddCategoriesState extends State<AddCategories> {
  final TextEditingController _nameUzController = TextEditingController();
  final TextEditingController _nameRuController = TextEditingController();
  final TextEditingController _nameEnController = TextEditingController();

  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.categoryId != null) {
      _isEditMode = true;
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    final data = widget.existingData;
    if (data != null) {
      _nameUzController.text = data['name1'] ?? '';
      _nameRuController.text = data['name2'] ?? '';
      _nameEnController.text = data['name3'] ?? '';
    }
  }

  Future<void> _saveCategory() async {
    final nameUz = _nameUzController.text.trim();
    final nameRu = _nameRuController.text.trim();
    final nameEn = _nameEnController.text.trim();

    if (nameUz.isEmpty || nameRu.isEmpty || nameEn.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Заполните все поля')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isEditMode) {
        await requestHelper.putWithAuth(
          '/api/categories/update-category/${widget.categoryId}',
          {'name1': nameUz, 'name2': nameRu, 'name3': nameEn},
          log: true,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Категория успешно обновлена')),
        );
      } else {
        await requestHelper.postWithAuth('/api/categories/create-category', {
          'name1': nameUz,
          'name2': nameRu,
          'name3': nameEn,
        }, log: true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Категория успешно добавлена')),
        );

        _nameUzController.clear();
        _nameRuController.clear();
        _nameEnController.clear();
      }

      if (mounted) Navigator.pop(context, true);
    } on UnauthenticatedError {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ошибка авторизации')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameUzController.dispose();
    _nameRuController.dispose();
    _nameEnController.dispose();
    super.dispose();
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
        child: ListView(
          children: [
            const Text(
              'Название категории (на узбекском):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameUzController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Masalan: Tarix',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Название категории (на русском):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameRuController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Например: История',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Название категории (на английском):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameEnController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Example: History',
              ),
            ),
            const SizedBox(height: 24),
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
