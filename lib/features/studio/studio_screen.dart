import 'package:flutter/material.dart';
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/core/format.dart';
import 'package:mengliyevsebook/core/session.dart';
import 'package:mengliyevsebook/features/author/author_page.dart';
import 'package:mengliyevsebook/features/author/become_author_screen.dart';
import 'package:mengliyevsebook/features/studio/studio_books.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:mengliyevsebook/widgets/bar_chart.dart';
import 'package:mengliyevsebook/widgets/common.dart';

/// Author cabinet: balance, sales, books and payouts.
class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  final _key = GlobalKey<AsyncViewState<Map>>();

  Future<void> _go(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _key.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Muallif kabineti'),
        leading: AppIconButton('arrow-left', onTap: () => Navigator.pop(context)),
        actions: [
          AppIconButton('eye', tooltip: 'Ommaviy sahifa', onTap: () => openAuthorPage(context, session.user!['id'])),
          AppIconButton('settings', tooltip: 'Profil', onTap: () => _go(const BecomeAuthorScreen())),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _go(const StudioBookForm()),
        backgroundColor: AppPalette.brand,
        foregroundColor: Colors.white,
        icon: const AppIcon('book-plus', size: 20, color: Colors.white),
        label: Text('Kitob yuklash', style: AppText.label.copyWith(color: Colors.white)),
      ),
      body: AsyncView<Map>(
        key: _key,
        load: () async => Map.from(await api.get('/api/studio/dashboard')),
        builder: (context, d, reload) {
          final bal = Map.from(d['balance'] ?? {});
          final books = Map.from(d['books'] ?? {});
          final profile = Map.from(d['profile'] ?? {});
          final months = ((d['months'] as List?) ?? []).cast<Map>();
          final top = ((d['top_books'] as List?) ?? []).cast<Map>();
          final hasCard = (profile['card_number'] ?? '').toString().isNotEmpty;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: [
                _balanceCard(bal, d),
                if (!hasCard || profile['card_verified'] != true) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _go(const BecomeAuthorScreen()),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppPalette.warningSoft, borderRadius: BorderRadius.circular(18)),
                      child: Row(children: [
                        const AppIcon('credit-card', color: AppPalette.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            hasCard ? "Karta administrator tomonidan tekshirilmoqda. Tasdiqlangach to'lovlar boshlanadi." : "Daromad olish uchun to'lov kartangizni kiriting",
                            style: AppText.body.copyWith(fontSize: 14, color: AppPalette.ink),
                          ),
                        ),
                        if (!hasCard) const AppIcon('chevron-right', color: AppPalette.warning),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: StatTile(label: 'nashr qilingan', value: '${books['approved']}', icon: 'book-open-check', color: AppPalette.success)),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(label: 'moderatsiyada', value: '${books['pending']}', icon: 'clock', color: AppPalette.warning)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: StatTile(label: 'sotuv', value: '${books['sales']}', icon: 'shopping-bag')),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(label: 'kitobxon', value: '${d['readers'] ?? 0}', icon: 'users', color: AppPalette.brandMid)),
                ]),
                const SizedBox(height: 14),
                MenuGroup(children: [
                  MenuTile(icon: 'library-big', title: 'Kitoblarim', trailing: '${books['total']}', onTap: () => _go(const StudioBooksScreen())),
                  MenuTile(icon: 'trending-up', title: 'Sotuvlar tarixi', onTap: () => _go(const StudioMoneyScreen(initialTab: 0))),
                  MenuTile(icon: 'wallet', title: "To'lovlar", subtitle: 'Kartaga o‘tkazilgan daromad', onTap: () => _go(const StudioMoneyScreen(initialTab: 1))),
                ]),
                const SizedBox(height: 14),
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Oylik daromad', style: AppText.section),
                    const SizedBox(height: 12),
                    BarChart(bars: [for (final m in months) (formatPeriod(m['period']), (m['amount'] as num?) ?? 0)], format: formatMoney),
                  ]),
                ),
                if (top.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Panel(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Eng ko‘p sotilgan', style: AppText.section),
                      const SizedBox(height: 8),
                      for (final b in top)
                        InkWell(
                          onTap: () => _go(StudioBookScreen(bookId: b['id'])),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(children: [
                              Expanded(child: Text(b['title'] ?? '', style: AppText.body.copyWith(fontSize: 14.5), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 10),
                              Text('${b['sales_count']} ta', style: AppText.label),
                            ]),
                          ),
                        ),
                    ]),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _balanceCard(Map bal, Map d) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppPalette.brandDark, AppPalette.brandMid], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Hisobingizda', style: AppText.caption.copyWith(color: Colors.white70)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
            child: Text('Komissiya ${d['commission_percent']}%', style: AppText.caption.copyWith(color: Colors.white, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(formatMoney(bal['available']), style: AppText.display.copyWith(color: Colors.white, fontSize: 30)),
        const SizedBox(height: 4),
        Text("Keyingi oylik to'lovda o'tkaziladi (min. ${formatMoney(d['payout_min'])})", style: AppText.caption.copyWith(color: Colors.white70)),
        const SizedBox(height: 16),
        Row(children: [
          _mini('Shu oy', bal['this_month']),
          _mini("To'lov kutilmoqda", bal['pending_payout']),
          _mini("To'langan", bal['paid_total']),
        ]),
      ]),
    );
  }

  Widget _mini(String label, dynamic v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppText.caption.copyWith(color: Colors.white60, fontSize: 11.5)),
          const SizedBox(height: 2),
          FittedBox(child: Text(formatMoney(v), style: AppText.label.copyWith(color: Colors.white))),
        ]),
      );
}

/// Sales history (earnings rows) and payouts.
class StudioMoneyScreen extends StatelessWidget {
  final int initialTab;

  const StudioMoneyScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Daromad'),
          leading: AppIconButton('arrow-left', onTap: () => Navigator.pop(context)),
          bottom: const TabBar(
            labelColor: AppPalette.brand,
            unselectedLabelColor: AppPalette.muted,
            indicatorColor: AppPalette.brand,
            labelStyle: AppText.label,
            tabs: [Tab(text: 'Sotuvlar'), Tab(text: "To'lovlar")],
          ),
        ),
        body: TabBarView(children: [_earnings(), _payouts()]),
      ),
    );
  }

  Widget _earnings() {
    return AsyncView<List<Map>>(
      load: () async => ((await api.get('/api/studio/earnings'))['earnings'] as List).cast<Map>(),
      builder: (context, rows, reload) {
        if (rows.isEmpty) return const EmptyState(icon: 'trending-up', title: "Hali sotuvlar yo'q", text: 'Kitobingiz sotilganda har bir sotuv shu yerda ko‘rinadi');
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final e = rows[i];
              final refund = (e['author_amount'] as num) < 0;
              return Panel(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  AppIcon(refund ? 'rotate-ccw' : 'shopping-bag', color: refund ? AppPalette.danger : AppPalette.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e['book_title'] ?? 'Kitob', style: AppText.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(
                        '${formatDate(e['created_at'])} · ${refund ? 'qaytarildi' : 'narx ${formatMoney(e['gross'])}, komissiya ${formatMoney(e['platform_amount'])}'}',
                        style: AppText.caption,
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${refund ? '' : '+'}${formatMoney(e['author_amount'])}', style: AppText.label.copyWith(color: refund ? AppPalette.danger : AppPalette.success)),
                    if (e['payout_id'] != null) const Text("to'langan", style: AppText.caption),
                  ]),
                ]),
              );
            },
          ),
        );
      },
    );
  }

  Widget _payouts() {
    return AsyncView<Map>(
      load: () async => Map.from(await api.get('/api/studio/payouts')),
      builder: (context, d, reload) {
        final rows = ((d['payouts'] as List?) ?? []).cast<Map>();
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Panel(
                child: Row(children: [
                  const AppIcon('wallet', color: AppPalette.gold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      d['card_verified'] == true ? "Har oy boshida o'tgan oy daromadi tasdiqlangan kartangizga o'tkaziladi." : "To'lovlar karta tasdiqlangandan keyin boshlanadi.",
                      style: AppText.bodySoft.copyWith(fontSize: 14),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty) const EmptyState(icon: 'wallet', title: "Hali to'lovlar yo'q", text: "Birinchi oylik to'lov shu yerda ko'rinadi"),
              for (final p in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Panel(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(formatPeriod(p['period']), style: AppText.label),
                          const SizedBox(height: 3),
                          Text('${p['card_number'] ?? ''}${p['reference'] != null && p['reference'] != '' ? ' · ${p['reference']}' : ''}', style: AppText.caption),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(formatMoney(p['amount']), style: AppText.label),
                        const SizedBox(height: 4),
                        p['status'] == 'paid'
                            ? Chip2("O'tkazildi", color: AppPalette.success, background: AppPalette.successSoft)
                            : const Chip2('Jarayonda', color: AppPalette.warning, background: AppPalette.warningSoft),
                      ]),
                    ]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
