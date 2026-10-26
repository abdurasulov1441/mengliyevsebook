import 'package:flutter/material.dart';
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/features/book/book_page.dart';
import 'package:mengliyevsebook/services/utils/constants.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:mengliyevsebook/widgets/common.dart';

void openAuthorPage(BuildContext context, dynamic userId) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => AuthorPage(userId: (userId as num).toInt())));
}

/// Public author page: photo, bio, numbers and their books.
class AuthorPage extends StatelessWidget {
  final int userId;

  const AuthorPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: AppIconButton('arrow-left', onTap: () => Navigator.pop(context))),
      body: AsyncView<Map>(
        load: () async => Map.from(await api.get('/api/authors/$userId')),
        builder: (context, a, reload) {
          final books = ((a['books'] as List?) ?? []).cast<Map>();
          return LayoutBuilder(builder: (context, c) {
            final cols = ((c.maxWidth - 40) / 150).floor().clamp(2, 5);
            final w = (c.maxWidth - 40 - 16 * (cols - 1)) / cols;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                Center(child: Avatar(name: a['display_name'] ?? '', url: Constants.fileUrl(a['photo']), size: 96)),
                const SizedBox(height: 14),
                Text(a['display_name'] ?? '', textAlign: TextAlign.center, style: AppText.display.copyWith(fontSize: 26)),
                const SizedBox(height: 4),
                const Center(child: Chip2('Muallif', icon: 'pen-tool')),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: StatTile(label: 'kitob', value: '${a['books_count'] ?? 0}', icon: 'library-big')),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(label: 'kitobxon', value: '${a['readers'] ?? 0}', icon: 'users', color: AppPalette.success)),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(label: 'fikr', value: '${a['reviews'] ?? 0}', icon: 'message-square', color: AppPalette.gold)),
                ]),
                if ((a['bio'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const Text('Muallif haqida', style: AppText.section),
                  const SizedBox(height: 8),
                  Text(a['bio'], style: AppText.body.copyWith(color: AppPalette.inkSoft, height: 1.6)),
                ],
                const SizedBox(height: 24),
                Text('Kitoblari (${books.length})', style: AppText.section),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 22,
                  children: [for (final b in books) BookCard(book: b, width: w, onTap: () => openBookPage(context, b))],
                ),
              ],
            );
          });
        },
      ),
    );
  }
}
