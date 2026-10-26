import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/core/format.dart';
import 'package:mengliyevsebook/core/session.dart';
import 'package:mengliyevsebook/features/author/author_page.dart';
import 'package:mengliyevsebook/features/author/become_author_screen.dart';
import 'package:mengliyevsebook/services/utils/constants.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:mengliyevsebook/widgets/common.dart';

/// Search field + list that reloads as the admin types.
class _SearchList extends StatefulWidget {
  final String hint;
  final Future<List<Map>> Function(String q) load;
  final Widget Function(BuildContext context, Map item, Future<void> Function() reload) item;
  final Widget? header;

  const _SearchList({super.key, required this.hint, required this.load, required this.item, this.header});

  @override
  State<_SearchList> createState() => _SearchListState();
}

class _SearchListState extends State<_SearchList> {
  final _key = GlobalKey<AsyncViewState<List<Map>>>();
  final _q = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: TextField(
          controller: _q,
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), () => _key.currentState?.reload());
          },
          decoration: InputDecoration(hintText: widget.hint, prefixIcon: const Padding(padding: EdgeInsets.all(13), child: AppIcon('search', size: 20, color: AppPalette.muted))),
        ),
      ),
      if (widget.header != null) widget.header!,
      Expanded(
        child: AsyncView<List<Map>>(
          key: _key,
          load: () => widget.load(_q.text.trim()),
          builder: (context, items, reload) {
            if (items.isEmpty) return const EmptyState(icon: 'search', title: 'Hech narsa topilmadi', text: "Qidiruvni o'zgartirib ko'ring");
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (c, i) => widget.item(c, items[i], reload),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class AdminAuthorsScreen extends StatefulWidget {
  const AdminAuthorsScreen({super.key});

  @override
  State<AdminAuthorsScreen> createState() => _AdminAuthorsScreenState();
}

class _AdminAuthorsScreenState extends State<AdminAuthorsScreen> {
  bool _unverified = false;

  Future<void> _edit(Map a, Future<void> Function() reload) async {
    var verified = a['card_verified'] == true;
    var blocked = a['status'] == 'blocked';
    final note = TextEditingController(text: a['admin_note'] ?? '');
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Avatar(name: a['display_name'] ?? '', url: Constants.fileUrl(a['photo']), size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a['display_name'] ?? '', style: AppText.title),
                  Text(a['phone'] ?? '', style: AppText.caption),
                ]),
              ),
              AppIconButton('external-link', onTap: () => openAuthorPage(context, a['user_id'])),
            ]),
            const SizedBox(height: 14),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("To'lov kartasi", style: AppText.caption),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: Text((a['card_number'] ?? '').toString().isEmpty ? 'Kiritilmagan' : CardFormatter.format(a['card_number']), style: AppText.title.copyWith(fontSize: 18))),
                  if ((a['card_number'] ?? '').toString().isNotEmpty)
                    AppIconButton('copy', size: 36, onTap: () {
                      Clipboard.setData(ClipboardData(text: a['card_number']));
                      toast(c, 'Nusxa olindi');
                    }),
                ]),
                Text(a['card_holder'] ?? '', style: AppText.bodySoft),
                const SizedBox(height: 8),
                Text('Balans: ${formatMoney(a['balance'])} · jami: ${formatMoney(a['earned'])} · ${a['books_count'] ?? 0} kitob', style: AppText.caption),
              ]),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: verified,
              activeThumbColor: AppPalette.success,
              onChanged: (v) => setSheet(() => verified = v),
              title: const Text('Karta tasdiqlangan', style: AppText.label),
              subtitle: const Text("Faqat tasdiqlangan kartaga to'lov yaratiladi", style: AppText.caption),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: blocked,
              activeThumbColor: AppPalette.danger,
              onChanged: (v) => setSheet(() => blocked = v),
              title: const Text('Bloklash', style: AppText.label),
              subtitle: const Text("Kitoblari do'kondan olinadi", style: AppText.caption),
            ),
            TextField(controller: note, maxLines: 2, decoration: const InputDecoration(hintText: 'Izoh (muallifga bloklash sababi sifatida yuboriladi)')),
            const SizedBox(height: 14),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Saqlash')),
          ]),
        ),
      ),
    );
    if (save != true) return;
    try {
      await api.put('/api/admin/authors/${a['user_id']}', {'card_verified': verified, 'status': blocked ? 'blocked' : 'active', 'admin_note': note.text.trim()});
      if (mounted) toast(context, 'Saqlandi');
      reload();
    } catch (e) {
      if (mounted) toast(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mualliflar'), leading: AppIconButton('arrow-left', onTap: () => Navigator.pop(context))),
      body: _SearchList(
        key: ValueKey(_unverified),
        hint: 'Ism yoki telefon',
        header: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Row(children: [
            FilterChip(
              selected: _unverified,
              onSelected: (v) => setState(() => _unverified = v),
              label: const Text('Karta tekshiruvini kutayotganlar'),
              selectedColor: AppPalette.brandSoft,
            ),
          ]),
        ),
        load: (q) async => ((await api.get('/api/admin/authors', query: {if (q.isNotEmpty) 'q': q, if (_unverified) 'unverified': 1}))['authors'] as List).cast<Map>(),
        item: (context, a, reload) => InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _edit(a, reload),
          child: Panel(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Avatar(name: a['display_name'] ?? '', url: Constants.fileUrl(a['photo']), size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a['display_name'] ?? '', style: AppText.label),
                  const SizedBox(height: 2),
                  Text('${a['phone'] ?? ''} · ${a['books_count'] ?? 0} kitob · ${formatMoney(a['balance'])}', style: AppText.caption),
                ]),
              ),
              if (a['status'] == 'blocked')
                const Chip2('Bloklangan', color: AppPalette.danger, background: AppPalette.dangerSoft)
              else if ((a['card_number'] ?? '').toString().isEmpty)
                const Chip2('Karta yo‘q', color: AppPalette.inkSoft, background: AppPalette.surfaceAlt)
              else if (a['card_verified'] == true)
                const AppIcon('badge-check', color: AppPalette.success)
              else
                const Chip2('Tekshirish', color: AppPalette.warning, background: AppPalette.warningSoft),
            ]),
          ),
        ),
      ),
    );
  }
}

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  Future<void> _edit(BuildContext context, Map u, Future<void> Function() reload) async {
    final isSelf = u['id'] == session.user?['id'];
    final r = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(u['name'] ?? 'Ismsiz', style: AppText.title),
          Text(u['phone_number'] ?? '', style: AppText.caption),
          const SizedBox(height: 10),
          if (!isSelf) ...[
            MenuTile(
              icon: 'shield-check',
              title: u['is_admin'] == true ? 'Administratorlikdan olish' : 'Administrator qilish',
              onTap: () => Navigator.pop(c, 'role'),
            ),
            MenuTile(icon: 'lock', title: u['is_blocked'] == true ? 'Blokdan chiqarish' : 'Bloklash', danger: u['is_blocked'] != true, onTap: () => Navigator.pop(c, 'block')),
          ] else
            const Padding(padding: EdgeInsets.all(16), child: Text("Bu sizning hisobingiz", style: AppText.bodySoft)),
        ]),
      ),
    );
    if (r == null) return;
    try {
      await api.put('/api/admin/users/${u['id']}', r == 'role' ? {'role_id': u['is_admin'] == true ? 2 : 1} : {'is_blocked': u['is_blocked'] != true});
      if (context.mounted) toast(context, 'Saqlandi');
      reload();
    } catch (e) {
      if (context.mounted) toast(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Foydalanuvchilar'), leading: AppIconButton('arrow-left', onTap: () => Navigator.pop(context))),
      body: _SearchList(
        hint: 'Ism yoki telefon',
        load: (q) async => ((await api.get('/api/admin/users', query: {if (q.isNotEmpty) 'q': q, 'limit': 300}))['users'] as List).cast<Map>(),
        item: (context, u, reload) => InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _edit(context, u, reload),
          child: Panel(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Avatar(name: (u['name'] ?? '').toString().isEmpty ? '?' : u['name'], url: Constants.fileUrl(u['avatar']), size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((u['name'] ?? '').toString().isEmpty ? 'Ismsiz' : u['name'], style: AppText.label),
                  const SizedBox(height: 2),
                  Text('${u['phone_number']} · ${u['books_count'] ?? 0} kitob · ${formatDate(u['created_at'])}', style: AppText.caption),
                ]),
              ),
              Wrap(spacing: 4, children: [
                if (u['is_admin'] == true) const Chip2('Admin', color: AppPalette.danger, background: AppPalette.dangerSoft),
                if (u['is_author'] == true) const Chip2('Muallif'),
                if (u['is_blocked'] == true) const AppIcon('lock', size: 18, color: AppPalette.danger),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
