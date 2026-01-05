import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/user_page/books/epub_reader.dart';
import 'package:mengliyevsebook/services/db/cache.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/style/app_colors.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> myBooks = [];
  Map<String, double> downloadProgress = {};
  Map<String, bool> isDownloading = {};

  @override
  void initState() {
    super.initState();
    _fetchMyBooks();
  }

  Future<void> _fetchMyBooks() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final resp = await requestHelper.getWithAuth(
        "/api/books/my-books",
        log: true,
      );

      if (resp is Map && resp["books"] is List) {
        myBooks = resp["books"];
        // Проверяем какие книги уже скачаны
        await _checkDownloadedBooks();
      } else {
        myBooks = [];
      }

      setState(() => isLoading = false);
    } catch (e) {
      setState(() {
        errorMessage = "Xatolik: $e";
        isLoading = false;
      });
    }
  }

  Future<void> _checkDownloadedBooks() async {
    for (var book in myBooks) {
      final id = book["id"].toString();
      final localPath = cache.getString("book_${id}_path");
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          book["is_downloaded"] = true;
          book["local_path"] = localPath;
        } else {
          // Если файл не существует, удаляем из кэша
          cache.remove("book_${id}_path");
        }
      }
    }
  }

  Future<String> _getDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Для Android
        final directory = await getExternalStorageDirectory();
        if (directory != null && await directory.exists()) {
          // Создаем папку для книг
          final booksDir = Directory('${directory.path}/MengliyevBooks');
          if (!await booksDir.exists()) {
            await booksDir.create(recursive: true);
          }
          return booksDir.path;
        }
      }

      // Для iOS или если не удалось получить внешнее хранилище
      final directory = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${directory.path}/Books');
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }
      return booksDir.path;
    } catch (e) {
      print("Directory error: $e");
      // Резервный вариант
      final directory = await getTemporaryDirectory();
      return directory.path;
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true;
  }

  Future<void> _downloadBook(Map book) async {
    final bookId = book["id"].toString();
    final epubFile = book["epub_file"];

    if (epubFile == null || epubFile.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("EPUB fayl topilmadi")));
      return;
    }

    try {
      // Показываем индикатор загрузки
      setState(() {
        isDownloading[bookId] = true;
        downloadProgress[bookId] = 0.0;
      });

      // Запрашиваем разрешения
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        throw Exception("Fayl yuklash uchun ruxsat berilmadi");
      }

      // Готовим URL для скачивания
      final downloadUrl = "https://etimolog.uz/_files$epubFile";
      final fileName = "book_$bookId.epub";

      // Получаем директорию для сохранения
      final directory = await _getDownloadDirectory();
      final savePath = "$directory/$fileName";

      // Скачиваем файл
      final dio = Dio();

      await dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              downloadProgress[bookId] = received / total;
            });
          }
        },
        options: Options(headers: {'Accept': 'application/octet-stream'}),
      );

      // Проверяем что файл скачался
      final downloadedFile = File(savePath);
      if (!await downloadedFile.exists()) {
        throw Exception("Fayl yuklanmadi");
      }

      // Проверяем размер файла
      final fileSize = await downloadedFile.length();
      if (fileSize < 1024) {
        // Если файл меньше 1KB, вероятно ошибка
        await downloadedFile.delete();
        throw Exception("Fayl hajmi noto'g'ri");
      }

      // Сохраняем в кэш
      await cache.setString("book_${bookId}_path", savePath);

      // Обновляем состояние
      if (mounted) {
        setState(() {
          book["is_downloaded"] = true;
          book["local_path"] = savePath;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Kitob muvaffaqiyatli yuklandi"),
          action: SnackBarAction(
            label: "Ochish",
            onPressed: () => _onBookTap(book),
          ),
        ),
      );
    } catch (e) {
      print("Download error: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Yuklashda xatolik: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isDownloading.remove(bookId);
          downloadProgress.remove(bookId);
        });
      }
    }
  }

  void _onBookTap(Map book) async {
    final id = book["id"].toString();
    final localPath = cache.getString("book_${id}_path");

    if (localPath != null && await File(localPath).exists()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EpubReaderScreen(
            bookId: id,
            bookTitle: book["title"] ?? "Kitob",
            filePath: localPath,
          ),
        ),
      );
    } else {
      _showDownloadSheet(book);
    }
  }

  void _showDownloadSheet(Map book) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.3,
          maxChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.download_rounded,
                    size: 60,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),

                  Text(
                    book["title"] ?? "Kitob",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    "Kitobni o'qish uchun avval yuklab oling",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text("Bekor qilish"),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _downloadBook(book);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.grade1,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            "Yuklash",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ui,
      appBar: AppBar(
        title: const Text("Mening kitoblarim"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.4,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!))
          : myBooks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Hozircha kitoblar yo'q",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Do'kondan kitob sotib oling",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchMyBooks,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...myBooks.map((book) {
                    final id = book["id"].toString();
                    final img = book['photo'] != null
                        ? 'https://etimolog.uz/_files${book['photo']}'
                        : 'https://via.placeholder.com/100';

                    final isDownloaded = book["is_downloaded"] == true;
                    final isCurrentlyDownloading = isDownloading[id] == true;
                    final progress = downloadProgress[id] ?? 0.0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: AppColors.backgroundColor,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            img,
                            width: 40,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text(
                          book["title"] ?? "Noma'lum",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book["author"]?["uz"] ?? "Muallif",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Sana: ${book['purchase_date']?.toString().substring(0, 10) ?? 'Noma\'lum'}",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            if (isCurrentlyDownloading)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.grey.shade300,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.grade1,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: isCurrentlyDownloading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                isDownloaded ? Icons.menu_book : Icons.download,
                                color: isDownloaded
                                    ? Colors.green
                                    : AppColors.grade1,
                              ),
                        onTap: () => _onBookTap(book),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }
}
