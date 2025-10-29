import 'package:flutter/material.dart';
import 'package:mengliyevsebook/services/style/app_colors.dart';
import 'package:mengliyevsebook/services/style/app_style.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  // Статичный список книг
  final List<Map<String, dynamic>> books = [
    {
      "title": "The Silent Patient",
      "author": "Alex Michaelides",
      "price": 6000,
      "rating": 4.7,
      "cover": "assets/images/book1.jpeg",
    },
    {
      "title": "Atomic Habits",
      "author": "James Clear",
      "price": 9000,
      "rating": 4.9,
      "cover": "assets/images/book2.jpg",
    },
    {
      "title": "The Alchemist",
      "author": "Paulo Coelho",
      "price": 12000,
      "rating": 4.6,
      "cover": "assets/images/book3.jpg",
    },
  ];

  // Удаление книги из списка
  void removeBook(int index) {
    setState(() {
      books.removeAt(index);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Book removed from cart")));
  }

  double get totalPrice {
    double total = 0;
    for (var book in books) {
      total += book["price"];
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ui,
      appBar: AppBar(
        backgroundColor: AppColors.ui,
        centerTitle: true,
        elevation: 0,
        title: Text(
          "Savatcha",
          style: AppStyle.fontStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: Colors.black87,
          ),
        ),
      ),
      body: Column(
        children: [
          // ---- Итоговая сумма сверху ----
          if (books.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Jami:",
                    style: AppStyle.fontStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    "${totalPrice.toStringAsFixed(2)} so'm",
                    style: AppStyle.fontStyle.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.grade1,
                    ),
                  ),
                ],
              ),
            ),

          // ---- Основное содержимое ----
          Expanded(
            child: books.isEmpty
                ? const Center(
                    child: Text(
                      "Your cart is empty.",
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              book["cover"],
                              width: 50,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(
                            book["title"],
                            style: AppStyle.fontStyle.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book["author"],
                                style: AppStyle.fontStyle.copyWith(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${book["price"]} so'm",
                                style: AppStyle.fontStyle.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.grade1,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            onPressed: () => removeBook(index),
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.redAccent,
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // ---- Кнопка "Купить" внизу ----
          if (books.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Sotib olish muvaffaqiyatli amalga oshirildi!",
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.grade1,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "Sotib olish ${totalPrice.toStringAsFixed(2)} so'm",
                  style: AppStyle.fontStyle.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
