import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/follow/follow_list_page.dart';
import 'package:bu_kampus/features/follow/follow_summary.dart';
import 'package:bu_kampus/features/profile/account_security_page.dart';
import 'package:bu_kampus/features/profile/blocked_users_page.dart';
import 'package:bu_kampus/features/profile/my_clubs_page.dart';
import 'package:bu_kampus/features/profile/privacy_data_page.dart';
import 'package:bu_kampus/features/profile/profil2_delete_account_page.dart';
import 'package:bu_kampus/features/profile/profil2_my_data_page.dart';
import 'package:bu_kampus/features/profile/profile_menu_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/features/profile/profil_widgets.dart' show ProfilRow, ProfilTopBar;
import 'package:bu_kampus/features/profile/settings_page.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/profile/user_profile_page.dart';
import 'package:bu_kampus/widgets/bu.dart' show BuCard, BuCountUp;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';
import 'package:bu_kampus/core/icons/bu_icons.dart';

/// Tur 3 (P3-PROFILE, minimal): Profil sekmesi tek sayac seridi, tek notr simge tonu, sakin cikis; duzenleme tek sutun;
/// takip satiri duzeni; tum profil ekranlari 3 dil x acik/koyu x 1.3 x 320 matrisinde tasmasiz.
FakeBackend _backend() {
  final b = _base();
  fakePosts(b, count: 4);
  return b;
}

FakeBackend _base() => FakeBackend()
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

  group('Profil sekmesi (Stitch v3): tek kutuda 3 sutun sayac', () {
    testWidgets('Takipci, Takip, Gonderi tek yuzeyde ve tek satirda', (tester) async {
      await _open(tester, ProfileTab(session: makeSession(_backend()), themeController: ThemeController()));
      expect(find.byType(StatStrip), findsOneWidget);
      for (final s in ['Takipçi', 'Takip', 'Gönderi']) {
        expect(find.descendant(of: find.byType(StatStrip), matching: find.text(s)), findsOneWidget, reason: s);
      }
      for (final n in ['128', '94']) {
        expect(find.descendant(of: find.byType(StatStrip), matching: find.text(n)), findsOneWidget, reason: n);
      }
      final ys = [for (final s in ['Takipçi', 'Takip', 'Gönderi']) tester.getCenter(find.text(s)).dy];
      expect(ys.every((y) => (y - ys.first).abs() < 1), isTrue, reason: '$ys');
      // Buyuk bilgi karti yok: sayac seridi duz satir (ust/alt ince cizgi), icinde BuCard yok; vurgu yok: sayilar ink renginde.
      expect(find.descendant(of: find.byType(StatStrip), matching: find.byType(BuCard)), findsNothing);
      expect(find.byType(BuCountUp), findsNWidgets(3));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('1.3 yazi olceginde 320 dp de tek satir kalir, tasma yok', (tester) async {
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
      final c = tester.getCenter(find.text('Gönderi')).dy;
      expect((c - a).abs(), lessThan(2));
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

    testWidgets('takip sayilari alinamazsa yalniz Gonderi gorunur', (tester) async {
      final b = _backend()..fail('/users/1', status: 500, code: 'SERVER_ERROR', message: 'x');
      await _open(tester, ProfileTab(session: makeSession(b), themeController: ThemeController()));
      expect(find.text('Gönderi'), findsOneWidget);
      expect(find.text('Takipçi'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('Profilim altinda satir listesi yok; satirlar uc cizgi menusunde, kulup/etkinlik sayisi satirin sagindaki deger', (tester) async {
      await _open(tester, ProfileTab(session: makeSession(_backend()), themeController: ThemeController()));
      expect(find.byType(ProfilRow), findsNothing);
      for (final s in ['Kayıtlı haberler', 'Kulüplerim', 'Etkinliklerim', 'Ayarlar']) {
        expect(find.text(s), findsNothing, reason: s);
      }
      await tester.tap(find.byKey(const ValueKey('profile-menu-button')));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byType(ProfileMenuPage), findsOneWidget);
      for (final s in ['Gönderilerim', 'Kayıtlı haberler', 'Kulüplerim', 'Etkinliklerim', 'Akademik', 'Bildirimler', 'Gizlilik ve veriler', 'Ayarlar', 'Yardım ve destek']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      // Önerilen kişiler artık Ana Sayfa'da; menüde satırı yok.
      expect(find.text('Önerilen kişiler'), findsNothing);
      final rows = find.byType(ProfilRow);
      expect(rows.evaluate().length, greaterThanOrEqualTo(9));
      for (var i = 0; i < rows.evaluate().length; i++) {
        expect(tester.getSize(rows.at(i)).height, greaterThanOrEqualTo(56));
      }
      // Kulup (3) ve Etkinlik (4) sayilari ilgili satirda deger olarak durur.
      expect(find.descendant(of: find.widgetWithText(ProfilRow, 'Kulüplerim'), matching: find.text('3')), findsOneWidget);
      expect(find.descendant(of: find.widgetWithText(ProfilRow, 'Etkinliklerim'), matching: find.text('4')), findsOneWidget);
      // Dil/tema/cikis menude degil, Ayarlar sayfasinda.
      expect(find.text('Çıkış yap'), findsNothing);
      expect(find.text('Tema'), findsNothing);
      await unmount(tester);
    });

    testWidgets('Menude Ayarlar satiri Ayarlar sayfasini acar', (tester) async {
      await _open(tester, ProfileTab(session: makeSession(_backend()), themeController: ThemeController()));
      await tester.tap(find.byKey(const ValueKey('profile-menu-button')));
      await settle(tester, const Duration(seconds: 1));
      await tester.ensureVisible(find.widgetWithText(ProfilRow, 'Ayarlar'));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(ProfilRow, 'Ayarlar'));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byType(SettingsPage), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Ayarlar (Stitch v3): tam genislik 56 dp satirlar', () {
    testWidgets('bolumler, dil/tema degeri, sohbet arka plani, cikis en sonda', (tester) async {
      await _open(tester, SettingsPage(session: makeSession(_backend()), themeController: ThemeController()), size: kPhoneLarge);
      for (final s in ['Görünüm', 'Sohbet', 'Bildirimler', 'Gizlilik ve hesap']) {
        expect(find.text(s), findsOneWidget, reason: s); // buyuk harf degil
      }
      expect(find.text('Dil'), findsOneWidget);
      expect(find.text('Sohbet arka planı'), findsOneWidget);
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.byKey(const ValueKey('settings-sign-out')), 300, scrollable: list);
      expect(find.byKey(const ValueKey('settings-logout-all')), findsNothing);
      expect(find.byKey(const ValueKey('settings-delete-account')), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('Alt sayfalar (Stitch v3 birebir)', () {
    testWidgets('Gizlilik: 20 dp kenar bosluklu cerceveli grup (satirlar grup genisliginde), segment 48 dp dokunma, ust cubuk duz', (tester) async {
      await _open(tester, PrivacyDataPage(session: makeSession(_backend())), size: kPhoneLarge);
      expect(find.byType(ProfilTopBar), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('privacy-select-avatar'))).height, greaterThanOrEqualTo(48));
      final row = tester.getSize(find.byKey(const ValueKey('privacy-row-avatar')));
      expect(row.width, kPhoneLarge.width - 40); // premium monochrome: 20 dp kenar boslugu + cerceveli 16 dp grup, satir grup genisliginde
      await unmount(tester);
    });

    testWidgets('Hesabi sil: Devam et onaysiz %40 opak, onayla tam opak', (tester) async {
      await _open(tester, DeleteAccountPage(session: makeSession(_backend())), size: kPhoneLarge);
      double opacity() => tester.widget<AnimatedOpacity>(find.ancestor(of: find.byKey(const ValueKey('delete-continue')), matching: find.byType(AnimatedOpacity)).first).opacity;
      expect(opacity(), .4);
      await tester.tap(find.byKey(const ValueKey('delete-ack')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacity(), 1);
      await unmount(tester);
    });

    testWidgets('Engellenenler: bos durumda illustrasyon yok, baslik 18/600', (tester) async {
      final b = _backend()..on('/users/me/blocks*', <Object>[]);
      await _open(tester, BlockedUsersPage(session: makeSession(b)), size: kPhoneLarge);
      expect(find.text('Kimseyi engellemedin'), findsOneWidget);
      expect(find.byIcon(BuIcons.ban), findsNothing);
      await unmount(tester);
    });
  });

  group('Takip satiri (Stitch v3)', () {
    testWidgets('Takip et dolu (prPressed), Takipte tonal soft (Stitch profil-v4); dokunma alani 48', (tester) async {
      final b = _backend()..on('/users/11/follow', {'followerCount': 2});
      await _open(tester, FollowListPage(session: makeSession(b), userId: 7, followers: true, name: 'A'));
      final key = find.byKey(const ValueKey('followButton'));
      expect(tester.getSize(key).height, greaterThanOrEqualTo(48));
      final ctx = tester.element(key);
      final bu = ctx.bu;
      var box = tester.widget<AnimatedContainer>(find.descendant(of: key, matching: find.byType(AnimatedContainer)));
      var deco = box.decoration! as BoxDecoration;
      expect(deco.color, bu.prPressed);
      expect(deco.border, isNull);
      await tester.tap(key);
      await tester.pump(const Duration(milliseconds: 400));
      box = tester.widget<AnimatedContainer>(find.descendant(of: key, matching: find.byType(AnimatedContainer)));
      deco = box.decoration! as BoxDecoration;
      expect(deco.color, bu.soft);
      expect(deco.border, isNull);
      await settle(tester, const Duration(milliseconds: 300));
      await unmount(tester);
    });
  });

  group('Matris (tr/en/ar x acik/koyu x 1.0/1.3 x 320/390): tasma yok', () {
    final screens = <String, Widget Function()>{
      'ProfileTab': () => ProfileTab(session: makeSession(_backend()), themeController: ThemeController()),
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
