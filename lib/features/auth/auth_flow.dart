import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/core/session.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';
import 'package:mengliyevsebook/widgets/common.dart';

/// Makes sure there is a signed-in user; opens the SMS sign-in if needed.
/// Returns true when the user is signed in afterwards.
Future<bool> requireLogin(BuildContext context, {String? reason}) async {
  if (session.loggedIn) return true;
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => AuthFlow(reason: reason)));
  return ok == true && session.loggedIn;
}

class AuthFlow extends StatefulWidget {
  final String? reason;

  const AuthFlow({super.key, this.reason});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

enum _Step { phone, code, name }

class _AuthFlowState extends State<AuthFlow> {
  _Step _step = _Step.phone;
  final _phone = TextEditingController(text: '+998 ');
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _codeFocus = FocusNode();
  final _nameFocus = FocusNode();
  bool _busy = false;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _codeFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// Switches the step and opens the keyboard on its field once the
  /// switch animation has put it on screen.
  void _go(_Step step) {
    setState(() => _step = step);
    final focus = step == _Step.code ? _codeFocus : step == _Step.name ? _nameFocus : null;
    if (focus != null) Future.delayed(const Duration(milliseconds: 350), () => mounted ? focus.requestFocus() : null);
  }

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _resendIn <= 1) {
        t.cancel();
        if (mounted) setState(() => _resendIn = 0);
        return;
      }
      setState(() => _resendIn--);
    });
  }

  Future<void> _requestCode() async {
    if (_digits.length != 12) return toast(context, "Telefon raqamini to'liq kiriting", error: true);
    setState(() => _busy = true);
    try {
      final r = await api.post('/api/auth/request-otp', {'phone': _digits});
      _startTimer((r['resend_after'] as num?)?.toInt() ?? 60);
      _go(_Step.code);
    } catch (e) {
      if (mounted) toast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_code.text.length != 6) return;
    setState(() => _busy = true);
    try {
      final r = await api.post('/api/auth/verify', {'phone': _digits, 'code': _code.text});
      await session.signedIn(r);
      if (!mounted) return;
      if (session.user?['needs_name'] == true) {
        _go(_Step.name);
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _code.clear();
      if (mounted) toast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveName() async {
    final name = _name.text.trim();
    if (name.length < 2) return toast(context, 'Ismingizni kiriting', error: true);
    setState(() => _busy = true);
    try {
      final me = await api.put('/api/me', {'name': name});
      session.setUser(Map<String, dynamic>.from(me));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        leading: AppIconButton(_step == _Step.code ? 'arrow-left' : 'x', onTap: () {
          if (_step == _Step.code) {
            setState(() => _step = _Step.phone);
          } else {
            Navigator.pop(context, session.loggedIn);
          }
        }),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (_step) {
              _Step.phone => _phoneStep(),
              _Step.code => _codeStep(),
              _Step.name => _nameStep(),
            },
          ),
        ),
      ),
    );
  }

  Widget _title(String icon, String title, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppPalette.brandSoft, borderRadius: BorderRadius.circular(18)),
          child: AppIcon(icon, size: 28, color: AppPalette.brand),
        ),
        const SizedBox(height: 22),
        Text(title, style: AppText.display),
        const SizedBox(height: 8),
        Text(text, style: AppText.bodySoft.copyWith(fontSize: 15)),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _phoneStep() {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('smartphone', 'Kirish', widget.reason ?? "Telefon raqamingizni kiriting — SMS orqali tasdiqlash kodi yuboramiz. Hisob bo'lmasa, avtomatik yaratiladi."),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          autofocus: true,
          inputFormatters: [_UzPhoneFormatter()],
          style: AppText.body.copyWith(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          decoration: const InputDecoration(hintText: '+998 90 123 45 67', prefixIcon: Padding(padding: EdgeInsets.all(14), child: AppIcon('phone', size: 20, color: AppPalette.muted))),
          onSubmitted: (_) => _requestCode(),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _requestCode, child: _busy ? const _Spinner() : const Text('Kod olish')),
        const SizedBox(height: 18),
        Text(
          "Davom etish orqali siz BookHub foydalanish shartlari va maxfiylik siyosatiga rozilik bildirasiz.",
          textAlign: TextAlign.center,
          style: AppText.caption.copyWith(fontSize: 12.5),
        ),
      ],
    );
  }

  Widget _codeStep() {
    return Column(
      key: const ValueKey('code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('message-square', 'Kodni kiriting', '${_phone.text.trim()} raqamiga 6 xonali kod yuborildi.'),
        TextField(
          controller: _code,
          focusNode: _codeFocus,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontFamily: AppFonts.ui, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: 14),
          decoration: const InputDecoration(counterText: '', hintText: '••••••'),
          onChanged: (v) {
            if (v.length == 6) _verify();
          },
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _verify, child: _busy ? const _Spinner() : const Text('Tasdiqlash')),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _resendIn > 0 || _busy ? null : _requestCode,
          child: Text(_resendIn > 0 ? 'Qayta yuborish: ${_resendIn}s' : 'Kodni qayta yuborish'),
        ),
      ],
    );
  }

  Widget _nameStep() {
    return Column(
      key: const ValueKey('name'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('circle-user', 'Tanishib olaylik', "Ismingiz fikrlar va xaridlarda ko'rinadi."),
        TextField(
          controller: _name,
          focusNode: _nameFocus,
          textCapitalization: TextCapitalization.words,
          style: AppText.body.copyWith(fontSize: 18),
          decoration: const InputDecoration(hintText: 'Ism va familiya'),
          onSubmitted: (_) => _saveName(),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _saveName, child: _busy ? const _Spinner() : const Text('Davom etish')),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white));
}

/// "+998 90 123 45 67" while typing.
class _UzPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (!d.startsWith('998')) d = '998${d.length > 3 ? d.substring(3) : ''}';
    d = d.substring(0, min(12, d.length));
    final rest = d.substring(3);
    final b = StringBuffer('+998 ');
    for (var i = 0; i < rest.length; i++) {
      if (i == 2 || i == 5 || i == 7) b.write(' ');
      b.write(rest[i]);
    }
    final text = b.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
