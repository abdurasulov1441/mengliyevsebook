import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/core/format.dart';
import 'package:mengliyevsebook/core/session.dart';
import 'package:mengliyevsebook/features/admin/admin_screen.dart';
import 'package:mengliyevsebook/features/auth/auth_flow.dart';
import 'package:mengliyevsebook/features/author/become_author_screen.dart';
import 'package:mengliyevsebook/features/book/book_page.dart';
import 'package:mengliyevsebook/features/profile/notifications_screen.dart';
import 'package:mengliyevsebook/features/studio/studio_screen.dart';
import 'package:mengliyevsebook/services/books/book_events.dart';
import 'package:mengliyevsebook/services/books/book_library.dart';
import 'package:mengliyevsebook/services/utils/constants.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:mengliyevsebook/widgets/common.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _push(BuildContext context, Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: session,
          builder: (context, _) => RefreshIndicator(
            onRefresh: session.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              children: [
                const PageHeader(overline: Constants.appName, title: 'Profil'),
                const SizedBox(height: 18),
                if (session.loggedIn) _userCard(context) else _guestCard(context),
                const SizedBox(height: 18),
                if (session.loggedIn) ...[
                  if (session.isAdmin) ...[
                    _adminBanner(context),
                    const SizedBox(height: 14),
                  ],
                  _authorBlock(context),
                  const SizedBox(height: 14),
                  MenuGroup(children: [
                    MenuTile(
                      icon: 'bell',
                      title: 'Bildirishnomalar',
                      trailingWidget: session.unread > 0 ? Chip2('${session.unread}', color: Colors.white, background: AppPalette.danger) : null,
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                        session.refresh();
                      },
                    ),
                    MenuTile(icon: 'receipt', title: 'Xaridlar tarixi', onTap: () => _push(context, const OrdersScreen())),
                    MenuTile(icon: 'user-round', title: "Shaxsiy ma'lumotlar", onTap: () => _push(context, const EditProfileScreen())),
                  ]),
                  const SizedBox(height: 14),
                ],
                MenuGroup(children: [
                  MenuTile(icon: 'folder', title: 'Yuklangan kitoblar', subtitle: "Telefondagi joy", onTap: () => _storage(context)),
                  MenuTile(icon: 'phone', title: "Qo'llab-quvvatlash", trailing: Constants.supportPhone, onTap: () => launchUrl(Uri.parse('tel:${Constants.supportPhone}'))),
                  MenuTile(icon: 'info', title: 'Ilova haqida', onTap: () => _about(context)),
                ]),
                if (session.loggedIn) ...[
                  const SizedBox(height: 14),
                  MenuGroup(children: [
                    MenuTile(
                      icon: 'log-out',
                      title: 'Chiqish',
                      danger: true,
                      onTap: () async {
                        if (await confirm(context, title: 'Hisobdan chiqasizmi?', text: "Yuklangan kitoblar telefonda qoladi. Qayta kirganingizda kutubxonangiz tiklanadi.", ok: 'Chiqish', danger: true, icon: 'log-out')) {
                          await session.logout();
                          notifyBooksChanged();
                        }
                      },
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _guestCard(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Image.asset('assets/images/logo.png', width: 48, height: 48),
          const SizedBox(width: 14),
          const Expanded(child: Text('BookHub ga xush kelibsiz', style: AppText.title)),
        ]),
        const SizedBox(height: 12),
        const Text("Kirish orqali kitob sotib olish, o'qish joyini saqlash, fikr qoldirish va o'z kitobingizni nashr qilish mumkin.", style: AppText.bodySoft),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => requireLogin(context),
            icon: const AppIcon('log-in', size: 18, color: Colors.white),
            label: const Text('Telefon raqam bilan kirish'),
          ),
        ),
      ]),
    );
  }

  Widget _userCard(BuildContext context) {
    final u = session.user!;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _push(context, const EditProfileScreen()),
      child: Panel(
        child: Row(children: [
          Avatar(name: session.name, url: Constants.fileUrl(u['avatar']), size: 60),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(session.name, style: AppText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(u['phone_number'] ?? '', style: AppText.bodySoft),
              if (session.isAdmin || session.isAuthor) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: [
                  if (session.isAdmin) const Chip2('Administrator', icon: 'shield-check', color: AppPalette.danger, background: AppPalette.dangerSoft),
                  if (session.isAuthor) const Chip2('Muallif', icon: 'pen-tool'),
                ]),
              ],
            ]),
          ),
          const AppIcon('chevron-right', color: AppPalette.muted),
        ]),
      ),
    );
  }

  Widget _adminBanner(BuildContext context) {
    return _Banner(
      icon: 'layout-dashboard',
      title: 'Boshqaruv paneli',
      text: 'Moderatsiya, mualliflar, to‘lovlar va sozlamalar',
      colors: const [Color(0xFF121A2E), Color(0xFF2B3654)],
      onTap: () => _push(context, const AdminScreen()),
    );
  }

  Widget _authorBlock(BuildContext context) {
    if (session.isAuthor) {
      return _Banner(
        icon: 'pen-tool',
        title: 'Muallif kabineti',
        text: 'Kitoblaringiz, sotuvlar va daromad',
        colors: const [AppPalette.brand, AppPalette.brandMid],
        onTap: () => _push(context, const StudioScreen()),
      );
    }
    return _Banner(
      icon: 'rocket',
      title: 'Muallif bo‘ling',
      text: 'Kitobingizni yuklang, sotuvlardan har oy daromad oling',
      colors: const [AppPalette.brand, AppPalette.brandMid],
      onTap: () => _push(context, const BecomeAuthorScreen()),
    );
  }

  Future<void> _storage(BuildContext context) async {
    final bytes = await BookLibrary.instance.usedBytes();
    if (!context.mounted) return;
    final mb = (bytes / 1024 / 1024).toStringAsFixed(1);
    final ok = await confirm(
      context,
      title: 'Yuklangan kitoblar',
      text: "Kitoblar telefonda $mb MB joy egallaydi. Ularni o'chirsangiz, keyingi ochishda qayta yuklab olinadi (sotib olinganlar yo'qolmaydi).",
      ok: "Hammasini o'chirish",
      danger: true,
      icon: 'folder',
    );
    if (!ok) return;
    final root = await BookLibrary.instance.root();
    await for (final d in root.list()) {
      final name = d.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (RegExp(r'^p?\d+$').hasMatch(name)) await d.delete(recursive: true);
    }
    notifyBooksChanged();
    if (context.mounted) toast(context, "Telefondagi kitoblar o'chirildi");
  }

  void _about(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/images/logo.png', width: 72, height: 72),
            const SizedBox(height: 12),
            const Text(Constants.appName, style: AppText.display),
            const SizedBox(height: 8),
            const Text(
              "O'zbek kitoblari uchun ochiq platforma: o'qing, sotib oling va o'z kitobingizni nashr qiling. Har bir kitob moderatsiyadan o'tadi, mualliflar har oy daromad oladi.",
              textAlign: TextAlign.center,
              style: AppText.bodySoft,
            ),
            const SizedBox(height: 16),
            Text('Versiya 2.0.0', style: AppText.caption),
          ]),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String icon;
  final String title;
  final String text;
  final List<Color> colors;
  final VoidCallback onTap;

  const _Banner({required this.icon, required this.title, required this.text, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
              child: AppIcon(icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppText.section.copyWith(color: Colors.white)),
                const SizedBox(height: 3),
                Text(text, style: AppText.caption.copyWith(color: Colors.white.withValues(alpha: 0.82), fontSize: 13)),
              ]),
            ),
            const AppIcon('chevron-right', color: Colors.white),
          ]),
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController(text: session.user?['name'] ?? '');
  XFile? _avatar;
  bool _busy = false;

  Future<void> _pick() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (f != null) setState(() => _avatar = f);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return toast(context, 'Ismingizni kiriting', error: true);
    setState(() => _busy = true);
    try {
      final form = FormData.fromMap({
        'name': _name.text.trim(),
        if (_avatar != null) 'avatar': await MultipartFile.fromFile(_avatar!.path, filename: _avatar!.name),
      });
      session.setUser(Map<String, dynamic>.from(await api.upload('PUT', '/api/me', form)));
      if (mounted) {
        toast(context, 'Saqlandi');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) toast(context, errorText(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final u = session.user ?? {};
    return Scaffold(
      appBar: AppBar(title: const Text("Shaxsiy ma'lumotlar"), leading: AppIconButton('arrow-left', onTap: () => Navigator.pop(context))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pick,
              child: Stack(children: [
                _avatar != null
                    ? ClipOval(child: Image.file(File(_avatar!.path), width: 104, height: 104, fit: BoxFit.cover))
                    : Avatar(name: session.name, url: Constants.fileUrl(u['avatar']), size: 104),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppPalette.brand, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                    child: const AppIcon('camera', size: 16, color: Colors.white),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Ism', style: AppText.label),
          const SizedBox(height: 8),
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Ism familiya')),
          const SizedBox(height: 16),
          const Text('Telefon raqam', style: AppText.label),
          const SizedBox(height: 8),
          TextField(enabled: false, controller: TextEditingController(text: u['phone_number'] ?? ''), decoration: const InputDecoration(prefixIcon: Padding(padding: EdgeInsets.all(13), child: AppIcon('lock', size: 18, color: AppPalette.muted)))),
          const SizedBox(height: 28),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saqlanmoqda…' : 'Saqlash')),
        ],
      ),
    );
  }
}

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  static const _status = {
    'paid': ("To'langan", AppPalette.success, AppPalette.successSoft),
    'created': ('Kutilmoqda', AppPalette.warning, AppPalette.warningSoft),
    'cancelled': ('Bekor qilingan', AppPalette.inkSoft, AppPalette.surfaceAlt),
    'refunded': ('Qaytarilgan', AppPalette.danger, AppPalette.dangerSoft),
  };
  static const _providers = {'payme': 'Payme', 'click': 'Click', 'demo': 'Demo', 'admin': 'Administrator'};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xaridlar tarixi'), leading: AppIconButton('arrow-left', onTap: () => Navigator.pop(context))),
      body: AsyncView<List<Map>>(
        load: () async => ((await api.get('/api/me/orders'))['orders'] as List).cast<Map>(),
        builder: (context, orders, reload) {
          if (orders.isEmpty) return const EmptyState(icon: 'receipt', title: "Xaridlar yo'q", text: "Sotib olgan kitoblaringiz cheklari shu yerda saqlanadi");
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final o = orders[i];
                final st = _status[o['status']] ?? (o['status'].toString(), AppPalette.inkSoft, AppPalette.surfaceAlt);
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => openBookPage(context, {'id': o['book_id'], 'title': o['book_title']}),
                  child: Panel(
                    child: Row(children: [
                      const AppIcon('receipt', color: AppPalette.brand),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(o['book_title'] ?? 'Kitob', style: AppText.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('№${o['id']} · ${formatDate(o['paid_at'] ?? o['created_at'])}${o['provider'] != null ? ' · ${_providers[o['provider']] ?? o['provider']}' : ''}', style: AppText.caption),
                        ]),
                      ),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(formatMoney(o['amount']), style: AppText.label),
                        const SizedBox(height: 4),
                        Chip2(st.$1, color: st.$2, background: st.$3),
                      ]),
                    ]),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
