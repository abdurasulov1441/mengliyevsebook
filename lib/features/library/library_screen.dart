import 'package:flutter/material.dart';
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/core/session.dart';
import 'package:mengliyevsebook/features/auth/auth_flow.dart';
import 'package:mengliyevsebook/features/book/book_page.dart';
import 'package:mengliyevsebook/features/reader/reader_launcher.dart';
import 'package:mengliyevsebook/features/shell/main_shell.dart';
import 'package:mengliyevsebook/services/books/book_events.dart';
import 'package:mengliyevsebook/services/books/book_library.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:mengliyevsebook/widgets/common.dart';

/// "My books" (bought + free) and saved favorites.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (!session.loggedIn) {
          return Scaffold(
            body: SafeArea(
              child: EmptyState(
                icon: 'library-big',
                title: 'Kutubxonangiz shu yerda',
                text: "Sotib olgan va saqlagan kitoblaringizni ko'rish uchun telefon raqamingiz bilan kiring",
                action: 'Kirish',
                onAction: () => requireLogin(context),
              ),
            ),
          );
        }
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            body: SafeArea(
              bottom: false,
              child: Column(children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: PageHeader(overline: 'Mening', title: 'Kutubxona'),
                ),
                TabBar(
                  labelStyle: AppText.label,
                  unselectedLabelStyle: AppText.label,
                  labelColor: AppPalette.brand,
                  unselectedLabelColor: AppPalette.muted,
                  indicatorColor: AppPalette.brand,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: AppPalette.line,
                  tabs: const [Tab(text: 'Kitoblarim'), Tab(text: 'Saqlanganlar')],
                ),
                const Expanded(child: TabBarView(children: [_MyBooks(), _Favorites()])),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _MyBooks extends StatefulWidget {
  const _MyBooks();

  @override
  State<_MyBooks> createState() => _MyBooksState();
}

class _MyBooksState extends State<_MyBooks> {
  final _key = GlobalKey<AsyncViewState<List<Map>>>();
  final _downloaded = <String>{};
  final _progress = <String, double>{};
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    booksChanged.addListener(_onChanged);
  }

  @override
  void dispose() {
    booksChanged.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => _key.currentState?.reload();

  Future<List<Map>> _load() async {
    List<Map> books;
    try {
      books = ((await api.get('/api/me/library'))['books'] as List).cast<Map>();
      _offline = false;
    } on ApiException catch (e) {
      // Offline: show what is on the phone so reading still works.
      if (!e.offline) rethrow;
      books = await BookLibrary.instance.offlineBooks();
      _offline = true;
    }
    _downloaded.clear();
    for (final b in books) {
      if (await BookLibrary.instance.localVersion(b['id'].toString()) != null) _downloaded.add(b['id'].toString());
    }
    return books;
  }

  Future<void> _open(Map b) async {
    final id = b['id'].toString();
    try {
      await openBook(context, b, onProgress: (p) => setState(() => _progress[id] = p));
    } catch (e) {
      if (mounted) toast(context, errorText(e), error: true);
    }
    if (mounted) setState(() => _progress.remove(id));
  }

  Future<void> _menu(Map b) async {
    final id = b['id'].toString();
    final free = b['is_purchased'] != true;
    final r = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(b['title'] ?? '', style: AppText.section, maxLines: 2, textAlign: TextAlign.center),
          ),
          MenuTile(icon: 'info', title: 'Kitob haqida', onTap: () => Navigator.pop(c, 'about')),
          if (_downloaded.contains(id)) MenuTile(icon: 'trash-2', title: "Telefondan o'chirish", subtitle: "Internetsiz o'qish uchun qayta yuklab olish mumkin", onTap: () => Navigator.pop(c, 'local')),
          if (free && !_offline) MenuTile(icon: 'x', title: 'Kutubxonadan olib tashlash', danger: true, onTap: () => Navigator.pop(c, 'remove')),
        ]),
      ),
    );
    if (!mounted || r == null) return;
    if (r == 'about') return openBookPage(context, b);
    await BookLibrary.instance.remove(id);
    if (r == 'remove') {
      try {
        await api.delete('/api/me/library/$id');
      } catch (e) {
        if (mounted) toast(context, errorText(e), error: true);
      }
    }
    notifyBooksChanged();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Map>>(
      key: _key,
      load: _load,
      builder: (context, books, reload) {
        if (books.isEmpty) {
          return EmptyState(
            icon: 'book-open',
            title: "Hali kitoblar yo'q",
            text: "Katalogdan bepul kitob oling yoki yoqqanini sotib oling — ular shu yerda saqlanadi",
            action: 'Katalogga o‘tish',
            onAction: () => ShellNav.openCatalog(),
          );
        }
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.only(top: 6, bottom: 24),
            children: [
              if (_offline)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Panel(
                    child: Row(children: [
                      AppIcon('wifi-off', size: 20, color: AppPalette.warning),
                      SizedBox(width: 10),
                      Expanded(child: Text("Internet yo'q. Telefonga yuklangan kitoblar ko'rsatilmoqda", style: AppText.bodySoft)),
                    ]),
                  ),
                ),
              for (final b in books) _row(b),
            ],
          ),
        );
      },
    );
  }

  Widget _row(Map b) {
    final id = b['id'].toString();
    final percent = ((b['progress'] as num?) ?? 0).toDouble().clamp(0, 100) / 100;
    final loading = _progress[id];
    return GestureDetector(
      onLongPress: () => _menu(b),
      child: BookRow(
        book: b,
        onTap: () => loading == null ? _open(b) : null,
        badge: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: loading ?? percent.toDouble(), minHeight: 5, color: loading != null ? AppPalette.brandMid : AppPalette.brand, backgroundColor: AppPalette.surfaceAlt),
              ),
            ),
            const SizedBox(width: 10),
            Text(loading != null ? 'Yuklanmoqda' : percent == 0 ? 'Yangi' : '${(percent * 100).round()}%', style: AppText.caption),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            AppIcon(_downloaded.contains(id) ? 'circle-check' : 'download', size: 14, color: _downloaded.contains(id) ? AppPalette.success : AppPalette.muted),
            const SizedBox(width: 4),
            Text(_downloaded.contains(id) ? 'Telefonda' : 'Bulutda', style: AppText.caption),
          ]),
        ]),
        trailing: AppIconButton('ellipsis-vertical', color: AppPalette.muted, onTap: () => _menu(b)),
      ),
    );
  }
}

class _Favorites extends StatefulWidget {
  const _Favorites();

  @override
  State<_Favorites> createState() => _FavoritesState();
}

class _FavoritesState extends State<_Favorites> {
  final _key = GlobalKey<AsyncViewState<List<Map>>>();

  @override
  void initState() {
    super.initState();
    booksChanged.addListener(_onChanged);
  }

  @override
  void dispose() {
    booksChanged.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => _key.currentState?.reload();

  @override
  Widget build(BuildContext context) {
    return AsyncView<List<Map>>(
      key: _key,
      load: () async => ((await api.get('/api/me/favorites'))['books'] as List).cast<Map>(),
      builder: (context, books, reload) {
        if (books.isEmpty) {
          return const EmptyState(icon: 'heart', title: "Saqlanganlar bo'sh", text: "Kitob sahifasida yurakchani bosing — keyinroq o'qish uchun shu yerda turadi");
        }
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.only(top: 6, bottom: 24),
            children: [
              for (final b in books)
                BookRow(
                  book: b,
                  onTap: () => openBookPage(context, b),
                  trailing: AppIconButton('heart-filled', color: AppPalette.danger, onTap: () async {
                    try {
                      await api.post('/api/books/${b['id']}/favorite');
                      notifyBooksChanged();
                    } catch (e) {
                      if (context.mounted) toast(context, errorText(e), error: true);
                    }
                  }),
                ),
            ],
          ),
        );
      },
    );
  }
}
