import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/profile/notification_prefs_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// P9 / P9b / P9e: profil ana ekranı, profili düzenle, bildirim tercihleri.
void main() {
  setUpAll(loadTestFonts);

  FakeBackend backend() => FakeBackend()
    ..on('/users/me', {
      'id': 1,
      'displayName': 'Ayşe Yılmaz Çok Uzun Bir Soyadı Olan Öğrenci',
      'email': 'ayse.yilmaz@bingol.edu.tr',
      'faculty': 'Mühendislik Fakültesi',
      'department': 'Bilgisayar Mühendisliği',
      'grade': '3',
      'bio': 'Yazılım kulübünde ve kampüs etkinliklerinde yer alıyorum.',
      'showEmail': false,
      'language': 'tr',
    })
    ..on('/me/summary', {'communities': 2, 'events': 3, 'bookmarks': 4})
    ..on('/notifications/preferences', {
      'news': true,
      'announcements': true,
      'events': true,
      'communities': false,
      'messages': true,
      'quietHours': {'enabled': true, 'start': '23:00', 'end': '07:00', 'timezone': 'Europe/Istanbul'},
      'subtypes': {
        'MESSAGE_DIRECT': true,
        'MESSAGE_GROUP': true,
        'EVENT_REMINDER': true,
        'EVENT_UPDATE': true,
        'EVENT_ADMISSION': true,
        'COMMUNITY_POST': true,
        'COMMUNITY_ROLE': true,
        'COMMUNITY_JOIN': true,
        'POST_MENTION': true,
        'USER_FOLLOW': true,
        'POST_LIKE': true,
        'POST_COMMENT': true,
        'COMMENT_REPLY': true,
      },
    });

  Widget wrap(Widget page, {required bool rtl, required Brightness br, required Size size}) {
    final app = buildApp(page, brightness: br, size: size);
    if (!rtl) return app;
    return Directionality(textDirection: TextDirection.rtl, child: app);
  }

  for (final br in Brightness.values) {
    for (final rtl in [false, true]) {
      final tag = '${br.name}${rtl ? ' rtl' : ''} 320';
      testWidgets('ProfileTab $tag: kimlik kartı + menü satırları, taşma yok', (tester) async {
        useScreen(tester, kPhoneSmall);
        final b = backend();
        await tester.pumpWidget(wrap(
            ProfileTab(session: makeSession(b), themeController: ThemeController()),
            rtl: rtl,
            br: br,
            size: kPhoneSmall));
        await settle(tester);
        expect(find.text('Düzenle'), findsNothing); // düzenle düğmesi yok: alanlar yerinde düzenlenir
        expect(find.byKey(const ValueKey('inline-name')), findsOneWidget);
        // Bölüm ve sınıf ayrı çipler; hesap/gizlilik/dil/tema/çıkış Ayarlar sayfasındadır.
        expect(find.text('Bilgisayar Mühendisliği'), findsOneWidget);
        expect(find.text('3. sınıf'), findsOneWidget);
        // Profilim'in altında satır listesi yok; tüm satırlar sağ üstteki üç çizgi menüsünde.
        for (final s in ['Kayıtlı haberler', 'Kulüplerim', 'Etkinliklerim', 'Akademik', 'Bildirimler', 'Ayarlar', 'Yardım ve destek']) {
          expect(find.text(s), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('profile-menu-button')));
        await settle(tester);
        for (final s in ['Gönderilerim', 'Kayıtlı haberler', 'Kulüplerim', 'Etkinliklerim', 'Akademik', 'Bildirimler', 'Gizlilik ve veriler', 'Ayarlar', 'Yardım ve destek']) {
          await tester.scrollUntilVisible(find.text(s), 200, scrollable: find.byType(Scrollable).first);
          expect(find.text(s), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });

      testWidgets('NotificationPrefsPage $tag: tercihler + sessiz saatler, taşma yok', (tester) async {
        useScreen(tester, kPhoneSmall);
        final b = backend();
        await tester.pumpWidget(
            wrap(NotificationPrefsPage(session: makeSession(b)), rtl: rtl, br: br, size: kPhoneSmall));
        await settle(tester);
        expect(find.text('Anlık bildirimler'), findsOneWidget);
        // Test yerelinde (en) büyük harf kuralı İngilizcedir.
        expect(find.text('Neler bildirilsin'), findsOneWidget);
        // Sosyal etkileşimler bölümü eklendi: sessiz saatler satırına kadar kaydır.
        await tester.scrollUntilVisible(find.text('23:00 – 07:00'), 200, scrollable: find.byType(Scrollable).first);
        await settle(tester, const Duration(milliseconds: 600));
        // Stitch v3: sessiz saatler özet satırı; saatler kendi sayfasında.
        expect(find.text('23:00 – 07:00'), findsOneWidget);
        await tester.tap(find.text('Sessiz saatler'));
        await settle(tester);
        expect(find.text('23:00'), findsOneWidget);
        expect(find.text('07:00'), findsOneWidget);
        await tester.tap(find.byType(BuIconButton).first);
        await settle(tester);
        await tester.ensureVisible(find.text('Ayrıntılı tercihler'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Ayrıntılı tercihler'));
        await settle(tester);
        // Günlük menü hatırlatıcısı satırları eklendi: hedef satıra kadar kaydır.
        for (var i = 0; i < 8 && find.text('Kulüp gönderileri').evaluate().isEmpty; i++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -500));
          await tester.pump(const Duration(milliseconds: 300));
        }
        await settle(tester, const Duration(milliseconds: 600));
        expect(find.text('Kulüp gönderileri'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });

    }
  }

  testWidgets('Bildirim tercihleri: sessiz saat anahtarı kısmi gövde gönderir', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = backend();
    await tester.pumpWidget(buildApp(NotificationPrefsPage(session: makeSession(b)), size: kPhoneMedium));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Sessiz saatler'), 200, scrollable: find.byType(Scrollable).first);
    await settle(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Sessiz saatler'));
    await settle(tester);
    await tester.tap(find.text('Sessiz saatleri aç'));
    await settle(tester);
    expect(b.bodies['PUT /notifications/preferences'], {
      'quietHours': {'enabled': false}
    });
    await unmount(tester);
  });

  testWidgets('Bildirim tercihleri: üst bayrak kapalıyken alt tür dokunulmaz', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = backend();
    await tester.pumpWidget(buildApp(NotificationPrefsPage(session: makeSession(b)), size: kPhoneMedium));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Ayrıntılı tercihler'), 200, scrollable: find.byType(Scrollable).first);
    await settle(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Ayrıntılı tercihler'));
    await settle(tester);
    await tester.tap(find.text('Kulüp gönderileri'));
    await settle(tester);
    // communities kapalı: PUT gitmemeli.
    expect(b.bodies['PUT /notifications/preferences'], isNull);
    await unmount(tester);
  });
}
