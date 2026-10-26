import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/core/format.dart';
import 'package:mengliyevsebook/core/session.dart';
import 'package:mengliyevsebook/features/auth/auth_flow.dart';
import 'package:mengliyevsebook/features/studio/studio_screen.dart';
import 'package:mengliyevsebook/services/utils/constants.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:mengliyevsebook/widgets/common.dart';

/// Author application for new authors, and the author profile editor
/// (name, bio, photo, payout card) for existing ones.
class BecomeAuthorScreen extends StatefulWidget {
  const BecomeAuthorScreen({super.key});

  @override
  State<BecomeAuthorScreen> createState() => _BecomeAuthorScreenState();
}

class _BecomeAuthorScreenState extends State<BecomeAuthorScreen> {
  late final Map? _profile = session.author;
  late final _name = TextEditingController(text: _profile?['display_name'] ?? session.user?['name'] ?? '');
  late final _bio = TextEditingController(text: _profile?['bio'] ?? '');
  late final _card = TextEditingController(text: CardFormatter.format(_profile?['card_number'] ?? ''));
  late final _holder = TextEditingController(text: _profile?['card_holder'] ?? '');
  XFile? _photo;
  bool _accept = false;
  bool _busy = false;
  Map? _rules;

  bool get _isNew => _profile == null;

  @override
  void initState() {
    super.initState();
    api.get('/api/studio/rules').then((r) {
      if (mounted) setState(() => _rules = Map.from(r));
    }).catchError((_) {});
  }

  Future<void> _save() async {
    if (!await requireLogin(context, reason: "Muallif bo'lish uchun hisobingizga kiring")) return;
    if (_name.text.trim().isEmpty) return _err('Muallif ismini kiriting');
    final card = _card.text.replaceAll(' ', '');
    if (card.isNotEmpty && card.length != 16) return _err("Karta raqami 16 ta raqamdan iborat bo'lishi kerak");
    if (_isNew && !_accept) return _err('Muallif shartlarini qabul qiling');
    setState(() => _busy = true);
    try {
      final form = FormData.fromMap({
        'display_name': _name.text.trim(),
        'bio': _bio.text.trim(),
        'card_number': card,
        'card_holder': _holder.text.trim(),
        if (_isNew) 'accept_terms': 'true',
        if (_photo != null) 'photo': await MultipartFile.fromFile(_photo!.path, filename: _photo!.name),
      });
      await api.upload('PUT', '/api/studio/profile', form);
      await session.refresh();
      if (!mounted) return;
      if (_isNew) {
        toast(context, 'Tabriklaymiz! Endi siz muallifsiz');
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StudioScreen()));
      } else {
        toast(context, 'Saqlandi');
        Navigator.pop(context, true);
      }
    } catch (e) {
      _err(errorText(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  void _err(String m) => toast(context, m, error: true);

  @override
  Widget build(BuildContext context) {
    final commission = _rules?['commission_percent'] ?? 30;
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? "Muallif bo'lish" : 'Muallif profili'), leading: AppIconButton('arrow-left', onTap: () => Navigator.pop(context))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          if (_isNew) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppPalette.brand, AppPalette.brandMid], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const AppIcon('rocket', size: 30, color: Colors.white),
                const SizedBox(height: 12),
                Text('Kitobingizni minglab kitobxonlarga yetkazing', style: AppText.title.copyWith(color: Colors.white)),
                const SizedBox(height: 14),
                for (final s in [
                  ('file-up', "Word (.docx), EPUB yoki TXT faylni yuklaysiz — o'qish uchun avtomatik tayyorlanadi"),
                  ('shield-check', "Moderator tekshiradi va kitob do'konda chiqadi"),
                  ('banknote', 'Har bir sotuvdan ${100 - (commission as num)}% sizga, $commission% platforma komissiyasi'),
                  ('calendar', _rules?['payout_schedule'] ?? "Har oy daromad kartangizga o'tkaziladi"),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      AppIcon(s.$1, size: 18, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(child: Text(s.$2, style: AppText.body.copyWith(color: Colors.white.withValues(alpha: 0.92), fontSize: 14.5))),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 22),
          ],
          Center(
            child: GestureDetector(
              onTap: () async {
                final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
                if (f != null) setState(() => _photo = f);
              },
              child: Stack(children: [
                _photo != null
                    ? ClipOval(child: Image.file(File(_photo!.path), width: 92, height: 92, fit: BoxFit.cover))
                    : Avatar(name: _name.text.isEmpty ? 'M' : _name.text, url: Constants.fileUrl(_profile?['photo']), size: 92),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: AppPalette.brand, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                    child: const AppIcon('camera', size: 15, color: Colors.white),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          const Center(child: Text('Muallif surati (ixtiyoriy)', style: AppText.caption)),
          const SizedBox(height: 20),
          _label('Muallif ismi', 'Kitob muqovasida va sahifangizda ko‘rinadi'),
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Masalan: Abdulla Qodiriy')),
          const SizedBox(height: 16),
          _label("O'zingiz haqingizda", 'Kitobxonlar sahifangizda o‘qiydi'),
          TextField(controller: _bio, minLines: 3, maxLines: 6, maxLength: 3000, decoration: const InputDecoration(hintText: 'Qisqacha tarjimai hol, yo‘nalishingiz…')),
          const SizedBox(height: 10),
          Row(children: [
            const Text("To'lov kartasi", style: AppText.section),
            const Spacer(),
            if (_profile != null)
              _profile['card_verified'] == true
                  ? const Chip2('Tasdiqlangan', icon: 'badge-check', color: AppPalette.success, background: AppPalette.successSoft)
                  : const Chip2('Tekshiruvda', icon: 'clock', color: AppPalette.warning, background: AppPalette.warningSoft),
          ]),
          const SizedBox(height: 4),
          const Text("Daromad shu kartaga o'tkaziladi. Karta administrator tomonidan tekshirilgach to'lovlar boshlanadi. Keyinroq ham kiritishingiz mumkin.", style: AppText.caption),
          const SizedBox(height: 12),
          TextField(
            controller: _card,
            keyboardType: TextInputType.number,
            inputFormatters: [CardFormatter()],
            decoration: const InputDecoration(hintText: '8600 0000 0000 0000', prefixIcon: Padding(padding: EdgeInsets.all(13), child: AppIcon('credit-card', size: 20, color: AppPalette.muted))),
          ),
          const SizedBox(height: 10),
          TextField(controller: _holder, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'Karta egasi (ISM FAMILIYA)')),
          if (_isNew) ...[
            const SizedBox(height: 18),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _accept = !_accept),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Checkbox(value: _accept, onChanged: (v) => setState(() => _accept = v == true), visualDensity: VisualDensity.compact),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        "Kitoblar menga tegishli yoki ularni tarqatish huquqiga egaman. Platforma komissiyasi $commission%, minimal to'lov ${formatMoney(_rules?['payout_min'] ?? 50000)}. Qoidalarni buzgan kitoblar olib tashlanadi.",
                        style: AppText.bodySoft.copyWith(fontSize: 14),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saqlanmoqda…' : _isNew ? "Muallif bo'lish" : 'Saqlash')),
        ],
      ),
    );
  }

  Widget _label(String title, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppText.label),
          Text(hint, style: AppText.caption),
        ]),
      );
}

/// "8600123412341234" -> "8600 1234 1234 1234".
class CardFormatter extends TextInputFormatter {
  static String format(String v) {
    final d = v.replaceAll(RegExp(r'\D'), '');
    final b = StringBuffer();
    for (var i = 0; i < d.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) b.write(' ');
      b.write(d[i]);
    }
    return b.toString();
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = format(newValue.text);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
