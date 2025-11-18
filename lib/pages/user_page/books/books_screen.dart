import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/user_page/books/book_open/book_reader_page.dart';
import 'package:mengliyevsebook/services/db/cache.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/style/app_colors.dart';
import 'package:path_provider/path_provider.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  bool isLoading = true;
  String? errorMessage;

  List<dynamic> books = []; // Barcha kitoblar
  List<dynamic> userReadBooks = []; // User o‘qigan kitoblar (yoki yuklab olgan)

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Barcha kitoblar
      final booksResp = await requestHelper.getWithAuth(
        "/api/books/get-books?page=1&limit=50&is_free=true",
        log: true,
      );

      if (booksResp is Map && booksResp["books"] is List) {
        books = booksResp["books"];
      }

      // User o‘qigan/yuklab olgan kitoblar (demo uchun)
      // Agar sening APIing bo‘lsa shu yerga qo‘shib beraman.
      userReadBooks = books.take(5).toList(); // Test uchun 5 tasini oldik

      setState(() => isLoading = false);
    } catch (e) {
      setState(() {
        errorMessage = "Xatolik: $e";
        isLoading = false;
      });
    }
  }

  Future<void> _downloadBook(Map book) async {
    try {
      final dio = Dio();

      final fileUrl =
          "https://etimolog.uz/_files${book['epub_file']}"; // 🔥 YARATILGAN URL

      final dir = await getApplicationDocumentsDirectory();
      final savePath = "${dir.path}/${book['id']}.epub";

      await dio.download(fileUrl, savePath);

      // 🔥 Cache ga saqlaymiz
      cache.setString("book_${book['id']}_path", savePath);

      Navigator.pop(context); // bottom sheet ni yopamiz

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kitob muvaffaqiyatli yuklandi!")),
      );

      // 🔥 Endi kitobni o‘qiymiz
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EpubProReaderPage(
            bookPath: savePath,
            title: book["title"] ?? "Kitob",
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Yuklab olishda xato: $e")));
    }
  }

  void _openBookBottomSheet(Map book) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final img = book["photo"] != null
            ? "https://etimolog.uz/_files${book['photo']}"
            : "https://via.placeholder.com/200";

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(img, width: 150, height: 200),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                book["title"],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),
              Text(
                book["author"]?["uz"] ?? "Muallif",
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),

              const SizedBox(height: 16),
              Text(book["description"] ?? ""),

              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _downloadBook(book),
                icon: const Icon(Icons.download),
                label: const Text("Kitobni yuklab olish"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onBookTap(Map book) async {
    final id = book["id"].toString();
    final localPath = cache.getString("book_${id}_path");

    if (localPath != null) {
      // 🔥 Kitob allaqachon yuklangan → ochamiz
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EpubProReaderPage(
            bookPath: localPath,
            title: book["title"] ?? "Kitob",
          ),
        ),
      );
    } else {
      // 📌 Yuklanmagan → bottom sheet ochamiz
      _openBookBottomSheet(book);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ui,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(child: Text(errorMessage!))
            : RefreshIndicator(
                onRefresh: _fetchAll,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 🔵 GORIZONTAL USER O‘QIGAN KITOBLAR
                    if (userReadBooks.isNotEmpty) ...[
                      Text(
                        "O‘qilgan / Yuklab olingan kitoblar",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      HorizontalUserBooks(books: userReadBooks),
                      const SizedBox(height: 30),
                    ],

                    // 🔥 BARCHA KITOBLAR VERTICAL LISTVIEW
                    Text(
                      "Barcha kitoblar",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...books.map((book) {
                      final img = book['photo'] != null
                          ? 'https://etimolog.uz/_files${book['photo']}'
                          : 'https://via.placeholder.com/100';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              img,
                              width: 60,
                              height: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(
                            book["title"] ?? "Noma'lum",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            book['author']?['uz'] ?? "Muallif yo‘q",
                          ),
                          onTap: () => _onBookTap(book),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
      ),
    );
  }
}

class HorizontalUserBooks extends StatelessWidget {
  final List<dynamic> books;

  const HorizontalUserBooks({super.key, required this.books});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        itemBuilder: (context, index) {
          final b = books[index];

          final img = b['photo'] != null
              ? 'https://etimolog.uz/_files${b['photo']}'
              : "https://via.placeholder.com/150";

          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: NetworkImage(img),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
              padding: const EdgeInsets.all(8),
              alignment: Alignment.bottomLeft,
              child: Text(
                b["title"] ?? "Noma'lum",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }
}
