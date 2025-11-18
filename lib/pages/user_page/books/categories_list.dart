import 'package:flutter/material.dart';
import 'package:mengliyevsebook/services/style/app_colors.dart';
import 'package:mengliyevsebook/services/style/app_style.dart';

class GenresList extends StatelessWidget {
  final List<String> genres;
  const GenresList({super.key, required this.genres});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: genres.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.grade1,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              genres[index],
              style: AppStyle.fontStyle.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.backgroundColor,
              ),
            ),
          );
        },
      ),
    );
  }
}
