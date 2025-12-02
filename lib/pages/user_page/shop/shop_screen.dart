import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/user_page/books/book_open/book_reader_page.dart';
import 'package:mengliyevsebook/pages/user_page/shop/buy_book_page.dart';
import 'package:mengliyevsebook/services/db/cache.dart';
import 'package:mengliyevsebook/services/gradientbutton.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/style/app_colors.dart';

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

  void _openBookBuySheet(Map book) {
    final img = book["photo"] != null
        ? "https://etimolog.uz/_files${book['photo']}"
        : "https://via.placeholder.com/200";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,

      isScrollControlled: true, // ➤ to‘liq ekranga chiqishiga ruxsat
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6, // boshlang'ich ochilish (60%)
          minChildSize: 0.4,
          maxChildSize: 0.95, // deyarli to‘liq ekran
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                controller: scrollController, // ➤ scroll boshqaruvchisi
                child: Column(
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
                      book["title"] ?? "",
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

                    const SizedBox(height: 20),

                    Text(
                      "Narxi: ${book['price']} so‘m",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),
                    GradientButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BuyBookScreen(book: book),
                          ),
                        );
                      },
                      text: "Sotib olish",
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
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
                  ...paidBooks.map((book) {
                    final img = book['photo'] != null
                        ? 'https://etimolog.uz/_files${book['photo']}'
                        : 'https://via.placeholder.com/100';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: AppColors.backgroundColor,
                        leading: Image.network(
                          img,
                          width: 40,
                          height: 64,

                          fit: BoxFit.fitHeight,
                        ),
                        title: Text(
                          book["title"],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          "${book['author']?['uz'] ?? "Muallif"} • ${book['price']} so‘m",
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.grade1,
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
