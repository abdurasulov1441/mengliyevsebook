import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/utils/errors.dart';

class AddSubBookPage extends StatefulWidget {
  final int bookId;
  final Map<String, dynamic>? existingData;

  const AddSubBookPage({super.key, required this.bookId, this.existingData});

  @override
  State<AddSubBookPage> createState() => _AddSubBookPageState();
}

class _AddSubBookPageState extends State<AddSubBookPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedLang = "1";
  File? _imageFile;
  File? _epubFile;
  bool _isLoading = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.existingData != null;
    if (_isEditMode) _loadExistingData();
  }

  void _loadExistingData() {
    final data = widget.existingData!;
    _titleController.text = data['title'] ?? '';
    _descController.text = data['description'] ?? '';
    _selectedLang = data['lang_id']?.toString() ?? "1";
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['doc', 'docx', 'epub', 'pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _epubFile = File(result.files.single.path!);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Файл выбран: ${result.files.single.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка выбора файла: $e')));
    }
  }

  Future<void> _saveSubBook() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите все обязательные поля')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formData = dio.FormData();

      // обычные текстовые поля
      formData.fields.addAll([
        MapEntry('book_id', widget.bookId.toString()),
        MapEntry('lang_id', _selectedLang),
        MapEntry('title', title),
        MapEntry('description', desc),
      ]);

      // обложка (если выбрана)
      if (_imageFile != null) {
        formData.files.add(
          MapEntry(
            'image',
            await dio.MultipartFile.fromFile(
              _imageFile!.path,
              filename: _imageFile!.path.split('/').last,
              contentType: MediaType('image', 'jpeg'),
            ),
          ),
        );
      }

      // файл книги (docx / epub / pdf)
      if (_epubFile != null) {
        final extension = _epubFile!.path.split('.').last.toLowerCase();

        // определяем MIME тип в зависимости от расширения
        final mimeType = switch (extension) {
          'epub' => MediaType('application', 'epub+zip'),
          'docx' => MediaType(
            'application',
            'vnd.openxmlformats-officedocument.wordprocessingml.document',
          ),
          'pdf' => MediaType('application', 'pdf'),
          _ => MediaType('application', 'octet-stream'),
        };

        formData.files.add(
          MapEntry(
            'file',
            await dio.MultipartFile.fromFile(
              _epubFile!.path,
              filename: _epubFile!.path.split('/').last,
              contentType: mimeType,
            ),
          ),
        );
      }

      // ✅ Запрос
      if (_isEditMode) {
        await requestHelper.putWithAuthMultipart(
          '/api/sub-books/update-sub-book/${widget.existingData!['id']}',
          formData,
          log: true,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Файл успешно обновлён')));
      } else {
        await requestHelper.postWithAuthMultipart(
          '/api/sub-books/create-sub-book',
          formData,
          log: true,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Файл успешно добавлен')));
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
  Widget build(BuildContext context) {
    final imageUrl = widget.existingData?['photo'] != null
        ? 'https://etimolog.uz${widget.existingData!['photo']}'
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Редактировать файл' : 'Добавить файл'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Описание',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedLang,
              decoration: const InputDecoration(
                labelText: 'Язык',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "1", child: Text("O‘zbek")),
                DropdownMenuItem(value: "2", child: Text("Русский")),
                DropdownMenuItem(value: "3", child: Text("English")),
              ],
              onChanged: (v) => setState(() => _selectedLang = v ?? "1"),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text("Выбрать обложку"),
              trailing: _imageFile != null || imageUrl != null
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: _pickImage,
            ),
            ListTile(
              leading: const Icon(Icons.file_present),
              title: const Text("Выбрать файл книги (.epub/.docx)"),
              trailing: _epubFile != null
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: _pickFile,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveSubBook,
              icon: const Icon(Icons.save),
              label: Text(
                _isEditMode ? 'Сохранить изменения' : 'Добавить файл',
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
