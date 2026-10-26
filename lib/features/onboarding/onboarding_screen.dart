import 'package:flutter/material.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;

  static const _slides = [
    ('library-big', "Minglab kitoblar\nbir ilovada", "O'zbek tilidagi ilmiy, o'quv va badiiy kitoblarni toping, parchasini bepul o'qing."),
    ('book-open', "Qulay o'qish\ninternetsiz ham", "Shrift, fon, varaqlash animatsiyasi, xatcho'p va belgilar — barchasi siz uchun sozlanadi."),
    ('pen-tool', "Muallif bo'ling\nva daromad oling", "Kitobingizni yuklang, moderatsiyadan o'tkazing va har oy sotuvdan daromad oling."),
  ];

  void _next() {
    if (_index == _slides.length - 1) return widget.onDone();
    _pages.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(children: [
                Image.asset('assets/images/logo.png', width: 34, height: 34),
                const SizedBox(width: 10),
                const Text('BookHub', style: TextStyle(fontFamily: AppFonts.book, fontSize: 22, fontWeight: FontWeight.w700, color: AppPalette.brand)),
                const Spacer(),
                TextButton(onPressed: widget.onDone, child: const Text("O'tkazib yuborish")),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 210,
                          height: 210,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [Color(0xFFDCE6FA), Color(0xFFF2F5FC)]),
                          ),
                          child: Center(
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: AppPalette.brand,
                                borderRadius: BorderRadius.circular(34),
                                boxShadow: [BoxShadow(color: AppPalette.brand.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 14))],
                              ),
                              child: Center(child: AppIcon(s.$1, size: 56, color: Colors.white)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 44),
                        Text(s.$2, textAlign: TextAlign.center, style: AppText.display.copyWith(fontSize: 30)),
                        const SizedBox(height: 16),
                        Text(s.$3, textAlign: TextAlign.center, style: AppText.bodySoft.copyWith(fontSize: 16, height: 1.5)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _index ? 26 : 8,
                          height: 8,
                          decoration: BoxDecoration(color: i == _index ? AppPalette.brand : AppPalette.line, borderRadius: BorderRadius.circular(4)),
                        ),
                    ],
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(minimumSize: const Size(150, 54)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_index == _slides.length - 1 ? 'Boshlash' : 'Keyingi'),
                      const SizedBox(width: 8),
                      const AppIcon('arrow-right', size: 18, color: Colors.white),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
