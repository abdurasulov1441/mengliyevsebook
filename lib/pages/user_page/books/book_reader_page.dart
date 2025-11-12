import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epub_pro/epub_pro.dart';
import 'package:path/path.dart' as path;

class EpubProReaderPage extends StatefulWidget {
  final String bookPath;
  final String title;

  const EpubProReaderPage({
    super.key,
    required this.bookPath,
    required this.title,
  });

  @override
  State<EpubProReaderPage> createState() => _EpubProReaderPageState();
}

class _EpubProReaderPageState extends State<EpubProReaderPage> {
  bool isLoading = true;
  String? errorMessage;
  EpubBook? _book;
  int _currentChapter = 0;
  double _fontSize = 16.0;

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  Future<void> _loadBook() async {
    try {
      final file = File(widget.bookPath);
      final bytes = await file.readAsBytes();
      final epub = await EpubReader.readBook(bytes);

      setState(() {
        _book = epub;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Kitobni ochib bo‘lmadi: $e';
      });
    }
  }

  void _nextChapter() {
    if (_book == null) return;
    if (_currentChapter < _book!.chapters.length - 1) {
      setState(() => _currentChapter++);
    }
  }

  void _prevChapter() {
    if (_currentChapter > 0) {
      setState(() => _currentChapter--);
    }
  }

  void _changeFontSize(double delta) {
    setState(() => _fontSize += delta);
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _book?.chapters.isNotEmpty == true
        ? _book!.chapters[_currentChapter]
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_increase),
            onPressed: () => _changeFontSize(2),
          ),
          IconButton(
            icon: const Icon(Icons.text_decrease),
            onPressed: () => _changeFontSize(-2),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!))
          : chapter == null
          ? const Center(child: Text('Bo‘limlar topilmadi'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.title ?? 'Bo‘lim ${_currentChapter + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      // HTML из главы без тегов
                      _stripHtml(chapter.htmlContent ?? ''),
                      style: TextStyle(fontSize: _fontSize, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'prev',
            onPressed: _prevChapter,
            child: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            heroTag: 'next',
            onPressed: _nextChapter,
            child: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  String _stripHtml(String html) {
    final regex = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);
    return html.replaceAll(regex, '').replaceAll('&nbsp;', ' ').trim();
  }
}
