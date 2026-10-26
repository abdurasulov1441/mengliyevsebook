import 'package:flutter/foundation.dart';
import 'package:mengliyevsebook/core/api.dart';
import 'package:mengliyevsebook/services/db/cache.dart';

/// Who is using the app: a guest (user == null) or a signed-in user with
/// their author profile and admin flag. Screens listen to it.
class Session extends ChangeNotifier {
  Session._();
  static final Session instance = Session._();

  Map<String, dynamic>? user;
  bool ready = false;

  bool get loggedIn => user != null;
  bool get isAdmin => user?['is_admin'] == true;
  bool get isAuthor => user?['is_author'] == true;
  Map<String, dynamic>? get author => user?['author'] as Map<String, dynamic>?;
  int get unread => (user?['unread_notifications'] as num?)?.toInt() ?? 0;
  String get name => (user?['name'] as String?)?.trim().isNotEmpty == true ? user!['name'] : 'Kitobxon';

  Future<void> restore() async {
    api.onSessionExpired = () {
      user = null;
      notifyListeners();
    };
    if (api.hasSession) {
      try {
        user = Map<String, dynamic>.from(await api.get('/api/me'));
      } on ApiException catch (e) {
        if (e.unauthorized) await api.clearTokens();
        // Offline: keep the last known profile so the library still opens.
        final saved = cache.getMap('session_user');
        if (!e.unauthorized && saved != null) user = saved;
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> signedIn(Map data) async {
    await api.saveTokens(data['accessToken'], data['refreshToken']);
    setUser(Map<String, dynamic>.from(data['user']));
  }

  void setUser(Map<String, dynamic> u) {
    user = u;
    cache.setMap('session_user', u);
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!api.hasSession) return;
    try {
      setUser(Map<String, dynamic>.from(await api.get('/api/me')));
    } catch (_) {}
  }

  Future<void> logout() async {
    final refresh = api.refreshToken;
    if (refresh != null) api.post('/api/auth/logout', {'refreshToken': refresh}).catchError((_) => null);
    await api.clearTokens();
    await cache.remove('session_user');
    user = null;
    notifyListeners();
  }
}

final session = Session.instance;
