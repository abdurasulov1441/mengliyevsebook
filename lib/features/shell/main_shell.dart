import 'package:flutter/material.dart';
import 'package:mengliyevsebook/features/catalog/catalog_screen.dart';
import 'package:mengliyevsebook/features/home/home_screen.dart';
import 'package:mengliyevsebook/features/library/library_screen.dart';
import 'package:mengliyevsebook/features/profile/profile_screen.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';
import 'package:mengliyevsebook/widgets/app_icon.dart';

/// Lets any screen switch tabs (e.g. "see all" -> catalog with a filter).
class ShellNav {
  static final tab = ValueNotifier<int>(0);
  static final catalogQuery = ValueNotifier<CatalogQuery?>(null);

  static void openCatalog([CatalogQuery? q]) {
    catalogQuery.value = q ?? const CatalogQuery();
    tab.value = 1;
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const _tabs = [
    ('house', 'Asosiy'),
    ('compass', 'Katalog'),
    ('library-big', 'Kutubxona'),
    ('circle-user', 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ShellNav.tab,
      builder: (context, index, _) => PopScope(
        // Back on another tab goes to Home first.
        canPop: index == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) ShellNav.tab.value = 0;
        },
        child: Scaffold(
          body: IndexedStack(
            index: index,
            children: const [HomeScreen(), CatalogScreen(), LibraryScreen(), ProfileScreen()],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AppPalette.surface,
              border: const Border(top: BorderSide(color: AppPalette.line)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, -4))],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: InkWell(
                        onTap: () => ShellNav.tab.value = i,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                            decoration: BoxDecoration(color: i == index ? AppPalette.brandSoft : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                            child: AppIcon(_tabs[i].$1, size: 22, color: i == index ? AppPalette.brand : AppPalette.muted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _tabs[i].$2,
                            style: AppText.caption.copyWith(fontSize: 11.5, color: i == index ? AppPalette.brand : AppPalette.muted, fontWeight: i == index ? FontWeight.w700 : FontWeight.w500),
                          ),
                        ]),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
