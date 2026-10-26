import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/user_page/books/book_reader_page.dart';
import 'package:mengliyevsebook/services/books/book_cover.dart';
import 'package:mengliyevsebook/services/books/book_events.dart';
import 'package:mengliyevsebook/services/books/book_library.dart';
import 'package:mengliyevsebook/services/books/local_catalog.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/utils/constants.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';

/// "Kutubxona": bought and free books. The first tap prepares the book on
/// the device (download from the server, or copy from the app in local mode);
/// after that it opens offline.
class BooksScreen extends StatefulWidget {
  final VoidCallback? onOpenShop;

  const BooksScreen({super.key, this.onOpenShop});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<Map> myBooks = [];
  final Map<String, double> downloadProgress = {};
  final Map<String, int?> localVersions = {};

  @override
  void initState() {
    super.initState();
    booksChanged.addListener(_fetchMyBooks);
    _fetchMyBooks();
  }

  @override
  void dispose() {
    booksChanged.removeListener(_fetchMyBooks);
    super.dispose();
  }

  Future<void> _fetchMyBooks() async {
    if (myBooks.isEmpty && mounted) setState(() => isLoading = true);
    errorMessage = null;
    try {
      if (Constants.localMode) {
        myBooks = await LocalCatalog.myBooks();
      } else {
        final resp = await requestHelper.getWithAuth('/api/books/my-books');
        myBooks = resp is Map && resp['books'] is List ? (resp['books'] as List).cast<Map>() : [];
      }
      for (final b in myBooks) {
        final id = b['id'].toString();
        localVersions[id] = await BookLibrary.instance.localVersion(id);
      }
    } catch (e) {
      errorMessage = "Kitoblarni yuklab bo'lmadi. Internetni tekshiring.";
    }
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _open(Map book) async {
    final id = book['id'].toString();
    if (downloadProgress.containsKey(id)) return;
    final needsDownload = !(await BookLibrary.instance.isUpToDate(book));
    if (!mounted) return;
    if (needsDownload) setState(() => downloadProgress[id] = 0);
    try {
      await openBook(context, book, onProgress: (p) {
        if (mounted) setState(() => downloadProgress[id] = p);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      downloadProgress.remove(id);
      notifyBooksChanged();
    }
  }

  void _actions(Map book) {
    final id = book['id'].toString();
    final downloaded = localVersions[id] != null;
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                BookCover(book: book, width: 54, height: 80),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(book['title'] ?? '', style: AppText.bookTitle.copyWith(fontSize: 17), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(_author(book), style: AppText.caption),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              _SheetAction(icon: 'book-open', label: "O'qish", onTap: () {
                Navigator.pop(c);
                _open(book);
              }),
              if (downloaded)
                _SheetAction(icon: 'trash-2', label: "Qurilmadan o'chirish", danger: true, onTap: () async {
                  Navigator.pop(c);
                  await BookLibrary.instance.remove(id);
                  notifyBooksChanged();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kitob qurilmadan o'chirildi. Xatcho'plar saqlanib qoldi.")));
                  }
                }),
            ],
          ),
        ),
      ),
    );
  }

  static String _author(Map b) {
    final a = (b['author'] is Map ? b['author']['uz'] : null)?.toString() ?? '';
    return a.isEmpty ? 'Muallif ko‘rsatilmagan' : a;
  }

  static String _timeLeft(Map b) {
    final minutes = ((b['reading_minutes'] as num?) ?? 0) * (1 - (((b['progress'] as num?) ?? 0).toDouble()));
    if (minutes <= 0) return '';
    if (minutes < 60) return '${minutes.round()} daqiqa qoldi';
    return '${(minutes / 60).toStringAsFixed(minutes < 600 ? 1 : 0)} soat qoldi';
  }

  @override
  Widget build(BuildContext context) {
    final started = myBooks.where((b) => ((b['progress'] as num?) ?? 0) > 0 && ((b['progress'] as num?) ?? 0) < 0.995).toList();
    final current = started.isNotEmpty ? started.first : null;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchMyBooks,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("MENGLIYEV'S EBOOK", style: AppText.overline),
                      const SizedBox(height: 6),
                      const Text('Kutubxonam', style: AppText.display),
                      const SizedBox(height: 4),
                      Text(
                        isLoading ? ' ' : '${myBooks.length} ta kitob${Constants.localMode ? ' · oflayn rejim' : ''}',
                        style: AppText.bodySoft,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isLoading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (errorMessage != null && myBooks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(icon: 'wifi-off', title: 'Aloqa yo‘q', text: errorMessage!, action: 'Qayta urinish', onAction: _fetchMyBooks),
              )
            else if (myBooks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  icon: 'library-big',
                  title: "Kutubxona bo'sh",
                  text: "Do'kondan kitob tanlang — u shu yerda paydo bo'ladi va internetsiz ham o'qiladi.",
                  action: "Do'konga o'tish",
                  onAction: widget.onOpenShop,
                ),
              )
            else ...[
              if (current != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                    child: _ContinueCard(
                      book: current,
                      timeLeft: _timeLeft(current),
                      progress: downloadProgress[current['id'].toString()],
                      onTap: () => _open(current),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: Padding(padding: EdgeInsets.fromLTRB(20, 22, 20, 12), child: Text('Barcha kitoblar', style: AppText.section)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverLayoutBuilder(builder: (context, constraints) {
                  final columns = (constraints.crossAxisExtent / 108).floor().clamp(2, 6);
                  final tileW = (constraints.crossAxisExtent - 16 * (columns - 1)) / columns;
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 22,
                      crossAxisSpacing: 16,
                      // Cover + two title lines + author + progress bar.
                      mainAxisExtent: tileW * 1.48 + 92,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final b = myBooks[i];
                        final id = b['id'].toString();
                        final local = localVersions[id];
                        final remote = (b['package_version'] as num?)?.toInt() ?? 0;
                        return _BookTile(
                          book: b,
                          downloaded: local != null && local >= remote,
                          outdated: local != null && local < remote,
                          downloadProgress: downloadProgress[id],
                          onTap: () => _open(b),
                          onLongPress: () => _actions(b),
                        );
                      },
                      childCount: myBooks.length,
                    ),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final Map book;
  final String timeLeft;
  final double? progress;
  final VoidCallback onTap;

  const _ContinueCard({required this.book, required this.timeLeft, required this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final percent = ((book['progress'] as num?) ?? 0).toDouble();
    return Material(
      color: AppPalette.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppPalette.line),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppPalette.surface, Color(0xFFF2F8F5)]),
          ),
          child: Row(
            children: [
              BookCover(book: book, width: 84, height: 124),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("DAVOM ETTIRISH", style: AppText.overline),
                    const SizedBox(height: 6),
                    Text(book['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bookTitle.copyWith(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(_BooksScreenState._author(book), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: progress ?? percent, minHeight: 6),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text("${(percent * 100).round()}%", style: AppText.label.copyWith(color: AppPalette.brand)),
                        if (timeLeft.isNotEmpty) Text('  ·  $timeLeft', style: AppText.caption),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: AppPalette.brand, shape: BoxShape.circle),
                          child: const AppIcon('book-open', size: 18, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  final Map book;
  final bool downloaded;
  final bool outdated;
  final double? downloadProgress;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BookTile({required this.book, required this.downloaded, required this.outdated, required this.downloadProgress, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final percent = ((book['progress'] as num?) ?? 0).toDouble();
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                BookCover(book: book, width: w, height: w * 1.48),
                if (downloadProgress != null)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(6)),
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(value: downloadProgress! > 0 ? downloadProgress : null, strokeWidth: 3, color: Colors.white, backgroundColor: Colors.white24),
                      ),
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 10),
          Text(book['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bookTitle.copyWith(fontSize: 13.5)),
          const SizedBox(height: 3),
          // Author + device state (on the phone / needs download / update).
          Row(
            children: [
              Expanded(
                child: Text(_BooksScreenState._author(book), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(fontSize: 11.5)),
              ),
              const SizedBox(width: 4),
              AppIcon(
                outdated ? 'refresh-cw' : (downloaded ? 'circle-check' : 'download'),
                size: 14,
                color: downloaded && !outdated ? AppPalette.brand : AppPalette.muted,
              ),
            ],
          ),
          if (percent > 0) ...[
            const SizedBox(height: 7),
            ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: percent, minHeight: 3)),
          ],
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final String icon;
  final String label;
  final bool danger;
  final VoidCallback onTap;

  const _SheetAction({required this.icon, required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppPalette.danger : AppPalette.ink;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: AppIcon(icon, color: color),
      title: Text(label, style: AppText.body.copyWith(color: color, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  const _EmptyState({required this.icon, required this.title, required this.text, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(color: AppPalette.brandSoft, shape: BoxShape.circle),
            child: Center(child: AppIcon(icon, size: 42, color: AppPalette.brand)),
          ),
          const SizedBox(height: 20),
          Text(title, style: AppText.title, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(text, style: AppText.bodySoft, textAlign: TextAlign.center),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 22),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}
