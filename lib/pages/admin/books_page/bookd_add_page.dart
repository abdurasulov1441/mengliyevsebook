import 'package:flutter/material.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/utils/errors.dart';

class AddBookPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;

  const AddBookPage({super.key, this.existingData});

  @override
  State<AddBookPage> createState() => _AddBookPageState();
}

class _AddBookPageState extends State<AddBookPage> {
  final _slugController = TextEditingController();
  final _priceController = TextEditingController();

  String? _selectedAuthorId;
  String? _selectedCategoryId;
  bool _isFree = true;
  bool _isLoading = false;
  bool _isEditMode = false;

  List<dynamic> authors = [];
  List<dynamic> categories = [];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.existingData != null;
    fetchAuthorsAndCategories();
  }

  /// Загружаем авторов и категории
  Future<void> fetchAuthorsAndCategories() async {
    try {
      final authorsResp = await requestHelper.getWithAuth(
        '/api/authors/get-authors?page=1&limit=100',
      );
      final catsResp = await requestHelper.getWithAuth(
        '/api/categories/categories',
      );

      if (authorsResp is Map && authorsResp['authors'] is List) {
        authors = authorsResp['authors'];
      }
      if (catsResp is List) {
        categories = catsResp;
      }

      // После загрузки данных — если редактирование, подставляем значения
      if (_isEditMode) {
        _loadExistingData();
      }

      setState(() {});
    } catch (e) {
      debugPrint('Ошибка при загрузке справочников: $e');
    }
  }

  void _loadExistingData() {
    final data = widget.existingData!;
    _slugController.text = data['slug'] ?? '';
    _selectedAuthorId = data['author_id']?.toString();
    _selectedCategoryId = data['category_id']?.toString();
    _isFree = data['is_free'] ?? true;
    _priceController.text = data['price']?.toString() ?? '';
  }

  Future<void> _saveBook() async {
    final slug = _slugController.text.trim();
    final authorId = _selectedAuthorId;
    final categoryId = _selectedCategoryId;
    final price = _priceController.text.trim();

    if (slug.isEmpty || authorId == null || categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все обязательные поля')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final body = {
        "slug": slug,
        "author_id": int.parse(authorId),
        "category_id": int.parse(categoryId),
        "is_free": _isFree,
        "price": _isFree ? 0 : double.tryParse(price) ?? 0,
      };

      if (_isEditMode) {
        await requestHelper.putWithAuth(
          '/api/books/update-book/${widget.existingData!['id']}',
          body,
          log: true,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Книга успешно обновлена')),
        );
      } else {
        await requestHelper.postWithAuth(
          '/api/books/create-book',
          body,
          log: true,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Книга успешно добавлена')),
        );
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
    _slugController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDataReady = authors.isNotEmpty && categories.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Редактировать книгу' : 'Добавить книгу'),
      ),
      body: isDataReady
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _slugController,
                    decoration: const InputDecoration(
                      labelText: 'Slug книги',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedAuthorId,
                    decoration: const InputDecoration(
                      labelText: 'Автор',
                      border: OutlineInputBorder(),
                    ),
                    items: authors.map((a) {
                      return DropdownMenuItem(
                        value: a['id'].toString(),
                        child: Text(a['name']['uz'] ?? 'Без имени'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedAuthorId = val),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Категория',
                      border: OutlineInputBorder(),
                    ),
                    items: categories.map((c) {
                      return DropdownMenuItem(
                        value: c['id'].toString(),
                        child: Text(c['name']['uz'] ?? 'Без названия'),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedCategoryId = val),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Бесплатная книга'),
                    value: _isFree,
                    onChanged: (val) => setState(() => _isFree = val),
                  ),
                  if (!_isFree)
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Цена (сум)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveBook,
                    icon: const Icon(Icons.save),
                    label: Text(
                      _isEditMode ? 'Сохранить изменения' : 'Добавить книгу',
                    ),
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
