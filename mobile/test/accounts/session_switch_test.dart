import 'dart:convert';

import 'package:bu_kampus/core/accounts/account_store.dart';
import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/app_hooks.dart';
import 'package:bu_kampus/core/secure_store.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

String _b64(String s) => base64Url.encode(utf8.encode(s)).replaceAll('=', '');
String _jwt(int id) => '${_b64('{"alg":"none"}')}.${_b64('{"sub":"$id"}')}.sig';

/// /auth/me yanıtı Bearer jetonundaki kullanıcıya göre döner.
FakeBackend _backend() {
  final b = FakeBackend();
  b.handlers.add((req, path) {
    if (path != '/auth/me') return null;
    final auth = req.headers['Authorization'] ?? '';
    final id = RegExp(r'"sub":"(\d+)"').firstMatch(utf8.decode(base64Url.decode(base64Url.normalize(auth.split('.')[1]))))?.group(1);
    return FakeResult.json({'id': int.parse(id!), 'displayName': 'Kullanici $id', 'email': 'k$id@gmail.com'});
  });
  return b;
}

class _Ctx {
  _Ctx(this.b, this.s, this.order);
  final FakeBackend b;
  final Session s;
  final List<String> order;
}

/// Hesap 1 etkin (sahte oturum), hesap 2 (ve istenirse 3) kayitli.
Future<_Ctx> _setup({int extra = 1, bool hooks = true}) async {
  mockSecureStorage();
  final b = _backend();
  final s = Session(ApiClient(client: b.client, retryDelay: Duration.zero), accounts: AccountStore(kv: MemoryAccountKv()));
  final order = <String>[];
  await s.accounts.upsert(1, Tokens(_jwt(1), 'r1'), displayName: 'Ayse');
  for (var i = 2; i <= 1 + extra; i++) {
    await s.accounts.upsert(i, Tokens(_jwt(i), 'r$i'), displayName: 'Hesap $i');
  }
  await s.accounts.setActive(1);
  s.api.tokens = Tokens(_jwt(1), 'r1');
  s.state = SessionState.signedIn;
  s.userId = 1;
  s.displayName = 'Ayse';
  if (hooks) {
    // push cihaz kaydi: eski hesaptan sil (cikis kancasi, eski jeton gecerliyken) -> yeni hesaba kaydet (giris kancasi).
    s.beforeSignOut.add(() async => order.add('push-unregister:${s.api.tokens?.refresh}'));
    s.api.onUserDataCleared.add(() async => order.add('user-data-cleared'));
  }
  return _Ctx(b, s, order);
}

Future<void> _drain() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  test('hesap degistirme: sunucuda cikis YOK, jeton takasi, temizleyiciler, kabuk nesli artar', () async {
    final c = await _setup();
    final s = c.s;
    final r = await s.switchAccount(2);
    await _drain();
    expect(r, SwitchResult.switched);
    expect(s.userId, 2);
    expect(s.api.tokens!.refresh, 'r2');
    expect(s.state, SessionState.signedIn);
    expect(s.accountEpoch, 1);
    expect(s.accounts.activeId, 2);
    expect(c.b.count('/auth/logout'), 0);
    expect(c.order, containsAllInOrder(['push-unregister:r1', 'user-data-cleared']));
    // Eski hesabin belirtecleri deposunda kalir (cikis yapilmadi).
    expect(s.accounts.tokensOf(1)!.refresh, 'r1');
    expect(s.accounts.byId(1)!.expired, isFalse);
    // Yeni hesabin /auth/me istegi YENI jetonla atildi.
    expect(c.b.requests.where((q) => q == 'GET /auth/me').length, greaterThanOrEqualTo(1));
    expect(s.displayName, 'Kullanici 2');
  });

  test('push sirasi: eski hesaptan kayit silinir, SONRA yeni hesaba kaydedilir (kanca tekrar oynatma)', () async {
    final c = await _setup();
    final s = c.s;
    final hooks = AppLifecycleHooks.instance;
    hooks.attach(s);
    SessionHook? signedIn;
    signedIn = (x) => c.order.add('push-register:${x.api.tokens?.refresh}');
    hooks.onSignedIn.add(signedIn);
    addTearDown(() => hooks.onSignedIn.remove(signedIn));
    c.order.clear();
    await s.switchAccount(2);
    await _drain();
    final iUn = c.order.indexOf('push-unregister:r1');
    final iReg = c.order.indexOf('push-register:r2');
    expect(iUn, greaterThanOrEqualTo(0));
    expect(iReg, greaterThan(iUn));
  });

  test('oturumu dolmus hesap: gecis reddedilir (needsLogin), etkin oturum degismez', () async {
    final c = await _setup();
    await c.s.accounts.markExpired(2);
    final r = await c.s.switchAccount(2);
    expect(r, SwitchResult.needsLogin);
    expect(c.s.userId, 1);
    expect(c.s.api.tokens!.refresh, 'r1');
    expect(c.b.count('/auth/logout'), 0);
    expect(c.s.accounts.byId(1)!.expired, isFalse);
  });

  test('cikis yalniz ETKIN hesabi cikarir ve baska hesaba otomatik gecer', () async {
    final c = await _setup();
    final s = c.s;
    await s.signOut();
    await _drain();
    expect(c.b.bodies['POST /auth/logout'], {'refreshToken': 'r1'});
    expect(c.b.count('/auth/logout'), 1);
    expect(s.accounts.has(1), isFalse);
    expect(s.accounts.has(2), isTrue);
    expect(s.userId, 2);
    expect(s.state, SessionState.signedIn);
    expect(s.api.tokens!.refresh, 'r2');
  });

  test('tek hesap varken cikis giris ekranina doner ve liste bosalir', () async {
    final c = await _setup(extra: 0);
    await c.s.signOut();
    expect(c.s.state, SessionState.signedOut);
    expect(c.s.api.tokens, isNull);
    expect(c.s.accounts.accounts, isEmpty);
    expect(c.s.userId, isNull);
  });

  test('tum hesaplardan cik: her hesabin oturumu sunucuda kapanir, liste temizlenir', () async {
    final c = await _setup(extra: 2);
    await c.s.signOutAll();
    expect(c.b.count('/auth/logout'), 3);
    final sent = c.b.bodyLog['POST /auth/logout']!.map((e) => (e as Map)['refreshToken']).toSet();
    expect(sent, {'r1', 'r2', 'r3'});
    expect(c.s.state, SessionState.signedOut);
    expect(c.s.accounts.accounts, isEmpty);
  });

  test('etkin olmayan hesabi kaldirmak yalniz onun oturumunu kapatir', () async {
    final c = await _setup(extra: 2);
    await c.s.removeAccount(3);
    expect(c.b.bodies['POST /auth/logout'], {'refreshToken': 'r3'});
    expect(c.s.accounts.has(3), isFalse);
    expect(c.s.userId, 1);
    expect(c.s.accounts.has(2), isTrue);
  });

  test('etkin hesabin refresh i iptal (401): hesap "oturum doldu" isaretlenir, digeri etkilenmez, baska hesaba gecilir', () async {
    final c = await _setup();
    final s = c.s;
    await s.forceSignOut();
    await _drain();
    expect(s.accounts.byId(1)!.expired, isTrue);
    expect(s.accounts.tokensOf(1), isNull);
    expect(s.accounts.byId(2)!.expired, isFalse);
    expect(s.userId, 2);
    expect(s.state, SessionState.signedIn);
    expect(s.accountNotice.value, 'Ayse');
  });

  test('tek hesap ve oturumu doldu: giris ekranina doner, hesap listede isaretli kalir', () async {
    final c = await _setup(extra: 0);
    await c.s.forceSignOut();
    expect(c.s.state, SessionState.signedOut);
    expect(c.s.accounts.byId(1)!.expired, isTrue);
  });

  test('yeni hesap girisi (hesap ekle): mevcut hesap cikis yapilmadan birakilir, yeni hesap etkin olur', () async {
    final c = await _setup(extra: 0);
    final s = c.s;
    c.b.on('/auth/login', {'accessToken': _jwt(9), 'refreshToken': 'r9'});
    final ch = await s.login('yeni@gmail.com', 'Sifre123');
    await _drain();
    expect(ch, isNull);
    expect(s.userId, 9);
    expect(s.api.tokens!.refresh, 'r9');
    expect(s.accounts.has(1), isTrue);
    expect(s.accounts.has(9), isTrue);
    expect(s.accounts.activeId, 9);
    expect(s.accountEpoch, 1);
    expect(c.b.count('/auth/logout'), 0);
    expect(c.order, containsAllInOrder(['push-unregister:r1', 'user-data-cleared']));
    expect(s.accounts.tokensOf(1)!.refresh, 'r1');
  });

  test('cihaz siniri: 6. hesap eklenemez, sunucudaki yeni oturum kapatilir, etkin hesap korunur', () async {
    final c = await _setup(extra: 4); // 5 hesap
    final s = c.s;
    c.b.on('/auth/login', {'accessToken': _jwt(6), 'refreshToken': 'r6'});
    await expectLater(s.login('x@gmail.com', 'Sifre123'), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'ACCOUNT_LIMIT')));
    expect(c.b.bodies['POST /auth/logout'], {'refreshToken': 'r6'});
    expect(s.userId, 1);
    expect(s.api.tokens!.refresh, 'r1');
    expect(s.accounts.accounts.length, 5);
  });

  test('ayni hesaba yeniden giris yeni hesap ya da onbellek temizligi uretmez', () async {
    final c = await _setup(extra: 0);
    c.b.on('/auth/login', {'accessToken': _jwt(1), 'refreshToken': 'r1b'});
    await c.s.login('a@gmail.com', 'Sifre123');
    await _drain();
    expect(c.s.accounts.accounts.length, 1);
    expect(c.s.accountEpoch, 0);
    expect(c.s.accounts.tokensOf(1)!.refresh, 'r1b');
  });

  test('yenilenen jeton cifti hesap deposuna yansir (gecis sonrasi eski jeton kullanilmaz)', () async {
    final c = await _setup();
    final s = c.s;
    c.b.on('/auth/refresh', {'accessToken': _jwt(1), 'refreshToken': 'r1-rot'});
    await s.api.refresh();
    await _drain();
    expect(s.accounts.tokensOf(1)!.refresh, 'r1-rot');
  });

  test('restore: etkin jeton anahtari yoksa etkin hesabin kayitli jetonlariyla acilir', () async {
    mockSecureStorage();
    for (final k in ['access', 'refresh', 'signed_out']) {
      await kDeviceSecureStorage.delete(key: k);
    }
    final kv = MemoryAccountKv();
    final seed = AccountStore(kv: kv);
    await seed.upsert(4, Tokens(_jwt(4), 'r4'), displayName: 'Dort');
    await seed.setActive(4);
    final b = _backend();
    final s = Session(ApiClient(client: b.client, retryDelay: Duration.zero), accounts: AccountStore(kv: kv));
    await s.restore();
    await _drain();
    expect(s.state, SessionState.signedIn);
    expect(s.userId, 4);
    expect(s.api.tokens!.refresh, 'r4');
  });
}
