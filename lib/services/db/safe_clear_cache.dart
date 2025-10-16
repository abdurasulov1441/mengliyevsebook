import 'package:mengliyevsebook/app/router.dart';
import 'package:mengliyevsebook/services/db/cache.dart';

Future<void> safeClearCache() async {
  final fcm = cache.getString('fcm_token');
  print(' fcm token: $fcm');
  await cache.clear();
  print('Cache cleared');
  if (fcm != null) {
    await cache.setString('fcm_token', fcm);
    print('FCM token restored: $fcm');
  }
  pragma('vm:entry-point');
  router.go(Routes.loginScreen);
}
