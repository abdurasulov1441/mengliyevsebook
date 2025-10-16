import 'package:flutter/material.dart';
import 'package:fluid_bottom_nav_bar/fluid_bottom_nav_bar.dart';
import 'package:mengliyevsebook/pages/user_page/audio/audio_screen.dart';
import 'package:mengliyevsebook/pages/user_page/books/books_screen.dart';
import 'package:mengliyevsebook/pages/user_page/shop/shop_screen.dart';
import 'package:mengliyevsebook/pages/user_page/user/user_account_screen.dart';
import 'package:mengliyevsebook/services/style/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Widget _child = const BooksScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _child,
      ),
      bottomNavigationBar: SafeArea(
        child: FluidNavBar(
          icons: [
            FluidNavBarIcon(
              svgPath: "assets/icons/books.svg",
              backgroundColor: AppColors.grade1,
              extras: {"label": "Books"},
            ),
            FluidNavBarIcon(
              svgPath: "assets/icons/music.svg",
              backgroundColor: AppColors.grade1,
              extras: {"label": "Audio"},
            ),
            FluidNavBarIcon(
              svgPath: "assets/icons/shop.svg",
              backgroundColor: AppColors.grade1,
              extras: {"label": "Shop"},
            ),
            FluidNavBarIcon(
              svgPath: "assets/icons/user.svg",
              backgroundColor: AppColors.grade1,
              extras: {"label": "Account"},
            ),
          ],
          onChange: _handleNavigationChange,
          style: FluidNavBarStyle(
            barBackgroundColor: AppColors.grade1,
            iconUnselectedForegroundColor: AppColors.backgroundColor,
            iconSelectedForegroundColor: AppColors.backgroundColor,
          ),
          scaleFactor: 1.5,
          defaultIndex: 0,
        ),
      ),
    );
  }

  void _handleNavigationChange(int index) {
    setState(() {
      switch (index) {
        case 0:
          _child = const BooksScreen();
          break;
        case 1:
          _child = const AudioScreen();
          break;
        case 2:
          _child = const ShopScreen();
          break;
        case 3:
          _child = const UserAccountScreen();
          break;
      }
    });
  }
}
