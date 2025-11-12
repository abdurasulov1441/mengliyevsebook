import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/user_page/books/user_subboks.dart';

class NewArrivals extends StatelessWidget {
  final List<Map<String, String>> books;
  const NewArrivals({super.key, required this.books});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Yangi yuklanganlar",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              final imageUrl =
                  (book['image'] != null &&
                      book['image']!.isNotEmpty &&
                      book['image'] != 'https://etimolog.uz/_files')
                  ? book['image']!
                  : null;

              return GestureDetector(
                onTap: () {
                  final id = int.tryParse(book['id'] ?? '');
                  if (id != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserSubBooksPage(bookId: id),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: imageUrl != null
                            ? Image.network(
                                imageUrl,
                                height: 180,
                                width: 140,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                height: 180,
                                width: 140,
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.menu_book_outlined,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        book['title'] ?? 'No title',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        book['author'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
