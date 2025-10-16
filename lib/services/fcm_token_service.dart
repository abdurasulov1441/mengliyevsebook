import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mengliyevsebook/services/db/cache.dart';

class FcmService {
  static Future<String?> getOrCreateToken() async {
    String? cached = cache.getString('fcm_token');
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await cache.setString('fcm_token', token);
        return token;
      }
    } catch (e) {
      print('Ошибка получения FCM токена: $e');
    }
    return null;
  }

  static Future<void> deleteToken() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
      await cache.remove('fcm_token');
    } catch (e) {
      print('Ошибка удаления токена: $e');
    }
  }
}
