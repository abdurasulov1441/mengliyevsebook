import 'package:flutter/material.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';

class AudioScreen extends StatelessWidget {
  const AudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TINGLASH', style: AppText.overline),
              const SizedBox(height: 6),
              const Text('Audio kitoblar', style: AppText.display),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [AppPalette.brandSoft, Color(0xFFF3EBDD)]),
                        ),
                        child: const Center(child: AppIcon('headphones', size: 48, color: AppPalette.brand)),
                      ),
                      const SizedBox(height: 22),
                      const Text('Tez kunda', style: AppText.title),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          "Sevimli kitoblaringizni muallif ovozida tinglash imkoniyati ustida ishlayapmiz.",
                          textAlign: TextAlign.center,
                          style: AppText.bodySoft,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: AppPalette.goldSoft, borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const AppIcon('sparkles', size: 16, color: AppPalette.gold),
                          const SizedBox(width: 6),
                          Text('Yangi imkoniyat', style: AppText.label.copyWith(color: AppPalette.gold)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
