import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epubx/epubx.dart';

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
  EpubBook? epubBook;

  List<EpubChapter> chapters = [];
  int chapterIndex = 0;

  double fontSize = 18;
  bool darkMode = false;

  @override
  void initState() {
    super.initState();
    loadBook();
  }

  Future<void> loadBook() async {
    try {
      final bytes = await File(widget.bookPath).readAsBytes();
      final book = await EpubReader.readBook(bytes);

      // Agar Chapters bo‘lmasa, Content orqali yuklaymiz
      List<EpubChapter> loadedChapters = [];

      if (book.Chapters != null && book.Chapters!.isNotEmpty) {
        loadedChapters = book.Chapters!;
      } else {
        // TOC yo‘q bo‘lsa — HTML sahifalarni o‘qib bo‘lim qilamiz
        book.Content?.Html?.forEach((key, value) {
          loadedChapters.add(EpubChapter());
        });
      }

      setState(() {
        epubBook = book;
        chapters = loadedChapters;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = "Kitobni ochib bo‘lmadi: $e";
        isLoading = false;
      });
    }
  }

  // HTML → Plain text
  String cleanHtml(String html) {
    if (html.isEmpty) return "";

    // Удаляем теги
    String text = html.replaceAll(RegExp(r'<[^>]*>'), '');

    // Декодируем HTML сущности (&nbsp; &quot; …)
    text = text.replaceAll("&nbsp;", " ");
    text = text.replaceAll("&quot;", "\"");
    text = text.replaceAll("&amp;", "&");
    text = text.replaceAll("&lt;", "<");
    text = text.replaceAll("&gt;", ">");

    return text.trim();
  }

  void nextChapter() {
    if (chapterIndex < chapters.length - 1) {
      setState(() => chapterIndex++);
    }
  }

  void prevChapter() {
    if (chapterIndex > 0) {
      setState(() => chapterIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapter = chapters.isNotEmpty ? chapters[chapterIndex] : null;
    final plainText = chapter == null
        ? ""
        : cleanHtml(chapter.HtmlContent ?? "");

    return Scaffold(
      backgroundColor: darkMode ? Colors.black : Colors.white,

      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_increase),
            onPressed: () => setState(() => fontSize += 2),
          ),
          IconButton(
            icon: const Icon(Icons.text_decrease),
            onPressed: () => setState(() => fontSize -= 2),
          ),
          IconButton(
            icon: Icon(darkMode ? Icons.dark_mode : Icons.light_mode),
            onPressed: () => setState(() => darkMode = !darkMode),
          ),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!))
          : chapter == null
          ? const Center(child: Text("Bo‘limlar topilmadi"))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                plainText,
                style: TextStyle(
                  fontSize: fontSize,
                  color: darkMode ? Colors.white : Colors.black,
                  height: 1.7,
                ),
              ),
            ),

      bottomNavigationBar: chapters.isEmpty
          ? null
          : BottomAppBar(
              color: darkMode ? Colors.grey[900] : Colors.grey[200],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: chapterIndex > 0 ? prevChapter : null,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text("Oldingi"),
                  ),
                  Text(
                    "Bo‘lim ${chapterIndex + 1}/${chapters.length}",
                    style: TextStyle(
                      color: darkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: chapterIndex < chapters.length - 1
                        ? nextChapter
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text("Keyingi"),
                  ),
                ],
              ),
            ),
    );
  }
}
