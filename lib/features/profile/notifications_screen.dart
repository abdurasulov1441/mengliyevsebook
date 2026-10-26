import 'package:flutter/material.dart';
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/core/format.dart';
import 'package:mengliyevsebook/core/session.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:mengliyevsebook/widgets/common.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const _icons = {
    'purchase': ('shopping-bag', AppPalette.success),
    'sale': ('banknote', AppPalette.success),
    'moderation': ('shield-check', AppPalette.brand),
    'book': ('book-open', AppPalette.brand),
    'payout': ('wallet', AppPalette.gold),
    'author': ('pen-tool', AppPalette.brandMid),
    'gift': ('gift', AppPalette.gold),
  };

  Future<List<Map>> _load() async {
    final r = await api.get('/api/me/notifications');
    final list = (r['notifications'] as List).cast<Map>();
    // Opening the list marks everything read.
    if ((r['unread'] ?? 0) > 0) {
      api.post('/api/me/notifications/read').then((_) => session.refresh()).catchError((_) {});
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirishnomalar'), leading: AppIconButton('arrow-left', onTap: () => Navigator.pop(context))),
      body: AsyncView<List<Map>>(
        load: _load,
        builder: (context, list, reload) {
          if (list.isEmpty) return const EmptyState(icon: 'bell', title: "Bildirishnomalar yo'q", text: "Xaridlar, moderatsiya natijalari va to'lovlar haqida shu yerda xabar beramiz");
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final n = list[i];
                final style = _icons[n['type']] ?? ('bell', AppPalette.brand);
                return Panel(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: style.$2.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                      child: AppIcon(style.$1, size: 20, color: style.$2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(n['title'] ?? '', style: AppText.label)),
                          if (n['read'] != true) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppPalette.brand, shape: BoxShape.circle)),
                        ]),
                        if ((n['body'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(n['body'], style: AppText.bodySoft.copyWith(fontSize: 14)),
                        ],
                        const SizedBox(height: 6),
                        Text(timeAgo(n['created_at']), style: AppText.caption),
                      ]),
                    ),
                  ]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
