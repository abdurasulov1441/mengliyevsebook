import 'dart:io';
import 'package:flutter/material.dart';
import 'package:epub_pro/epub_pro.dart';
import 'package:flutter_html/flutter_html.dart';

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
      final bytes = File(widget.bookPath).readAsBytesSync();
      final book = await EpubReader.readBook(bytes);

      setState(() {
        epubBook = book;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = "Kitobni ochib bo‘lmadi: $e";
      });
    }
  }

  void nextChapter() {
    if (chapterIndex < epubBook!.chapters.length - 1) {
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
    final chapter = epubBook?.chapters.isNotEmpty == true
        ? epubBook!.chapters[chapterIndex]
        : null;

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
                      child: Html(
                        data: chapter.htmlContent ?? "",
                        style: {
                          "body": Style(
                            color: darkMode ? Colors.white : Colors.black,
                            fontSize: FontSize(fontSize),
                            lineHeight: LineHeight(1.7),
                          )
                        },
                      ),
                    ),

      bottomNavigationBar: epubBook == null
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
                    "Bo‘lim ${chapterIndex + 1}/${epubBook!.chapters.length}",
                    style: TextStyle(color: darkMode ? Colors.white : Colors.black),
                  ),
                  TextButton.icon(
                    onPressed: chapterIndex < epubBook!.chapters.length - 1
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
