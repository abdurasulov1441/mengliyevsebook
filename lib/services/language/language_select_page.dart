import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mengliyevsebook/services/db/cache.dart';
import 'package:mengliyevsebook/services/language/language_provider.dart';

Future<void> showLanguageBottomSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final List<Map<String, dynamic>> languages = [
    {'locale': const Locale('uz'), 'name': 'O‘zbekcha', 'flag': '🇺🇿'},
    {'locale': const Locale('ru'), 'name': 'Русский', 'flag': '🇷🇺'},
    {'locale': const Locale('uk'), 'name': 'Ўзбекча', 'flag': '🇺🇿'},
  ];

  await showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'select_language',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ).tr(),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              itemCount: languages.length,
              itemBuilder: (context, index) {
                final lang = languages[index];
                return GestureDetector(
                  onTap: () {
                    ref.read(languageProvider.notifier).state = lang['locale'];
                    context.setLocale(lang['locale']);
                    cache.setString('language', lang['locale'].languageCode);
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: context.locale == lang['locale']
                          ? Colors.blue.shade100
                          : Colors.white,
                      border: Border.all(
                        color: context.locale == lang['locale']
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      children: [
                        ClipOval(
                          child: Container(
                            color: Colors.grey.shade200,
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              lang['flag'],
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          lang['name'],
                          style: TextStyle(
                            color: context.locale == lang['locale']
                                ? Colors.blue
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

class LanguageSelectionButton extends ConsumerWidget {
  const LanguageSelectionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(languageProvider);
    final String currentFlag = currentLocale == const Locale('uz')
        ? '🇺🇿'
        : currentLocale == const Locale('ru')
        ? '🇷🇺'
        : '🇺🇿';

    return GestureDetector(
      onTap: () => showLanguageBottomSheet(context, ref),
      child: CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        radius: 25,
        child: Text(currentFlag, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}
