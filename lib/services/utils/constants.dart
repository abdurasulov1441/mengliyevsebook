abstract final class Constants {
  static const appName = 'BookHub';

  // Backend address, set at build time:
  //   flutter run --dart-define=API_URL=http://192.168.1.10:3000   (real phone, PC on the same Wi-Fi)
  //   flutter build apk --dart-define=API_URL=https://api.example.uz
  // The default reaches a backend on this PC from the Android emulator.
  static const baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000');

  static const supportPhone = '+998900961704';

  /// Uploaded files (covers, author photos) come as "/covers/x.jpg".
  static String? fileUrl(dynamic path) {
    if (path == null || path.toString().isEmpty) return null;
    final p = path.toString();
    if (p.startsWith('http') || p.startsWith('asset:')) return p;
    return p.startsWith('/_files') ? '$baseUrl$p' : '$baseUrl/_files$p';
  }
}
