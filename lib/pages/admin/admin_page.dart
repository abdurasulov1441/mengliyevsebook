import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/admin/audio_books_page/audio_books_page.dart';
import 'package:mengliyevsebook/pages/admin/authors_page/authors_page.dart';
import 'package:mengliyevsebook/pages/admin/book_stats_page/book_stats_page.dart';
import 'package:mengliyevsebook/pages/admin/books_page/books_page.dart';
import 'package:mengliyevsebook/pages/admin/categories_page/categories_page.dart';
import 'package:mengliyevsebook/pages/admin/main_page/main_page.dart';
import 'package:mengliyevsebook/pages/admin/settings_page/settings_page.dart';
import 'package:mengliyevsebook/pages/admin/user_stats_page/user_stats_page.dart';

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
    BookStatsPage(),
    UserStatsPage(),
    SettingsPage(),
  ];

  final List<String> _titles = [
    'Основная страница',
    'Добавление категории',
    'Добавление автора',
    'Добавление книги',
    'Добавление аудиокниги',
    'Статистика книг',
    'Статистика пользователей',
    'Настройки',
  ];

  void _onItemTap(int index) {
    setState(() {
      _selectedIndex = index;
      Navigator.pop(context); // закрываем Drawer
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
              decoration: BoxDecoration(color: Colors.blue),
              child: Center(
                child: Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            _drawerItem(Icons.dashboard, 'Основная страница', 0),
            _drawerItem(Icons.category, 'Добавление категории', 1),
            _drawerItem(Icons.person_add, 'Добавление автора', 2),
            _drawerItem(Icons.book, 'Добавление книги', 3),
            _drawerItem(Icons.audiotrack, 'Добавление аудиокниги', 4),
            _drawerItem(Icons.bar_chart, 'Статистика книг', 5),
            _drawerItem(Icons.people, 'Статистика пользователей', 6),
            _drawerItem(Icons.settings, 'Настройки', 7),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }

  ListTile _drawerItem(IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(icon, color: _selectedIndex == index ? Colors.blue : null),
      title: Text(
        title,
        style: TextStyle(
          color: _selectedIndex == index ? Colors.blue : null,
          fontWeight: _selectedIndex == index ? FontWeight.bold : null,
        ),
      ),
      onTap: () => _onItemTap(index),
    );
  }
}
