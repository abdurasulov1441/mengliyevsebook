import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mengliyevsebook/app/app.dart';
import 'package:mengliyevsebook/services/db/cache.dart';
import 'package:mengliyevsebook/services/firebase_notification.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');

    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    try {
      await FirebaseMessaging.instance.requestPermission();
      debugPrint('Firebase Messaging permission requested');
    } catch (e) {
      debugPrint('Firebase Messaging permission error: $e');
    }

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  try {
    await cache.init();
    debugPrint('Cache initialized successfully');
  } catch (e) {
    debugPrint('Cache initialization error: $e');
  }

  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    debugPrint('Orientation set successfully');
  } catch (e) {
    debugPrint('Orientation error: $e');
  }

  try {
    EasyLocalization.logger.enableBuildModes = [];
    await EasyLocalization.ensureInitialized();
    debugPrint('EasyLocalization initialized successfully');
  } catch (e) {
    debugPrint('EasyLocalization error: $e');
  }
  NotificationService().initNotifications();

  try {
    final prefs = await SharedPreferences.getInstance();
    final savedLocaleCode = prefs.getString('locale') ?? 'uz';
    debugPrint('Locale loaded: $savedLocaleCode');
    final initialLocale = ['uz', 'ru'].contains(savedLocaleCode)
        ? Locale(savedLocaleCode)
        : Locale('uz');

    runApp(
      ProviderScope(
        child: EasyLocalization(
          path: 'assets/translations',
          supportedLocales: const [Locale('uz'), Locale('ru'), Locale('uk')],
          saveLocale: true,
          startLocale: initialLocale,
          child: App(),
        ),
      ),
    );
  } catch (e) {
    debugPrint('Error starting app: $e');
  }
}
