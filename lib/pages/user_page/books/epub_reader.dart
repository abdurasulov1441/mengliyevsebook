import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mengliyevsebook/services/style/app_colors.dart';
import 'epub_reader_controller.dart';
import 'epub_reader_service.dart';

class EpubReaderScreen extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final String filePath;

  const EpubReaderScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.filePath,
  });

  @override
  State<EpubReaderScreen> createState() => _EpubReaderScreenState();
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  late EpubReaderController _controller;
  bool _showChapters = false;

  @override
  void initState() {
    super.initState();
    _controller = EpubReaderController();
    _controller.addListener(_onControllerChanged); // ✅ ДОБАВЬТЕ ЭТУ СТРОКУ
    _loadBook();
  }

  void _onControllerChanged() {
    setState(() {}); // ✅ ОБНОВЛЯЕМ UI ПРИ ИЗМЕНЕНИЯХ В КОНТРОЛЛЕРЕ
  }

  Future<void> _loadBook() async {
    await _controller.loadBook(widget.filePath);
  }

  Future<void> _changeChapter(int index) async {
    await _controller.goToChapter(index);
  }

  void _toggleChapters() {
    setState(() {
      _showChapters = !_showChapters;
    });
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _controller.isDarkMode
                    ? Colors.grey.shade900
                    : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "O'qish sozlamalari",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _controller.isDarkMode
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Размер шрифта
                  ListTile(
                    leading: Icon(
                      Icons.text_fields,
                      color: _controller.isDarkMode
                          ? Colors.white
                          : Colors.black,
                    ),
                    title: Text(
                      "Shrift o'lchami",
                      style: TextStyle(
                        color: _controller.isDarkMode
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.remove,
                            color: _controller.isDarkMode
                                ? Colors.white
                                : Colors.black,
                          ),
                          onPressed: () {
                            _controller.changeFontSize(
                              _controller.fontSize - 2,
                            );
                            setState(() {}); // ✅ ОБНОВЛЯЕМ BOTTOM SHEET
                          },
                        ),
                        Text(
                          _controller.fontSize.toInt().toString(),
                          style: TextStyle(
                            color: _controller.isDarkMode
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.add,
                            color: _controller.isDarkMode
                                ? Colors.white
                                : Colors.black,
                          ),
                          onPressed: () {
                            _controller.changeFontSize(
                              _controller.fontSize + 2,
                            );
                            setState(() {}); // ✅ ОБНОВЛЯЕМ BOTTOM SHEET
                          },
                        ),
                      ],
                    ),
                  ),

                  // Тема
                  ListTile(
                    leading: Icon(
                      Icons.color_lens,
                      color: _controller.isDarkMode
                          ? Colors.white
                          : Colors.black,
                    ),
                    title: Text(
                      "Tungi rejim",
                      style: TextStyle(
                        color: _controller.isDarkMode
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                    trailing: Switch(
                      value: _controller.isDarkMode,
                      onChanged: (value) {
                        _controller.toggleDarkMode();
                        setState(() {}); // ✅ ОБНОВЛЯЕМ BOTTOM SHEET
                      },
                    ),
                  ),

                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text("Tayyor"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.grade1),
          const SizedBox(height: 20),
          const Text("Kitob yuklanmoqda...", style: TextStyle(fontSize: 16)),
          const SizedBox(height: 10),
          Text(
            widget.bookTitle,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red.shade400),
            const SizedBox(height: 20),
            Text(
              _controller.errorMessage ?? "Noma'lum xatolik",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
            const SizedBox(height: 10),
            Text(
              "Fayl: ${widget.filePath.split('/').last}",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.grade1,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
              ),
              child: const Text(
                "Orqaga qaytish",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterContent() {
    if (_controller.currentChapterContent == null) {
      return Center(child: CircularProgressIndicator(color: AppColors.grade1));
    }

    // Обрабатываем HTML контент для отображения
    final html = _controller.currentChapterContent!;
    final plainText = _extractTextFromHtml(html);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок главы
          Text(
            _controller.getCurrentChapterTitle(),
            style: TextStyle(
              fontSize: _controller.fontSize + 4,
              fontWeight: FontWeight.bold,
              color: _controller.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 10),

          // Прогресс
          Text(
            "Bob ${_controller.currentChapterIndex + 1} / ${_controller.chapters.length}",
            style: TextStyle(
              fontSize: 14,
              color: _controller.isDarkMode
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),

          // Контент
          Text(
            plainText,
            style: TextStyle(
              fontSize: _controller.fontSize,
              color: _controller.isDarkMode ? Colors.white70 : Colors.black87,
              height: 1.6,
            ),
            textAlign: TextAlign.justify,
          ),
        ],
      ),
    );
  }

  String _extractTextFromHtml(String html) {
    // Простая очистка HTML тегов
    String text = html
        .replaceAll(RegExp(r'<[^>]*>'), ' ') // Удаляем HTML теги
        .replaceAll(RegExp(r'\s+'), ' ') // Убираем лишние пробелы
        .replaceAll('&nbsp;', ' ') // Заменяем неразрывные пробелы
        .replaceAll('&quot;', '"') // Заменяем кавычки
        .replaceAll('&amp;', '&') // Заменяем амперсанд
        .replaceAll('&lt;', '<') // Заменяем <
        .replaceAll('&gt;', '>') // Заменяем >
        .trim();

    return text;
  }

  Widget _buildChaptersPanel() {
    return Drawer(
      backgroundColor: _controller.isDarkMode
          ? Colors.grey.shade900
          : Colors.white,
      width: 300,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.grade1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Mundarija",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _toggleChapters,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _controller.chapters.length,
              itemBuilder: (context, index) {
                final chapter = _controller.chapters[index];
                final isCurrent = index == _controller.currentChapterIndex;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCurrent
                        ? AppColors.grade1
                        : (_controller.isDarkMode
                              ? Colors.grey.shade700
                              : Colors.grey.shade300),
                    child: Text(
                      (index + 1).toString(),
                      style: TextStyle(
                        color: isCurrent ? Colors.white : Colors.black,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  title: Text(
                    chapter.title ?? "Bob ${index + 1}",
                    style: TextStyle(
                      color: _controller.isDarkMode
                          ? Colors.white
                          : Colors.black,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: isCurrent ? 16 : 14,
                    ),
                  ),
                  subtitle: isCurrent
                      ? Text(
                          "Joriy bob",
                          style: TextStyle(
                            color: AppColors.grade1,
                            fontSize: 12,
                          ),
                        )
                      : null,
                  trailing: isCurrent
                      ? Icon(Icons.check_circle, color: AppColors.grade1)
                      : null,
                  onTap: () {
                    _changeChapter(index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReader() {
    return Stack(
      children: [
        // Основной контент
        _buildChapterContent(),

        // Верхняя панель навигации
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: _controller.isDarkMode
                ? Colors.black.withOpacity(0.9)
                : Colors.white.withOpacity(0.95),
            padding: const EdgeInsets.only(
              top: 40,
              bottom: 10,
              left: 16,
              right: 16,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: _controller.isDarkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    _controller.getCurrentChapterTitle(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _controller.isDarkMode
                          ? Colors.white
                          : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.menu_book,
                    color: _controller.isDarkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: _toggleChapters,
                ),
              ],
            ),
          ),
        ),

        // Нижняя панель навигации
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            color: _controller.isDarkMode
                ? Colors.black.withOpacity(0.9)
                : Colors.white.withOpacity(0.95),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: _controller.isDarkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: () async {
                    await _controller.previousChapter();
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.bookmark_border,
                    color: _controller.isDarkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("Beldak qo'shildi"),
                        backgroundColor: _controller.isDarkMode
                            ? Colors.grey.shade800
                            : null,
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.settings,
                    color: _controller.isDarkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: _showSettings,
                ),
                IconButton(
                  icon: Icon(
                    Icons.arrow_forward_ios,
                    color: _controller.isDarkMode ? Colors.white : Colors.black,
                  ),
                  onPressed: () async {
                    await _controller.nextChapter();
                  },
                ),
              ],
            ),
          ),
        ),

        // Панель глав
        if (_showChapters) _buildChaptersPanel(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _controller.isDarkMode ? Colors.black : AppColors.ui,
      body: _controller.isLoading
          ? _buildLoading()
          : _controller.hasError
          ? _buildError()
          : _buildReader(),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged); // ✅ УДАЛЯЕМ СЛУШАТЕЛЬ
    _controller.dispose();
    super.dispose();
  }
}
