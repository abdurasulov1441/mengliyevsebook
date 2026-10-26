import 'package:flutter/material.dart';
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/core/format.dart';
import 'package:mengliyevsebook/features/admin/admin_books.dart';
import 'package:mengliyevsebook/features/admin/admin_people.dart';
import 'package:mengliyevsebook/features/admin/admin_money.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:mengliyevsebook/widgets/bar_chart.dart';
import 'package:mengliyevsebook/widgets/common.dart';

/// Admin dashboard: platform numbers and entry points to every admin tool.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _key = GlobalKey<AsyncViewState<Map>>();

  Future<void> _go(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _key.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Boshqaruv paneli'), leading: AppIconButton('arrow-left', onTap: () => Navigator.pop(context))),
      body: AsyncView<Map>(
        key: _key,
        load: () async => Map.from(await api.get('/api/admin/stats')),
        builder: (context, s, reload) {
          final series = ((s['sales_series'] as List?) ?? []).cast<Map>();
          final pending = (s['moderation_pending'] as num?) ?? 0;
          final unverified = (s['authors_unverified'] as num?) ?? 0;
          final settings = Map.from(s['settings'] ?? {});
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                if (pending > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _go(const AdminBooksScreen()),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppPalette.warningSoft, borderRadius: BorderRadius.circular(18)),
                        child: Row(children: [
                          const AppIcon('shield-check', color: AppPalette.warning),
                          const SizedBox(width: 12),
                          Expanded(child: Text('$pending ta kitob moderatsiyani kutmoqda', style: AppText.label.copyWith(color: AppPalette.ink))),
                          const AppIcon('chevron-right', color: AppPalette.warning),
                        ]),
                      ),
                    ),
                  ),
                Row(children: [
                  Expanded(child: StatTile(label: 'tushum (shu oy)', value: _short(s['revenue_month']), icon: 'trending-up', color: AppPalette.success)),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(label: 'komissiya (shu oy)', value: _short(s['commission_month']), icon: 'percent')),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: StatTile(label: 'bugungi sotuv', value: '${s['sales_today']}', icon: 'shopping-bag', color: AppPalette.brandMid)),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(label: "mualliflarga qarz", value: _short(s['authors_balance']), icon: 'wallet', color: AppPalette.gold)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: StatTile(label: 'foydalanuvchi (+${s['users_today']} bugun)', value: '${s['users']}', icon: 'users', color: AppPalette.brandMid)),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(label: 'nashr qilingan kitob', value: '${s['books_published']}', icon: 'library-big', color: AppPalette.success)),
                ]),
                const SizedBox(height: 14),
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Tushum · 30 kun', style: AppText.section),
                    const SizedBox(height: 12),
                    BarChart(
                      bars: [for (final d in series) (_day(d['day']), (d['revenue'] as num?) ?? 0)],
                      format: formatMoney,
                      color: AppPalette.success,
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                MenuGroup(children: [
                  MenuTile(
                    icon: 'shield-check',
                    title: 'Moderatsiya va kitoblar',
                    trailingWidget: pending > 0 ? Chip2('$pending', color: Colors.white, background: AppPalette.warning) : null,
                    onTap: () => _go(const AdminBooksScreen()),
                  ),
                  MenuTile(
                    icon: 'pen-tool',
                    title: 'Mualliflar',
                    subtitle: '${s['authors']} ta faol',
                    trailingWidget: unverified > 0 ? Chip2('$unverified karta', color: Colors.white, background: AppPalette.brandMid) : null,
                    onTap: () => _go(const AdminAuthorsScreen()),
                  ),
                  MenuTile(icon: 'wallet', title: "Mualliflarga to'lovlar", subtitle: "Kutilmoqda: ${formatMoney(s['payouts_pending'])}", onTap: () => _go(const AdminPayoutsScreen())),
                  MenuTile(icon: 'receipt', title: 'Buyurtmalar', subtitle: 'Jami tushum: ${formatMoney(s['revenue_total'])}', onTap: () => _go(const AdminOrdersScreen())),
                ]),
                const SizedBox(height: 14),
                MenuGroup(children: [
                  MenuTile(icon: 'users', title: 'Foydalanuvchilar', onTap: () => _go(const AdminUsersScreen())),
                  MenuTile(icon: 'layout-grid', title: 'Kategoriyalar', onTap: () => _go(const AdminCategoriesScreen())),
                  MenuTile(icon: 'sliders-horizontal', title: 'Sozlamalar', subtitle: 'Komissiya ${settings['commission_percent']}% · min. to‘lov ${formatMoney(settings['payout_min'])}', onTap: () => _go(const AdminSettingsScreen())),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _day(dynamic d) {
    final s = d.toString();
    return s.length >= 10 ? '${s.substring(8, 10)}.${s.substring(5, 7)}' : s;
  }

  /// 1250000 -> "1,25 mln"
  static String _short(dynamic v) {
    final n = (v as num?) ?? 0;
    if (n.abs() >= 1000000) return "${(n / 1000000).toStringAsFixed(2).replaceAll('.', ',')} mln";
    if (n.abs() >= 10000) return '${(n / 1000).round()} ming';
    return formatMoney(n);
  }
}
