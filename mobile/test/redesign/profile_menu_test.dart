import 'package:bu_kampus/core/icons/bu_icons.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/academic/academic_hub_page.dart';
import 'package:bu_kampus/features/posts/user_posts_page.dart';
import 'package:bu_kampus/features/profile/my_clubs_page.dart';
import 'package:bu_kampus/features/profile/my_events_page.dart';
import 'package:bu_kampus/features/profile/notification_prefs_page.dart';
import 'package:bu_kampus/features/profile/privacy_data_page.dart';
import 'package:bu_kampus/features/profile/profile_content_tabs.dart';
import 'package:bu_kampus/features/profile/profile_menu_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/features/profile/profil_widgets.dart' show ProfilRow;
import 'package:bu_kampus/features/profile/saved_news_page.dart';
import 'package:bu_kampus/features/profile/settings_page.dart';
import 'package:bu_kampus/features/support/support_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// Profilim: üç çizgi menüsü, sayısız Gönderiler | Reels sekmeleri, e-posta anahtarı Gizlilik ve veriler'de.
FakeBackend _backend({int followRequests = 0}) {
  final b = FakeBackend()
    ..on('/me/summary', {'communities': 3, 'events': 4, 'bookmarks': 12})
    ..on('/users/me', {
      'id': 1,
      'displayName': 'Ayşe Kaya',
      'email': 'ayse@bingol.edu.tr',
      'faculty': 'Mühendislik Fakültesi',
      'department': 'Bilgisayar Mühendisliği',
      'grade': '3',
      'bio': 'Yazılım ve satranç.',
      'showEmail': true,
      'postCount': 2,
      'reelCount': 1,
    })
    ..on('/users/1', {'id': 1, 'followerCount': 128, 'followingCount': 94, 'followedByMe': false})
    ..on('/users/me/follow-requests/count', {'count': followRequests})
    ..on('/users/me/privacy', {
      'avatar': 'EVERYONE',
      'bio': 'EVERYONE',
      'department': 'EVERYONE',
      'faculty': 'EVERYONE',
      'classYear': 'EVERYONE',
      'avatarHiddenByModeration': false,
    });
  fakeCatalog(b);
  fakePosts(b, count: 2);
  return b;
}

Widget _tab(FakeBackend b) => ProfileTab(session: makeSession(b), themeController: ThemeController());

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('profile-menu-button')));
  await settle(tester, const Duration(seconds: 1));
}

void main() {
  setUpAll(loadTestFonts);

  group('Profilim', () {
    testWidgets('sekme etiketlerinde sayı yok; e-posta anahtarı ve satır listesi yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(_tab(_backend()), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byType(ProfileContentTabs), findsOneWidget);
      expect(find.text('Gönderiler'), findsOneWidget);
      expect(find.text('Reels'), findsOneWidget);
      expect(find.textContaining('Gönderiler '), findsNothing);
      expect(find.textContaining('Reels '), findsNothing);
      expect(find.byKey(const ValueKey('inline-show-email')), findsNothing);
      expect(find.text('E-postamı diğer kullanıcılara göster'), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(ProfilRow), findsNothing);
      // Başlıkta üç çizgi menü düğmesi, sağ üst köşede; >= 44 dp.
      final btn = find.byKey(const ValueKey('profile-menu-button'));
      expect(btn, findsOneWidget);
      expect(tester.getSize(btn).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(btn).height, greaterThanOrEqualTo(44));
      expect(tester.getTopRight(btn).dx, greaterThan(kPhoneMedium.width - 40));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('menü düğmesi anlamsal etiketi "Menü"', (tester) async {
      final h = tester.ensureSemantics();
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(_tab(_backend()), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      final node = tester.getSemantics(find.byKey(const ValueKey('profile-menu-button')));
      expect(node.label, contains('Menü'));
      expect(node.flagsCollection.isButton, isTrue);
      h.dispose();
      await unmount(tester);
    });
  });

  group('Menü sayfası', () {
    testWidgets('menü düğmesi menüyü açar; eski tüm satırlar menüde', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(_tab(_backend()), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      await _openMenu(tester);
      expect(find.byType(ProfileMenuPage), findsOneWidget);
      expect(find.text('Menü'), findsNothing); // sayfa başlığı görünmez (sadeleştirme)
      for (final s in [
        'Gönderilerim',
        'Kayıtlı haberler',
        'Kulüplerim',
        'Etkinliklerim',
        'Akademik',
        'Bildirimler',
        'Gizlilik ve veriler',
        'Ayarlar',
        'Yardım ve destek',
      ]) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      // Sayılar satırın sağında.
      expect(find.descendant(of: find.widgetWithText(ProfilRow, 'Kulüplerim'), matching: find.text('3')), findsOneWidget);
      expect(find.descendant(of: find.widgetWithText(ProfilRow, 'Etkinliklerim'), matching: find.text('4')), findsOneWidget);
      expect(find.descendant(of: find.widgetWithText(ProfilRow, 'Kayıtlı haberler'), matching: find.text('12')), findsOneWidget);
      // Geri oku Profilim'e döner.
      await tester.tap(find.byIcon(BuIcons.arrowLeft));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byType(ProfileMenuPage), findsNothing);
      expect(find.byType(ProfileContentTabs), findsOneWidget);
      await unmount(tester);
    });

    final targets = <String, (String, Type)>{
      'menu-my-posts': ('Gönderilerim', UserPostsPage),
      'menu-saved': ('Kayıtlı haberler', SavedNewsPage),
      'menu-my-clubs': ('Kulüplerim', MyClubsPage),
      'menu-my-events': ('Etkinliklerim', MyEventsPage),
      'menu-academic': ('Akademik', AcademicHubPage),
      'menu-notifications': ('Bildirimler', NotificationPrefsPage),
      'menu-privacy': ('Gizlilik ve veriler', PrivacyDataPage),
      'menu-settings': ('Ayarlar', SettingsPage),
      'menu-support': ('Yardım ve destek', SupportPage),
    };
    for (final e in targets.entries) {
      testWidgets('${e.value.$1} satırı hedef sayfayı açar', (tester) async {
        useScreen(tester, kPhoneMedium);
        await tester.pumpWidget(buildApp(_tab(_backend()), size: kPhoneMedium));
        await settle(tester, const Duration(seconds: 1));
        await _openMenu(tester);
        await tester.tap(find.byKey(ValueKey(e.key)));
        await settle(tester, const Duration(seconds: 1));
        expect(find.byType(e.value.$2), findsOneWidget);
        await unmount(tester);
      });
    }

    testWidgets('takip isteği satırı yalnız bekleyen varken görünür ve istekler sayfasını açar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _backend(followRequests: 3)..on('/users/me/follow-requests*', {'items': <Object>[], 'nextCursor': null, 'total': 0});
      await tester.pumpWidget(buildApp(_tab(b), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      await _openMenu(tester);
      final row = find.byKey(const ValueKey('profile-follow-requests'));
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.text('3')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Gizlilik ve veriler: e-posta anahtarı', () {
    testWidgets('mevcut değer /users/me showEmail; açıp kapatınca PATCH { showEmail }', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _backend();
      await tester.pumpWidget(buildApp(PrivacyDataPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      final sw = find.descendant(of: find.byKey(const ValueKey('privacy-email-switch')), matching: find.byType(Switch));
      await tester.ensureVisible(sw);
      await tester.pump();
      expect(find.text('E-postamı diğer kullanıcılara göster'), findsOneWidget);
      expect(tester.widget<Switch>(sw).value, isTrue);
      await tester.tap(find.byKey(const ValueKey('privacy-email-switch')));
      await settle(tester);
      expect(b.bodies['PATCH /users/me'], {'showEmail': false});
      expect(tester.widget<Switch>(sw).value, isFalse);
      await unmount(tester);
    });

    testWidgets('kayıt hatasında anahtar eski değerine döner ve hata bildirimi çıkar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _backend();
      await tester.pumpWidget(buildApp(PrivacyDataPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(tester);
      b.fail('/users/me', status: 500);
      final sw = find.descendant(of: find.byKey(const ValueKey('privacy-email-switch')), matching: find.byType(Switch));
      await tester.ensureVisible(sw);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('privacy-email-switch')));
      await settle(tester);
      expect(tester.widget<Switch>(sw).value, isTrue);
      expect(find.byKey(const ValueKey('privacy-save-failed')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Matris (tr/en/ar x açık/koyu x 1.0/1.3 x 320/390): taşma yok', () {
    testWidgets('Profilim', (tester) async {
      await p00Matrix(tester, () => _tab(_backend()), scaffold: false, settleMs: 700);
    });
    testWidgets('Menü sayfası', (tester) async {
      await p00Matrix(
        tester,
        () => ProfileMenuPage(session: makeSession(_backend(followRequests: 12)), themeController: ThemeController()),
        scaffold: false,
        settleMs: 700,
      );
    });
  });
}
