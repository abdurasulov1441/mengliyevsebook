import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/core/format.dart';
import 'package:mengliyevsebook/features/author/become_author_screen.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:mengliyevsebook/widgets/common.dart';

/// Monthly author payouts: what is accrued, generating payouts, marking them paid.
class AdminPayoutsScreen extends StatefulWidget {
  const AdminPayoutsScreen({super.key});

  @override
  State<AdminPayoutsScreen> createState() => _AdminPayoutsScreenState();
}

class _AdminPayoutsScreenState extends State<AdminPayoutsScreen> {
  final _key = GlobalKey<AsyncViewState<Map>>();

  Future<void> _generate(String period) async {
    if (!await confirm(
      context,
      title: "${formatPeriod(period)} uchun to'lovlar",
      text: "Shu oygacha yig'ilgan daromad bo'yicha har bir muallifga to'lov yaratiladi (karta tasdiqlangan va minimal summadan oshgan bo'lsa).",
      ok: 'Yaratish',
      icon: 'wallet',
    )) {
      return;
    }
    try {
      final r = Map.from(await api.post('/api/admin/payouts/generate', {'period': period}));
      final created = (r['created'] as List?)?.length ?? 0;
      final skipped = (r['skipped'] as List?)?.length ?? 0;
      if (mounted) toast(context, "$created ta to'lov yaratildi${skipped > 0 ? ', $skipped ta o‘tkazib yuborildi' : ''}");
      _key.currentState?.reload();
    } catch (e) {
      if (mounted) toast(context, errorText(e), error: true);
    }
  }

  Future<void> _markPaid(Map p) async {
    final ref = await askText(context, title: "To'langan deb belgilash", hint: "To'lov raqami / izoh (ixtiyoriy)", ok: "To'landi", required: false, maxLines: 1);
    if (ref == null) return;
    try {
      await api.post('/api/admin/payouts/${p['id']}/mark-paid', {'reference': ref});
      if (mounted) toast(context, "Muallifga xabar yuborildi");
      _key.currentState?.reload();
    } catch (e) {
      if (mounted) toast(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mualliflarga to'lovlar"), leading: AppIconButton('arrow-left', onTap: () => Navigator.pop(context))),
      body: AsyncView<Map>(
        key: _key,
        load: () async => Map.from(await api.get('/api/admin/payouts')),
        builder: (context, d, reload) {
          final accrued = ((d['accrued'] as List?) ?? []).cast<Map>();
          final payouts = ((d['payouts'] as List?) ?? []).cast<Map>();
          final pending = payouts.where((p) => p['status'] == 'pending').toList();
          final paid = payouts.where((p) => p['status'] != 'pending').toList();
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text("Oylik to'lov", style: AppText.section),
                    const SizedBox(height: 6),
                    Text("Minimal summa: ${formatMoney(d['payout_min'])}. Har oy boshida o'tgan oy uchun to'lovlarni yarating, so'ng kartalarga o'tkazib, \"To'landi\" deb belgilang.", style: AppText.bodySoft.copyWith(fontSize: 14)),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _generate(d['last_month']),
                      icon: const AppIcon('hand-coins', size: 18, color: Colors.white),
                      label: Text("${formatPeriod(d['last_month'])} uchun yaratish"),
                    ),
                  ]),
                ),
                if (accrued.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text("Yig'ilgan daromad", style: AppText.section),
                  const SizedBox(height: 8),
                  for (final a in accrued)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Panel(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Expanded(child: Text(a['author_name'] ?? 'Muallif #${a['author_user_id']}', style: AppText.label)),
                          if (a['card_verified'] != 1 && a['card_verified'] != true) const Padding(padding: EdgeInsets.only(right: 8), child: Chip2('Karta tasdiqlanmagan', color: AppPalette.warning, background: AppPalette.warningSoft)),
                          Text(formatMoney(a['amount']), style: AppText.label),
                        ]),
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                Text("To'lanishi kerak (${pending.length})", style: AppText.section),
                const SizedBox(height: 8),
                if (pending.isEmpty) const Text("Kutilayotgan to'lovlar yo'q", style: AppText.bodySoft),
                for (final p in pending) _payout(p, true),
                if (paid.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text("To'langanlar", style: AppText.section),
                  const SizedBox(height: 8),
                  for (final p in paid) _payout(p, false),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _payout(Map p, bool pending) {
    final card = (p['card_number'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(p['author_name'] ?? '', style: AppText.label)),
            Text(formatMoney(p['amount']), style: AppText.title.copyWith(fontSize: 17)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: Text('${CardFormatter.format(card)} · ${p['card_holder'] ?? ''}\n${formatPeriod(p['period'])}${p['paid_at'] != null ? ' · ${formatDate(p['paid_at'])}' : ''}${(p['reference'] ?? '').toString().isNotEmpty ? ' · ${p['reference']}' : ''}', style: AppText.caption)),
            if (card.isNotEmpty)
              AppIconButton('copy', size: 36, color: AppPalette.muted, onTap: () {
                Clipboard.setData(ClipboardData(text: card));
                toast(context, 'Karta raqami nusxalandi');
              }),
          ]),
          if (pending) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(onPressed: () => _markPaid(p), icon: const AppIcon('check', size: 18, color: AppPalette.brand), label: const Text("To'landi deb belgilash")),
            ),
          ],
        ]),
      ),
    );
  }
}

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  static const _tabs = [('paid', "To'langan"), ('created', 'Kutilmoqda'), ('refunded', 'Qaytarilgan'), ('cancelled', 'Bekor')];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Buyurtmalar'),
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
        body: TabBarView(children: [for (final t in _tabs) _orders(t.$1)]),
      ),
    );
  }

  Widget _orders(String status) {
    return AsyncView<List<Map>>(
      load: () async => ((await api.get('/api/admin/orders', query: {'status': status, 'limit': 200}))['orders'] as List).cast<Map>(),
      builder: (context, orders, reload) {
        if (orders.isEmpty) return const EmptyState(icon: 'receipt', title: "Buyurtmalar yo'q", text: "Bu bo'limda hozircha buyurtma yo'q");
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final o = orders[i];
              return Panel(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(o['book_title'] ?? '', style: AppText.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(formatMoney(o['amount']), style: AppText.label),
                  ]),
                  const SizedBox(height: 4),
                  Text('№${o['id']} · ${o['user_name'] ?? ''} ${o['phone_number'] ?? ''}\n${formatDate(o['paid_at'] ?? o['created_at'])}${o['provider'] != null ? ' · ${o['provider']}' : ''}', style: AppText.caption),
                  if (status == 'created') ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          if (!await confirm(context, title: "To'langan deb belgilansinmi?", text: "Faqat pul haqiqatan tushganini tekshirgan bo'lsangiz. Kitob xaridorga beriladi, muallifga daromad yoziladi.")) return;
                          try {
                            await api.post('/api/admin/orders/${o['id']}/mark-paid');
                            reload();
                          } catch (e) {
                            if (context.mounted) toast(context, errorText(e), error: true);
                          }
                        },
                        child: const Text("To'landi"),
                      ),
                    ),
                  ],
                ]),
              );
            },
          ),
        );
      },
    );
  }
}

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final _key = GlobalKey<AsyncViewState<List<Map>>>();

  Future<void> _edit([Map? c]) async {
    final name = await askText(context, title: c == null ? 'Yangi kategoriya' : 'Kategoriya nomi', hint: 'Masalan: Ilmiy adabiyot', initial: c?['name']?['uz'], maxLines: 1);
    if (name == null) return;
    try {
      final body = {'name_uz': name, 'name_ru': c?['name']?['ru'] ?? '', 'name_en': c?['name']?['en'] ?? ''};
      c == null ? await api.post('/api/admin/categories', body) : await api.put('/api/admin/categories/${c['id']}', body);
      _key.currentState?.reload();
    } catch (e) {
      if (mounted) toast(context, errorText(e), error: true);
    }
  }

  Future<void> _delete(Map c) async {
    if (!await confirm(context, title: "O'chirilsinmi?", text: "\"${c['name']['uz']}\" kategoriyasidagi kitoblar kategoriyasiz qoladi.", danger: true, ok: "O'chirish")) return;
    try {
      await api.delete('/api/admin/categories/${c['id']}');
      _key.currentState?.reload();
    } catch (e) {
      if (mounted) toast(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategoriyalar'),
        leading: AppIconButton('arrow-left', onTap: () => Navigator.pop(context)),
        actions: [AppIconButton('plus', onTap: () => _edit()), const SizedBox(width: 6)],
      ),
      body: AsyncView<List<Map>>(
        key: _key,
        load: () async => (await api.get('/api/categories') as List).cast<Map>(),
        builder: (context, list, reload) {
          if (list.isEmpty) return EmptyState(icon: 'layout-grid', title: "Kategoriyalar yo'q", text: 'Kitoblarni guruhlash uchun kategoriya qo‘shing', action: "Qo'shish", onAction: () => _edit());
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final c = list[i];
              return Panel(
                padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                child: Row(children: [
                  Expanded(child: Text(c['name']['uz'] ?? '', style: AppText.label)),
                  Text('${c['books_count'] ?? 0} kitob', style: AppText.caption),
                  AppIconButton('pencil', size: 40, color: AppPalette.muted, onTap: () => _edit(c)),
                  AppIconButton('trash-2', size: 40, color: AppPalette.danger, onTap: () => _delete(c)),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _commission = TextEditingController();
  final _min = TextEditingController();
  final _phone = TextEditingController();
  final _telegram = TextEditingController();
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    api.get('/api/admin/settings').then((s) {
      if (!mounted) return;
      setState(() {
        _commission.text = '${s['commission_percent']}';
        _min.text = '${s['payout_min']}';
        _phone.text = s['support_phone'] ?? '';
        _telegram.text = s['support_telegram'] ?? '';
        _loaded = true;
      });
    }).catchError((e) {
      if (mounted) toast(context, errorText(e), error: true);
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await api.put('/api/admin/settings', {
        'commission_percent': num.tryParse(_commission.text.replaceAll(',', '.')) ?? 30,
        'payout_min': int.tryParse(_min.text.replaceAll(RegExp(r'\D'), '')) ?? 0,
        'support_phone': _phone.text.trim(),
        'support_telegram': _telegram.text.trim(),
      });
      if (mounted) {
        toast(context, 'Sozlamalar saqlandi');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) toast(context, errorText(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sozlamalar'), leading: AppIconButton('arrow-left', onTap: () => Navigator.pop(context))),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Platforma komissiyasi (%)', style: AppText.label),
                const SizedBox(height: 4),
                const Text("Har bir sotuvdan platforma ulushi. Yangi sotuvlarga qo'llaniladi, eskilari o'zgarmaydi.", style: AppText.caption),
                const SizedBox(height: 8),
                TextField(controller: _commission, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(suffixText: '%')),
                const SizedBox(height: 18),
                const Text("Minimal to'lov summasi", style: AppText.label),
                const SizedBox(height: 4),
                const Text("Bundan kam daromad keyingi oyga o'tadi.", style: AppText.caption),
                const SizedBox(height: 8),
                TextField(controller: _min, keyboardType: TextInputType.number, decoration: const InputDecoration(suffixText: "so'm")),
                const SizedBox(height: 18),
                const Text("Qo'llab-quvvatlash telefoni", style: AppText.label),
                const SizedBox(height: 8),
                TextField(controller: _phone, keyboardType: TextInputType.phone),
                const SizedBox(height: 18),
                const Text('Telegram (ixtiyoriy)', style: AppText.label),
                const SizedBox(height: 8),
                TextField(controller: _telegram, decoration: const InputDecoration(hintText: '@bookhub_support')),
                const SizedBox(height: 28),
                FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saqlanmoqda…' : 'Saqlash')),
              ],
            ),
    );
  }
}
