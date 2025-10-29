import 'package:flutter/material.dart';

import 'package:mengliyevsebook/services/style/app_colors.dart';
import 'package:mengliyevsebook/services/style/app_style.dart';

class UserAccountScreen extends StatelessWidget {
  const UserAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ui,
      appBar: AppBar(
        backgroundColor: AppColors.ui,
        centerTitle: true,
        elevation: 0,
        title: Text(
          "Akkaunt",
          style: AppStyle.fontStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: Colors.black87,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          // --- Профиль пользователя ---
          const SizedBox(height: 10),
          Row(
            children: [
              const CircleAvatar(
                radius: 45,
                backgroundImage: NetworkImage(
                  "https://cdn-icons-png.flaticon.com/512/3135/3135715.png",
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Abdulaziz Abdurasulov",
                      style: AppStyle.fontStyle.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      "+998 90 123 45 67",
                      style: AppStyle.fontStyle.copyWith(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),
          _buildSectionTitle("Mening kutubxonam"),
          _buildListTile(Icons.bookmark_outline, "Saqlangan kitoblar", () {}),
          _buildListTile(Icons.favorite_outline, "Sevimli kitoblarim", () {}),
          _buildListTile(
            Icons.download_done_outlined,
            "Yuklab olingan kitoblar",
            () {},
          ),
          _buildListTile(Icons.history, "O'qilgan kitoblar", () {}),

          const SizedBox(height: 25),
          _buildSectionTitle("Sozlamalar"),
          _buildListTile(Icons.language_outlined, "Til", () {}),
          _buildListTile(Icons.notifications_none, "Bildirishnomalar", () {}),
          _buildListTile(Icons.dark_mode_outlined, "Tungi rejim", () {}),
          _buildListTile(
            Icons.security_outlined,
            "Maxfiylik va xavfsizlik",
            () {},
          ),

          const SizedBox(height: 25),
          _buildSectionTitle("Yordam va qo'llab-quvvatlash"),
          _buildListTile(Icons.help_outline, "Yordam", () {}),
          _buildListTile(Icons.info_outline, "Ilova haqida", () {}),

          const SizedBox(height: 25),
          _buildLogoutButton(context),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- Заголовок секции ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: AppStyle.fontStyle.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  // --- Элемент списка ---
  Widget _buildListTile(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.grade1),
        title: Text(
          title,
          style: AppStyle.fontStyle.copyWith(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }

  // --- Кнопка выхода ---
  Widget _buildLogoutButton(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.logout, color: Colors.white),
        label: Text(
          "Chiqish",
          style: AppStyle.fontStyle.copyWith(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.grade1,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
