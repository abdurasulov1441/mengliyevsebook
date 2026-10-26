import 'package:flutter/material.dart';
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/core/format.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:mengliyevsebook/widgets/common.dart';

class ReviewCard extends StatelessWidget {
  final Map review;

  const ReviewCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    final text = (review['text'] ?? '').toString();
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Avatar(name: review['user_name'] ?? 'K', size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(review['user_name'] ?? 'Kitobxon', style: AppText.label),
              Text(timeAgo(review['updated_at'] ?? review['created_at']), style: AppText.caption),
            ]),
          ),
          RatingStars(((review['rating'] as num?) ?? 0).toDouble(), size: 13),
        ]),
        if (text.isNotEmpty) ...[const SizedBox(height: 10), Text(text, style: AppText.body.copyWith(fontSize: 14.5, color: AppPalette.inkSoft))],
      ]),
    );
  }
}

class ReviewsPage extends StatelessWidget {
  final Map book;

  const ReviewsPage({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fikrlar'), leading: AppIconButton('arrow-left', onTap: () => Navigator.pop(context))),
      body: AsyncView<Map>(
        load: () async => Map.from(await api.get('/api/books/${book['id']}/reviews', query: {'limit': 100})),
        builder: (context, data, reload) {
          final reviews = ((data['reviews'] as List?) ?? []).cast<Map>();
          final dist = Map<String, dynamic>.from(data['distribution'] ?? {});
          final total = reviews.isEmpty ? 1 : dist.values.fold<int>(0, (a, v) => a + (v as num).toInt());
          final rating = ((book['rating'] as num?) ?? 0).toDouble();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Panel(
                child: Row(children: [
                  Column(children: [
                    Text(rating.toStringAsFixed(1), style: AppText.display.copyWith(fontSize: 42)),
                    RatingStars(rating, size: 15),
                    const SizedBox(height: 4),
                    Text('${book['rating_count'] ?? reviews.length} ta baho', style: AppText.caption),
                  ]),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(children: [
                      for (var s = 5; s >= 1; s--)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.5),
                          child: Row(children: [
                            SizedBox(width: 12, child: Text('$s', style: AppText.caption)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(value: ((dist['$s'] as num?) ?? 0) / total, minHeight: 7, color: AppPalette.gold, backgroundColor: AppPalette.surfaceAlt),
                              ),
                            ),
                          ]),
                        ),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              if (reviews.isEmpty) const EmptyState(icon: 'message-square', title: "Hali fikrlar yo'q", text: 'Kitobni o‘qiganlar fikrlari shu yerda chiqadi'),
              for (final r in reviews) Padding(padding: const EdgeInsets.only(bottom: 10), child: ReviewCard(review: r)),
            ],
          );
        },
      ),
    );
  }
}

/// Write or edit the user's review. Returns true when saved.
Future<bool> showReviewSheet(BuildContext context, Map book) async {
  final mine = book['my_review'] as Map?;
  var rating = (mine?['rating'] as num?)?.toInt() ?? 0;
  final text = TextEditingController(text: mine?['text'] ?? '');
  var busy = false;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Kitobga baho bering', style: AppText.title, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(book['title'] ?? '', style: AppText.bodySoft, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var s = 1; s <= 5; s++)
              GestureDetector(
                onTap: () => setState(() => rating = s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: AppIcon(s <= rating ? 'star-filled' : 'star', size: 38, color: s <= rating ? AppPalette.gold : AppPalette.line),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          TextField(controller: text, maxLines: 4, minLines: 3, maxLength: 2000, decoration: const InputDecoration(hintText: 'Kitob haqida fikringiz (ixtiyoriy)')),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: rating == 0 || busy
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      await api.post('/api/books/${book['id']}/reviews', {'rating': rating, 'text': text.text.trim()});
                      if (c.mounted) Navigator.pop(c, true);
                    } catch (e) {
                      setState(() => busy = false);
                      if (c.mounted) toast(c, errorText(e), error: true);
                    }
                  },
            child: Text(busy ? 'Saqlanmoqda…' : 'Yuborish'),
          ),
        ]),
      ),
    ),
  );
  if (saved == true && context.mounted) toast(context, 'Rahmat! Fikringiz saqlandi');
  return saved == true;
}
