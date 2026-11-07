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
  int _lastEpoch = 0;
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
    if (st == SessionState.loading) return;
    final switched = st == SessionState.signedIn && _last == SessionState.signedIn && s.accountEpoch != _lastEpoch;
    if (st == _last && !switched) return;
    _last = st;
    _lastEpoch = s.accountEpoch;
    // Hesap geçişi (oturum açık kalır): önce eski hesabın çıkış kancaları, sonra yeni hesabın giriş kancaları.
    if (switched) _run(onSignedOut, s);
    _run(st == SessionState.signedIn ? onSignedIn : onSignedOut, s);
  }

  void _run(List<SessionHook> list, Session s) {
    for (final h in List.of(list)) {
      try {
        h(s);
      } catch (_) {
        // Bir kanca hatası diğerlerini ve uygulamayı etkilemez.
      }
    }
  }
}
