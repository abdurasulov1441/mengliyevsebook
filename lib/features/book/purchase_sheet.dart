import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/core/format.dart';
import 'package:mengliyevsebook/services/books/book_events.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:mengliyevsebook/widgets/book_cover.dart';
import 'package:mengliyevsebook/widgets/common.dart';
import 'package:url_launcher/url_launcher.dart';

/// Buying a paid book: creates an order, sends the user to Payme/Click (or a
/// demo payment) and waits until the server confirms the payment.
/// Returns true when the book is now owned.
Future<bool> showPurchaseSheet(BuildContext context, Map book) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PurchaseSheet(book: book),
  );
  return r == true;
}

class _PurchaseSheet extends StatefulWidget {
  final Map book;

  const _PurchaseSheet({required this.book});

  @override
  State<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends State<_PurchaseSheet> with WidgetsBindingObserver {
  Map? _order;
  Object? _error;
  String? _busy; // payme | click | demo | check
  bool _waiting = false; // user went to the payment page
  bool _paid = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createOrder();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from Payme/Click: check the payment.
    if (state == AppLifecycleState.resumed && _waiting && !_paid) _check(silent: true);
  }

  Future<void> _createOrder() async {
    try {
      final o = await api.post('/api/orders', {'book_id': widget.book['id']});
      if (mounted) setState(() => _order = o);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _pay(String method) async {
    final o = _order!;
    if (method == 'demo') {
      setState(() => _busy = 'demo');
      try {
        final r = await api.post('/api/orders/${o['id']}/demo-pay');
        _done(r);
      } catch (e) {
        if (mounted) toast(context, errorText(e), error: true);
      } finally {
        if (mounted) setState(() => _busy = null);
      }
      return;
    }
    final url = (o['checkout'] as Map?)?[method]?.toString();
    if (url == null) return;
    setState(() => _waiting = true);
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    // Some phones return without a lifecycle event: poll for a while too.
    _poll?.cancel();
    var n = 0;
    _poll = Timer.periodic(const Duration(seconds: 4), (t) {
      if (++n > 45 || _paid || !mounted) return t.cancel();
      _check(silent: true);
    });
  }

  Future<void> _check({bool silent = false}) async {
    if (_order == null) return;
    if (!silent) setState(() => _busy = 'check');
    try {
      final r = await api.get('/api/orders/${_order!['id']}');
      if (r['status'] == 'paid') {
        _done(r);
      } else if (!silent && mounted) {
        toast(context, "To'lov hali tasdiqlanmadi. Bir necha soniyadan keyin qayta tekshiring");
      }
    } catch (e) {
      if (!silent && mounted) toast(context, errorText(e), error: true);
    } finally {
      if (mounted && !silent) setState(() => _busy = null);
    }
  }

  void _done(dynamic order) {
    _poll?.cancel();
    notifyBooksChanged();
    if (mounted) setState(() => _paid = true);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: _paid ? _success() : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                BookCover(book: b, width: 60, height: 88),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bookTitle.copyWith(fontSize: 17)),
                    const SizedBox(height: 4),
                    Text((b['author_name'] ?? '').toString(), style: AppText.caption),
                    const SizedBox(height: 8),
                    Text(formatMoney(b['price']), style: AppText.title.copyWith(fontFamily: AppFonts.ui, fontSize: 20)),
                  ]),
                ),
              ]),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Text(errorText(_error!), style: AppText.body.copyWith(color: AppPalette.danger)),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Yopish')),
              ] else if (_order == null)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else ...[
                const Text("To'lov usulini tanlang", style: AppText.label),
                const SizedBox(height: 10),
                if ((_order!['checkout'] as Map?)?['payme'] != null)
                  _Method(name: 'Payme', color: const Color(0xFF00BAC7), subtitle: 'Uzcard, Humo, Visa', busy: false, onTap: () => _pay('payme')),
                if ((_order!['checkout'] as Map?)?['click'] != null)
                  _Method(name: 'Click', color: const Color(0xFF0099E5), subtitle: 'Uzcard, Humo', busy: false, onTap: () => _pay('click')),
                if (_order!['demo'] == true)
                  _Method(name: "Demo to'lov", color: AppPalette.brand, subtitle: "Sinov rejimi — haqiqiy pul yechilmaydi", icon: 'sparkles', busy: _busy == 'demo', onTap: () => _pay('demo')),
                if (_waiting) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy == 'check' ? null : () => _check(),
                    icon: const AppIcon('refresh-cw', size: 18),
                    label: const Text("To'lovni tekshirish"),
                  ),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  const AppIcon('lock', size: 14, color: AppPalette.muted),
                  const SizedBox(width: 6),
                  Expanded(child: Text("Karta ma'lumotlari faqat to'lov tizimida kiritiladi. BookHub ularni ko'rmaydi.", style: AppText.caption)),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _success() {
    return Column(
      key: const ValueKey('ok'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(color: AppPalette.successSoft, shape: BoxShape.circle),
          child: const Center(child: AppIcon('circle-check', size: 44, color: AppPalette.success)),
        ),
        const SizedBox(height: 16),
        const Text('Xarid muvaffaqiyatli!', style: AppText.title),
        const SizedBox(height: 6),
        Text("«${widget.book['title']}» kutubxonangizga qo'shildi", textAlign: TextAlign.center, style: AppText.bodySoft),
        const SizedBox(height: 22),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => Navigator.pop(context, true), icon: const AppIcon('book-open', size: 20, color: Colors.white), label: const Text("O'qishni boshlash"))),
      ],
    );
  }
}

class _Method extends StatelessWidget {
  final String name;
  final String subtitle;
  final Color color;
  final String? icon;
  final bool busy;
  final VoidCallback onTap;

  const _Method({required this.name, required this.subtitle, required this.color, required this.busy, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: busy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppPalette.line)),
            child: Row(children: [
              Container(
                width: 48,
                height: 34,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
                alignment: Alignment.center,
                child: icon != null
                    ? AppIcon(icon!, size: 18, color: Colors.white)
                    : Text(name.substring(0, 1), style: const TextStyle(fontFamily: AppFonts.ui, color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: AppText.caption),
                ]),
              ),
              busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : const AppIcon('chevron-right', size: 18, color: AppPalette.muted),
            ]),
          ),
        ),
      ),
    );
  }
}
