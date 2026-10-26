import 'package:flutter/material.dart';
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/core/session.dart';
import 'package:mengliyevsebook/features/author/author_page.dart';
import 'package:mengliyevsebook/features/author/become_author_screen.dart';
import 'package:mengliyevsebook/features/book/book_page.dart';
import 'package:mengliyevsebook/features/catalog/catalog_screen.dart';
import 'package:mengliyevsebook/features/profile/notifications_screen.dart';
import 'package:mengliyevsebook/features/reader/reader_launcher.dart';
import 'package:mengliyevsebook/features/shell/main_shell.dart';
import 'package:mengliyevsebook/services/books/book_events.dart';
import 'package:mengliyevsebook/services/utils/constants.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:mengliyevsebook/widgets/book_cover.dart';
import 'package:mengliyevsebook/widgets/common.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map? _home;
  Map? _continue;
  Object? _error;

  @override
  void initState() {
    super.initState();
    booksChanged.addListener(_load);
    session.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    booksChanged.removeListener(_load);
    session.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final home = await api.get('/api/home');
      Map? cont;
      if (session.loggedIn) {
        final lib = await api.get('/api/me/library');
        final started = ((lib['books'] as List?) ?? []).cast<Map>().where((b) {
          final p = ((b['progress'] as num?) ?? 0).toDouble();
          return p > 0 && p < 0.995;
        });
        cont = started.isEmpty ? null : started.first;
      }
      if (mounted) {
        setState(() {
          _home = home;
          _continue = cont;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = _home;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverSafeArea(bottom: false, sliver: SliverToBoxAdapter(child: _top())),
            if (home == null && _error == null)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (home == null)
              SliverFillRemaining(hasScrollBody: false, child: ErrorView(error: _error!, onRetry: _load))
            else ...[
              if (_continue != null) SliverToBoxAdapter(child: _ContinueCard(book: _continue!)),
              SliverToBoxAdapter(child: _categories((home['categories'] as List).cast<Map>())),
              for (final s in (home['sections'] as List).cast<Map>()) ...[
                SliverToBoxAdapter(
                  child: SectionHeader(s['title'], action: 'Hammasi', onAction: () => ShellNav.openCatalog(CatalogQuery(sort: _sortFor(s['key']), free: s['key'] == 'free' ? true : null))),
                ),
                SliverToBoxAdapter(child: BookCarousel(books: (s['books'] as List).cast<Map>(), width: s['key'] == 'new' ? 132 : 112)),
              ],
              if ((home['authors'] as List).isNotEmpty) ...[
                const SliverToBoxAdapter(child: SectionHeader('Mualliflar')),
                SliverToBoxAdapter(child: _authors((home['authors'] as List).cast<Map>())),
              ],
              if (!session.isAuthor) SliverToBoxAdapter(child: _authorBanner()),
              if ((home['sections'] as List).isEmpty)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 40), child: EmptyState(icon: 'library-big', title: "Kitoblar tez orada", text: "Mualliflar kitoblarini yuklashmoqda. Birinchi bo'lib o'z kitobingizni joylang!"))),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        ),
      ),
    );
  }

  static String _sortFor(String key) => switch (key) { 'popular' => 'popular', 'rating' => 'rating', _ => 'new' };

  Widget _top() {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Image.asset('assets/images/logo.png', width: 30, height: 30),
              const SizedBox(width: 8),
              const Text('BookHub', style: TextStyle(fontFamily: AppFonts.book, fontSize: 21, fontWeight: FontWeight.w700, color: AppPalette.brand)),
              const Spacer(),
              if (session.loggedIn)
                Stack(clipBehavior: Clip.none, children: [
                  AppIconButton('bell', onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                    session.refresh();
                  }),
                  if (session.unread > 0)
                    Positioned(
                      right: 8,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: AppPalette.danger, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppPalette.background, width: 2)),
                        child: Text('${session.unread}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ]),
            ]),
            const SizedBox(height: 18),
            Text(session.loggedIn ? 'Salom, ${session.name.split(' ').first}!' : 'Xush kelibsiz!', style: AppText.display.copyWith(fontSize: 26)),
            const SizedBox(height: 4),
            const Text("Bugun nima o'qiymiz?", style: AppText.bodySoft),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => ShellNav.openCatalog(const CatalogQuery(focusSearch: true)),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppPalette.line)),
                  child: Row(children: [
                    const AppIcon('search', size: 20, color: AppPalette.muted),
                    const SizedBox(width: 10),
                    Text('Kitob, muallif yoki mavzu…', style: AppText.bodySoft.copyWith(color: AppPalette.muted)),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categories(List<Map> cats) {
    final visible = cats.where((c) => (c['books_count'] ?? 0) > 0).toList();
    if (visible.isEmpty) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: visible.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final c = visible[i];
            return ActionChip(
              label: Text('${c['name']['uz']}  ${c['books_count']}'),
              labelStyle: AppText.label.copyWith(color: AppPalette.inkSoft),
              backgroundColor: AppPalette.surface,
              side: const BorderSide(color: AppPalette.line),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () => ShellNav.openCatalog(CatalogQuery(categoryId: c['id'], categoryName: c['name']['uz'])),
            );
          },
        ),
      ),
    );
  }

  Widget _authors(List<Map> authors) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: authors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (_, i) {
          final a = authors[i];
          return GestureDetector(
            onTap: () => openAuthorPage(context, a['user_id']),
            child: SizedBox(
              width: 76,
              child: Column(children: [
                Avatar(name: a['display_name'] ?? '', url: Constants.fileUrl(a['photo']), size: 66),
                const SizedBox(height: 8),
                Text(a['display_name'] ?? '', maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: AppPalette.ink, fontWeight: FontWeight.w600)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _authorBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BecomeAuthorScreen())),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppPalette.brandMid, AppPalette.brandDark]),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Kitobingiz bormi?', style: AppText.title.copyWith(color: Colors.white)),
                const SizedBox(height: 6),
                Text("Muallif bo'ling: kitobni yuklang, sotuvdan har oy daromad oling.", style: AppText.body.copyWith(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Text("Muallif bo'lish", style: AppText.label.copyWith(color: AppPalette.brand)),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
              child: const Center(child: AppIcon('pen-tool', size: 34, color: Colors.white)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ContinueCard extends StatefulWidget {
  final Map book;

  const _ContinueCard({required this.book});

  @override
  State<_ContinueCard> createState() => _ContinueCardState();
}

class _ContinueCardState extends State<_ContinueCard> {
  double? _dl;

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    final p = ((b['progress'] as num?) ?? 0).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Material(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () async {
            setState(() => _dl = 0);
            try {
              await openBook(context, b, onProgress: (v) => mounted ? setState(() => _dl = v) : null);
            } catch (e) {
              if (context.mounted) toast(context, errorText(e), error: true);
            } finally {
              if (mounted) setState(() => _dl = null);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: AppPalette.line)),
            child: Row(children: [
              BookCover(book: b, width: 70, height: 104),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("DAVOM ETTIRISH", style: AppText.overline),
                  const SizedBox(height: 6),
                  Text(b['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bookTitle.copyWith(fontSize: 16.5)),
                  const SizedBox(height: 12),
                  ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _dl ?? p, minHeight: 6)),
                  const SizedBox(height: 6),
                  Text(_dl != null ? 'Yuklanmoqda…' : "${(p * 100).round()}% o'qildi", style: AppText.caption),
                ]),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: const BoxDecoration(color: AppPalette.brand, shape: BoxShape.circle),
                child: const AppIcon('book-open', size: 20, color: Colors.white),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
