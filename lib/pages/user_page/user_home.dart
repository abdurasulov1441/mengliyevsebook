import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/user_page/audio/audio_screen.dart';
import 'package:mengliyevsebook/pages/user_page/books/books_screen.dart';
import 'package:mengliyevsebook/pages/user_page/shop/shop_screen.dart';
import 'package:mengliyevsebook/pages/user_page/user/user_account_screen.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';

class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  int _index = 0;

  static const _tabs = [
    ('library-big', 'Kutubxona'),
    ('headphones', 'Audio'),
    ('shopping-bag', "Do'kon"),
    ('user-round', 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      // IndexedStack keeps each tab's scroll position and state.
      body: IndexedStack(
        index: _index,
        children: [
          BooksScreen(onOpenShop: () => setState(() => _index = 2)),
          const AudioScreen(),
          const ShopScreen(),
          const UserAccountScreen(),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        index: _index,
        tabs: _tabs,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int index;
  final List<(String, String)> tabs;
  final ValueChanged<int> onTap;

  const _BottomBar({required this.index, required this.tabs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surface,
        border: const Border(top: BorderSide(color: AppPalette.line)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                          decoration: BoxDecoration(
                            color: i == index ? AppPalette.brandSoft : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: AppIcon(tabs[i].$1, size: 22, color: i == index ? AppPalette.brand : AppPalette.muted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tabs[i].$2,
                          style: AppText.caption.copyWith(
                            fontSize: 11.5,
                            color: i == index ? AppPalette.brand : AppPalette.muted,
                            fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
