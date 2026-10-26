import 'session.dart';

typedef SessionHook = void Function(Session session);

/// Oturum geçişlerinde (signedIn/signedOut) çağrılan kancalar.
/// Örn. PushService kendini `AppLifecycleHooks.instance.onSignedIn.add(...)` ile ekler.
class AppLifecycleHooks {
  AppLifecycleHooks._();
  static final AppLifecycleHooks instance = AppLifecycleHooks._();

  final List<SessionHook> onSignedIn = [];
  final List<SessionHook> onSignedOut = [];

  SessionState? _last;
  Session? _attached;

  /// Session dinleyicisi bağlar; yalnızca durum değişince kancaları çağırır.
  void attach(Session session) {
    if (identical(_attached, session)) return;
    _attached = session;
    _last = null;
    session.addListener(() => _check(session));
    _check(session);
  }

  void _check(Session s) {
    final st = s.state;
    if (st == _last || st == SessionState.loading) return;
    _last = st;
    final list = st == SessionState.signedIn ? onSignedIn : onSignedOut;
    for (final h in List.of(list)) {
      try {
        h(s);
      } catch (_) {
        // Bir kanca hatası diğerlerini ve uygulamayı etkilemez.
      }
    }
  }
}
