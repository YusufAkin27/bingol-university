import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/auth/forgot_password_page.dart';
import 'package:bu_kampus/features/auth/widgets/auth_ref.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/new_password_page.dart';
import 'package:bu_kampus/features/auth/otp_code_boxes.dart';
import 'package:bu_kampus/features/auth/register_page.dart';
import 'package:bu_kampus/features/auth/reset_code_page.dart';
import 'package:bu_kampus/features/auth/reset_success_page.dart';
import 'package:bu_kampus/features/auth/verify_code_page.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/news/news_detail_page.dart';
import 'package:bu_kampus/features/news/news_list_page.dart';
import 'package:bu_kampus/features/news/news_tile.dart';
import 'package:bu_kampus/features/shell/app_shell.dart';
import 'package:bu_kampus/features/system/gate_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

SemanticsHandle sem(WidgetTester t) => t.ensureSemantics();

/// Tembel (görünür olunca yüklenen) Gündem bölümüne kadar kaydırır.
Future<void> toNews(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Öne Çıkan Haberler'), 300, scrollable: find.byType(Scrollable).first);
  await settle(tester, const Duration(seconds: 1));
}

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split(String.fromCharCode(10)).take(40).join(String.fromCharCode(10))}');
}

/// Tema x ekran boyutu matrisinde sayfayı çizer; istisna/taşma olmamalı.
void matrix(String name, Widget Function() page,
    {void Function(FakeBackend b)? setup, Duration settleFor = const Duration(milliseconds: 600)}) {
  for (final br in Brightness.values) {
    for (final size in kPhoneSizes) {
      testWidgets('$name | ${br.name} ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        useScreen(tester, size);
        final b = FakeBackend();
        setup?.call(b);
        _b = b;
        final prev = FlutterError.onError;
        final seen = <String>[];
        FlutterError.onError = (d) {
          final t = d.toString();
          seen.add(t.split(String.fromCharCode(10)).where((l) => l.contains('file:///') || l.contains('overflowed') || l.contains('creator') || l.contains('relevant')).take(6).join(String.fromCharCode(10)));
          prev?.call(d);
        };
        await tester.pumpWidget(buildApp(page(), brightness: br, size: size));
        await settle(tester, settleFor);
        await unmount(tester);
        FlutterError.onError = prev;
        if (seen.isNotEmpty) {
          tester.takeException();
          fail(seen.first);
        }
      });
    }
  }
}

FakeBackend _b = FakeBackend();

void main() {
  setUpAll(loadTestFonts);
  FakeBackend newB() => _b = FakeBackend();

  // ---------------- AUTH ----------------
  group('auth ekranlari matris', () {
    matrix('login', () => LoginPage(session: makeSession(_b, signedIn: false)));
    matrix('register', () => RegisterPage(session: makeSession(_b, signedIn: false)));
    matrix('forgot', () => ForgotPasswordPage(session: makeSession(_b, signedIn: false)));
    matrix('verify', () => VerifyCodePage(session: makeSession(_b, signedIn: false), email: 'ayse@bingol.edu.tr'));
    matrix('resetCode', () => ResetCodePage(session: makeSession(_b, signedIn: false), email: 'ayse@bingol.edu.tr'));
    matrix(
        'newPassword',
        () => NewPasswordPage(
            session: makeSession(_b, signedIn: false), email: 'ayse@bingol.edu.tr', resetToken: 'tok'));
  });

  group('login', () {
    testWidgets('bos gonderim dogrulama hatasi gosterir, istek atmaz', (tester) async {
      final b = newB();
      await tester.pumpWidget(buildApp(LoginPage(session: makeSession(b, signedIn: false))));
      await tester.tap(find.text('Giriş yap'));
      await tester.pump();
      expect(find.text('Okul numaranızı veya e-posta adresinizi girin.'), findsOneWidget);
      expect(find.text('Şifrenizi girin.'), findsOneWidget);
      expect(b.count('/auth/login'), 0);
      noErr(tester);
    });

    testWidgets('yanlis sifre sunucu mesajini gosterir, dugme tekrar aktif', (tester) async {
      final b = newB()..fail('/auth/login', status: 401, code: 'INVALID_CREDENTIALS', message: 'E-posta veya şifre hatalı.');
      await tester.pumpWidget(buildApp(LoginPage(session: makeSession(b, signedIn: false))));
      await tester.enterText(find.byType(TextFormField).at(0), 'ayse@bingol.edu.tr');
      await tester.enterText(find.byType(TextFormField).at(1), 'Sifre1234');
      await tester.tap(find.text('Giriş yap'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('E-posta veya şifre hatalı.'), findsOneWidget);
      expect(tester.widget<RefButton>(find.widgetWithText(RefButton, 'Giriş yap')).onPressed, isNotNull);
      noErr(tester);
    });

    testWidgets('ag hatasi yerel metin gosterir', (tester) async {
      final b = newB()..network('/auth/login');
      await tester.pumpWidget(buildApp(LoginPage(session: makeSession(b, signedIn: false))));
      await tester.enterText(find.byType(TextFormField).at(0), 'ayse@bingol.edu.tr');
      await tester.enterText(find.byType(TextFormField).at(1), 'Sifre1234');
      await tester.tap(find.text('Giriş yap'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.textContaining('Sunucuya ulaşılamadı'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('EMAIL_NOT_VERIFIED dogrulama ekranina gider ve kodu yeniden gonderir', (tester) async {
      final b = newB()..fail('/auth/login', status: 403, code: 'EMAIL_NOT_VERIFIED');
      await tester.pumpWidget(buildApp(LoginPage(session: makeSession(b, signedIn: false))));
      await tester.enterText(find.byType(TextFormField).at(0), 'ayse@bingol.edu.tr');
      await tester.enterText(find.byType(TextFormField).at(1), 'Sifre1234');
      await tester.tap(find.text('Giriş yap'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('E-postanızı doğrulayın'), findsOneWidget);
      expect(b.count('/auth/resend-code'), 1);
      await unmount(tester);
      noErr(tester);
    });

    testWidgets('sifremi unuttum ve kayit ol sayfalarina gecer', (tester) async {
      final h = sem(tester);
      final b = newB();
      await tester.pumpWidget(buildApp(LoginPage(session: makeSession(b, signedIn: false))));
      await tester.tap(find.text('Şifremi unuttum'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(ForgotPasswordPage), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Geri'));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.ensureVisible(find.text('Kayıt ol'));
      await tester.tap(find.text('Kayıt ol'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(RegisterPage), findsOneWidget);
      await unmount(tester);
      noErr(tester);
      h.dispose();
    });
  });

  group('register', () {
    testWidgets('akademik bilgi girilmeden ilerlenmez; istek atilmaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = newB();
      await tester.pumpWidget(buildApp(RegisterPage(session: makeSession(b, signedIn: false))));
      await tester.ensureVisible(find.text('Devam'));
      await tester.tap(find.text('Devam'));
      await tester.pump();
      expect(b.count('/auth/register'), 0);
      expect(find.text('Adım 1/3'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('sunucu hatasi (500) mesaj olarak gosterilir', (tester) async {
      useScreen(tester, const Size(390, 1800));
      final b = newB()..fail('/auth/register', status: 500);
      fakeCatalog(b);
      await tester.pumpWidget(buildApp(RegisterPage(session: makeSession(b, signedIn: false))));
      await settle(tester, const Duration(milliseconds: 300));
      await fillRegister(tester);
      await tester.tap(find.text('Kayıt ol').last);
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.count('/auth/register'), 1);
      expect(find.textContaining('Bir sorun oluştu'), findsOneWidget);
      noErr(tester);
    });
  });

  group('sifremi unuttum: minimal metin', () {
    const old = [
      'spam',
      'güvenlik için',
      '10 dakika',
      'Adres kayıtlıysa',
      'Hatırladınız mı',
      'Kod doğrulandı',
      'şifre sıfırlamayı',
      'Yeni kod için',
    ];
    void noOld() {
      for (final o in old) {
        expect(find.textContaining(o, findRichText: true), findsNothing, reason: o);
      }
    }

    testWidgets('tum adimlar kisa; akis e-posta -> kod -> yeni sifre calisir', (tester) async {
      final b = newB()..on('/auth/verify-reset-code', {'resetToken': 'tok'});
      final s = makeSession(b, signedIn: false);
      await tester.pumpWidget(buildApp(ForgotPasswordPage(session: s)));
      expect(find.text('Şifrenizi mi unuttunuz?'), findsOneWidget);
      noOld();
      await tester.enterText(find.byType(TextFormField), 'ayse@bingol.edu.tr');
      await tester.tap(find.text('Kod gönder'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(ResetCodePage), findsOneWidget);
      expect(find.text('ayse@bingol.edu.tr adresine gönderdiğimiz 6 haneli kodu girin.'), findsOneWidget);
      expect(find.textContaining('Yeniden gönder (60 sn)'), findsOneWidget);
      noOld();
      await tester.enterText(find.byType(EditableText).first, '123456');
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(NewPasswordPage), findsOneWidget);
      expect(find.text('Yeni şifre'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      noOld();
      await unmount(tester);
      noErr(tester);
    });
  });

  group('verify / reset', () {
    testWidgets('verify: eksik kod hata, geri sayim biter ve yeniden gonder dugmesi cikar', (tester) async {
      final b = newB();
      await tester.pumpWidget(buildApp(VerifyCodePage(session: makeSession(b, signedIn: false), email: 'a@bingol.edu.tr')));
      await tester.ensureVisible(find.text('Doğrula'));
      await tester.tap(find.text('Doğrula'));
      await tester.pump();
      expect(find.text('6 haneli kodu girin.'), findsOneWidget);
      expect(find.textContaining('60 sn'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
      expect(find.text('Kodu yeniden gönder'), findsOneWidget);
      await tester.ensureVisible(find.text('Kodu yeniden gönder'));
      await tester.tap(find.text('Kodu yeniden gönder'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Yeni kod gönderildi.'), findsOneWidget);
      expect(find.textContaining('60 sn'), findsOneWidget);
      await unmount(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('verify: yanlis kod sunucu hatasini gosterir', (tester) async {
      final b = newB()..fail('/auth/verify-email', status: 400, code: 'INVALID_CODE', message: 'Kod geçersiz.');
      final c = TextEditingController();
      addTearDown(c.dispose);
      // Kayıt şifresi bellekte: parola alanı çıkmaz, doğrulama isteğine şifre eklenir.
      final s = makeSession(b, signedIn: false)..rememberCredentials('a@bingol.edu.tr', 'Sifre1234');
      await tester.pumpWidget(buildApp(VerifyCodePage(session: s, email: 'a@bingol.edu.tr')));
      expect(find.text('Kayıtta belirlediğiniz şifre'), findsNothing);
      await tester.enterText(find.byType(EditableText).first, '123456');
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Kod geçersiz.'), findsOneWidget);
      expect((b.bodies['POST /auth/verify-email'] as Map)['password'], 'Sifre1234');
      await unmount(tester);
      noErr(tester);
    });

    testWidgets('verify: kayit sifresi bellekte yoksa parola kaniti istenir ve istege eklenir', (tester) async {
      final b = newB()..on('/auth/verify-email', {'accessToken': 'a', 'refreshToken': 'r'});
      await tester.pumpWidget(buildApp(VerifyCodePage(session: makeSession(b, signedIn: false), email: 'a@bingol.edu.tr')));
      expect(find.text('Kayıtta belirlediğiniz şifre'), findsOneWidget);
      // Şifre boşken kod tamamlansa da istek gitmez
      await tester.enterText(find.byType(EditableText).first, '123456');
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Kayıtta belirlediğiniz şifreyi girin.'), findsOneWidget);
      expect(b.count('POST /auth/verify-email'), 0);
      await tester.enterText(find.byType(TextFormField).first, 'Sifre1234');
      await tester.pump();
      await tester.ensureVisible(find.text('Doğrula'));
      await tester.tap(find.text('Doğrula'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.count('POST /auth/verify-email'), 1);
      expect((b.bodies['POST /auth/verify-email'] as Map)['password'], 'Sifre1234');
      await unmount(tester);
    });

    testWidgets('resetCode: dogru kod yeni sifre ekranina gecer', (tester) async {
      final b = newB()..on('/auth/verify-reset-code', {'resetToken': 'tok'});
      await tester.pumpWidget(buildApp(ResetCodePage(session: makeSession(b, signedIn: false), email: 'a@bingol.edu.tr')));
      await tester.enterText(find.byType(EditableText).first, '123456');
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(NewPasswordPage), findsOneWidget);
      await unmount(tester);
      noErr(tester);
    });

    testWidgets('resetCode: yanlis kod hata gosterir ve kutuyu temizler', (tester) async {
      final b = newB()..fail('/auth/verify-reset-code', status: 400, code: 'INVALID_CODE', message: 'Kod geçersiz.');
      await tester.pumpWidget(buildApp(ResetCodePage(session: makeSession(b, signedIn: false), email: 'a@bingol.edu.tr')));
      await tester.enterText(find.byType(EditableText).first, '123456');
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Kod geçersiz.'), findsOneWidget);
      expect(tester.widget<EditableText>(find.byType(EditableText).first).controller.text, '');
      await unmount(tester);
      noErr(tester);
    });

    testWidgets('newPassword: kisa sifre reddedilir; basarida kok ekrana doner', (tester) async {
      final b = newB();
      final s = makeSession(b, signedIn: false);
      await tester.pumpWidget(buildApp(Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
                c, MaterialPageRoute(builder: (_) => NewPasswordPage(session: s, email: 'a@bingol.edu.tr', resetToken: 't'))),
            child: const Text('git'),
          ),
        ),
      )));
      await tester.tap(find.text('git'));
      await settle(tester, const Duration(milliseconds: 500));
      final f = find.byType(TextFormField);
      expect(f, findsNWidgets(2));
      await tester.enterText(f.at(0), 'kisa');
      await tester.ensureVisible(find.text('Şifreyi güncelle'));
      await tester.tap(find.text('Şifreyi güncelle'));
      await tester.pump();
      expect(find.text('Şifre en az 8 karakter olmalı.'), findsOneWidget);
      await tester.enterText(f.at(0), 'Sifre1234');
      await tester.enterText(f.at(1), 'Sifre1234');
      await tester.ensureVisible(find.text('Şifreyi güncelle'));
      await tester.tap(find.text('Şifreyi güncelle'));
      await settle(tester, const Duration(milliseconds: 800));
      // Başarı ekranı: çizilen tik + "Şifreniz güncellendi"; tek eylem girişe (kök ekrana) döner.
      expect(find.byType(ResetSuccessPage), findsOneWidget);
      expect(find.text('Şifreniz güncellendi'), findsOneWidget);
      await tester.tap(find.text('Girişe dön'));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('git'), findsOneWidget);
      expect(find.byType(ResetSuccessPage), findsNothing);
      noErr(tester);
    });

    testWidgets('forgot: gecersiz e-posta reddedilir; gecerli e-posta kod ekranina gider', (tester) async {
      final b = newB();
      await tester.pumpWidget(buildApp(ForgotPasswordPage(session: makeSession(b, signedIn: false))));
      await tester.tap(find.widgetWithText(RefButton, 'Kod gönder'));
      await tester.pump();
      expect(find.text('Okul numaranızı veya e-posta adresinizi girin.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'ayse@bingol.edu.tr');
      await tester.tap(find.widgetWithText(RefButton, 'Kod gönder'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(ResetCodePage), findsOneWidget);
      await unmount(tester);
      noErr(tester);
    });
  });

  testWidgets('OtpCodeBoxes 6 hane sonunda onCompleted cagirir', (tester) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    var done = 0;
    await tester.pumpWidget(buildApp(Scaffold(body: OtpCodeBoxes(controller: c, onCompleted: () => done++))));
    await tester.enterText(find.byType(EditableText), '12345');
    await tester.pump();
    expect(done, 0);
    await tester.enterText(find.byType(EditableText), '123456');
    await tester.pump();
    expect(done, 1);
    await tester.enterText(find.byType(EditableText), '12a4b6789');
    await tester.pump();
    expect(c.text.length <= 6, isTrue);
    noErr(tester);
  });

  // ---------------- SYSTEM ----------------
  group('gate ekranlari', () {
    matrix('UpdateRequired', () => const UpdateRequiredScreen(storeUrl: 'https://apps.apple.com/x'));
    matrix('UpdateRequired(url yok)', () => const UpdateRequiredScreen(storeUrl: null));
    matrix(
        'TopStrip+UpdateNotice',
        () => Scaffold(
              body: Column(children: [
                TopStrip(icon: Icons.build, text: 'Sistem bakımda. ' * 8, danger: true),
                const TopStrip(icon: Icons.wifi_off, text: 'Çevrimdışı'),
                UpdateNotice(latest: '2.0.0', storeUrl: 'https://x.example/a', onClose: () {}),
              ]),
            ));

    testWidgets('http store url butonu gostermez', (tester) async {
      await tester.pumpWidget(buildApp(const UpdateRequiredScreen(storeUrl: 'http://x.example')));
      expect(find.text('Mağazada aç'), findsNothing);
      await tester.pumpWidget(buildApp(const UpdateRequiredScreen(storeUrl: 'https://x.example')));
      expect(find.text('Mağazada aç'), findsOneWidget);
    });

    testWidgets('UpdateNotice kapat geri cagrisini calistirir', (tester) async {
      var closed = false;
      await tester.pumpWidget(buildApp(Scaffold(
          body: UpdateNotice(latest: null, storeUrl: null, onClose: () => closed = true))));
      expect(find.text('Yeni sürüm mevcut.'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      expect(closed, isTrue);
    });
  });

  // ---------------- NEWS ----------------
  group('news', () {
    final items = [
      newsItem(1, title: 'Çok uzun bir haber başlığı ' * 6),
      newsItem(2, type: 'ETKINLIK', eventDate: '2026-11-03'),
      newsItem(3, type: 'DUYURU', title: 'Uzunkelime' * 20),
    ];
    matrix(
        'tile/featured',
        () => Scaffold(
              body: ListView(padding: const EdgeInsets.all(20), children: [
                NewsFeaturedCard(item: items[0], saved: true, onTap: () {}, onToggleSave: () {}),
                for (final n in items) NewsTile(item: n, onTap: () {}, saved: false, onToggleSave: () {}),
              ]),
            ));

    matrix('detail dolu', () => NewsDetailPage(session: makeSession(_b), item: newsItem(2, type: 'ETKINLIK', eventDate: '2026-11-03')),
        setup: (b) => b.on('/news/2', {'id': 2, 'content': 'Birinci paragraf.\n\nİkinci paragraf ' * 5, 'url': 'https://www.bingol.edu.tr/x'}));
    matrix('detail hata', () => NewsDetailPage(session: makeSession(_b), item: newsItem(5)),
        setup: (b) => b.fail('/news/5'));
    matrix('detail bos icerik', () => NewsDetailPage(session: makeSession(_b), item: newsItem(6)),
        setup: (b) => b.on('/news/6', {'id': 6, 'content': null}));

    testWidgets('detail: yukleniyor -> icerik', (tester) async {
      final b = newB()
        ..delay = const Duration(milliseconds: 200)
        ..on('/news/1', {'id': 1, 'content': 'Gövde metni.', 'url': 'https://www.bingol.edu.tr/x'});
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(NewsDetailPage(session: makeSession(b), item: newsItem(1), saved: false)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(CircularProgressIndicator), findsNothing); // iskelet (K3)
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Gövde metni.'), findsOneWidget);
      expect(find.text('Kaynak sayfada aç'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('detail: 500 -> hata + yeniden dene icerigi getirir', (tester) async {
      final b = newB()..fail('/news/1');
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(NewsDetailPage(session: makeSession(b), item: newsItem(1), saved: false)));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Yeniden dene'), findsOneWidget);
      b.on('/news/1', {'id': 1, 'content': 'Geldi.'});
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Geldi.'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('detail: ag hatasi -> yeniden dene', (tester) async {
      final b = newB()..network('/news/1');
      await tester.pumpWidget(buildApp(NewsDetailPage(session: makeSession(b), item: newsItem(1), saved: false)));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Yeniden dene'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('detail: favori geri alinir (kayit basarisiz)', (tester) async {
      final b = newB()
        ..on('/news/1', {'id': 1, 'content': 'x'})
        ..fail('/bookmarks/news/1');
      await tester.pumpWidget(buildApp(NewsDetailPage(session: makeSession(b), item: newsItem(1))));
      await settle(tester, const Duration(milliseconds: 400));
      b.delay = const Duration(milliseconds: 300);
      await tester.tap(find.byTooltip('Favorilere ekle'));
      await tester.pump();
      expect(find.byTooltip('Favorilerden çıkar'), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byTooltip('Favorilere ekle'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('detail: imageUrl bozuksa cokmez', (tester) async {
      final b = newB()..on('/news/1', {'id': 1, 'content': 'x'});
      await tester.pumpWidget(buildApp(NewsDetailPage(
          session: makeSession(b), item: newsItem(1, imageUrl: 'https://img.invalid/a.jpg'), saved: false)));
      await settle(tester, const Duration(milliseconds: 500));
      noErr(tester);
    });
  });


  // ---------------- HOME ----------------
  group('home', () {
    final event = {
      'id': 7,
      'source': 'USER',
      'title': 'Çok uzun bir etkinlik başlığı ' * 4,
      'startsAt': DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String(),
      'location': 'Merkez Kampüs Konferans Salonu ' * 3,
      'goingCount': 3,
      'capacity': 50,
    };
    void full(FakeBackend b) {
      b.on('/events/featured', event);
      b.on('/me/summary', {'unreadNotifications': 3, 'unreadMessages': 120, 'communities': 2, 'upcomingEvents': 1});
      b.on('/menu/today', {
        'date': '2026-10-26',
        'items': ['Mercimek çorbası', 'Pilav', 'Ayran'],
      });
      b.on('/me/communities*', {
        'items': [
          {'id': 1, 'name': 'Bilgisayar Kulübü ' * 3, 'memberCount': 20}
        ],
        'nextCursor': null
      });
      b.on('/news*', newsPage([newsItem(1), newsItem(2, type: 'DUYURU')]));
      b.on('/app/info', {
        'maintenance': {'enabled': true, 'message': 'Sistem bakımda ' * 5},
        'banner': {'text': 'Duyuru metni ' * 6, 'url': 'https://x.example'}
      });
    }

    Widget home() => Scaffold(body: HomeTab(session: makeSession(_b), onOpenTab: (i, {newsType}) {}));

    matrix('dolu', home, setup: full);
    matrix('bos', home);
    matrix('hata', home, setup: (b) => b.offline = true, settleFor: const Duration(seconds: 2));
    matrix('hata500', home, setup: (b) {
      b.fail('/app/info');
      b.fail('/menu/today');
      b.fail('/me/summary');
      b.fail('/events/featured');
    }, settleFor: const Duration(seconds: 2));

    testWidgets('yukleniyor -> dolu', (tester) async {
      final b = newB()
        ..delay = const Duration(milliseconds: 200);
      full(b);
      await tester.pumpWidget(buildApp(home()));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(CircularProgressIndicator), findsNothing); // iskelet (K3)
      await settle(tester, const Duration(seconds: 2));
      await toNews(tester);
      expect(find.text('Öne Çıkan Haberler'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('tum cekirdek istekler dusunce hata + yeniden dene', (tester) async {
      final b = newB()
        ..fail('/app/info')
        ..fail('/menu/today')
        ..fail('/me/summary')
        ..fail('/events/featured');
      await tester.pumpWidget(buildApp(home()));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Yeniden dene'), findsOneWidget);
      b.reset('/app/info');
      b.reset('/menu/today');
      b.reset('/me/summary');
      b.reset('/events/featured');
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Yeniden dene'), findsNothing);
      await toNews(tester);
      expect(find.text('Öne Çıkan Haberler'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('bos durum: yaklasan etkinlik yok ve haber yok metinleri', (tester) async {
      useScreen(tester, const Size(390, 2400));
      final b = newB();
      await tester.pumpWidget(buildApp(home()));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Yaklaşan etkinlik yok'), findsOneWidget);
      expect(find.text('Henüz içerik yok.'), findsOneWidget);
      expect(b.count('/me/communities'), 0); // uyelik yoksa istenmez
      noErr(tester);
    });

    testWidgets('haber bolumu hata -> Tekrar dene', (tester) async {
      final b = newB()..fail('/news*');
      await tester.pumpWidget(buildApp(home()));
      await settle(tester, const Duration(seconds: 2));
      await toNews(tester);
      expect(find.text('İçerik yüklenemedi.'), findsOneWidget);
      b.on('/news*', newsPage([newsItem(9)]));
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Haber başlığı 9'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('Tumu baglantisi haber listesini acar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = newB();
      full(b);
      await tester.pumpWidget(buildApp(Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {}))));
      await settle(tester, const Duration(seconds: 1));
      await toNews(tester);
      final all = find.text('Tümü');
      await tester.ensureVisible(all.first);
      await tester.tap(all.first);
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(NewsListPage), findsOneWidget);
      noErr(tester);
    });

    testWidgets('RSVP: hata olursa iyimser guncelleme geri alinir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = newB();
      full(b);
      b.fail('/events/7/rsvp');
      await tester.pumpWidget(buildApp(home()));
      await settle(tester, const Duration(seconds: 1));
      final btn = find.text('Katıl');
      if (btn.evaluate().isNotEmpty) {
        await tester.tap(btn);
        await settle(tester, const Duration(seconds: 1));
        expect(find.text('Katıl'), findsOneWidget);
      }
      noErr(tester);
    });

    testWidgets('sayfa kaldirilinca istisna yok', (tester) async {
      final b = newB()..delay = const Duration(seconds: 2);
      full(b);
      await tester.pumpWidget(buildApp(home()));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 40));
      noErr(tester);
    });
  });

  // ---------------- SHELL ----------------
  group('shell', () {
    Widget shell() => AppShell(session: makeSession(_b), themeController: ThemeController());

    matrix('AppShell', shell, settleFor: const Duration(seconds: 1));

    for (final size in kPhoneSizes) {
      testWidgets('FloatingNav ${size.width.toInt()} tum sekmeler', (tester) async {
        final h = sem(tester);
        useScreen(tester, size);
        var idx = 0;
        final badge = ValueNotifier<int>(150);
        addTearDown(badge.dispose);
        await tester.pumpWidget(buildApp(StatefulBuilder(
          builder: (c, set) => Scaffold(
              bottomNavigationBar:
                  FloatingNav(index: idx, onChanged: (i) => set(() => idx = i), chatBadge: badge)),
        ), size: size));
        for (var i = 0; i < 5; i++) {
          await tester.tap(find.bySemanticsLabel(RegExp(['Ana Sayfa', 'Keşfet', 'Sohbet', 'Kulüpler', 'Profil'][i])).first);
          await tester.pump(const Duration(milliseconds: 300));
          expect(idx, i);
          noErr(tester);
        }
        h.dispose();
      });
    }

    testWidgets('sekme gecisi: her sekme acilir, zamanlayici dispose edilir', (tester) async {
      final h = sem(tester);
      useScreen(tester, kPhoneMedium);
      final b = newB();
      await tester.pumpWidget(buildApp(shell()));
      await settle(tester, const Duration(seconds: 1));
      for (final label in ['Keşfet', 'Sohbet', 'Kulüpler', 'Profil', 'Ana Sayfa']) {
        await tester.tap(find.bySemanticsLabel(label).first);
        await settle(tester, const Duration(milliseconds: 800));
        noErr(tester);
      }
      expect(b.count('/me/summary') >= 1, isTrue);
      await unmount(tester);
      noErr(tester);
      h.dispose();
    });

    testWidgets('1 dk zamanlayici rozetleri tazeler', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = newB();
      final s = makeSession(b);
      await tester.pumpWidget(buildApp(AppShell(session: s, themeController: ThemeController())));
      await settle(tester, const Duration(seconds: 1));
      b.on('/me/summary', {'unreadNotifications': 4, 'unreadMessages': 2, 'communities': 0});
      await tester.pump(const Duration(minutes: 1, seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(s.badges.chat.value, 2);
      expect(s.badges.notifications.value, 4);
      await unmount(tester);
      noErr(tester);
    });
  });
}
