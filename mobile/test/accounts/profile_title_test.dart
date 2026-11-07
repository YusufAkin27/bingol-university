import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('profil basliginda kullanici adi + ▾: dokununca hesap sayfasi acilir', (tester) async {
    useScreen(tester, kPhoneSmall);
    final b = FakeBackend()
      ..on('/users/me', {'id': 1, 'displayName': 'Ayşe Kaya', 'username': 'ayse.kaya', 'email': 'ayse@gmail.com', 'postCount': 0, 'reelCount': 0})
      ..on('/users/1', {'id': 1, 'followerCount': 1, 'followingCount': 1, 'followedByMe': false});
    fakeCatalog(b);
    fakePosts(b, count: 0);
    final s = makeSession(b);
    await tester.runAsync(() async {
      await s.accounts.upsert(1, Tokens('a', 'r'), displayName: 'Ayşe Kaya');
      await s.accounts.setActive(1);
    });
    await tester.pumpWidget(buildApp(ProfileTab(session: s, themeController: ThemeController()), size: kPhoneSmall));
    await settle(tester, const Duration(seconds: 1));
    expect(find.text('@ayse.kaya'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-account-switch')));
    await settle(tester, const Duration(seconds: 1));
    expect(find.text('Hesaplar'), findsOneWidget);
    expect(find.text('Hesap ekle'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-active-1')), findsOneWidget);
    // Profil sekmesi acilinca kullanici adi hesap satirina yazilir.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    expect(s.accounts.byId(1)!.username, 'ayse.kaya');
    expect(tester.takeException(), isNull);
  });
}
