import 'package:flutter/material.dart';

abstract final class Constants {
  static const double leftPadding = 34;
  // Backend address. For a local backend on an Android emulator use
  // 'http://10.0.2.2:3000', on a real phone the PC's LAN IP.
  static const baseUrl = String.fromEnvironment('API_URL', defaultValue: 'https://etimolog.uz');
  static const callCenter = '+998900961704';

  /// Uploaded files (covers, author photos, receipts) come as "/covers/x.jpg".
  static String? fileUrl(dynamic path) {
    if (path == null || path.toString().isEmpty) return null;
    final p = path.toString();
    if (p.startsWith('http')) return p;
    return p.startsWith('/_files') ? '$baseUrl$p' : '$baseUrl/_files$p';
  }

  static const ofertaLink = 'https://insurance.uz/ru/terms-of-use';

  static const numberCharacter = '№';

  static const localeLa = Locale('uz');
  static const localeUz = Locale('uk');
  static const localeRu = Locale('ru');
  static const userImage =
      'https://avatars.mds.yandex.net/get-yapic/40138/PNspbnuWIoYTTeBboPewZIG6PU-1574216359/orig';
}
