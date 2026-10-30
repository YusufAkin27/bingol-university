import 'package:bu_kampus/core/api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

void main() {
  test('cikis istegi cihazin FCM jetonunu tasir (erisim jetonu bitmis olsa da sunucu kaydi siler)', () async {
    final b = FakeBackend()..on('/auth/logout', {});
    final s = makeSession(b);
    s.api.tokens = Tokens('access', 'refresh-1');
    s.pushToken = () => 'fcm-tok-1';
    // Kanca jetonu sifirlasa bile (PushService.onSignedOut) cikis istegi jetonu cikis baslamadan once okur.
    s.beforeSignOut.add(() async => s.pushToken = () => null);
    await s.signOut();
    expect(b.bodies['POST /auth/logout'], {'refreshToken': 'refresh-1', 'fcmToken': 'fcm-tok-1'});
  });

  test('jeton yoksa eski govde (yalniz refreshToken)', () async {
    final b = FakeBackend()..on('/auth/logout', {});
    final s = makeSession(b);
    s.api.tokens = Tokens('access', 'refresh-2');
    await s.signOut();
    expect(b.bodies['POST /auth/logout'], {'refreshToken': 'refresh-2'});
  });
}
