import 'package:flutter/material.dart';

class TopReadsList extends StatelessWidget {
  final List<Map<String, dynamic>> topReads;
  const TopReadsList({super.key, required this.topReads});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  "${book['author']} tomonidan • ${book['year']} nashr etilgan",
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
    );
  }
}
