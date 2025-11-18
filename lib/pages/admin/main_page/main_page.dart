import 'package:flutter/material.dart';
import 'package:mengliyevsebook/services/style/app_colors.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatCard(
              title: 'Umumiy foydalanuvchilar',
              value: '12,450',
              icon: Icons.people,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            _buildStatCard(
              title: 'Umumiy kitoblar soni',
              value: '3,120',
              icon: Icons.menu_book,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            _buildStatCard(
              title: 'Bugun sotilgan kitoblar',
              value: '240',
              icon: Icons.shopping_cart,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),

            const Text(
              'Eng ko‘p xarid qilingan kitoblar',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTopBook('Atomic Habits', 1240),
            _buildTopBook('Rich Dad Poor Dad', 980),
            _buildTopBook('Clean Code', 870),
            _buildTopBook('Harry Potter', 750),

            const SizedBox(height: 24),
            const Text(
              'Oylik savdo diagrammasi (Mock)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey.shade300,
              alignment: Alignment.center,
              child: const Text('Diagramma uchun joy'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16)),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBook(String name, int sold) {
    return ListTile(
      leading: const Icon(Icons.book, size: 30),
      title: Text(name),
      trailing: Text('$sold dona'),
    );
  }
}
