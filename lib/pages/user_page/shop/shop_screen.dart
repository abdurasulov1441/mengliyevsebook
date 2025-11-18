import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/user_page/books/book_open/book_reader_page.dart';
import 'package:mengliyevsebook/pages/user_page/shop/buy_book_page.dart';
import 'package:mengliyevsebook/services/db/cache.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/style/app_colors.dart';
import 'package:path_provider/path_provider.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  bool isLoading = true;
  String? errorMessage;

  List<dynamic> paidBooks = [];

  @override
  void initState() {
    super.initState();
    _fetchPaidBooks();
  }

  Future<void> _fetchPaidBooks() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final resp = await requestHelper.getWithAuth(
        "/api/books/get-books?page=1&limit=50&is_free=false",
        log: true,
      );

      if (resp is Map && resp["books"] is List) {
        paidBooks = resp["books"];
      }

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

      final fileUrl = "https://etimolog.uz/_files${book['epub_file']}";
      final dir = await getApplicationDocumentsDirectory();
      final savePath = "${dir.path}/${book['id']}.epub";

      await dio.download(fileUrl, savePath);

      cache.setString("book_${book['id']}_path", savePath);

      Navigator.pop(context);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Kitob yuklab olindi!")));

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EpubProReaderPage(bookPath: savePath, title: book["title"]),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Yuklab olishda xato: $e")));
    }
  }

  void _openBookBuySheet(Map book) {
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

              const SizedBox(height: 14),

              Text(
                "Narxi: ${book['price']} so‘m",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // 👉 Sotib olish tugmasi
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // bottom sheet yopiladi
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BuyBookScreen(book: book),
                    ),
                  );
                },
                icon: const Icon(Icons.shopping_cart),
                label: const Text("Sotib olish"),
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EpubProReaderPage(bookPath: localPath, title: book["title"]),
        ),
      );
    } else {
      _openBookBuySheet(book);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ui,
      appBar: AppBar(
        title: const Text("Do‘kon (Pullik kitoblar)"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.4,
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!))
          : RefreshIndicator(
              onRefresh: _fetchPaidBooks,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    "Pullik kitoblar",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ...paidBooks.map((book) {
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
                          book["title"],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          "${book['author']?['uz'] ?? "Muallif"} • ${book['price']} so‘m",
                        ),
                        trailing: const Icon(Icons.chevron_right),
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
