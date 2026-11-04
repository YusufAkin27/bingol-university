import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/profile/profile_content_tabs.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/features/profile/user_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// QA-SO: ProfileContentTabs (Gönderiler | Reels) kendi profili ve kullanıcı profiline entegre; eski ızgara kalktı.

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(20).join('\n')}');
}

Map<String, dynamic> post(int id, {bool video = false}) => {
      'id': id,
      'text': 'merhaba',
      if (!video) 'media': [
        {'id': id, 'kind': 'IMAGE', 'url': '/api/posts/media/$id', 'thumbUrl': '/api/posts/media/$id?thumb=true'}
      ],
      if (video) 'type': 'VIDEO',
      if (video) 'video': {'url': '/api/posts/media/$id', 'posterUrl': '/api/posts/media/$id?poster=true', 'durationMs': 12000},
      if (video) 'viewCount': 40,
    };

const _other = {
  'id': 2,
  'displayName': 'Mert Kaya',
  'faculty': 'Mühendislik Fakültesi',
  'department': 'Bilgisayar Mühendisliği',
  'grade': '3',
  'bio': 'Merhaba',
  'followerCount': 5,
  'followingCount': 1,
  'followedByMe': false,
  'followsMe': false,
};

FakeBackend otherBe({Map<String, dynamic> over = const {}}) => FakeBackend()
  ..on('/users/2', {..._other, ...over})
  ..on('/users/2/posts*', {
    'items': [post(1), post(2), post(3)],
    'nextCursor': null,
    'total': 3,
  })
  ..on('/users/2/reels*', {
    'items': [post(9, video: true)],
    'nextCursor': null,
  });

FakeBackend meBe() => FakeBackend()
  ..on('/users/me', {
    'id': 1,
    'displayName': 'Ayşe Yılmaz',
    'email': 'ayse.yilmaz@bingol.edu.tr',
    'faculty': 'Mühendislik Fakültesi',
    'department': 'Bilgisayar Mühendisliği',
    'grade': '3',
    'bio': 'Merhaba',
    'postCount': 5,
    'reelCount': 1,
  })
  ..on('/me/summary', {'communities': 2, 'events': 3, 'bookmarks': 4})
  ..on('/posts/mine*', {
    'items': [post(11), post(12)],
    'nextCursor': null,
    'total': 2,
  })
  ..on('/users/1/reels*', {
    'items': [post(19, video: true)],
    'nextCursor': null,
  });

void main() {
  setUpAll(loadTestFonts);

  group('UserProfilePage', () {
    testWidgets('Gönderiler | Reels sekmeleri; eski ızgara başlığı yok; Reels yalnız seçilince istenir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = otherBe(over: {'postCount': 4, 'reelCount': 1});
      await tester.pumpWidget(buildApp(UserProfilePage(session: makeSession(b), userId: 2), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.text('Gönderiler 4'), findsOneWidget);
      expect(find.text('Reels 1'), findsOneWidget);
      expect(find.text('GÖNDERİLER'), findsNothing);
      expect(find.byType(ProfileContentTabs), findsOneWidget);
      expect(b.requests.any((r) => r.startsWith('GET /users/2/posts?size=9')), isTrue);
      expect(b.requests.any((r) => r.contains('/reels')), isFalse);
      await tester.ensureVisible(find.text('Reels 1'));
      await tester.tap(find.text('Reels 1'));
      await settle(tester, const Duration(milliseconds: 700));
      expect(b.requests.any((r) => r.startsWith('GET /users/2/reels?size=9')), isTrue);
      expect(find.byKey(const ValueKey('profile-reel-9')), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('profil yanıtında postCount yoksa sayaç ilk sayfanın toplamından gelir; sekme etiketinde sayı yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = otherBe();
      await tester.pumpWidget(buildApp(UserProfilePage(session: makeSession(b), userId: 2), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.text('Gönderiler'), findsOneWidget);
      expect(find.text('Reels'), findsOneWidget);
      // Gönderi sayacı (3) — Takipçi 5 ve Takip 1 ile birlikte.
      expect(find.text('3'), findsWidgets);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('gizli hesap (kilitli): sekmeler yok, gönderi isteği atılmaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = otherBe(over: {'isPrivate': true, 'locked': true, 'followState': 'NONE', 'followerCount': null, 'followingCount': null});
      await tester.pumpWidget(buildApp(UserProfilePage(session: makeSession(b), userId: 2), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.byType(ProfileContentTabs), findsNothing);
      expect(b.requests.any((r) => r.contains('/posts')), isFalse);
      expect(find.text('Bu hesap gizli'), findsOneWidget);
      await unmount(tester);
    });

    for (final size in [kPhoneSmall, kPhoneMedium]) {
      for (final dark in [false, true]) {
        testWidgets('taşma yok ${size.width.toInt()} dp x1.3 ${dark ? 'koyu' : 'açık'} + RTL', (tester) async {
          useScreen(tester, size);
          final b = otherBe(over: {'postCount': 4, 'reelCount': 1});
          await tester.pumpWidget(MediaQuery(
            data: MediaQueryData(size: size, textScaler: const TextScaler.linear(1.3)),
            child: buildApp(
              Directionality(textDirection: TextDirection.rtl, child: UserProfilePage(session: makeSession(b), userId: 2)),
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
          ));
          await settle(tester, const Duration(milliseconds: 900));
          await tester.drag(find.byType(ListView).first, const Offset(0, -500));
          await settle(tester, const Duration(milliseconds: 400));
          noErr(tester);
          await unmount(tester);
        });
      }
    }
  });

  group('ProfileTab (kendi profilim)', () {
    testWidgets('Gönderiler | Reels sekmeleri kimlik altında; Gönderilerim satırı kalktı; Reels /users/1/reels', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = meBe();
      await tester.pumpWidget(buildApp(ProfileTab(session: makeSession(b), themeController: ThemeController()), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.byType(ProfileContentTabs), findsOneWidget);
      expect(find.text('Gönderiler 5'), findsOneWidget);
      expect(find.text('Reels 1'), findsOneWidget);
      expect(find.text('Gönderilerim'), findsNothing);
      expect(b.requests.any((r) => r.startsWith('GET /posts/mine?size=9')), isTrue);
      expect(find.byKey(const ValueKey('profile-post-11')), findsOneWidget);
      await tester.ensureVisible(find.text('Reels 1'));
      await tester.tap(find.text('Reels 1'));
      await settle(tester, const Duration(milliseconds: 700));
      expect(b.requests.any((r) => r.startsWith('GET /users/1/reels?size=9')), isTrue);
      expect(find.byKey(const ValueKey('profile-reel-19')), findsOneWidget);
      // Ayar satırları hâlâ erişilebilir (hesap silme Ayarlar'dadır).
      await tester.scrollUntilVisible(find.text('Ayarlar'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Ayarlar'), findsOneWidget);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('çekerek yenileme sekmeleri baştan yükler', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = meBe();
      await tester.pumpWidget(buildApp(ProfileTab(session: makeSession(b), themeController: ThemeController()), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 900));
      final before = b.count('GET /posts/mine');
      await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
      await settle(tester, const Duration(milliseconds: 1200));
      expect(b.count('GET /posts/mine'), greaterThan(before));
      noErr(tester);
      await unmount(tester);
    });
  });
}
