import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/features/book/book_page.dart';
import 'package:mengliyevsebook/features/shell/main_shell.dart';
import 'package:mengliyevsebook/services/books/book_events.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:mengliyevsebook/widgets/common.dart';

/// Filter state passed from other screens ("see all", a category chip...).
class CatalogQuery {
  final String sort;
  final int? categoryId;
  final String? categoryName;
  final bool? free;
  final bool focusSearch;

  const CatalogQuery({this.sort = 'new', this.categoryId, this.categoryName, this.free, this.focusSearch = false});
}

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;

  String _sort = 'new';
  int? _categoryId;
  bool? _free;
  List<Map> _categories = [];
  final List<Map> _books = [];
  int _page = 1;
  int _total = 0;
  bool _loading = false;
  Object? _error;

  static const _sorts = {'new': 'Yangilari', 'popular': 'Ommabop', 'rating': 'Reyting', 'price_asc': 'Arzonroq', 'price_desc': 'Qimmatroq'};

  @override
  void initState() {
    super.initState();
    ShellNav.catalogQuery.addListener(_applyQuery);
    booksChanged.addListener(_reload);
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) _more();
    });
    api.get('/api/categories').then((c) {
      if (mounted) setState(() => _categories = (c as List).cast<Map>().where((x) => (x['books_count'] ?? 0) > 0).toList());
    }).catchError((_) {});
    _applyQuery();
  }

  @override
  void dispose() {
    ShellNav.catalogQuery.removeListener(_applyQuery);
    booksChanged.removeListener(_reload);
    _debounce?.cancel();
    super.dispose();
  }

  void _applyQuery() {
    final q = ShellNav.catalogQuery.value;
    if (q != null) {
      _sort = q.sort;
      _categoryId = q.categoryId;
      _free = q.free;
      if (q.focusSearch) Future.delayed(const Duration(milliseconds: 300), () => _focus.requestFocus());
      ShellNav.catalogQuery.value = null;
    }
    _reload();
  }

  Future<void> _reload() async {
    _page = 1;
    _books.clear();
    await _fetch();
  }

  Future<void> _more() async {
    if (_loading || _books.length >= _total) return;
    _page++;
    await _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final r = await api.get('/api/books', query: {
        'page': _page,
        'limit': 30,
        'sort': _sort,
        if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
        if (_categoryId != null) 'category_id': _categoryId,
        if (_free != null) 'is_free': _free,
      });
      _books.addAll((r['books'] as List).cast<Map>());
      _total = (r['total'] as num).toInt();
      _error = null;
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  Widget _chip(String label, bool on, VoidCallback onTap, {String? icon}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: on,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        avatar: icon != null ? AppIcon(icon, size: 15, color: on ? Colors.white : AppPalette.inkSoft) : null,
        label: Text(label),
        labelStyle: AppText.label.copyWith(color: on ? Colors.white : AppPalette.inkSoft),
        backgroundColor: AppPalette.surface,
        selectedColor: AppPalette.brand,
        side: BorderSide(color: on ? AppPalette.brand : AppPalette.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  void _pickSort() async {
    final r = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Saralash', style: AppText.section)),
          for (final e in _sorts.entries)
            ListTile(
              title: Text(e.value, style: AppText.body),
              trailing: e.key == _sort ? const AppIcon('check', color: AppPalette.brand) : null,
              onTap: () => Navigator.pop(c, e.key),
            ),
        ]),
      ),
    );
    if (r != null && r != _sort) {
      setState(() => _sort = r);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const PageHeader(overline: 'Kitoblar', title: 'Katalog'),
                const SizedBox(height: 14),
                TextField(
                  controller: _search,
                  focusNode: _focus,
                  onChanged: _onSearch,
                  textInputAction: TextInputAction.search,
                  style: AppText.body,
                  decoration: InputDecoration(
                    hintText: 'Kitob, muallif yoki mavzu…',
                    prefixIcon: const Padding(padding: EdgeInsets.all(13), child: AppIcon('search', size: 20, color: AppPalette.muted)),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : AppIconButton('x', size: 40, color: AppPalette.muted, onTap: () {
                            _search.clear();
                            _reload();
                          }),
                  ),
                ),
              ]),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _chip(_sorts[_sort]!, false, _pickSort, icon: 'arrow-up-down'),
                  _chip('Bepul', _free == true, () {
                    setState(() => _free = _free == true ? null : true);
                    _reload();
                  }),
                  _chip('Pullik', _free == false, () {
                    setState(() => _free = _free == false ? null : false);
                    _reload();
                  }),
                  for (final c in _categories)
                    _chip(c['name']['uz'], _categoryId == c['id'], () {
                      setState(() => _categoryId = _categoryId == c['id'] ? null : c['id'] as int);
                      _reload();
                    }),
                ],
              ),
            ),
            Expanded(child: _results()),
          ],
        ),
      ),
    );
  }

  Widget _results() {
    if (_books.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_books.isEmpty && _error != null) return ErrorView(error: _error!, onRetry: _reload);
    if (_books.isEmpty) return const EmptyState(icon: 'search', title: 'Hech narsa topilmadi', text: "So'rovni o'zgartirib ko'ring yoki filtrlarni olib tashlang");
    return RefreshIndicator(
      onRefresh: _reload,
      child: LayoutBuilder(builder: (context, c) {
        final cols = ((c.maxWidth - 40) / 150).floor().clamp(2, 6);
        final w = (c.maxWidth - 40 - 16 * (cols - 1)) / cols;
        return GridView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 16, mainAxisSpacing: 22, mainAxisExtent: w * 1.48 + 96),
          itemCount: _books.length + (_books.length < _total ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= _books.length) return const Center(child: CircularProgressIndicator());
            return BookCard(book: _books[i], width: w, onTap: () => openBookPage(context, _books[i]));
          },
        );
      }),
    );
  }
}
