import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/admin/audio_books_page/audio_books_page.dart';
import 'package:mengliyevsebook/pages/admin/authors_page/authors_page.dart';
import 'package:mengliyevsebook/pages/admin/book_stats_page/book_stats_page.dart';
import 'package:mengliyevsebook/pages/admin/books_page/books_page.dart';
import 'package:mengliyevsebook/pages/admin/categories_page/categories_page.dart';
import 'package:mengliyevsebook/pages/admin/main_page/main_page.dart';
import 'package:mengliyevsebook/pages/admin/settings_page/settings_page.dart';
import 'package:mengliyevsebook/services/style/app_colors.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    MainPage(),
    CategoriesPage(),
    AuthorsPage(),
    BooksPage(),
    AudioBooksPage(),
    PaymentAcceptPage(),
    SettingsPage(),
  ];

  final List<String> _titles = [
    'Asosiy sahifa',
    'Kategoriya qo‘shish',
    'Muallif qo‘shish',
    'Kitob qo‘shish',
    'Audio kitob qo‘shish',
    'To‘lov xabarlari',
    'Sozlamalar',
  ];

  void _onItemTap(int index) {
    setState(() {
      _selectedIndex = index;
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selectedIndex]), centerTitle: true),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: AppColors.grade1),
              child: Center(
                child: Text(
                  'E-Book Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            _drawerItem(Icons.dashboard, 'Asosiy sahifa', 0),
            _drawerItem(Icons.category, 'Kategoriya qo‘shish', 1),
            _drawerItem(Icons.person_add, 'Muallif qo‘shish', 2),
            _drawerItem(Icons.book, 'Kitob qo‘shish', 3),
            _drawerItem(Icons.audiotrack, 'Audio kitob qo‘shish', 4),
            _drawerItem(Icons.payment, 'To‘lov xabarlari', 5),
            _drawerItem(Icons.settings, 'Sozlamalar', 6),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }

  ListTile _drawerItem(IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(
        icon,
        color: _selectedIndex == index ? AppColors.grade1 : AppColors.uiText,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: _selectedIndex == index ? AppColors.grade1 : AppColors.uiText,
          fontWeight: _selectedIndex == index
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
      onTap: () => _onItemTap(index),
    );
  }
}
