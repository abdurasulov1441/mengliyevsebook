import 'package:flutter/material.dart';
import 'package:mengliyevsebook/core/session.dart';
import 'package:mengliyevsebook/features/onboarding/onboarding_screen.dart';
import 'package:mengliyevsebook/features/shell/main_shell.dart';
import 'package:mengliyevsebook/services/db/cache.dart';
import 'package:mengliyevsebook/theme/app_theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class BookHubApp extends StatelessWidget {
  const BookHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BookHub',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.light(),
      home: const _Root(),
    );
  }
}

/// Splash -> onboarding (first launch) -> main shell. Guests can browse; the
/// sign-in sheet appears when an action needs an account.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _onboarded = cache.getBool('onboarded') == true;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (!session.ready) return const _Splash();
        if (!_onboarded) {
          return OnboardingScreen(onDone: () {
            cache.setBool('onboarded', true);
            setState(() => _onboarded = true);
          });
        }
        return const MainShell();
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', width: 96, height: 96),
            const SizedBox(height: 16),
            const Text('BookHub', style: TextStyle(fontFamily: AppFonts.book, fontSize: 30, fontWeight: FontWeight.w700, color: AppPalette.brand)),
          ],
        ),
      ),
    );
  }
}
