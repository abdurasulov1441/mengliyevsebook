import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/user_page/books/book_reader_page.dart';
import 'package:mengliyevsebook/pages/user_page/shop/buy_book_page.dart';
import 'package:mengliyevsebook/services/books/book_cover.dart';
import 'package:mengliyevsebook/services/books/book_events.dart';
import 'package:mengliyevsebook/services/books/local_catalog.dart';
import 'package:mengliyevsebook/services/utils/constants.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';

String formatPrice(dynamic price) {
  final n = (price is num ? price : num.tryParse('$price') ?? 0).round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < n.length; i++) {
    if (i > 0 && (n.length - i) % 3 == 0) buf.write(' ');
    buf.write(n[i]);
  }
  return "$buf so'm";
}

/// Book page in the shop: cover, facts, description and the buy/read action.
class BookDetailPage extends StatefulWidget {
  final Map book;

  const BookDetailPage({super.key, required this.book});

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  late Map book = widget.book;
  double? _progress;

  bool get _owned => book['has_access'] == true;

  Future<void> _read() async {
    setState(() => _progress = 0);
    try {
      await openBook(context, book, onProgress: (p) => mounted ? setState(() => _progress = p) : null);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _progress = null);
      notifyBooksChanged();
    }
  }

  Future<void> _buy() async {
    if (!Constants.localMode) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => BuyBookScreen(book: book)));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const AppIcon('credit-card', size: 30, color: AppPalette.brand),
        title: const Text('Demo xarid', textAlign: TextAlign.center),
        content: Text(
          "Serversiz rejimda haqiqiy to'lov yo'q. «${book['title']}» ${formatPrice(book['price'])}ga sotib olingan deb belgilanadi va kutubxonangizda paydo bo'ladi.",
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Bekor qilish')),
          FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(minimumSize: const Size(120, 46)), child: const Text('Sotib olish')),
        ],
      ),
    );
    if (ok != true) return;
    await LocalCatalog.purchase(book['id'].toString());
    notifyBooksChanged();
    if (!mounted) return;
    setState(() => book = {...book, 'has_access': true, 'is_purchased': true});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kitob kutubxonangizga qo'shildi")));
  }

  @override
  Widget build(BuildContext context) {
    final author = (book['author'] is Map ? book['author']['uz'] : '')?.toString() ?? '';
    final description = (book['description'] ?? '').toString();
    final hours = (((book['reading_minutes'] as num?) ?? 0) / 60);
    final facts = <(String, String)>[
      if (book['chapters'] != null) ('layers', '${book['chapters']} bob'),
      if (hours > 0) ('clock', hours < 1 ? '${(hours * 60).round()} daq.' : '~${hours.round()} soat'),
      if (book['words'] != null) ('file-text', "${((book['words'] as num) / 1000).round()} ming so'z"),
    ];

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    // Blurred cover as a soft backdrop.
                    Positioned.fill(
                      child: ClipRect(
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                          child: Transform.scale(scale: 1.4, child: BookCover(book: book, width: 400, height: 600, shadow: false)),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black.withValues(alpha: 0.25), AppPalette.background.withValues(alpha: 0.6), AppPalette.background],
                            stops: const [0, 0.65, 1],
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                            child: Row(children: [
                              AppIconButton('arrow-left', onTap: () => Navigator.pop(context), background: Colors.white.withValues(alpha: 0.9), color: AppPalette.ink),
                            ]),
                          ),
                          const SizedBox(height: 8),
                          Hero(tag: 'cover-${book['id']}', child: BookCover(book: book, width: 168, height: 248)),
                          const SizedBox(height: 22),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Text(book['title'] ?? '', textAlign: TextAlign.center, style: AppText.display.copyWith(fontSize: 25)),
                          ),
                          const SizedBox(height: 8),
                          if (author.isNotEmpty) Text(author, textAlign: TextAlign.center, style: AppText.bodySoft),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      for (final f in facts)
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppPalette.line)),
                            child: Column(children: [
                              AppIcon(f.$1, size: 20, color: AppPalette.brand),
                              const SizedBox(height: 6),
                              Text(f.$2, style: AppText.label, textAlign: TextAlign.center),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kitob haqida', style: AppText.section),
                      const SizedBox(height: 10),
                      Text(description.isEmpty ? "Tavsif qo'shilmagan." : description, style: AppText.body.copyWith(color: AppPalette.inkSoft, height: 1.6)),
                      const SizedBox(height: 22),
                      Row(children: [
                        const AppIcon('wifi-off', size: 18, color: AppPalette.muted),
                        const SizedBox(width: 10),
                        Expanded(child: Text("Bir marta yuklab olinadi va internetsiz o'qiladi", style: AppText.caption.copyWith(fontSize: 13))),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        const AppIcon('bookmark', size: 18, color: AppPalette.muted),
                        const SizedBox(width: 10),
                        Expanded(child: Text("Xatcho'p, belgilar, izohlar va qidiruv", style: AppText.caption.copyWith(fontSize: 13))),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Sticky action bar.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                border: const Border(top: BorderSide(color: AppPalette.line)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -6))],
              ),
              child: _owned
                  ? FilledButton.icon(
                      onPressed: _progress != null ? null : _read,
                      icon: _progress != null
                          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white, value: _progress! > 0 ? _progress : null))
                          : const AppIcon('book-open', size: 20, color: Colors.white),
                      label: Text(_progress != null ? 'Tayyorlanmoqda…' : "O'qish"),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                    )
                  : Row(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Narxi', style: AppText.caption),
                            Text(formatPrice(book['price']), style: AppText.title.copyWith(fontFamily: AppFonts.ui, fontSize: 20)),
                          ],
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _buy,
                            icon: const AppIcon('shopping-bag', size: 20, color: Colors.white),
                            label: const Text('Sotib olish'),
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
