import 'package:flutter/material.dart';
import 'package:mengliyevsebook/services/style/app_colors.dart';

class AudioScreen extends StatelessWidget {
  const AudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = [
      {'title': 'Motivation', 'icon': Icons.bolt},
      {'title': 'Romance', 'icon': Icons.favorite},
      {'title': 'Thriller', 'icon': Icons.movie_filter},
      {'title': 'Fantasy', 'icon': Icons.auto_awesome},
      {'title': 'Science', 'icon': Icons.psychology},
    ];

    final recommended = [
      {
        'title': 'Atomic Habits',
        'author': 'James Clear',
        'image': 'https://randomuser.me/api/portraits/women/2.jpg',
        'duration': '5h 34m',
      },
      {
        'title': 'The Subtle Art of Not Giving a F*ck',
        'author': 'Mark Manson',
        'image': 'https://randomuser.me/api/portraits/women/2.jpg',
        'duration': '6h 12m',
      },
      {
        'title': 'Can’t Hurt Me',
        'author': 'David Goggins',
        'image': 'https://randomuser.me/api/portraits/women/2.jpg',
        'duration': '4h 50m',
      },
    ];

    final trending = [
      {
        'title': 'The Power of Now',
        'author': 'Eckhart Tolle',
        'image': 'https://randomuser.me/api/portraits/women/2.jpg',
        'listeners': '12k',
      },
      {
        'title': 'Think Like a Monk',
        'author': 'Jay Shetty',
        'image': 'https://randomuser.me/api/portraits/women/2.jpg',
        'listeners': '9.8k',
      },
      {
        'title': 'Rich Dad Poor Dad',
        'author': 'Robert Kiyosaki',
        'image': 'https://randomuser.me/api/portraits/women/2.jpg',
        'listeners': '15k',
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
                          hintText: "Search audiobooks, authors...",
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

              // 🔊 Categories
              const Text(
                "Categories",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.primaries[index % Colors.primaries.length]
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            cat['icon'] as IconData,
                            color: Colors.teal,
                            size: 28,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cat['title']! as String,
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

              // 🎧 Recommended
              const Text(
                "Recommended for You",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 210,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: recommended.length,
                  itemBuilder: (context, index) {
                    final book = recommended[index];
                    return Container(
                      width: 150,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  book['image']!,
                                  height: 160,
                                  width: 150,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        book['duration']!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            book['title']!,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            book['author']!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // 🔥 Trending Now
              const Text(
                "Trending Now",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Column(
                children: trending.map((book) {
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
                      contentPadding: const EdgeInsets.all(10),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          book['image']!,
                          width: 50,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        book['title']!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        "by ${book['author']} • ${book['listeners']} listeners",
                      ),
                      trailing: const Icon(
                        Icons.play_circle_fill,
                        color: Colors.teal,
                        size: 32,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 90),
            ],
          ),
        ),
      ),

      // 🎵 Mini Player (Static)
      bottomSheet: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                'https://m.media-amazon.com/images/I/71UwSHSZRnS.jpg',
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "The Power of Now",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "Eckhart Tolle",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.skip_previous, color: Colors.grey),
            const SizedBox(width: 10),
            const Icon(Icons.play_circle_fill, color: Colors.teal, size: 36),
            const SizedBox(width: 10),
            const Icon(Icons.skip_next, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
