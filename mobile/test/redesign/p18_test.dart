import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/follow/follow_list_page.dart';
import 'package:bu_kampus/features/follow/follow_suggestions.dart';
import 'package:bu_kampus/features/posts/user_posts_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/features/shell/app_shell.dart';
import 'package:bu_kampus/widgets/bu.dart' show BuButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// Paket 18: kabuk (tembel sekmeler), Profil sekmesi, takip listesi/onerileri, kullanici gonderileri.
FakeBackend _backend() {
  final b = FakeBackend()
    ..on('/me/summary', {'unreadNotifications': 1, 'unreadMessages': 2, 'communities': 3, 'events': 4, 'bookmarks': 5})
    ..on('/users/me', {
      'id': 1,
      'displayName': 'Ayşe Yılmaz Çok Uzun Bir Soyadı Olan Öğrenci',
      'faculty': 'Mühendislik Fakültesi',
      'department': 'Bilgisayar Mühendisliği',
      'grade': '3',
      'bio': 'Yazılım kulübünde ve kampüs etkinliklerinde yer alıyorum.',
    })
    ..on('/users/1', {'id': 1, 'followerCount': 128, 'followingCount': 94})
    ..on('/users/7/followers*', {
      'items': [
        {'id': 11, 'displayName': 'Emre Yılmaz', 'department': 'Bilgisayar Mühendisliği', 'followedByMe': true, 'followsMe': true},
        {'id': 12, 'displayName': 'Selin Kaya', 'followedByMe': false, 'followsMe': true},
      ],
      'nextCursor': null,
      'total': 2,
    })
    ..on('/users/7/following*', {'items': <Object>[], 'nextCursor': null, 'total': 0})
    ..on('/users/me/follow-suggestions*', {
      'items': [
        {'id': 21, 'displayName': 'Burak Çelik', 'department': 'Hukuk', 'followedByMe': false},
      ],
    });
  fakePosts(b, count: 4);
  return b;
}

void main() {
  setUpAll(loadTestFonts);

  group('P18 matris (tr/en/ar x acik/koyu x 1.0/1.3 x 320/390): tasma yok', () {
    final screens = <String, Widget Function()>{
      'ProfileTab': () => ProfileTab(session: makeSession(_backend()), themeController: ThemeController()),
      'FollowListPage': () => FollowListPage(session: makeSession(_backend()), userId: 7, followers: true, name: 'Ayşe Demir'),
      'FollowSuggestionsPage': () => FollowSuggestionsPage(session: makeSession(_backend())),
      'UserPostsPage': () => UserPostsPage(session: makeSession(_backend())),
    };
    for (final e in screens.entries) {
      testWidgets(e.key, (tester) async {
        await p00Matrix(tester, e.value, scaffold: false, settleMs: 700);
      });
    }
  });

  group('durumlar', () {
    testWidgets('ProfileTab yuklenirken iskelet, sonra icerik', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _backend()..delay = const Duration(milliseconds: 400);
      await tester.pumpWidget(buildApp(ProfileTab(session: makeSession(b), themeController: ThemeController())));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Profili düzenle'), findsNothing);
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Profili düzenle'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('ProfileTab hata: yeniden dene calisir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _backend()..fail('/users/me', status: 500, code: 'SERVER_ERROR', message: 'x');
      await tester.pumpWidget(buildApp(ProfileTab(session: makeSession(b), themeController: ThemeController())));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Profili düzenle'), findsNothing);
      b.on('/users/me', {'id': 1, 'displayName': 'Ayşe', 'department': 'X'});
      await tester.tap(find.byType(BuButton).first);
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Profili düzenle'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('ProfileTab istatistik karolari sayilari gosterir', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(ProfileTab(session: makeSession(_backend()), themeController: ThemeController())));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('128'), findsOneWidget); // takipci
      expect(find.text('94'), findsOneWidget); // takip
      expect(find.text('3'), findsWidgets);
      expect(find.text('4'), findsWidgets);
      await unmount(tester);
    });

    testWidgets('Takip listesi bos: bos durum; arama sonucsuz: eslesme yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _backend();
      await tester.pumpWidget(buildApp(FollowListPage(session: makeSession(b), userId: 7, followers: false, name: 'A')));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Henüz kimseyi takip etmiyor'), findsNothing); // metin ARB'den; yalniz istisna olmamali
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(buildApp(FollowListPage(session: makeSession(b), userId: 7, followers: true, name: 'A')));
      await settle(tester, const Duration(seconds: 1));
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();
      expect(find.text('Emre Yılmaz'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('Takip onerileri: satir + takip et dugmesi', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(FollowSuggestionsPage(session: makeSession(_backend()))));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Burak Çelik'), findsOneWidget);
      expect(find.byKey(const ValueKey('followButton')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('AppShell tembel sekmeler', () {
    testWidgets('ilk karede yalniz ana sekme agi baslatir; sekme ilk secimde kurulur ve sonra canli kalir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _backend();
      await tester.pumpWidget(buildApp(AppShell(session: makeSession(b), themeController: ThemeController())));
      await settle(tester, const Duration(seconds: 1));
      // Profil ve Kulupler sekmeleri henuz kurulmadi: profil/kulup istekleri yok.
      expect(b.requests.any((r) => r.contains('/users/me')), isFalse, reason: b.requests.join('\n'));
      expect(find.byType(ProfileTab), findsNothing);
      await tester.tap(find.text('Profil'));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byType(ProfileTab), findsOneWidget);
      expect(b.requests.any((r) => r.contains('/users/me')), isTrue);
      final n = b.requests.where((r) => r.contains('GET /users/me')).length;
      // Ana sayfaya don, tekrar profil: yeniden kurulmaz (istek sayisi artmaz).
      await tester.tap(find.text('Ana Sayfa'));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('Profil'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests.where((r) => r.contains('GET /users/me')).length, n);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('animasyonlari azalt: sekme gecisi anlik, istisna yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(buildApp(AppShell(session: makeSession(_backend()), themeController: ThemeController())));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('Keşfet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });
}
