import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/follow/follow_list_page.dart';
import 'package:bu_kampus/features/follow/follow_summary.dart';
import 'package:bu_kampus/features/profile/account_security_page.dart';
import 'package:bu_kampus/features/profile/blocked_users_page.dart';
import 'package:bu_kampus/features/profile/edit_profile_page.dart';
import 'package:bu_kampus/features/profile/my_clubs_page.dart';
import 'package:bu_kampus/features/profile/privacy_data_page.dart';
import 'package:bu_kampus/features/profile/profil2_delete_account_page.dart';
import 'package:bu_kampus/features/profile/profil2_my_data_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/features/profile/user_profile_page.dart';
import 'package:bu_kampus/widgets/bu.dart' show BuCard, BuCountUp, LucideIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// Tur 3 (P3-PROFILE, minimal): Profil sekmesi tek sayac seridi, tek notr simge tonu, sakin cikis; duzenleme tek sutun;
/// takip satiri duzeni; tum profil ekranlari 3 dil x acik/koyu x 1.3 x 320 matrisinde tasmasiz.
FakeBackend _backend() => FakeBackend()
  ..on('/me/summary', {'communities': 3, 'events': 4, 'bookmarks': 12})
  ..on('/users/me', {
    'id': 1,
    'displayName': 'Ayşe Kaya',
    'email': 'ayse@bingol.edu.tr',
    'faculty': 'Mühendislik Fakültesi',
    'department': 'Bilgisayar Mühendisliği',
    'grade': '3',
    'bio': 'Yazılım ve satranç.',
    'showEmail': false,
  })
  ..on('/users/1', {'id': 1, 'followerCount': 128, 'followingCount': 94, 'followedByMe': false})
  ..on('/users/2', {
    'id': 2,
    'displayName': 'Mehmet Kaya',
    'faculty': 'Mühendislik Fakültesi',
    'department': 'Bilgisayar Mühendisliği',
    'classYear': 3,
    'bio': 'Merhaba.',
    'email': 'mehmet@bingol.edu.tr',
    'followerCount': 5,
    'followingCount': 1,
    'followedByMe': false,
  })
  ..on('/users/me/privacy', {
    'avatar': 'EVERYONE',
    'bio': 'SHARED_CONTEXT',
    'department': 'EVERYONE',
    'faculty': 'ONLY_ME',
    'classYear': 'SHARED_CONTEXT',
    'avatarHiddenByModeration': false,
  })
  ..on('/users/me/blocks*', [
    {'id': 40, 'displayName': 'Burak Çelik', 'department': 'Hukuk'}
  ])
  ..on('/users/7/followers*', {
    'items': [
      {'id': 11, 'displayName': 'Emre Yılmaz', 'department': 'Bilgisayar Mühendisliği', 'followedByMe': false, 'followsMe': true},
    ],
    'nextCursor': null,
    'total': 1,
  })
  ..on('/me/communities*', {
    'items': [
      {'id': 5, 'name': 'Satranç Kulübü', 'category': 'SOCIAL', 'memberCount': 40, 'myRole': 'ADMIN'},
    ],
    'nextCursor': null,
  });

Future<void> _open(WidgetTester tester, Widget page, {Size size = kPhoneMedium}) async {
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(page, size: size));
  await settle(tester, const Duration(seconds: 1));
}

void main() {
  setUpAll(loadTestFonts);

  group('Profil sekmesi: tek sayac seridi', () {
    testWidgets('Takipci, Takip, Kulup, Etkinlik tek yuzeyde ve tek satirda', (tester) async {
      await _open(tester, ProfileTab(session: makeSession(_backend()), themeController: ThemeController()));
      expect(find.byType(StatStrip), findsOneWidget);
      for (final s in ['Takipçi', 'Takip', 'Kulüp', 'Etkinlik']) {
        expect(find.descendant(of: find.byType(StatStrip), matching: find.text(s)), findsOneWidget, reason: s);
      }
      for (final n in ['128', '94', '3', '4']) {
        expect(find.descendant(of: find.byType(StatStrip), matching: find.text(n)), findsOneWidget, reason: n);
      }
      // 4 hucre ayni satirda (ayni dikey konum).
      final ys = [for (final s in ['Takipçi', 'Takip', 'Kulüp', 'Etkinlik']) tester.getCenter(find.text(s)).dy];
      expect(ys.every((y) => (y - ys.first).abs() < 1), isTrue, reason: '$ys');
      // Tek kart: seridin icinde ikinci bir BuCard yok.
      expect(find.descendant(of: find.byType(StatStrip), matching: find.byType(BuCard)), findsOneWidget);
      expect(find.byType(BuCountUp), findsNWidgets(4));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('buyuk yazi olceginde 2 x 2 dizilir, tasma yok', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      await tester.pumpWidget(p00App(
          ProfileTab(session: makeSession(_backend()), themeController: ThemeController()),
          scale: 1.3,
          scaffold: false));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      final a = tester.getCenter(find.text('Takipçi')).dy;
      final c = tester.getCenter(find.text('Kulüp')).dy;
      expect(c, greaterThan(a + 20), reason: 'ikinci satira inmeli');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('hucreye dokununca takipci listesi acilir', (tester) async {
      final b = _backend()..on('/users/1/followers*', {'items': <Object>[], 'nextCursor': null, 'total': 0});
      await _open(tester, ProfileTab(session: makeSession(b), themeController: ThemeController()));
      await tester.tap(find.text('Takipçi'));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byType(FollowListPage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('takip sayilari alinamazsa yalniz Kulup ve Etkinlik gorunur', (tester) async {
      final b = _backend()..fail('/users/1', status: 500, code: 'SERVER_ERROR', message: 'x');
      await _open(tester, ProfileTab(session: makeSession(b), themeController: ThemeController()));
      expect(find.text('Kulüp'), findsOneWidget);
      expect(find.text('Etkinlik'), findsOneWidget);
      expect(find.text('Takipçi'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('cikis sakin: simgesiz, listenin sonunda, surum yazisi altinda', (tester) async {
      await _open(tester, ProfileTab(session: makeSession(_backend()), themeController: ThemeController()));
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.byKey(const ValueKey('profile-signout')), 300, scrollable: list);
      expect(find.descendant(of: find.byKey(const ValueKey('profile-signout')), matching: find.byType(Icon)), findsNothing);
      expect(find.byIcon(LucideIcons.logOut), findsNothing);
      final dySign = tester.getCenter(find.byKey(const ValueKey('profile-signout'))).dy;
      final dyLegal = tester.getCenter(find.text('Sözleşmeler ve politikalar')).dy;
      expect(dySign, greaterThan(dyLegal));
      await unmount(tester);
    });
  });

  group('Profil sekmesi: tek yuzey ailesi, tek notr simge tonu', () {
    testWidgets('liste satiri simge karolari ayni notr tonda', (tester) async {
      await _open(tester, ProfileTab(session: makeSession(_backend()), themeController: ThemeController()));
      final colors = <Color>{};
      for (final icon in [LucideIcons.newspaper, LucideIcons.bell, LucideIcons.keyRound, LucideIcons.fileText]) {
        await tester.scrollUntilVisible(find.byIcon(icon), 200, scrollable: find.byType(Scrollable).first);
        final ic = tester.widget<Icon>(find.byIcon(icon));
        colors.add(ic.color!);
      }
      expect(colors.length, 1, reason: 'tek simge tonu: $colors');
      await unmount(tester);
    });
  });

  group('Profil duzenle: tek sutun', () {
    testWidgets('kart yok, etiket basina tek etiket, simgesiz', (tester) async {
      await _open(tester, EditProfilePage(session: makeSession(_backend()), profile: const {
        'displayName': 'Ayşe Kaya',
        'email': 'ayse@bingol.edu.tr',
        'faculty': 'Mühendislik Fakültesi',
        'department': 'Bilgisayar Mühendisliği',
        'grade': '3',
        'bio': 'x',
      }), size: kPhoneLarge);
      expect(find.byType(BuCard), findsNothing);
      expect(find.text('Ad soyad'), findsOneWidget);
      expect(find.text('Bölüm'), findsOneWidget);
      expect(find.text('Sınıf'), findsOneWidget);
      expect(find.byIcon(LucideIcons.mail), findsNothing);
      expect(find.byIcon(LucideIcons.save), findsNothing);
      expect(find.text('Kaydet'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('Takip satiri', () {
    testWidgets('Takip et soluk marka zemini (dolgu kirmizi degil), Takipte cizgili', (tester) async {
      final b = _backend()..on('/users/11/follow', {'followerCount': 2});
      await _open(tester, FollowListPage(session: makeSession(b), userId: 7, followers: true, name: 'A'));
      final box = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('followButton')));
      final deco = box.decoration! as BoxDecoration;
      final ctx = tester.element(find.byKey(const ValueKey('followButton')));
      final t = Theme.of(ctx);
      expect(deco.color, isNot(t.colorScheme.primary));
      expect((deco.border! as Border).top.color, Colors.transparent);
      await tester.tap(find.byKey(const ValueKey('followButton')));
      await tester.pump(const Duration(milliseconds: 400));
      final after = tester.widget<AnimatedContainer>(find.byKey(const ValueKey('followButton'))).decoration! as BoxDecoration;
      expect((after.border! as Border).top.color, isNot(Colors.transparent));
      expect(after.color, Colors.transparent);
      await settle(tester, const Duration(milliseconds: 300));
      await unmount(tester);
    });
  });

  group('Matris (tr/en/ar x acik/koyu x 1.0/1.3 x 320/390): tasma yok', () {
    final screens = <String, Widget Function()>{
      'EditProfilePage': () => EditProfilePage(session: makeSession(_backend()), profile: const {
            'displayName': 'Ayşe Kaya',
            'email': 'ayse@bingol.edu.tr',
            'faculty': 'Mühendislik Fakültesi',
            'department': 'Bilgisayar Mühendisliği',
            'grade': '3',
            'bio': 'Yazılım ve satranç.',
          }),
      'UserProfilePage': () => UserProfilePage(session: makeSession(_backend()), userId: 2, initialName: 'Mehmet'),
      'PrivacyDataPage': () => PrivacyDataPage(session: makeSession(_backend())),
      'MyDataPage': () => MyDataPage(session: makeSession(_backend())),
      'DeleteAccountPage': () => DeleteAccountPage(session: makeSession(_backend())),
      'BlockedUsersPage': () => BlockedUsersPage(session: makeSession(_backend())),
      'AccountSecurityPage': () => AccountSecurityPage(session: makeSession(_backend())),
      'MyClubsPage': () => MyClubsPage(session: makeSession(_backend())),
      'FollowListPage': () => FollowListPage(session: makeSession(_backend()), userId: 7, followers: true, name: 'Ayşe Demir'),
    };
    for (final e in screens.entries) {
      testWidgets(e.key, (tester) async {
        await p00Matrix(tester, e.value, scaffold: false, settleMs: 700);
      });
    }
  });
}
