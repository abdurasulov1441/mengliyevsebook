import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mengliyevsebook/services/db/cache.dart';

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("📩 Фоновое сообщение: ${message.notification?.title}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isNotificationEnabled = true;

  Future<void> initNotifications() async {
    await _loadNotificationPreference();

    if (_isNotificationEnabled) {
      await _setupFirebaseMessaging();
      await _setupLocalNotifications();
    } else {
      debugPrint(
        "⚙️ Уведомления отключены пользователем, FCM не будет активен.",
      );
    }
  }

  Future<void> _loadNotificationPreference() async {
    _isNotificationEnabled = cache.getBool('isNotification') ?? true;
  }

  Future<void> _setupFirebaseMessaging() async {
    final FirebaseMessaging messaging = FirebaseMessaging.instance;

    final status = await Permission.notification.status;
    if (!status.isGranted) {
      final result = await Permission.notification.request();

      if (result.isPermanentlyDenied) {
        debugPrint('⚠️ Разрешение навсегда отклонено. Открываем настройки...');
        // openAppSettings();
        return;
      }

      if (!result.isGranted) {
        debugPrint('❌ Пользователь не дал разрешение.');
        return;
      }
    }

    debugPrint('✅ Разрешения получены.');

    // Push notifications are optional: a broken Firebase config (e.g. a
    // deleted API key -> FIS_AUTH_ERROR) or a device without Google Play
    // services must not stop the app.
    try {
      final token = await messaging.getToken();
      debugPrint("📲 FCM Token: $token");
      if (token != null) await cache.setString('fcm_token', token);
    } catch (e) {
      debugPrint(
        '⚠️ FCM token olinmadi (bildirishnomalarsiz davom etamiz): $e',
      );
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '📨 Получено сообщение в активном состоянии: ${message.notification?.title}',
      );
      if (_isNotificationEnabled) {
        _showLocalNotification(
          title: message.notification?.title ?? 'Yangi xabar',
          body: message.notification?.body ?? 'Нет описания',
        );
      }
    });

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        debugPrint('🔔 Уведомление нажато: ${response.payload}');
      },
    );

    debugPrint('📱 Локальные уведомления инициализированы.');
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    if (!_isNotificationEnabled) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'default_channel_id',
          'Основной канал',
          channelDescription:
              'Этот канал используется для уведомлений приложения',
          importance: Importance.high,
          priority: Priority.high,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotificationsPlugin.show(0, title, body, platformDetails);
  }
}
