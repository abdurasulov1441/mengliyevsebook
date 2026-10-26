import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/core/format.dart';
import 'package:mengliyevsebook/features/book/book_page.dart';
import 'package:mengliyevsebook/features/reader/reader_launcher.dart';
import 'package:mengliyevsebook/services/utils/constants.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:mengliyevsebook/widgets/book_cover.dart';
import 'package:mengliyevsebook/widgets/common.dart';

/// Moderation queue and all books, filtered by status.
class AdminBooksScreen extends StatelessWidget {
  const AdminBooksScreen({super.key});

  static const _tabs = [('pending', 'Moderatsiya'), ('approved', 'Nashrda'), ('rejected', 'Rad etilgan'), ('unpublished', 'Yashirilgan'), ('', 'Hammasi')];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kitoblar'),
          leading: AppIconButton('arrow-left', onTap: () => Navigator.pop(context)),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppPalette.brand,
            unselectedLabelColor: AppPalette.muted,
            indicatorColor: AppPalette.brand,
            labelStyle: AppText.label,
            tabs: [for (final t in _tabs) Tab(text: t.$2)],
          ),
        ),
        body: TabBarView(children: [for (final t in _tabs) _BookList(status: t.$1)]),
      ),
    );
  }
}

class _BookList extends StatefulWidget {
  final String status;

  const _BookList({required this.status});

  @override
  State<_BookList> createState() => _BookListState();
}

class _BookListState extends State<_BookList> with AutomaticKeepAliveClientMixin {
  final _key = GlobalKey<AsyncViewState<List<Map>>>();
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          controller: _search,
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), () => _key.currentState?.reload());
          },
          decoration: const InputDecoration(hintText: 'Nom yoki muallif', prefixIcon: Padding(padding: EdgeInsets.all(13), child: AppIcon('search', size: 20, color: AppPalette.muted))),
        ),
      ),
      Expanded(
        child: AsyncView<List<Map>>(
          key: _key,
          load: () async => ((await api.get('/api/admin/books', query: {
                    if (widget.status.isNotEmpty) 'status': widget.status,
                    if (_search.text.trim().isNotEmpty) 'q': _search.text.trim(),
                    'limit': 200,
                  }))['books'] as List)
              .cast<Map>(),
          builder: (context, books, reload) {
            if (books.isEmpty) {
              return EmptyState(
                icon: widget.status == 'pending' ? 'circle-check' : 'library-big',
                title: widget.status == 'pending' ? 'Navbat bo‘sh' : 'Kitoblar yo‘q',
                text: widget.status == 'pending' ? 'Yangi kitoblar yuklanganda shu yerda paydo bo‘ladi' : 'Bu bo‘limda hozircha kitob yo‘q',
              );
            }
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  for (final b in books)
                    BookRow(
                      book: b,
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminBookScreen(bookId: b['id'])));
                        _key.currentState?.reload();
                      },
                      badge: Wrap(spacing: 6, runSpacing: 6, children: [
                        StatusChip(b),
                        Chip2(b['is_free'] == true ? 'Bepul' : formatMoney(b['price']), color: AppPalette.inkSoft, background: AppPalette.surfaceAlt),
                        if (b['submitted_at'] != null && widget.status == 'pending') Chip2(timeAgo(b['submitted_at']), icon: 'clock', color: AppPalette.inkSoft, background: AppPalette.surfaceAlt),
                      ]),
                      trailing: const AppIcon('chevron-right', color: AppPalette.muted),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ]);
  }
}

/// Book review page for the moderator.
class AdminBookScreen extends StatefulWidget {
  final dynamic bookId;

  const AdminBookScreen({super.key, required this.bookId});

  @override
  State<AdminBookScreen> createState() => _AdminBookScreenState();
}

class _AdminBookScreenState extends State<AdminBookScreen> {
  final _key = GlobalKey<AsyncViewState<Map>>();

  Future<void> _run(Future<dynamic> Function() call, {bool pop = false}) async {
    try {
      final r = await call();
      if (!mounted) return;
      toast(context, (r is Map ? r['message'] : null) ?? 'Bajarildi');
      if (pop) return Navigator.pop(context);
      _key.currentState?.reload();
    } catch (e) {
      if (mounted) toast(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moderatsiya'), leading: AppIconButton('arrow-left', onTap: () => Navigator.pop(context))),
      body: AsyncView<Map>(
        key: _key,
        load: () async => Map.from(await api.get('/api/admin/books/${widget.bookId}')),
        builder: (context, b, reload) {
          final id = b['id'];
          final owner = b['owner_profile'] is Map ? Map.from(b['owner_profile']) : null;
          final report = b['conversion_report'] is Map ? Map.from(b['conversion_report']) : null;
          final warnings = ((report?['warnings'] as List?) ?? []).map((w) => w.toString()).toList();
          final ready = b['conversion_status'] == 'ready';
          final status = b['status'];
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  BookCover(book: b, width: 96, height: 142),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(b['title'] ?? '', style: AppText.bookTitle.copyWith(fontSize: 19)),
                      const SizedBox(height: 4),
                      Text(b['author_name'] ?? '', style: AppText.bodySoft),
                      const SizedBox(height: 10),
                      StatusChip(b),
                      const SizedBox(height: 8),
                      Text(b['is_free'] == true ? 'Bepul' : formatMoney(b['price']), style: AppText.title.copyWith(color: AppPalette.brand)),
                      if (b['category'] is Map) Text(b['category']['uz'] ?? '', style: AppText.caption),
                    ]),
                  ),
                ]),
                if (status == 'rejected' && (b['rejection_reason'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Panel(child: Text('Rad etish sababi: ${b['rejection_reason']}', style: AppText.body.copyWith(color: AppPalette.danger, fontSize: 14))),
                ],
                if (b['conversion_status'] == 'failed') ...[
                  const SizedBox(height: 14),
                  Panel(child: Text('Konvertatsiya xatosi: ${b['conversion_error'] ?? ''}', style: AppText.body.copyWith(color: AppPalette.danger, fontSize: 14))),
                ],
                if (owner != null) ...[
                  const SizedBox(height: 14),
                  Panel(
                    child: Row(children: [
                      Avatar(name: owner['display_name'] ?? '', url: Constants.fileUrl(owner['photo']), size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(owner['display_name'] ?? '', style: AppText.label),
                          Text('${owner['phone'] ?? ''} · ${owner['card_verified'] == true ? 'karta tasdiqlangan' : 'karta tasdiqlanmagan'}', style: AppText.caption),
                        ]),
                      ),
                      if (owner['status'] == 'blocked') const Chip2('Bloklangan', color: AppPalette.danger, background: AppPalette.dangerSoft),
                    ]),
                  ),
                ],
                if ((b['description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Panel(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Tavsif', style: AppText.section),
                      const SizedBox(height: 8),
                      Text(b['description'], style: AppText.bodySoft.copyWith(fontSize: 14.5)),
                    ]),
                  ),
                ],
                if (report != null) ...[
                  const SizedBox(height: 14),
                  Panel(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Fayl', style: AppText.section),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        Chip2('${report['chapters'] ?? 0} bob', icon: 'list'),
                        Chip2('${report['words'] ?? 0} so‘z', icon: 'type'),
                        if ((report['images'] ?? 0) > 0) Chip2('${report['images']} rasm', icon: 'image'),
                        if ((report['footnotes'] ?? 0) > 0) Chip2('${report['footnotes']} izoh', icon: 'message-square'),
                      ]),
                      if (b['source_name'] != null) ...[const SizedBox(height: 8), Text(b['source_name'], style: AppText.caption)],
                      for (final w in warnings.take(5)) Padding(padding: const EdgeInsets.only(top: 6), child: Text('• $w', style: AppText.caption.copyWith(color: AppPalette.warning))),
                    ]),
                  ),
                ],
                const SizedBox(height: 18),
                if (ready)
                  OutlinedButton.icon(
                    onPressed: () => openBook(context, b).catchError((e) {
                      if (context.mounted) toast(context, errorText(e), error: true);
                    }),
                    icon: const AppIcon('book-open', size: 18, color: AppPalette.brand),
                    label: const Text("To'liq o'qib chiqish"),
                  ),
                const SizedBox(height: 10),
                if (ready && status != 'approved')
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppPalette.success),
                    onPressed: () => _run(() => api.post('/api/admin/books/$id/approve')),
                    icon: const AppIcon('circle-check', size: 18, color: Colors.white),
                    label: const Text('Tasdiqlash va nashr qilish'),
                  ),
                if (status == 'pending' || status == 'approved') ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppPalette.danger, side: const BorderSide(color: AppPalette.danger)),
                    onPressed: () async {
                      final reason = await askText(context, title: 'Rad etish sababi', hint: "Muallif nimani tuzatishi kerak?", ok: 'Rad etish');
                      if (reason != null) _run(() => api.post('/api/admin/books/$id/reject', {'reason': reason}));
                    },
                    icon: const AppIcon('circle-x', size: 18, color: AppPalette.danger),
                    label: const Text('Rad etish'),
                  ),
                ],
                if (status == 'approved') ...[
                  const SizedBox(height: 10),
                  OutlinedButton(onPressed: () => openBookPage(context, b), child: const Text("Do'kondagi sahifa")),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () async {
                      if (await confirm(context, title: "Do'kondan olinsinmi?", text: "Sotib olganlar o'qishda davom etadi.")) _run(() => api.post('/api/admin/books/$id/unpublish'));
                    },
                    child: const Text("Do'kondan olish"),
                  ),
                ],
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextButton(onPressed: () => _run(() => api.post('/api/admin/books/$id/reconvert')), child: const Text('Qayta konvertatsiya'))),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(foregroundColor: AppPalette.danger),
                      onPressed: () async {
                        if (await confirm(context, title: "Kitob o'chirilsinmi?", text: "Kitob va uning fayllari butunlay o'chiriladi.", danger: true, ok: "O'chirish")) {
                          _run(() => api.delete('/api/admin/books/$id'), pop: true);
                        }
                      },
                      child: const Text("O'chirish"),
                    ),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}
