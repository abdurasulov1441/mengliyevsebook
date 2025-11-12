import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/user_page/books/book_reader_page.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/utils/errors.dart';
import 'package:path_provider/path_provider.dart';

class UserSubBooksPage extends StatefulWidget {
  final int bookId;
  const UserSubBooksPage({super.key, required this.bookId});

  @override
  State<UserSubBooksPage> createState() => _UserSubBooksPageState();
}

class _UserSubBooksPageState extends State<UserSubBooksPage> {
  List<dynamic> subBooks = [];
  bool isLoading = true;
  String? errorMessage;
  bool isDownloading = false;
  double downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchSubBooks();
  }

  Future<void> _fetchSubBooks() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await requestHelper.getWithAuth(
        '/api/sub-books/get-sub-book/${widget.bookId}',
        log: true,
      );

      if (response is Map && response['id'] != null) {
        subBooks = [response];
      } else if (response is List) {
        subBooks = response;
      } else {
        subBooks = [];
      }

      setState(() => isLoading = false);
    } on UnauthenticatedError {
      setState(() {
        errorMessage = 'Авторизация xatosi. Qayta kirish kerak.';
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Ma’lumot yuklashda xatolik: $e';
        isLoading = false;
      });
    }
  }

  /// 📁 Получаем путь для хранения книги
  Future<String> _getLocalPath(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$fileName';
  }

  /// 🔎 Проверяем, есть ли файл уже в кэше
  Future<bool> _isFileCached(String fileName) async {
    final path = await _getLocalPath(fileName);
    return File(path).exists();
  }

  /// ⬇️ Скачиваем и открываем книгу
  Future<void> _downloadAndOpen(String remotePath, String title) async {
    final fileName = remotePath.split('/').last;
    final localPath = await _getLocalPath(fileName);
    final dioClient = Dio();

    setState(() {
      isDownloading = true;
      downloadProgress = 0.0;
    });

    try {
      final url = remotePath.startsWith('http')
          ? remotePath
          : 'https://etimolog.uz/_files${remotePath.startsWith('/') ? '' : '/'}$remotePath';

      debugPrint('📘 Yuklanmoqda: $url');

      await dioClient.download(
        url,
        localPath,
        onReceiveProgress: (count, total) {
          if (total != -1) {
            setState(() => downloadProgress = count / total);
          }
        },
      );

      setState(() => isDownloading = false);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                EpubProReaderPage(bookPath: localPath, title: title),
          ),
        );
      }
    } catch (e) {
      setState(() => isDownloading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Yuklab olishda xatolik: $e')));
    }
  }

  /// 📖 Показываем окно с информацией и выбором (скачать или читать)
  void _showBookInfo(Map<String, dynamic> book) async {
    final fileUrl = book['epub_file'] ?? book['file'];
    final fileName = fileUrl.split('/').last;
    final isCached = await _isFileCached(fileName);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book['title'] ?? 'No title',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                book['description'] ?? 'Tavsif mavjud emas',
                style: const TextStyle(color: Colors.black54),
              ),
              const Spacer(),
              if (isCached)
                ElevatedButton.icon(
                  onPressed: () async {
                    final localPath = await _getLocalPath(fileName);
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EpubProReaderPage(
                          bookPath: localPath,
                          title: book['title'] ?? 'Kitob',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.menu_book),
                  label: const Text('O‘qishni boshlash'),
                )
              else if (isDownloading)
                Column(
                  children: [
                    const Text('Yuklanmoqda...'),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: downloadProgress),
                  ],
                )
              else
                ElevatedButton.icon(
                  onPressed: () {
                    _downloadAndOpen(fileUrl, book['title'] ?? '');
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Kitobni yuklab olish'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLang(dynamic id) {
    switch (id.toString()) {
      case '1':
        return 'O‘zbek';
      case '2':
        return 'Русский';
      case '3':
        return 'English';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kitob fayllari')),
      body: Builder(
        builder: (context) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (errorMessage != null) {
            return Center(child: Text(errorMessage!));
          }
          if (subBooks.isEmpty) {
            return const Center(child: Text('Fayllar mavjud emas'));
          }

          return ListView.builder(
            itemCount: subBooks.length,
            itemBuilder: (context, i) {
              final s = subBooks[i];
              final img = 'https://etimolog.uz/_files${s['photo'] ?? ''}';
              final lang = _getLang(s['lang_id']);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  onTap: () => _showBookInfo(s),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      img,
                      width: 60,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.grey[300]),
                    ),
                  ),
                  title: Text(
                    s['title'] ?? 'No title',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Til: $lang\n${s['description'] ?? ''}'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
