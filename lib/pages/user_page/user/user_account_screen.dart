import 'package:flutter/material.dart';
import 'package:mengliyevsebook/app/router.dart';
import 'package:mengliyevsebook/services/books/book_events.dart';
import 'package:mengliyevsebook/services/books/local_catalog.dart';
import 'package:mengliyevsebook/services/db/cache.dart';
import 'package:mengliyevsebook/services/utils/constants.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';

class UserAccountScreen extends StatefulWidget {
  const UserAccountScreen({super.key});

  @override
  State<UserAccountScreen> createState() => _UserAccountScreenState();
}

class _UserAccountScreenState extends State<UserAccountScreen> {
  int _books = 0;
  int _started = 0;
  int _finished = 0;

  @override
  void initState() {
    super.initState();
    booksChanged.addListener(_loadStats);
    _loadStats();
  }

  @override
  void dispose() {
    booksChanged.removeListener(_loadStats);
    super.dispose();
  }

  Future<void> _loadStats() async {
    if (!Constants.localMode) return;
    final mine = await LocalCatalog.myBooks();
    if (!mounted) return;
    setState(() {
      _books = mine.length;
      _started = mine.where((b) => ((b['progress'] as num?) ?? 0) > 0).length;
      _finished = mine.where((b) => ((b['progress'] as num?) ?? 0) >= 0.98).length;
    });
  }

  String get _name => cache.getString('user_name') ?? (Constants.localMode ? 'Mehmon' : 'Foydalanuvchi');

  Future<void> _resetOrLogout() async {
    final local = Constants.localMode;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: AppIcon(local ? 'rotate-ccw' : 'log-out', size: 28, color: AppPalette.danger),
        title: Text(local ? "Demo ma'lumotlarni tozalash" : 'Hisobdan chiqish', textAlign: TextAlign.center),
        content: Text(
          local ? "Demo xaridlar va o'qish jarayoni o'chiriladi. Kitoblar ilovada qoladi." : 'Qayta kirish uchun telefon raqamingizga SMS kod yuboriladi.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Bekor qilish')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: AppPalette.danger, minimumSize: const Size(120, 46)),
            child: Text(local ? 'Tozalash' : 'Chiqish'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await cache.clear();
    notifyBooksChanged();
    router.go(local ? Routes.userHome : Routes.loginScreen);
  }

  void _about() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        icon: Image.asset('assets/images/logo.png', width: 64, height: 64),
        title: const Text("Mengliyev's eBook", textAlign: TextAlign.center),
        content: const Text(
          "O'zbek tilidagi ilmiy va o'quv kitoblarni qulay o'qish uchun ilova.\n\n"
          'Shriftlar: Inter, Literata, Lora, PT Serif (SIL Open Font License).\n'
          'Ikonkalar: Lucide (ISC License).',
          textAlign: TextAlign.center,
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Yopish'))],
      ),
    );
  }

  void _soon(String what) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what — tez orada')));
  }

  @override
  Widget build(BuildContext context) {
    final initials = _name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).take(2).map((s) => s[0].toUpperCase()).join();
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 18, 20, 32),
        children: [
          const Text('PROFIL', style: AppText.overline),
          const SizedBox(height: 6),
          const Text('Hisobim', style: AppText.display),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppPalette.brand, AppPalette.brandDark]),
              boxShadow: [BoxShadow(color: AppPalette.brand.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(initials.isEmpty ? '?' : initials, style: AppText.title.copyWith(color: Colors.white, fontSize: 22)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_name, style: AppText.section.copyWith(color: Colors.white, fontSize: 19)),
                          const SizedBox(height: 3),
                          Text(
                            Constants.localMode ? "Oflayn demo rejim" : (cache.getString('user_phone') ?? ''),
                            style: AppText.caption.copyWith(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (Constants.localMode) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _Stat(value: '$_books', label: 'kitob'),
                      _Stat(value: '$_started', label: "o'qilmoqda"),
                      _Stat(value: '$_finished', label: 'tugatilgan'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 26),
          const _Section('Sozlamalar'),
          _Group(children: [
            _Tile(icon: 'globe', title: 'Til', trailing: "O'zbekcha", onTap: () => _soon('Tilni tanlash')),
            _Tile(icon: 'bell', title: 'Bildirishnomalar', onTap: () => _soon('Bildirishnomalar')),
            _Tile(icon: 'type', title: "O'qish sozlamalari", trailing: 'Kitob ichida', onTap: () => _soon("Shrift va fon kitob ichida «Aa» tugmasida")),
          ]),
          const SizedBox(height: 22),
          const _Section('Yordam'),
          _Group(children: [
            _Tile(icon: 'circle-help', title: 'Yordam markazi', onTap: () => _soon('Yordam markazi')),
            _Tile(icon: 'shield-check', title: 'Maxfiylik siyosati', onTap: () => _soon('Maxfiylik siyosati')),
            _Tile(icon: 'info', title: 'Ilova haqida', onTap: _about),
          ]),
          const SizedBox(height: 22),
          _Group(children: [
            _Tile(
              icon: Constants.localMode ? 'rotate-ccw' : 'log-out',
              title: Constants.localMode ? "Demo ma'lumotlarni tozalash" : 'Hisobdan chiqish',
              danger: true,
              onTap: _resetOrLogout,
            ),
          ]),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text(value, style: AppText.title.copyWith(color: Colors.white, fontFamily: AppFonts.ui, fontSize: 20)),
          const SizedBox(height: 2),
          Text(label, style: AppText.caption.copyWith(color: Colors.white.withValues(alpha: 0.8))),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String text;

  const _Section(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(text.toUpperCase(), style: AppText.caption.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8)),
      );
}

class _Group extends StatelessWidget {
  final List<Widget> children;

  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppPalette.line)),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 62),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String icon;
  final String title;
  final String? trailing;
  final bool danger;
  final VoidCallback onTap;

  const _Tile({required this.icon, required this.title, required this.onTap, this.trailing, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppPalette.danger : AppPalette.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: danger ? const Color(0xFFFBE9E1) : AppPalette.brandSoft, borderRadius: BorderRadius.circular(10)),
              child: Center(child: AppIcon(icon, size: 18, color: danger ? AppPalette.danger : AppPalette.brand)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: AppText.body.copyWith(color: color, fontWeight: FontWeight.w500))),
            if (trailing != null) Text(trailing!, style: AppText.caption.copyWith(fontSize: 13)),
            if (!danger) ...[const SizedBox(width: 6), const AppIcon('chevron-right', size: 18, color: AppPalette.muted)],
          ],
        ),
      ),
    );
  }
}
