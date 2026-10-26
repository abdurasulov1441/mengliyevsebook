import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/core/format.dart';
import 'package:mengliyevsebook/core/session.dart';
import 'package:mengliyevsebook/features/auth/auth_flow.dart';
import 'package:mengliyevsebook/features/author/author_page.dart';
import 'package:mengliyevsebook/features/book/purchase_sheet.dart';
import 'package:mengliyevsebook/features/book/reviews.dart';
import 'package:mengliyevsebook/features/reader/reader_launcher.dart';
import 'package:mengliyevsebook/services/books/book_events.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:mengliyevsebook/widgets/book_cover.dart';
import 'package:mengliyevsebook/widgets/common.dart';

void openBookPage(BuildContext context, Map book) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => BookPage(bookId: book['id'] as int, initial: book)));
}

class BookPage extends StatefulWidget {
  final int bookId;
  final Map? initial;

  const BookPage({super.key, required this.bookId, this.initial});

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  Map? _book;
  Object? _error;
  double? _progress;
  bool _descOpen = false;

  @override
  void initState() {
    super.initState();
    _book = widget.initial;
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await api.get('/api/books/${widget.bookId}');
      if (mounted) setState(() => _book = b);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  bool get _full => _book != null && _book!.containsKey('reviews');
  bool get _owned => _book?['has_access'] == true;

  Future<void> _read() async {
    setState(() => _progress = 0);
    try {
      await openBook(context, _book!, onProgress: (p) => mounted ? setState(() => _progress = p) : null);
    } catch (e) {
      if (mounted) toast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _progress = null);
      _load();
    }
  }

  Future<void> _getFree() async {
    if (!await requireLogin(context, reason: "Kitobni kutubxonangizga qo'shish uchun kiring")) return;
    try {
      await api.post('/api/books/${widget.bookId}/get');
      notifyBooksChanged();
      await _load();
      if (mounted) toast(context, "Kitob kutubxonangizga qo'shildi");
      if (mounted && _owned) _read();
    } catch (e) {
      if (mounted) toast(context, errorText(e), error: true);
    }
  }

  Future<void> _buy() async {
    if (!await requireLogin(context, reason: 'Kitob sotib olish uchun telefon raqamingiz bilan kiring')) return;
    await _load(); // maybe it is already owned after signing in
    if (!mounted || _owned) return;
    if (await showPurchaseSheet(context, _book!)) {
      await _load();
      if (mounted && _owned) _read();
    }
  }

  Future<void> _preview() async {
    final wantsBook = await openPreview(context, _book!);
    if (wantsBook && mounted) {
      _book!['is_free'] == true ? _getFree() : _buy();
    }
  }

  Future<void> _toggleFavorite() async {
    if (!await requireLogin(context, reason: "Sevimlilarga qo'shish uchun kiring")) return;
    try {
      final r = await api.post('/api/books/${widget.bookId}/favorite');
      setState(() => _book!['is_favorite'] = r['is_favorite']);
      notifyBooksChanged();
    } catch (e) {
      if (mounted) toast(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _book;
    if (b == null) {
      return Scaffold(appBar: AppBar(), body: _error != null ? ErrorView(error: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()));
    }
    final rating = ((b['rating'] as num?) ?? 0).toDouble();
    final facts = <(String, String, String)>[
      if (rating > 0) ('star', rating.toStringAsFixed(1), '${b['rating_count']} baho'),
      if ((b['chapters'] ?? 0) > 0) ('layers', '${b['chapters']}', 'bob'),
      if ((b['reading_minutes'] ?? 0) > 0) ('clock', readingTime(b['reading_minutes']), "o'qish"),
      if ((b['sales_count'] ?? 0) > 0) ('users', '${b['sales_count']}', 'kitobxon'),
    ];
    final description = (b['description'] ?? '').toString();
    final toc = ((b['toc'] as List?) ?? []).cast<String>();
    final reviews = ((b['reviews'] as List?) ?? []).cast<Map>();
    final more = ((b['more_by_author'] as List?) ?? []).cast<Map>();
    final similar = ((b['similar'] as List?) ?? []).cast<Map>();

    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _header(b)),
                if (facts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Panel(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          children: [
                            for (var i = 0; i < facts.length; i++) ...[
                              if (i > 0) Container(width: 1, height: 34, color: AppPalette.line),
                              Expanded(
                                child: Column(children: [
                                  Row(mainAxisSize: MainAxisSize.min, children: [
                                    AppIcon(facts[i].$1 == 'star' ? 'star-filled' : facts[i].$1, size: 15, color: facts[i].$1 == 'star' ? AppPalette.gold : AppPalette.brand),
                                    const SizedBox(width: 5),
                                    Text(facts[i].$2, style: AppText.label.copyWith(fontSize: 15)),
                                  ]),
                                  const SizedBox(height: 3),
                                  Text(facts[i].$3, style: AppText.caption),
                                ]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                if (description.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Kitob haqida', style: AppText.section),
                        const SizedBox(height: 10),
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 200),
                          crossFadeState: _descOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          firstChild: Text(description, maxLines: 4, overflow: TextOverflow.ellipsis, style: AppText.body.copyWith(color: AppPalette.inkSoft, height: 1.6)),
                          secondChild: Text(description, style: AppText.body.copyWith(color: AppPalette.inkSoft, height: 1.6)),
                        ),
                        if (description.length > 180)
                          TextButton(onPressed: () => setState(() => _descOpen = !_descOpen), style: TextButton.styleFrom(padding: EdgeInsets.zero), child: Text(_descOpen ? 'Yig‘ish' : "Ko'proq o'qish")),
                      ]),
                    ),
                  ),
                if (b['category'] != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Wrap(spacing: 8, runSpacing: 8, children: [
                        Chip2(b['category']['uz'] ?? '', icon: 'tag', color: AppPalette.inkSoft, background: AppPalette.surfaceAlt),
                        if (b['published_at'] != null) Chip2(formatDate(b['published_at']), icon: 'calendar', color: AppPalette.inkSoft, background: AppPalette.surfaceAlt),
                      ]),
                    ),
                  ),
                if (toc.isNotEmpty) ...[
                  const SliverToBoxAdapter(child: SectionHeader('Mundarija')),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Panel(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                        child: Column(children: [
                          for (var i = 0; i < toc.length && i < 8; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                SizedBox(width: 26, child: Text('${i + 1}', style: AppText.label.copyWith(color: AppPalette.muted))),
                                Expanded(child: Text(toc[i], maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body.copyWith(fontSize: 14))),
                              ]),
                            ),
                          if (toc.length > 8) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('va yana ${toc.length - 8} ta bob', style: AppText.caption)),
                        ]),
                      ),
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: SectionHeader(
                    'Fikrlar',
                    action: (b['rating_count'] ?? 0) > 0 ? 'Hammasi' : null,
                    onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewsPage(book: b))),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(children: [
                      if (_owned && b['is_mine'] != true)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              if (await showReviewSheet(context, b)) _load();
                            },
                            icon: const AppIcon('pencil', size: 18),
                            label: Text(b['my_review'] != null ? 'Fikrimni tahrirlash' : 'Fikr qoldirish'),
                          ),
                        ),
                      if (reviews.isEmpty)
                        Panel(child: Row(children: [
                          const AppIcon('message-square', size: 22, color: AppPalette.muted),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_owned ? "Birinchi bo'lib fikr qoldiring" : "Hali fikrlar yo'q", style: AppText.bodySoft)),
                        ]))
                      else
                        for (final r in reviews) Padding(padding: const EdgeInsets.only(bottom: 10), child: ReviewCard(review: r)),
                    ]),
                  ),
                ),
                if (more.isNotEmpty) ...[
                  SliverToBoxAdapter(child: SectionHeader('Muallifning boshqa kitoblari', action: 'Muallif', onAction: () => openAuthorPage(context, b['owner']['user_id']))),
                  SliverToBoxAdapter(child: BookCarousel(books: more)),
                ],
                if (similar.isNotEmpty) ...[
                  const SliverToBoxAdapter(child: SectionHeader("O'xshash kitoblar")),
                  SliverToBoxAdapter(child: BookCarousel(books: similar)),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 130)),
              ],
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _actionBar(b)),
        ],
      ),
    );
  }

  Widget _header(Map b) {
    final author = (b['author_name'] ?? '').toString();
    final rating = ((b['rating'] as num?) ?? 0).toDouble();
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRect(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
              child: Transform.scale(scale: 1.4, child: BookCover(book: b, width: 400, height: 600, shadow: false)),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.25), AppPalette.background.withValues(alpha: 0.65), AppPalette.background],
                stops: const [0, 0.62, 1],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Row(children: [
                AppIconButton('arrow-left', onTap: () => Navigator.pop(context), background: Colors.white.withValues(alpha: 0.92), color: AppPalette.ink),
                const Spacer(),
                AppIconButton(b['is_favorite'] == true ? 'heart-filled' : 'heart', onTap: _toggleFavorite, background: Colors.white.withValues(alpha: 0.92), color: b['is_favorite'] == true ? AppPalette.danger : AppPalette.ink),
              ]),
            ),
            const SizedBox(height: 4),
            BookCover(book: b, width: 164, height: 242),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(b['title'] ?? '', textAlign: TextAlign.center, style: AppText.display.copyWith(fontSize: 24)),
            ),
            const SizedBox(height: 6),
            if (author.isNotEmpty)
              GestureDetector(
                onTap: b['owner'] != null ? () => openAuthorPage(context, b['owner']['user_id']) : null,
                child: Text(author, textAlign: TextAlign.center, style: AppText.bodySoft.copyWith(color: b['owner'] != null ? AppPalette.brand : AppPalette.inkSoft, fontWeight: FontWeight.w500)),
              ),
            if (rating > 0) ...[
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [RatingStars(rating, size: 15), const SizedBox(width: 6), Text('${b['rating_count']} ta baho', style: AppText.caption)]),
            ],
            const SizedBox(height: 18),
          ]),
        ),
      ],
    );
  }

  Widget _actionBar(Map b) {
    final bottom = MediaQuery.of(context).padding.bottom;
    Widget primary;
    if (b['is_mine'] == true || _owned) {
      final progress = ((b['progress'] as num?) ?? 0).toDouble();
      primary = FilledButton.icon(
        onPressed: _progress != null ? null : _read,
        icon: _progress != null
            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white, value: _progress! > 0 ? _progress : null))
            : const AppIcon('book-open', size: 20, color: Colors.white),
        label: Text(_progress != null ? 'Yuklanmoqda ${(_progress! * 100).round()}%' : (progress > 0.01 ? "Davom ettirish · ${(progress * 100).round()}%" : "O'qish")),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
      );
    } else if (b['is_free'] == true) {
      primary = FilledButton.icon(
        onPressed: _full ? _getFree : null,
        icon: const AppIcon('book-plus', size: 20, color: Colors.white),
        label: const Text("Bepul — kutubxonaga qo'shish"),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54), backgroundColor: AppPalette.success),
      );
    } else {
      primary = Row(children: [
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Narxi', style: AppText.caption),
          Text(formatMoney(b['price']), style: AppText.title.copyWith(fontFamily: AppFonts.ui, fontSize: 19)),
        ]),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton.icon(
            onPressed: _full ? _buy : null,
            icon: const AppIcon('shopping-bag', size: 20, color: Colors.white),
            label: const Text('Sotib olish'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          ),
        ),
      ]);
    }
    final showPreview = !_owned && b['is_mine'] != true && b['has_preview'] == true;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        border: const Border(top: BorderSide(color: AppPalette.line)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -6))],
      ),
      child: Row(children: [
        if (showPreview) ...[
          SizedBox(
            height: 54,
            child: OutlinedButton(
              onPressed: _preview,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 54), padding: const EdgeInsets.symmetric(horizontal: 16)),
              child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                AppIcon('eye', size: 18),
                SizedBox(height: 2),
                Text('Parcha', style: TextStyle(fontSize: 12)),
              ]),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(child: primary),
      ]),
    );
  }
}

/// Horizontal list of book cards.
class BookCarousel extends StatelessWidget {
  final List<Map> books;
  final double width;

  const BookCarousel({super.key, required this.books, this.width = 118});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: width * 1.48 + 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, i) => BookCard(book: books[i], width: width, onTap: () => openBookPage(context, books[i])),
      ),
    );
  }
}

/// Signed-in check used by several screens.
bool get isGuest => !session.loggedIn;
