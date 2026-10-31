import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/auth/help/about_page.dart';
import 'package:bu_kampus/features/auth/help/help_code_page.dart';
import 'package:bu_kampus/features/auth/help/help_form_page.dart';
import 'package:bu_kampus/features/auth/help/help_track_page.dart';
import 'package:bu_kampus/features/auth/help/public_support_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// P66: herkese açık yardım akışı (form -> kod -> talep durumu) ve Hakkında. Yalnız `/api/public/support/**`,
/// oturumsuz (`auth: false`); honeypot hep boş, `elapsedMs` gönderilir, 429'da Retry-After'lı sade ileti.
void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });

  Session sess(FakeBackend b) => makeSession(b, signedIn: false);

  const detail = {
    'ticket': {'id': 7, 'category': 'ACCOUNT', 'subject': 'Giriş yapamıyorum', 'status': 'ANSWERED', 'createdAt': '2026-10-14T10:32:00Z', 'updatedAt': '2026-10-14T11:05:00Z'},
    'messages': [
      {'id': 1, 'fromStaff': false, 'text': 'Şifremi hatırlamıyorum ve kod gelmiyor.', 'createdAt': '2026-10-14T10:32:00Z'},
      {'id': 2, 'fromStaff': true, 'text': 'Hesabınız kontrol edildi, şifre sıfırlamayı deneyin.', 'createdAt': '2026-10-14T11:05:00Z'},
    ],
  };

  Future<void> fill(WidgetTester t, {String name = 'Elif Yıldız', String email = 'elif@gmail.com', String msg = 'Giriş yapamıyorum, yardım eder misiniz?'}) async {
    final f = find.byType(TextFormField);
    await t.enterText(f.at(0), name);
    await t.enterText(f.at(1), email);
    await t.enterText(f.at(2), msg);
    await t.pump();
  }

  group('doğrulama (saf)', () {
    test('boş/geçersiz/kısa/uzun alanlar', () {
      expect(validatePublicSupport(name: '', email: '', message: '').ok, isFalse);
      expect(validatePublicSupport(name: 'A', email: 'a@b', message: 'x' * 10).email, PublicFieldError.invalid);
      expect(validatePublicSupport(name: 'A', email: 'a@gmail.com', message: 'kısa').message, PublicFieldError.tooShort);
      expect(validatePublicSupport(name: 'A', email: 'a@gmail.com', message: 'x' * 2001).message, PublicFieldError.tooLong);
      expect(validatePublicSupport(name: 'A', email: 'a@gmail.com', message: 'x' * 10).ok, isTrue, reason: 'her alan adı kabul');
    });
  });

  group('form', () {
    testWidgets('boş gönderimde hatalar görünür, istek atılmaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      await tester.pumpWidget(buildApp(HelpFormPage(session: sess(b))));
      await settle(tester, const Duration(milliseconds: 900));
      await tester.ensureVisible(find.text('Devam'));
      await tester.tap(find.text('Devam'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Ad soyadınızı girin.'), findsOneWidget);
      expect(find.text('Geçerli bir e-posta adresi girin.'), findsOneWidget);
      expect(b.count('/public/support'), 0);
      await unmount(tester);
    });

    testWidgets('gönderim: honeypot boş, elapsedMs var, oturumsuz; kod adımına geçer', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..on('/public/support/tickets', {'status': 'CODE_SENT', 'expiresInMinutes': 10}, status: 202);
      await tester.pumpWidget(buildApp(HelpFormPage(session: sess(b))));
      await settle(tester, const Duration(milliseconds: 900));
      await fill(tester);
      await tester.ensureVisible(find.text('Devam'));
      await tester.tap(find.text('Devam'));
      await settle(tester, const Duration(milliseconds: 900));
      final body = b.bodies['POST /public/support/tickets']! as Map;
      expect(body['website'], '');
      expect(body['elapsedMs'], isA<int>());
      expect(body['category'], 'ACCOUNT');
      expect(body['email'], 'elif@gmail.com');
      expect(find.byType(HelpCodePage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('429: Retry-After ile sade uyarı, kod adımına geçilmez', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/public/support/tickets', {'code': 'TOO_MANY_REQUESTS', 'message': 'Çok fazla deneme. Lütfen biraz bekleyin.'}, status: 429, headers: {'retry-after': '40'});
      await tester.pumpWidget(buildApp(HelpFormPage(session: sess(b))));
      await settle(tester, const Duration(milliseconds: 900));
      await fill(tester);
      await tester.ensureVisible(find.text('Devam'));
      await tester.tap(find.text('Devam'));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.text('Çok fazla deneme. Lütfen biraz bekleyin.'), findsOneWidget);
      expect(find.byType(HelpCodePage), findsNothing);
      await unmount(tester);
    });

    testWidgets('ekranda bal kabağı alanı yok: yalnız 3 metin alanı', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(HelpFormPage(session: sess(FakeBackend()))));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.textContaining('website'), findsNothing);
      await unmount(tester);
    });
  });

  group('kod adımı', () {
    testWidgets('doğru kod: jeton güvenli depoya yazılır ve talep durumu açılır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/public/support/tickets/verify', {'ticketId': 7, 'trackToken': 'tok-123'})
        ..on('/public/support/track', detail);
      await tester.pumpWidget(buildApp(HelpCodePage(session: sess(b), email: 'elif@gmail.com', resend: () async {})));
      await settle(tester, const Duration(milliseconds: 900));
      await tester.enterText(find.byType(EditableText).first, '528412');
      await tester.pump();
      await settle(tester, const Duration(milliseconds: 1200));
      final body = b.bodies['POST /public/support/tickets/verify']! as Map;
      expect(body, {'email': 'elif@gmail.com', 'code': '528412'});
      expect(find.byType(HelpTrackPage), findsOneWidget);
      expect(await TrackTokenStore.read(), 'tok-123');
      await TrackTokenStore.clear();
      await unmount(tester);
    });

    testWidgets('yanlış kod: hata metni, talep durumu açılmaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..fail('/public/support/tickets/verify', status: 400, code: 'INVALID_CODE', message: 'x');
      await tester.pumpWidget(buildApp(HelpCodePage(session: sess(b), email: 'elif@gmail.com', resend: () async {})));
      await settle(tester, const Duration(milliseconds: 900));
      await tester.enterText(find.byType(EditableText).first, '111111');
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.text('Kod hatalı veya süresi dolmuş.'), findsOneWidget);
      expect(find.byType(HelpTrackPage), findsNothing);
      await unmount(tester);
    });
  });

  group('talep durumu', () {
    testWidgets('mesajlar balonsuz akar; Yanıtlandı hapı; yanıt gönderilir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/public/support/track', detail)
        ..on('/public/support/track/messages', detail);
      await tester.pumpWidget(buildApp(HelpTrackPage(session: sess(b), token: 'tok-123')));
      await settle(tester, const Duration(milliseconds: 1200));
      expect(find.text('Yanıtlandı'), findsOneWidget);
      expect(find.text('Giriş yapamıyorum'), findsOneWidget);
      expect(find.textContaining('Hesabınız kontrol edildi'), findsOneWidget);
      expect(find.textContaining('Destek ekibi'), findsOneWidget);
      // Boş iken Gönder pasif; yazınca etkin.
      TextButton send() => tester.widget<TextButton>(find.widgetWithText(TextButton, 'Gönder'));
      expect(send().onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'Teşekkürler, denedim.');
      await tester.pump();
      expect(send().onPressed, isNotNull);
      await tester.tap(find.widgetWithText(TextButton, 'Gönder'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.bodies['POST /public/support/track/messages'], {'token': 'tok-123', 'text': 'Teşekkürler, denedim.'});
      await unmount(tester);
    });

    testWidgets('kapalı talep: yanıt çubuğu yerine "Bu talep kapatıldı."', (tester) async {
      useScreen(tester, kPhoneMedium);
      final closed = {
        'ticket': {...(detail['ticket']! as Map), 'status': 'CLOSED'},
        'messages': detail['messages'],
      };
      final b = FakeBackend()..on('/public/support/track', closed);
      await tester.pumpWidget(buildApp(HelpTrackPage(session: sess(b), token: 't')));
      await settle(tester, const Duration(milliseconds: 1200));
      expect(find.text('Bu talep kapatıldı.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await unmount(tester);
    });

    testWidgets('yüklenemedi: tek cümle + Yeniden dene', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..fail('/public/support/track', status: 500);
      await tester.pumpWidget(buildApp(HelpTrackPage(session: sess(b), token: 't')));
      await settle(tester, const Duration(milliseconds: 1200));
      expect(find.text('Yüklenemedi, tekrar dene'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('hakkında', () {
    testWidgets('sürüm, açıklama, 4 sözleşme + Yardım al satırları; Talebim yalnız jeton varsa', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(AboutPage(session: sess(FakeBackend()))));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.text('BÜ Kampüs'), findsOneWidget);
      expect(find.textContaining('bağımsız bir öğrenci uygulamasıdır'), findsOneWidget);
      expect(find.text('Yardım al'), findsOneWidget);
      expect(find.text('Talebim'), findsNothing);
      expect(find.byType(InkWell), findsAtLeastNWidgets(5));
      await unmount(tester);
    });
  });

  group('320 dp / 1.3x yazı', () {
    final pages = <String, Widget Function(Session s)>{
      'form': (s) => HelpFormPage(session: s),
      'kod': (s) => HelpCodePage(session: s, email: 'ad.soyad@bingol.edu.tr', resend: () async {}),
      'talep': (s) => HelpTrackPage(session: s, token: 't'),
      'hakkında': (s) => AboutPage(session: s),
    };
    for (final e in pages.entries) {
      for (final rtl in [false, true]) {
        for (final br in Brightness.values) {
          testWidgets('${e.key} ${br.name}${rtl ? ' rtl' : ''}', (tester) async {
            useScreen(tester, kPhoneSmall);
            LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
            addTearDown(() => LocaleController.current = null);
            final b = FakeBackend()..on('/public/support/track', detail);
            await tester.pumpWidget(buildApp(
              Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
                    child: e.value(sess(b)),
                  ),
                ),
              ),
              brightness: br,
              size: kPhoneSmall,
            ));
            await settle(tester, const Duration(milliseconds: 1200));
            final err = tester.takeException();
            if (err != null) fail('$err');
            await unmount(tester);
            final err2 = tester.takeException();
            if (err2 != null) fail('$err2');
          });
        }
      }
    }
  });
}
