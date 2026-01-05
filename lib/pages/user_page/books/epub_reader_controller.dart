import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epub_pro/epub_pro.dart';
import 'package:mengliyevsebook/pages/user_page/books/epub_reader_service.dart';

class EpubReaderController extends ChangeNotifier {
  // Состояние
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  EpubBookRef? _bookRef;
  List<EpubChapterRef> _chapters = [];
  int _currentChapterIndex = 0;
  double _fontSize = 18.0;
  bool _isDarkMode = false;
  String _filePath = '';
  String? _currentChapterContent;

  // Геттеры
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;
  EpubBookRef? get bookRef => _bookRef;
  List<EpubChapterRef> get chapters => _chapters;
  int get currentChapterIndex => _currentChapterIndex;
  EpubChapterRef? get currentChapter => 
      _chapters.isNotEmpty ? _chapters[_currentChapterIndex] : null;
  double get fontSize => _fontSize;
  bool get isDarkMode => _isDarkMode;
  String get filePath => _filePath;
  String? get currentChapterContent => _currentChapterContent;

  // Загружаем книгу
  Future<void> loadBook(String filePath) async {
    try {
      _resetState();
      _filePath = filePath;
      notifyListeners();

      // Проверяем файл
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Fayl topilmadi: $filePath');
      }

      // Открываем книгу (ленивая загрузка)
      _bookRef = await EpubReaderService.openBook(filePath);
      
      // Получаем главы
      _chapters = await _bookRef!.getChapters();
      
      // Загружаем первую главу
      await _loadCurrentChapterContent();
      
      _isLoading = false;
      notifyListeners();

    } catch (e) {
      print('Book loading error: $e');
      _hasError = true;
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Загружаем контент текущей главы
  Future<void> _loadCurrentChapterContent() async {
    if (currentChapter != null) {
      _currentChapterContent = await EpubReaderService.getChapterContent(currentChapter!);
    }
  }

  // Переходим к главе
  Future<void> goToChapter(int index) async {
    if (index >= 0 && index < _chapters.length) {
      _currentChapterIndex = index;
      _currentChapterContent = null;
      notifyListeners(); // Уведомляем сразу о смене индекса
      
      // Загружаем контент новой главы
      await _loadCurrentChapterContent();
      notifyListeners(); // Уведомляем о загрузке контента
    }
  }

  // Следующая глава
  Future<void> nextChapter() async {
    if (_currentChapterIndex < _chapters.length - 1) {
      await goToChapter(_currentChapterIndex + 1);
    }
  }

  // Предыдущая глава
  Future<void> previousChapter() async {
    if (_currentChapterIndex > 0) {
      await goToChapter(_currentChapterIndex - 1);
    }
  }

  // Изменяем размер шрифта
  void changeFontSize(double size) {
    _fontSize = size.clamp(14.0, 30.0);
    notifyListeners(); // ✅ Важно!
  }

  // Увеличиваем шрифт
  void increaseFontSize() {
    _fontSize = (_fontSize + 2).clamp(14.0, 30.0);
    notifyListeners();
  }

  // Уменьшаем шрифт
  void decreaseFontSize() {
    _fontSize = (_fontSize - 2).clamp(14.0, 30.0);
    notifyListeners();
  }

  // Переключаем тему
  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners(); // ✅ Важно!
  }

  // Получаем заголовок текущей главы
  String getCurrentChapterTitle() {
    if (currentChapter != null) {
      return currentChapter!.title ?? 'Bob ${_currentChapterIndex + 1}';
    }
    return 'Bob topilmadi';
  }

  // Получаем прогресс чтения
  double getReadingProgress() {
    if (_chapters.isEmpty) return 0.0;
    return (_currentChapterIndex + 1) / _chapters.length;
  }

  // Сбрасываем состояние
  void _resetState() {
    _isLoading = true;
    _hasError = false;
    _errorMessage = null;
    _bookRef = null;
    _chapters = [];
    _currentChapterIndex = 0;
    _currentChapterContent = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}