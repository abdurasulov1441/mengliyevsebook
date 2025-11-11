import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/user_page/books/authors_list.dart';
import 'package:mengliyevsebook/pages/user_page/books/geners_list.dart';
import 'package:mengliyevsebook/pages/user_page/books/new_arrivals.dart';
import 'package:mengliyevsebook/pages/user_page/books/top_reads_list.dart';
import 'package:mengliyevsebook/services/style/app_colors.dart';

class BooksScreen extends StatelessWidget {
  const BooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    
    final genres = [
      'Avtobiografiya',
      'Sanʼat va hunar',
      'Biznes',
      'Bolalar',
      'Fan',
    ];

    final books = [
      {
        'title': 'Very Nice',
        'author': 'Jane Doe',
        'image': 'assets/images/book1.jpeg',
      },
      {
        'title': 'Dream Walker',
        'author': 'John Hill',
        'image': 'assets/images/book2.jpg',
      },
      {
        'title': 'Stars in the Sky',
        'author': 'Lucy Hale',
        'image': 'assets/images/book3.jpg',
      },
    ];

    final authors = [
      {
        'name': 'Popular',
        'image': 'https://randomuser.me/api/portraits/women/1.jpg',
      },
      {
        'name': 'Famous',
        'image': 'https://randomuser.me/api/portraits/men/2.jpg',
      },
      {
        'name': 'English',
        'image': 'https://randomuser.me/api/portraits/women/3.jpg',
      },
      {
        'name': 'Spanish',
        'image': 'https://randomuser.me/api/portraits/men/4.jpg',
      },
      {
        'name': 'World',
        'image': 'https://randomuser.me/api/portraits/women/5.jpg',
      },
    ];

    final topReads = [
      {
        'title': 'Clueless',
        'author': 'John Davies',
        'year': '2018',
        'rating': 4.5,
        'image': 'https://m.media-amazon.com/images/I/71UwSHSZRnS.jpg',
      },
      {
        'title': 'The Hobbit',
        'author': 'J.R.R. Tolkien',
        'year': '2012',
        'rating': 4.8,
        'image': 'https://m.media-amazon.com/images/I/91b0C2YNSrL.jpg',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.ui,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔍 Поисковая строка
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Qidiruv: kitob, muallif yoki janr",
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const Icon(Icons.mic_none, color: Colors.grey),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              GenresList(genres: genres),

              const SizedBox(height: 20),

              NewArrivals(books: books),

              const SizedBox(height: 20),

              AuthorsList(authors: authors),

              const SizedBox(height: 20),

              TopReadsList(topReads: topReads),
            ],
          ),
        ),
      ),
    );
  }
}
