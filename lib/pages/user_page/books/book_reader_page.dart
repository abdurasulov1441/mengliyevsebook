import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookReaderScreen extends StatefulWidget {
  final String bookPath; // Можно путь в assets или URL
  final String title;

  const BookReaderScreen({
    super.key,
    required this.bookPath,
    required this.title,
  });

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  final EpubController epubController = EpubController();

  double fontSize = 16;
  bool isDarkMode = false;
  String? lastCfi;
  List<EpubChapter> chapters = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLastPosition().then((_) => _openBook());
  }

  Future<void> _loadLastPosition() async {
    final prefs = await SharedPreferences.getInstance();
    lastCfi = prefs.getString('last_cfi_${widget.title}');
  }

  Future<void> _saveLastPosition(String cfi) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_cfi_${widget.title}', cfi);
  }

  Future<void> _openBook() async {
    await epubController;
  }

  void _changeFontSize(double value) {
    setState(() => fontSize = value);
    epubController.setFontSize(fontSize: value);
  }

  void _highlightSelection(String cfi) {
    epubController.addHighlight(cfi: cfi, color: Colors.yellow, opacity: 0.4);
  }

  void _search(String query) async {
    final results = await epubController.search(query: query);
    if (results.isNotEmpty) {
      epubController.display(cfi: results.first.cfi);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Поиск',
            onPressed: () async {
              final query = await showDialog<String>(
                context: context,
                builder: (context) {
                  final controller = TextEditingController();
                  return AlertDialog(
                    title: const Text('Поиск по книге'),
                    content: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: 'Введите слово или фразу',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, controller.text.trim()),
                        child: const Text('OK'),
                      ),
                    ],
                  );
                },
              );
              if (query != null && query.isNotEmpty) _search(query);
            },
          ),
          IconButton(
            icon: const Icon(Icons.text_increase),
            tooltip: 'Увеличить шрифт',
            onPressed: () => _changeFontSize(fontSize + 2),
          ),
          IconButton(
            icon: const Icon(Icons.text_decrease),
            tooltip: 'Уменьшить шрифт',
            onPressed: () => _changeFontSize(fontSize - 2),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Text('Оглавление', style: TextStyle(fontSize: 20)),
            ),
            ...chapters.map(
              (ch) => ListTile(
                title: Text(ch.title ?? 'Без названия'),
                onTap: () {
                  epubController.display(cfi: ch.href ?? '');
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : EpubViewer(
              epubController: epubController,
              epubSource: EpubSource.fromAsset(widget.bookPath),
              displaySettings: EpubDisplaySettings(flow: EpubFlow.paginated),
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'prev',
            onPressed: epubController.prev,
            child: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            heroTag: 'next',
            onPressed: epubController.next,
            child: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
