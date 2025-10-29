import 'package:flutter/material.dart';
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
              // 🔍 Search Bar
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

              // 🏷️ Genres
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: genres.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        genres[index],
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // 🆕 Fresh Arrivals
              const Text(
                "Yangi yuklanganlar",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final book = books[index];
                    return Container(
                      width: 160,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              book['image']!,
                              height: 180,
                              width: 140,
                              fit: BoxFit.fill,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            book['title']!,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Text(
                          //   book['author']!,
                          //   style: TextStyle(
                          //     color: Colors.grey[600],
                          //     fontSize: 13,
                          //   ),
                          // ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // 👨‍🎓 Authors
              const Text(
                "Mualliflar",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: authors.length,
                  itemBuilder: (context, index) {
                    final author = authors[index];
                    return Container(
                      margin: const EdgeInsets.only(right: 14),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundImage: NetworkImage(author['image']!),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            author['name']!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // 📖 Top Reads
              const Text(
                "Eng ko'p o'qilganlar",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              Column(
                children: topReads.map((book) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                        child: Image.network(
                          book['image']! as String,
                          width: 50,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        book['title']! as String,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        " ${book['author']} tomonidan •  ${book['year']} nashr etilgan",
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(book['rating'].toString()),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
