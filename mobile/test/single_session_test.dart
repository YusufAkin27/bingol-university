import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

const _notice = 'Hesabına başka bir cihazdan giriş yapıldı. Güvenliğin için bu cihazdaki oturum kapatıldı.';

Widget _app(Session s) => MaterialApp(
      navigatorKey: rootNavigatorKey,
      theme: BuTheme.light(),
      home: ListenableBuilder(
        listenable: s,
        builder: (_, __) => s.state == SessionState.signedIn
            ? Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => s.api.get('/news').catchError((_) {}),
                    child: const Text('ANA'),
                  ),
                ),
              )
            : LoginPage(session: s),
      ),
    );

void _replaced(FakeBackend b, String path) =>
    b.fail(path, status: 401, code: 'SESSION_REPLACED', message: 'Hesabınıza başka bir cihazdan giriş yapıldı.');

Session _signedIn(FakeBackend b) {
  final s = makeSession(b);
  s.api.tokens = Tokens('acc', 'ref');
  return s;
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('401 SESSION_REPLACED: girise doner, bilgi bandi, tokenlar temiz, yeniden deneme yok', (tester) async {
    final b = FakeBackend();
    _replaced(b, '/news');
    final s = _signedIn(b);
    await tester.pumpWidget(_app(s));
    expect(find.text('ANA'), findsOneWidget);

    await tester.tap(find.text('ANA'));
    await tester.pumpAndSettle();

    expect(s.state, SessionState.signedOut);
    expect(s.api.tokens, isNull);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text(_notice), findsOneWidget);
    expect(b.count('/auth/refresh'), 0);
    expect(b.count('GET /news'), 1);
    expect(b.count('DELETE /devices'), 0);

    // Bilgi bandi bir kez: kapatinca gider ve geri gelmez.
    await tester.tap(find.byKey(const ValueKey('replaced-notice-close')));
    await tester.pumpAndSettle();
    expect(find.text(_notice), findsNothing);
    await s.forceSignOut(reason: SignOutReason.replaced);
    await tester.pumpAndSettle();
    expect(find.text(_notice), findsNothing);
  });

  testWidgets('refresh sirasinda SESSION_REPLACED: bilgi bandi, istek tekrarlanmaz', (tester) async {
    final b = FakeBackend();
    b.fail('/news', status: 401, code: 'TOKEN_EXPIRED');
    _replaced(b, '/auth/refresh');
    final s = _signedIn(b);
    await tester.pumpWidget(_app(s));
    await tester.tap(find.text('ANA'));
    await tester.pumpAndSettle();
    expect(s.state, SessionState.signedOut);
    expect(find.text(_notice), findsOneWidget);
    expect(b.count('GET /news'), 1);
    expect(b.count('POST /auth/refresh'), 1);
  });

  testWidgets('eszamanli 401lerde tek signOut', (tester) async {
    final b = FakeBackend();
    _replaced(b, '/a');
    _replaced(b, '/b');
    _replaced(b, '/c');
    final s = _signedIn(b);
    var signedOutCount = 0;
    SessionState? last;
    s.addListener(() {
      if (s.state == SessionState.signedOut && last != SessionState.signedOut) signedOutCount++;
      last = s.state;
    });
    await tester.pumpWidget(_app(s));
    final fs = [s.api.get('/a'), s.api.get('/b'), s.api.get('/c')]
        .map((Future<dynamic> f) => f.then<Object?>((_) => null, onError: (Object e) => e));
    await tester.runAsync(() => Future.wait(fs));
    await tester.pumpAndSettle();
    expect(signedOutCount, 1);
    expect(find.text(_notice), findsOneWidget);
    expect(s.api.tokens, isNull);
  });

  testWidgets('STOMP session-replaced olayi oturumu kapatir', (tester) async {
    final b = FakeBackend();
    final s = _signedIn(b);
    await tester.pumpWidget(_app(s));
    s.realtime!.debugEmitMessageEvent({'type': 'session-replaced', 'at': 'x'});
    await tester.pumpAndSettle();
    expect(s.state, SessionState.signedOut);
    expect(s.api.tokens, isNull);
    expect(find.text(_notice), findsOneWidget);
    expect(s.realtime!.isConnected, isFalse);
  });

  testWidgets('oturumsuzken gelen SESSION_REPLACED yok sayilir', (tester) async {
    final b = FakeBackend();
    final s = makeSession(b, signedIn: false);
    s.state = SessionState.signedOut;
    await tester.pumpWidget(_app(s));
    await s.forceSignOut(reason: SignOutReason.replaced);
    s.realtime!.debugEmitMessageEvent({'type': 'session-replaced'});
    await tester.pumpAndSettle();
    expect(find.text(_notice), findsNothing);
    expect(s.replacedNotice.value, isFalse);
  });

  testWidgets('login/verify/reset govdesinde client: mobile', (tester) async {
    final b = FakeBackend();
    b.on('/auth/login', {'accessToken': 'a', 'refreshToken': 'r'});
    b.on('/auth/verify-email', {'accessToken': 'a', 'refreshToken': 'r'});
    final s = makeSession(b, signedIn: false);
    await tester.runAsync(() async {
      await s.login('ayse@bingol.edu.tr', 'sifre123');
      expect((b.bodies['POST /auth/login'] as Map)['client'], 'mobile');
      await s.verifyEmail('ayse@bingol.edu.tr', '123456');
      expect((b.bodies['POST /auth/verify-email'] as Map)['client'], 'mobile');
      await s.resetPassword('ayse@bingol.edu.tr', 'tok', 'yeniSifre1');
      expect((b.bodies['POST /auth/reset-password'] as Map)['client'], 'mobile');
    });
    expect(s.state, SessionState.signedIn);
  });

  testWidgets('baska 401 kodlari (TOKEN_EXPIRED) mevcut refresh davranisini korur', (tester) async {
    final b = FakeBackend();
    final s = _signedIn(b);
    b.on('/auth/refresh', {'accessToken': 'a2', 'refreshToken': 'r2'});
    b.fail('/data', status: 401, code: 'TOKEN_EXPIRED');
    final r = await tester.runAsync(() => s.api.get('/data').then<Object?>((_) => 'ok', onError: (Object e) => e));
    expect(b.count('POST /auth/refresh'), 1);
    expect(r, isA<ApiError>());
    expect(s.api.tokens?.access, 'a2');
    expect(s.replacedNotice.value, isFalse);
  });

  testWidgets('acilista saklanan refresh SESSION_REPLACED: bilgi bandi', (tester) async {
    final b = FakeBackend();
    b.fail('/auth/me', status: 401, code: 'TOKEN_EXPIRED');
    _replaced(b, '/auth/refresh');
    final s = makeSession(b, signedIn: false);
    await tester.pumpWidget(_app(s));
    await tester.runAsync(() async {
      const st = FlutterSecureStorage();
      await st.write(key: 'access', value: 'old');
      await st.write(key: 'refresh', value: 'oldr');
      await s.restore();
    });
    await tester.pumpAndSettle();
    expect(s.state, SessionState.signedOut);
    expect(find.text(_notice), findsOneWidget);
  });
}
