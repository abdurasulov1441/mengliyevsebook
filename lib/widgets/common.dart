import 'package:flutter/material.dart';
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/core/format.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:mengliyevsebook/widgets/book_cover.dart';

// Shared building blocks of the BookHub UI.

void toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? AppPalette.danger : null));
}

String errorText(Object e) => e is ApiException ? e.message : 'Xatolik yuz berdi';

/// Big screen title block used at the top of tabs.
class PageHeader extends StatelessWidget {
  final String overline;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const PageHeader({super.key, required this.overline, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(overline.toUpperCase(), style: AppText.overline),
              const SizedBox(height: 6),
              Text(title, style: AppText.display),
              if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: AppText.bodySoft)],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.section)),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(action!),
                const SizedBox(width: 2),
                const AppIcon('chevron-right', size: 16, color: AppPalette.brand),
              ]),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String icon;
  final String title;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  const EmptyState({super.key, required this.icon, required this.title, required this.text, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(color: AppPalette.brandSoft, shape: BoxShape.circle),
              child: Center(child: AppIcon(icon, size: 42, color: AppPalette.brand)),
            ),
            const SizedBox(height: 20),
            Text(title, style: AppText.title, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(text, style: AppText.bodySoft, textAlign: TextAlign.center),
            if (action != null && onAction != null) ...[
              const SizedBox(height: 22),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const ErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => EmptyState(icon: 'wifi-off', title: 'Yuklab bo‘lmadi', text: errorText(error), action: 'Qayta urinish', onAction: onRetry);
}

/// Loads a future and shows spinner / error / content.
class AsyncView<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  const AsyncView({super.key, required this.load, required this.builder});

  @override
  State<AsyncView<T>> createState() => AsyncViewState<T>();
}

class AsyncViewState<T> extends State<AsyncView<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    if (_data == null) setState(() => _loading = true);
    try {
      final d = await widget.load();
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) return const Center(child: CircularProgressIndicator());
    if (_error != null && _data == null) return ErrorView(error: _error!, onRetry: reload);
    return widget.builder(context, _data as T, reload);
  }
}

class RatingStars extends StatelessWidget {
  final double rating;
  final double size;

  const RatingStars(this.rating, {super.key, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 1),
            child: Opacity(opacity: rating >= i - 0.25 ? 1 : 0.25, child: _Star(size: size)),
          ),
      ],
    );
  }
}

class _Star extends StatelessWidget {
  final double size;

  const _Star({required this.size});

  @override
  Widget build(BuildContext context) => AppIcon('star-filled', size: size, color: AppPalette.gold);
}

class Chip2 extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  final String? icon;

  const Chip2(this.text, {super.key, this.color = AppPalette.brand, this.background = AppPalette.brandSoft, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[AppIcon(icon!, size: 13, color: color), const SizedBox(width: 5)],
        Text(text, style: AppText.label.copyWith(fontSize: 12, color: color)),
      ]),
    );
  }
}

/// Price / owned badge for a book.
class PriceTag extends StatelessWidget {
  final Map book;

  const PriceTag(this.book, {super.key});

  @override
  Widget build(BuildContext context) {
    if (book['has_access'] == true || book['in_library'] == true) return const Chip2('Sizda bor', icon: 'circle-check');
    if (book['is_free'] == true) return const Chip2('Bepul', color: AppPalette.success, background: AppPalette.successSoft);
    return Chip2(formatMoney(book['price']), color: AppPalette.gold, background: AppPalette.goldSoft);
  }
}

/// Moderation status of a book (author & admin screens).
class StatusChip extends StatelessWidget {
  final Map book;

  const StatusChip(this.book, {super.key});

  @override
  Widget build(BuildContext context) {
    final conv = book['conversion_status'];
    if (conv == 'pending' || conv == 'processing') return const Chip2('Tayyorlanmoqda', icon: 'hourglass', color: AppPalette.brandMid);
    if (conv == 'failed') return const Chip2('Fayl xatosi', icon: 'circle-alert', color: AppPalette.danger, background: AppPalette.dangerSoft);
    switch (book['status']) {
      case 'approved':
        return const Chip2('Nashr qilingan', icon: 'circle-check', color: AppPalette.success, background: AppPalette.successSoft);
      case 'pending':
        return const Chip2('Moderatsiyada', icon: 'clock', color: AppPalette.warning, background: AppPalette.warningSoft);
      case 'rejected':
        return const Chip2('Rad etilgan', icon: 'circle-x', color: AppPalette.danger, background: AppPalette.dangerSoft);
      case 'unpublished':
        return const Chip2('Yashirilgan', icon: 'eye-off', color: AppPalette.inkSoft, background: AppPalette.surfaceAlt);
      default:
        return const Chip2('Qoralama', color: AppPalette.inkSoft, background: AppPalette.surfaceAlt);
    }
  }
}

/// Vertical book card for grids and carousels.
class BookCard extends StatelessWidget {
  final Map book;
  final double width;
  final VoidCallback onTap;
  final bool showPrice;

  const BookCard({super.key, required this.book, required this.width, required this.onTap, this.showPrice = true});

  @override
  Widget build(BuildContext context) {
    final rating = ((book['rating'] as num?) ?? 0).toDouble();
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(tag: 'cover-${book['id']}-${identityHashCode(this)}', child: BookCover(book: book, width: width, height: width * 1.48)),
            const SizedBox(height: 10),
            Text(book['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bookTitle.copyWith(fontSize: 14)),
            const SizedBox(height: 3),
            Text((book['author_name'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
            const SizedBox(height: 6),
            Row(children: [
              if (rating > 0) ...[
                const AppIcon('star-filled', size: 13, color: AppPalette.gold),
                const SizedBox(width: 2),
                Text(rating.toStringAsFixed(1), style: AppText.label.copyWith(fontSize: 12)),
                const SizedBox(width: 8),
              ],
              if (showPrice) Flexible(child: _PriceText(book)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _PriceText extends StatelessWidget {
  final Map book;

  const _PriceText(this.book);

  @override
  Widget build(BuildContext context) {
    final owned = book['has_access'] == true || book['in_library'] == true;
    final free = book['is_free'] == true;
    return Text(
      owned ? 'Sizda bor' : (free ? 'Bepul' : formatMoney(book['price'])),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.label.copyWith(fontSize: 12.5, color: owned ? AppPalette.brand : (free ? AppPalette.success : AppPalette.ink)),
    );
  }
}

/// Horizontal list row of a book (search results, admin lists).
class BookRow extends StatelessWidget {
  final Map book;
  final VoidCallback onTap;
  final Widget? trailing;
  final Widget? badge;

  const BookRow({super.key, required this.book, required this.onTap, this.trailing, this.badge});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            BookCover(book: book, width: 58, height: 86),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bookTitle.copyWith(fontSize: 15.5)),
                  const SizedBox(height: 3),
                  Text((book['author_name'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(fontSize: 13)),
                  const SizedBox(height: 8),
                  badge ?? PriceTag(book),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// White rounded card container.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppPalette.line)),
        child: child,
      );
}

class MenuTile extends StatelessWidget {
  final String icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final Widget? trailingWidget;
  final bool danger;
  final VoidCallback onTap;

  const MenuTile({super.key, required this.icon, required this.title, required this.onTap, this.subtitle, this.trailing, this.trailingWidget, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppPalette.danger : AppPalette.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: danger ? AppPalette.dangerSoft : AppPalette.brandSoft, borderRadius: BorderRadius.circular(11)),
              child: Center(child: AppIcon(icon, size: 18, color: danger ? AppPalette.danger : AppPalette.brand)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppText.body.copyWith(color: color, fontWeight: FontWeight.w500)),
                if (subtitle != null) Text(subtitle!, style: AppText.caption),
              ]),
            ),
            if (trailingWidget != null) trailingWidget!,
            if (trailing != null) Text(trailing!, style: AppText.caption.copyWith(fontSize: 13)),
            if (!danger) ...[const SizedBox(width: 6), const AppIcon('chevron-right', size: 18, color: AppPalette.muted)],
          ],
        ),
      ),
    );
  }
}

class MenuGroup extends StatelessWidget {
  final List<Widget> children;

  const MenuGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppPalette.line)),
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(indent: 64), children[i]],
      ]),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? icon;
  final Color color;

  const StatTile({super.key, required this.label, required this.value, this.icon, this.color = AppPalette.brand});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: AppIcon(icon!, size: 17, color: color),
            ),
            const SizedBox(height: 10),
          ],
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: AppText.title.copyWith(fontFamily: AppFonts.ui, fontSize: 20))),
          const SizedBox(height: 2),
          Text(label, style: AppText.caption, maxLines: 2),
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final String name;
  final String? url;
  final double size;

  const Avatar({super.key, required this.name, this.url, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).take(2).map((s) => s[0].toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppPalette.brandMid, AppPalette.brand])),
      alignment: Alignment.center,
      child: url != null
          ? Image.network(url!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _letters(initials))
          : _letters(initials),
    );
  }

  Widget _letters(String initials) => Text(initials.isEmpty ? '?' : initials, style: TextStyle(fontFamily: AppFonts.book, fontSize: size * 0.38, fontWeight: FontWeight.w700, color: Colors.white));
}

/// Confirmation dialog in the app style.
Future<bool> confirm(BuildContext context, {required String title, required String text, String ok = 'Tasdiqlash', bool danger = false, String? icon}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: icon != null ? AppIcon(icon, size: 28, color: danger ? AppPalette.danger : AppPalette.brand) : null,
      title: Text(title, textAlign: TextAlign.center),
      content: Text(text, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Bekor qilish')),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          style: FilledButton.styleFrom(minimumSize: const Size(120, 46), backgroundColor: danger ? AppPalette.danger : null),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r == true;
}

/// Asks for a short text (rejection reason, payout reference...).
Future<String?> askText(BuildContext context, {required String title, String? hint, String ok = 'Saqlash', bool required = true, int maxLines = 3, String? initial, TextInputType? keyboard}) async {
  final ctrl = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, autofocus: true, keyboardType: keyboard, maxLines: maxLines, minLines: 1, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Bekor')),
        FilledButton(
          onPressed: () {
            if (required && ctrl.text.trim().isEmpty) return;
            Navigator.pop(c, ctrl.text.trim());
          },
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r;
}
