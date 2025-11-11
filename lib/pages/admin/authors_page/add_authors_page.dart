import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/utils/errors.dart';

class AddAuthorPage extends StatefulWidget {
  final int? authorId;
  final Map<String, dynamic>? existingData;

  const AddAuthorPage({super.key, this.authorId, this.existingData});

  @override
  State<AddAuthorPage> createState() => _AddAuthorPageState();
}

class _AddAuthorPageState extends State<AddAuthorPage> {
  final _nameUz = TextEditingController();
  final _nameRu = TextEditingController();
  final _nameEn = TextEditingController();

  final _aboutUz = TextEditingController();
  final _aboutRu = TextEditingController();
  final _aboutEn = TextEditingController();

  bool _isLoading = false;
  bool _isEditMode = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    if (widget.authorId != null) {
      _isEditMode = true;
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    final data = widget.existingData;
    if (data != null) {
      final name = data['name'] ?? {};
      final about = data['about'] ?? {};
      _nameUz.text = name['uz'] ?? '';
      _nameRu.text = name['ru'] ?? '';
      _nameEn.text = name['en'] ?? '';
      _aboutUz.text = about['uz'] ?? '';
      _aboutRu.text = about['ru'] ?? '';
      _aboutEn.text = about['en'] ?? '';
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _saveAuthor() async {
    final nameUz = _nameUz.text.trim();
    final nameRu = _nameRu.text.trim();
    final nameEn = _nameEn.text.trim();
    final aboutUz = _aboutUz.text.trim();
    final aboutRu = _aboutRu.text.trim();
    final aboutEn = _aboutEn.text.trim();

    if ([
      nameUz,
      nameRu,
      nameEn,
      aboutUz,
      aboutRu,
      aboutEn,
    ].any((e) => e.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Все поля должны быть заполнены')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // --- 🖼 Создание FormData с multipart ---
      final formData = dio.FormData.fromMap({
        'name1': nameUz,
        'name2': nameRu,
        'name3': nameEn,
        'about1': aboutUz,
        'about2': aboutRu,
        'about3': aboutEn,
        if (_selectedImage != null)
          'image': await dio.MultipartFile.fromFile(
            _selectedImage!.path,
            filename: 'author.jpg',
            contentType: dio.DioMediaType('image', 'jpeg'),
          ),
      });

      if (_isEditMode) {
        // ✏️ Обновление автора
        await requestHelper.putWithAuthMultipart(
          '/api/authors/update-author/${widget.authorId}',
          formData,
          log: true,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Автор успешно обновлён')));
      } else {
        // 🆕 Добавление автора
        await requestHelper.postWithAuthMultipart(
          '/api/authors/create-author',
          formData,
          log: true,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Автор успешно добавлен')));
      }

      if (mounted) Navigator.pop(context, true);
    } on UnauthenticatedError {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ошибка авторизации')));
    } catch (e) {
      String errorMessage = 'Ошибка при отправке данных: $e';
      if (e is dio.DioException) {
        if (e.response?.statusCode == 401) {
          errorMessage = 'Ошибка авторизации';
        } else if (e.response?.statusCode == 400) {
          errorMessage = 'Неверные данные: ${e.response?.data}';
        } else if (e.response?.statusCode == 500) {
          errorMessage = 'Ошибка сервера';
        }
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Редактировать автора' : 'Добавить автора'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 55,
                backgroundImage: _selectedImage != null
                    ? FileImage(_selectedImage!)
                    : widget.existingData?['photo'] != null
                    ? NetworkImage(
                        'https://etimolog.uz${widget.existingData!['photo']}',
                      )
                    : null,
                child:
                    _selectedImage == null &&
                        widget.existingData?['photo'] == null
                    ? const Icon(Icons.add_a_photo, size: 30)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField('Имя (UZ)', _nameUz),
            _buildTextField('Имя (RU)', _nameRu),
            _buildTextField('Имя (EN)', _nameEn),
            _buildTextField('О авторе (UZ)', _aboutUz, maxLines: 3),
            _buildTextField('О авторе (RU)', _aboutRu, maxLines: 3),
            _buildTextField('О авторе (EN)', _aboutEn, maxLines: 3),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveAuthor,
              icon: _isEditMode
                  ? const Icon(Icons.save)
                  : const Icon(Icons.add),
              label: Text(
                _isEditMode ? 'Сохранить изменения' : 'Добавить автора',
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

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
