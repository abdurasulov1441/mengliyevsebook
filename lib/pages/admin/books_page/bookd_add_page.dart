import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mengliyevsebook/services/request_helper.dart';

class AddBookPage extends StatefulWidget {
  final Map<String, dynamic>? existingData;

  const AddBookPage({super.key, this.existingData});

  @override
  State<AddBookPage> createState() => _AddBookPageState();
}

class _AddBookPageState extends State<AddBookPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();

  String? _selectedAuthorId;
  String? _selectedCategoryId;
  bool _isFree = true;

  bool _isLoading = false;
  bool _isEditMode = false;

  File? _selectedImage;
  File? _selectedBookFile;

  List authors = [];
  List categories = [];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.existingData != null;
    fetchInitialData();
  }

  Future<void> fetchInitialData() async {
    try {
      final a = await requestHelper.getWithAuth(
        '/api/authors/get-authors?page=1&limit=100',
      );
      final c = await requestHelper.getWithAuth('/api/categories/categories');

      if (a is Map && a['authors'] is List) authors = a['authors'];
      if (c is List) categories = c;

      if (_isEditMode) loadExisting();

      setState(() {});
    } catch (e) {
      debugPrint("Ошибка: $e");
    }
  }

  void loadExisting() {
    final d = widget.existingData!;
    _titleController.text = d['title'] ?? "";
    _descController.text = d['description'] ?? "";
    _priceController.text = d['price']?.toString() ?? "";
    _selectedAuthorId = d['author_id']?.toString();
    _selectedCategoryId = d['category_id']?.toString();
    _isFree = d['is_free'] == true || d['is_free'] == "true";
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _selectedImage = File(picked.path));
  }

  Future<void> pickBookFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['doc', 'docx', 'pdf', 'epub'],
    );

    if (picked != null && picked.files.single.path != null) {
      setState(() {
        _selectedBookFile = File(picked.files.single.path!);
      });
    }
  }

  Future<void> createBook(
    Map<String, dynamic> fields,
    File? image,
    File? file,
  ) async {
    final formData = FormData.fromMap({
      ...fields,
      if (image != null)
        "image": await MultipartFile.fromFile(
          image.path,
          filename: image.path.split("/").last,
        ),
      if (file != null)
        "file": await MultipartFile.fromFile(
          file.path,
          filename: file.path.split("/").last,
        ),
    });

    return await requestHelper.postWithAuthMultipart(
      "/api/books/create-book",
      formData,
      log: true,
    );
  }

  Future<void> updateBook(
    int id,
    Map<String, dynamic> fields,
    File? image,
    File? file,
  ) async {
    final formData = FormData.fromMap({
      ...fields,
      if (image != null)
        "image": await MultipartFile.fromFile(
          image.path,
          filename: image.path.split("/").last,
        ),
      if (file != null)
        "file": await MultipartFile.fromFile(
          file.path,
          filename: file.path.split("/").last,
        ),
    });

    return await requestHelper.putWithAuthMultipart(
      "/api/books/update-book/$id",
      formData,
      log: true,
    );
  }

  Future<void> _saveBook() async {
    if (_titleController.text.isEmpty ||
        _descController.text.isEmpty ||
        _selectedAuthorId == null ||
        _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Заполните обязательные поля")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final fields = {
      "title": _titleController.text.trim(),
      "description": _descController.text.trim(),
      "author_id": _selectedAuthorId!,
      "category_id": _selectedCategoryId!,
      "is_free": _isFree.toString(),
      "price": _isFree ? "0" : _priceController.text.trim(),
    };

    try {
      if (_isEditMode) {
        await updateBook(
          widget.existingData!['id'],
          fields,
          _selectedImage,
          _selectedBookFile,
        );

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Книга обновлена")));
      } else {
        await createBook(fields, _selectedImage, _selectedBookFile);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Книга создана")));
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? "Редактировать книгу" : "Создать книгу"),
      ),
      body: authors.isEmpty || categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: "Название",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Описание",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField(
                    value: _selectedAuthorId,
                    decoration: const InputDecoration(
                      labelText: "Автор",
                      border: OutlineInputBorder(),
                    ),
                    items: authors
                        .map(
                          (a) => DropdownMenuItem(
                            value: a['id'].toString(),
                            child: Text(a['name']['uz']),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedAuthorId = v),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: "Категория",
                      border: OutlineInputBorder(),
                    ),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['id'].toString(),
                            child: Text(c['name']['uz']),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    value: _isFree,
                    title: const Text("Бесплатная"),
                    onChanged: (v) => setState(() => _isFree = v),
                  ),

                  if (!_isFree)
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Цена",
                        border: OutlineInputBorder(),
                      ),
                    ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: pickImage,
                        child: const Text("Выбрать обложку"),
                      ),
                      const SizedBox(width: 12),
                      if (_selectedImage != null)
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: pickBookFile,
                        child: const Text("Выбрать файл книги"),
                      ),
                      const SizedBox(width: 12),
                      if (_selectedBookFile != null)
                        const Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),

                  const SizedBox(height: 32),

                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveBook,
                    icon: const Icon(Icons.save),
                    label: Text(_isEditMode ? "Сохранить" : "Создать"),
                  ),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
    );
  }
}
