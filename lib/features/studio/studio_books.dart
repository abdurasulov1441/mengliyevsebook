import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/core/format.dart';
import 'package:mengliyevsebook/core/session.dart';
import 'package:mengliyevsebook/features/book/book_page.dart';
import 'package:mengliyevsebook/features/reader/reader_launcher.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:mengliyevsebook/widgets/bar_chart.dart';
import 'package:mengliyevsebook/widgets/book_cover.dart';
import 'package:mengliyevsebook/widgets/common.dart';

/// The author's books with their moderation status.
class StudioBooksScreen extends StatefulWidget {
  const StudioBooksScreen({super.key});

  @override
  State<StudioBooksScreen> createState() => _StudioBooksScreenState();
}

class _StudioBooksScreenState extends State<StudioBooksScreen> {
  final _key = GlobalKey<AsyncViewState<List<Map>>>();

  Future<void> _go(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _key.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitoblarim'),
        leading: AppIconButton('arrow-left', onTap: () => Navigator.pop(context)),
        actions: [AppIconButton('plus', onTap: () => _go(const StudioBookForm())), const SizedBox(width: 6)],
      ),
      body: AsyncView<List<Map>>(
        key: _key,
        load: () async => ((await api.get('/api/studio/books'))['books'] as List).cast<Map>(),
        builder: (context, books, reload) {
          if (books.isEmpty) {
            return EmptyState(
              icon: 'book-plus',
              title: "Hali kitob yuklamadingiz",
              text: "Word (.docx) faylingizni yuklang — biz uni telefonda o'qish uchun chiroyli formatga o'tkazamiz",
              action: 'Kitob yuklash',
              onAction: () => _go(const StudioBookForm()),
            );
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final b in books)
                  BookRow(
                    book: b,
                    onTap: () => _go(StudioBookScreen(bookId: b['id'])),
                    badge: Wrap(spacing: 6, runSpacing: 6, children: [
                      StatusChip(b),
                      Chip2(b['is_free'] == true ? 'Bepul' : formatMoney(b['price']), color: AppPalette.inkSoft, background: AppPalette.surfaceAlt),
                      if ((b['sales_count'] ?? 0) > 0) Chip2('${b['sales_count']} sotuv', icon: 'shopping-bag', color: AppPalette.success, background: AppPalette.successSoft),
                    ]),
                    trailing: const AppIcon('chevron-right', color: AppPalette.muted),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One of the author's books: status, moderator feedback, stats and actions.
class StudioBookScreen extends StatefulWidget {
  final dynamic bookId;

  const StudioBookScreen({super.key, required this.bookId});

  @override
  State<StudioBookScreen> createState() => _StudioBookScreenState();
}

class _StudioBookScreenState extends State<StudioBookScreen> {
  final _key = GlobalKey<AsyncViewState<Map>>();
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<Map> _load() async {
    final b = Map.from(await api.get('/api/studio/books/${widget.bookId}'));
    // Refresh while the file is being converted.
    _poll?.cancel();
    if (b['conversion_status'] == 'pending' || b['conversion_status'] == 'processing') {
      _poll = Timer(const Duration(seconds: 3), () => _key.currentState?.reload());
    }
    return b;
  }

  Future<void> _action(String path, {String? confirmTitle, String? confirmText, bool danger = false, bool pop = false}) async {
    if (confirmTitle != null && !await confirm(context, title: confirmTitle, text: confirmText ?? '', danger: danger)) return;
    try {
      final r = path.startsWith('DELETE ') ? await api.delete(path.substring(7)) : await api.post(path);
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
      appBar: AppBar(title: const Text('Kitob'), leading: AppIconButton('arrow-left', onTap: () => Navigator.pop(context))),
      body: AsyncView<Map>(
        key: _key,
        load: _load,
        builder: (context, b, reload) {
          final id = b['id'];
          final report = b['conversion_report'] is Map ? Map.from(b['conversion_report']) : null;
          final monthly = ((b['monthly'] as List?) ?? []).cast<Map>();
          final ready = b['conversion_status'] == 'ready';
          final converting = b['conversion_status'] == 'pending' || b['conversion_status'] == 'processing';
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
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),
                if (converting) _note('hourglass', AppPalette.brandMid, AppPalette.brandSoft, "Fayl o'qish formatiga o'tkazilmoqda. Bu bir necha soniya davom etadi."),
                if (b['conversion_status'] == 'failed') _note('circle-alert', AppPalette.danger, AppPalette.dangerSoft, "Faylni o'qib bo'lmadi: ${b['conversion_error'] ?? ''}\nBoshqa faylni yuklab ko'ring."),
                if (b['status'] == 'pending' && ready) _note('clock', AppPalette.warning, AppPalette.warningSoft, "Moderator tekshiruvida. Natija haqida bildirishnoma keladi."),
                if (b['status'] == 'rejected') _note('circle-x', AppPalette.danger, AppPalette.dangerSoft, "Rad etildi: ${b['rejection_reason'] ?? ''}\nKamchiliklarni tuzatib, kitobni tahrirlang — u qayta tekshiruvga yuboriladi."),
                if (b['status'] == 'unpublished') _note('eye-off', AppPalette.inkSoft, AppPalette.surfaceAlt, "Kitob do'konda ko'rinmaydi. Sotib olganlar o'qishda davom etadi."),
                if (b['status'] == 'approved') _note('circle-check', AppPalette.success, AppPalette.successSoft, "Kitob do'konda sotuvda. ${b['published_at'] != null ? 'Nashr: ${formatDate(b['published_at'])}' : ''}"),
                Row(children: [
                  Expanded(child: StatTile(label: 'sotuv', value: '${b['sales_count'] ?? 0}', icon: 'shopping-bag', color: AppPalette.success)),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(label: '${b['rating_count'] ?? 0} baho', value: '${b['rating'] ?? 0}', icon: 'star', color: AppPalette.gold)),
                ]),
                if (report != null) ...[
                  const SizedBox(height: 12),
                  Panel(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Fayl tahlili', style: AppText.section),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        Chip2('${report['chapters'] ?? 0} bob', icon: 'list'),
                        Chip2('${report['words'] ?? 0} so‘z', icon: 'type'),
                        Chip2(readingTime(b['reading_minutes']), icon: 'clock'),
                        if ((report['images'] ?? 0) > 0) Chip2('${report['images']} rasm', icon: 'image'),
                        if ((report['footnotes'] ?? 0) > 0) Chip2('${report['footnotes']} izoh', icon: 'message-square'),
                      ]),
                      if (b['source_name'] != null) ...[
                        const SizedBox(height: 10),
                        Text('Manba: ${b['source_name']}', style: AppText.caption),
                      ],
                    ]),
                  ),
                ],
                if (monthly.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Panel(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Daromad (oylar)', style: AppText.section),
                      const SizedBox(height: 10),
                      BarChart(bars: [for (final m in monthly) (formatPeriod(m['period']), (m['amount'] as num?) ?? 0)], format: formatMoney, height: 120),
                    ]),
                  ),
                ],
                const SizedBox(height: 16),
                if (ready)
                  OutlinedButton.icon(
                    onPressed: () => openBook(context, b).catchError((e) {
                      if (context.mounted) toast(context, errorText(e), error: true);
                    }),
                    icon: const AppIcon('book-open', size: 18, color: AppPalette.brand),
                    label: const Text("O'qib ko'rish"),
                  ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => StudioBookForm(book: b)));
                    _key.currentState?.reload();
                  },
                  icon: const AppIcon('pencil', size: 18, color: Colors.white),
                  label: const Text('Tahrirlash'),
                ),
                const SizedBox(height: 10),
                if (b['status'] == 'approved') ...[
                  OutlinedButton(onPressed: () => openBookPage(context, b), child: const Text("Do'kondagi sahifa")),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => _action('/api/studio/books/$id/unpublish', confirmTitle: "Do'kondan yashirilsinmi?", confirmText: "Yangi xaridorlar kitobni ko'rmaydi. Sotib olganlar o'qishda davom etadi."),
                    child: const Text("Do'kondan yashirish"),
                  ),
                ],
                if (b['status'] == 'unpublished') OutlinedButton(onPressed: () => _action('/api/studio/books/$id/publish'), child: const Text("Do'konga qaytarish")),
                if ((b['sales_count'] ?? 0) == 0) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => _action('DELETE /api/studio/books/$id', confirmTitle: "Kitob o'chirilsinmi?", confirmText: "Bu amalni qaytarib bo'lmaydi.", danger: true, pop: true),
                    style: TextButton.styleFrom(foregroundColor: AppPalette.danger),
                    child: const Text("Kitobni o'chirish"),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _note(String icon, Color color, Color bg, String text) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppIcon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppText.body.copyWith(fontSize: 14, color: AppPalette.ink))),
        ]),
      );
}

/// Upload a new book or edit an existing one.
class StudioBookForm extends StatefulWidget {
  final Map? book;

  const StudioBookForm({super.key, this.book});

  @override
  State<StudioBookForm> createState() => _StudioBookFormState();
}

class _StudioBookFormState extends State<StudioBookForm> {
  late final Map? _b = widget.book;
  late final _title = TextEditingController(text: _b?['title'] ?? '');
  late final _author = TextEditingController(text: _b?['author_name'] ?? session.author?['display_name'] ?? '');
  late final _description = TextEditingController(text: _b?['description'] ?? '');
  late final _price = TextEditingController(text: _b != null && _b['is_free'] != true ? '${_b['price']}' : '');
  late bool _free = _b?['is_free'] == true;
  late int? _categoryId = _b?['category_id'];
  List<Map> _categories = [];
  PlatformFile? _file;
  XFile? _cover;
  double? _progress;
  Map? _rules;

  bool get _isNew => _b == null;

  @override
  void initState() {
    super.initState();
    api.get('/api/categories').then((c) {
      if (mounted) setState(() => _categories = (c as List).cast<Map>());
    }).catchError((_) {});
    api.get('/api/studio/rules').then((r) {
      if (mounted) setState(() => _rules = Map.from(r));
    }).catchError((_) {});
  }

  Future<void> _pickFile() async {
    final formats = ((_rules?['formats'] as List?) ?? ['docx', 'doc', 'epub', 'txt', 'rtf', 'odt']).cast<String>();
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: formats);
    if (r == null || r.files.single.path == null) return;
    final f = r.files.single;
    final maxMb = (_rules?['max_mb'] as num?) ?? 50;
    if (f.size > maxMb * 1024 * 1024) {
      if (mounted) toast(context, 'Fayl juda katta (maks. $maxMb MB)', error: true);
      return;
    }
    setState(() {
      _file = f;
      if (_title.text.trim().isEmpty) _title.text = f.name.replaceAll(RegExp(r'\.[^.]+$'), '').replaceAll(RegExp(r'[_-]+'), ' ');
    });
  }

  Future<void> _save() async {
    if (_isNew && _file == null) return _err('Kitob faylini tanlang');
    if (_title.text.trim().isEmpty) return _err('Kitob nomini kiriting');
    final price = int.tryParse(_price.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    if (!_free && price < 1000) return _err("Narx kamida 1 000 so'm bo'lishi kerak");
    setState(() => _progress = 0);
    try {
      final form = FormData.fromMap({
        'title': _title.text.trim(),
        'author_name': _author.text.trim(),
        'description': _description.text.trim(),
        'category_id': _categoryId?.toString() ?? '',
        'is_free': _free ? 'true' : 'false',
        'price': _free ? '0' : '$price',
        if (_file != null) 'file': await MultipartFile.fromFile(_file!.path!, filename: _file!.name),
        if (_cover != null) 'cover': await MultipartFile.fromFile(_cover!.path, filename: _cover!.name),
      });
      final r = await api.upload(_isNew ? 'POST' : 'PUT', _isNew ? '/api/studio/books' : '/api/studio/books/${_b!['id']}', form, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      toast(context, (r is Map ? r['message'] : null) ?? 'Saqlandi');
      final book = r is Map ? r['book'] : null;
      if (_isNew && book is Map) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => StudioBookScreen(bookId: book['id'])));
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _err(errorText(e));
      if (mounted) setState(() => _progress = null);
    }
  }

  void _err(String m) => toast(context, m, error: true);

  @override
  Widget build(BuildContext context) {
    final busy = _progress != null;
    final published = _b?['status'] == 'approved';
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'Yangi kitob' : 'Tahrirlash'), leading: AppIconButton('x', onTap: busy ? null : () => Navigator.pop(context))),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            _section('Kitob fayli'),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _pickFile,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _file != null ? AppPalette.successSoft : AppPalette.brandSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _file != null ? AppPalette.success : AppPalette.brand.withValues(alpha: 0.35), width: 1.4),
                ),
                child: Row(children: [
                  AppIcon(_file != null ? 'file-text' : 'file-up', size: 30, color: _file != null ? AppPalette.success : AppPalette.brand),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        _file?.name ?? (_isNew ? 'Faylni tanlang' : 'Yangi fayl yuklash (ixtiyoriy)'),
                        style: AppText.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _file != null
                            ? '${(_file!.size / 1024 / 1024).toStringAsFixed(1)} MB'
                            : _isNew
                                ? "Word (.docx), EPUB, TXT · sarlavhalar boblar bo'lib ajratiladi"
                                : 'Hozirgi: ${_b?['source_name'] ?? '—'}. Yangi fayl qayta moderatsiyaga yuboriladi',
                        style: AppText.caption,
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
            _section('Muqova'),
            Row(children: [
              GestureDetector(
                onTap: () async {
                  final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1400, imageQuality: 88);
                  if (f != null) setState(() => _cover = f);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _cover != null
                      ? Image.file(File(_cover!.path), width: 84, height: 124, fit: BoxFit.cover)
                      : _b != null && _b['photo'] != null
                          ? BookCover(book: _b, width: 84, height: 124, shadow: false)
                          : Container(width: 84, height: 124, color: AppPalette.surfaceAlt, alignment: Alignment.center, child: const AppIcon('image', color: AppPalette.muted)),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(child: Text("JPG yoki PNG, tik holatda (2:3). Muqova bo'lmasa, chiroyli muqova avtomatik yaratiladi.", style: AppText.bodySoft)),
            ]),
            _section("Ma'lumotlar"),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Kitob nomi')),
            const SizedBox(height: 12),
            TextField(controller: _author, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Muallif(lar)', hintText: 'Bir nechta bo‘lsa vergul bilan')),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _categories.any((c) => c['id'] == _categoryId) ? _categoryId : null,
              decoration: const InputDecoration(labelText: 'Kategoriya'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tanlanmagan')),
                for (final c in _categories) DropdownMenuItem(value: c['id'] as int, child: Text(c['name']['uz'] ?? '')),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            TextField(controller: _description, minLines: 4, maxLines: 10, maxLength: 10000, decoration: const InputDecoration(labelText: 'Tavsif', alignLabelWithHint: true, hintText: 'Kitob nima haqida, kimlar uchun…')),
            _section('Narx'),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _free,
                activeThumbColor: AppPalette.brand,
                onChanged: (v) => setState(() => _free = v),
                title: const Text('Bepul kitob', style: AppText.label),
                subtitle: const Text("Hamma bepul o'qiy oladi", style: AppText.caption),
              ),
            ),
            if (!_free) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: "Narx (so'm)", hintText: '35000'),
              ),
              const SizedBox(height: 8),
              Builder(builder: (_) {
                final price = int.tryParse(_price.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
                final c = (_rules?['commission_percent'] as num?) ?? 30;
                return Text('Har sotuvdan sizga: ${formatMoney(price * (100 - c) / 100)} (komissiya $c%)', style: AppText.caption.copyWith(color: AppPalette.success));
              }),
            ],
            const SizedBox(height: 24),
            if (published && !_isNew)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text("Narx va tavsif darhol yangilanadi. Nom yoki faylni o'zgartirsangiz, kitob qayta moderatsiyadan o'tadi.", style: AppText.caption),
              ),
            if (busy) ...[
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _progress! >= 1 ? null : _progress, minHeight: 6)),
              const SizedBox(height: 8),
              Text(_progress! >= 1 ? 'Saqlanmoqda…' : 'Yuklanmoqda ${(_progress! * 100).round()}%', style: AppText.caption, textAlign: TextAlign.center),
              const SizedBox(height: 12),
            ],
            FilledButton(onPressed: busy ? null : _save, child: Text(_isNew ? 'Moderatsiyaga yuborish' : 'Saqlash')),
          ],
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(top: 22, bottom: 10), child: Text(t, style: AppText.section));
}
