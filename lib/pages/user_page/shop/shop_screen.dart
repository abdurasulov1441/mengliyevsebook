import 'package:flutter/material.dart';
import 'package:mengliyevsebook/pages/user_page/shop/book_detail_page.dart';
import 'package:mengliyevsebook/services/books/book_cover.dart';
import 'package:mengliyevsebook/services/books/book_events.dart';
import 'package:mengliyevsebook/services/books/local_catalog.dart';
import 'package:mengliyevsebook/services/request_helper.dart';
import 'package:mengliyevsebook/services/utils/constants.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';

/// "Do'kon": paid books with search; a tap opens the book page.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<Map> books = [];
  String query = '';

  @override
  void initState() {
    super.initState();
    booksChanged.addListener(_fetch);
    _fetch();
  }

  @override
  void dispose() {
    booksChanged.removeListener(_fetch);
    super.dispose();
  }

  Future<void> _fetch() async {
    errorMessage = null;
    try {
      if (Constants.localMode) {
        books = await LocalCatalog.shopBooks();
      } else {
        final resp = await requestHelper.getWithAuth('/api/books/get-books?page=1&limit=100&is_free=false');
        books = resp is Map && resp['books'] is List ? (resp['books'] as List).cast<Map>() : [];
      }
    } catch (e) {
      errorMessage = "Do'konni yuklab bo'lmadi. Internetni tekshiring.";
    }
    if (mounted) setState(() => isLoading = false);
  }

  List<Map> get _filtered {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return books;
    return books.where((b) => '${b['title']} ${b['author']?['uz'] ?? ''}'.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('KITOBLAR DO‘KONI', style: AppText.overline),
                      const SizedBox(height: 6),
                      const Text("Do'kon", style: AppText.display),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (v) => setState(() => query = v),
                        style: AppText.body,
                        decoration: const InputDecoration(
                          hintText: 'Kitob yoki muallif…',
                          prefixIcon: Padding(padding: EdgeInsets.all(13), child: AppIcon('search', size: 20, color: AppPalette.muted)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isLoading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(errorMessage!, style: AppText.bodySoft, textAlign: TextAlign.center))),
              )
            else if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text(books.isEmpty ? "Hozircha pullik kitoblar yo'q" : 'Hech narsa topilmadi', style: AppText.bodySoft)),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                sliver: SliverLayoutBuilder(builder: (context, constraints) {
                  final columns = (constraints.crossAxisExtent / 165).floor().clamp(2, 5);
                  final tileW = (constraints.crossAxisExtent - 18 * (columns - 1)) / columns;
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 18,
                      // Cover + two title lines + author + price chip.
                      mainAxisExtent: tileW * 1.48 + 120,
                    ),
                    delegate: SliverChildBuilderDelegate((_, i) => _ShopTile(book: list[i]), childCount: list.length),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  final Map book;

  const _ShopTile({required this.book});

  @override
  Widget build(BuildContext context) {
    final owned = book['has_access'] == true;
    final author = (book['author'] is Map ? book['author']['uz'] : '')?.toString() ?? '';
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: book))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, c) {
            return Hero(tag: 'cover-${book['id']}', child: BookCover(book: book, width: c.maxWidth, height: c.maxWidth * 1.48));
          }),
          const SizedBox(height: 12),
          Text(book['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bookTitle),
          const SizedBox(height: 3),
          Text(author.isEmpty ? '—' : author, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: owned ? AppPalette.brandSoft : AppPalette.goldSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (owned) ...[const AppIcon('circle-check', size: 13, color: AppPalette.brand), const SizedBox(width: 5)],
                Text(
                  owned ? 'Sizda bor' : formatPrice(book['price']),
                  style: AppText.label.copyWith(fontSize: 12, color: owned ? AppPalette.brand : AppPalette.gold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
