
import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/analytics.dart';
import 'package:bu_kampus/core/error_log.dart';
import 'package:bu_kampus/core/platform/image_service.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/auth_widgets.dart';
import 'package:bu_kampus/features/auth/widgets/auth_controls.dart';
import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_qr_page.dart';
import 'package:bu_kampus/features/posts/social_api.dart';
import 'package:bu_kampus/features/system/gate_views.dart';
import 'package:bu_kampus/features/auth/register_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'support/fake_app.dart';

/// 1x1 PNG.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
  0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63,
  0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

class _FakeImages extends ImageService {
  _FakeImages() : super(picker: ImagePicker());

  @override
  Future<PreparedImage?> pickPrepared(ImageSource source, {bool avatar = false}) async => PreparedImage(_png, 'image/png');
}

void main() {
  setUpAll(loadTestFonts);

  group('Takip uçları (H5): gerçek sözleşme', () {
    test('followStats GET /users/{id} profil alanlarını okur (follow-stats çağrılmaz)', () async {
      final b = FakeBackend()
        ..on('/users/9', {'id': 9, 'followerCount': 12, 'followingCount': 3, 'followedByMe': true, 'followsMe': true});
      final st = await SocialApi(makeSession(b)).followStats(9);
      expect(st.followers, 12);
      expect(st.following, 3);
      expect(st.followedByMe, isTrue);
      expect(st.followsMe, isTrue);
      expect(b.requests, ['GET /users/9']);
    });

    test('eski sunucuda followsMe yoksa false', () async {
      final b = FakeBackend()..on('/users/9', {'id': 9, 'followerCount': 1, 'followingCount': 0, 'followedByMe': false});
      final st = await SocialApi(makeSession(b)).followStats(9);
      expect(st.followsMe, isFalse);
    });

    test('follow = POST, unfollow = DELETE; {following, followerCount} çözülür', () async {
      final b = FakeBackend()
        ..handlers.add((req, path) {
          if (path != '/users/9/follow') return null;
          return req.method == 'POST'
              ? const FakeResult.json({'following': true, 'followerCount': 5})
              : const FakeResult.json({'following': false, 'followerCount': 4});
        });
      final api = SocialApi(makeSession(b));
      final a = await api.follow(9);
      expect(a.following, isTrue);
      expect(a.followerCount, 5);
      final u = await api.unfollow(9);
      expect(u.following, isFalse);
      expect(u.followerCount, 4);
      expect(b.requests, ['POST /users/9/follow', 'DELETE /users/9/follow']);
    });
  });

  group('errorText: yeni backend hata kodları', () {
    AppLocalizations l(String c) => lookupAppLocalizations(Locale(c));

    test('her kod için tr/en/ar yerel metin vardır ve boş değildir', () {
      const codes = {
        'EMAIL_ALIAS_NOT_ALLOWED': 400,
        'PASSWORD_TOO_LONG': 400,
        'PAYLOAD_TOO_LARGE': 413,
        'UPLOAD_BUSY': 429,
        'UPLOAD_QUOTA_EXCEEDED': 429,
        'MAIL_QUOTA_EXHAUSTED': 503,
        'DB_TIMEOUT': 503,
        'LEGAL_REACCEPT_REQUIRED': 403,
      };
      for (final lang in ['tr', 'en', 'ar']) {
        final seen = <String>{};
        for (final e in codes.entries) {
          final t = knownErrorText(ApiError(e.value, e.key, ''), l(lang));
          expect(t, isNotNull, reason: '${e.key} $lang');
          expect(t!.trim(), isNotEmpty);
          seen.add(t);
        }
        expect(seen.length, greaterThanOrEqualTo(7), reason: 'kodlar ayrı metinlere eşlenmeli ($lang)');
      }
    });

    test('413 kodsuz (proxy) da PAYLOAD_TOO_LARGE metni', () {
      expect(knownErrorText(ApiError(413, 'HTTP_413', ''), l('tr')), l('tr').errPayloadTooLarge);
    });

    test('429 Retry-After gösterilir', () {
      expect(knownErrorText(ApiError(429, 'UPLOAD_QUOTA_EXCEEDED', '', retryAfter: 30), l('tr')),
          'Çok fazla yükleme yaptınız. Biraz sonra tekrar deneyin. 30 sn sonra tekrar deneyin.');
      expect(knownErrorText(ApiError(429, 'UPLOAD_BUSY', '', retryAfter: 300), l('en')), contains('5 min'));
      expect(retryAfterText(null, l('tr')), isNull);
      expect(retryAfterText(0, l('tr')), isNull);
      expect(retryAfterText(45, l('tr')), '45 sn sonra tekrar deneyin.');
      expect(retryAfterText(120, l('tr')), '2 dk sonra tekrar deneyin.');
    });

    test('errorText: bilinen kod sunucu mesajından önce, genel 429 + Retry-After, bilinmeyen kod mesajı korur', () {
      expect(errorText(ApiError(503, 'MAIL_QUOTA_EXHAUSTED', 'sunucu metni')), contains('doğrulama kodu gönderemiyoruz'));
      expect(errorText(ApiError(429, 'RATE_LIMITED', '', retryAfter: 20)), 'Çok fazla deneme. Lütfen biraz bekleyin. 20 sn sonra tekrar deneyin.');
      expect(errorText(ApiError(429, 'RATE_LIMITED', 'Çok sık deniyorsunuz', retryAfter: 20)), 'Çok sık deniyorsunuz 20 sn sonra tekrar deneyin.');
      expect(errorText(ApiError(409, 'EMAIL_TAKEN', 'Kayıtlı')), 'Kayıtlı');
      expect(errorText(ApiError(0, 'NETWORK', '')), contains('Sunucuya ulaşılamadı'));
    });

    testWidgets('şifre doğrulayıcı 72 BAYT sınırını uygular (ö, ş = 2 bayt)', (tester) async {
      late String? Function(String?) v;
      await tester.pumpWidget(buildApp(Builder(builder: (c) {
        v = newPasswordValidator(c);
        return const SizedBox();
      })));
      expect(v('a' * 72), isNull);
      expect(v('ö' * 36), isNull); // 72 bayt
      expect(v('ö' * 37), contains('72 bayt'));
      expect(v('a' * 73), isNotNull);
    });
  });

  group('Kayıt: EMAIL_ALIAS_NOT_ALLOWED', () {
    testWidgets('+ etiketi istemcide alan altında reddedilir; istek atılmaz', (tester) async {
      useScreen(tester, const Size(390, 1800));
      final b = FakeBackend();
      fakeCatalog(b);
      await tester.pumpWidget(buildApp(RegisterPage(session: makeSession(b, signedIn: false))));
      await settle(tester, const Duration(milliseconds: 300));
      await fillAcademic(tester);
      await tester.tap(find.text('Devam'));
      await tester.pump(const Duration(milliseconds: 400));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Ayşe Yılmaz');
      await tester.enterText(fields.at(1), 'ayse+etiket@bingol.edu.tr');
      await tester.pump();
      await tester.tap(find.text('Devam'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('E-posta adresinde + etiketi kullanılamaz.'), findsOneWidget);
      expect(find.text('Adım 2/3'), findsOneWidget);
      expect(b.count('/auth/register'), 0);
      await unmount(tester);
    });

    testWidgets('sunucu 400 EMAIL_ALIAS_NOT_ALLOWED: e-posta adımına dönülür, mesaj alan altında', (tester) async {
      useScreen(tester, const Size(390, 1800));
      final b = FakeBackend()..fail('/auth/register', status: 400, code: 'EMAIL_ALIAS_NOT_ALLOWED', message: 'x');
      fakeCatalog(b);
      await tester.pumpWidget(buildApp(RegisterPage(session: makeSession(b, signedIn: false))));
      await settle(tester, const Duration(milliseconds: 300));
      await fillRegister(tester);
      await tester.tap(find.text('Kayıt ol').last);
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.count('/auth/register'), 1);
      expect(find.text('Adım 2/3'), findsOneWidget);
      expect(find.text('E-posta adresinde + etiketi kullanılamaz.'), findsOneWidget);
      // E-posta değişince hata kalkar.
      await tester.enterText(find.byType(TextFormField).at(1), 'ayse2@bingol.edu.tr');
      await tester.pump();
      expect(find.text('E-posta adresinde + etiketi kullanılamaz.'), findsNothing);
      await unmount(tester);
    });
  });

  group('Kulüp gönderisi: metin zorunlu (M39)', () {
    FakeBackend be() => FakeBackend()
      ..on('/communities/7', {
        'id': 7,
        'name': 'Robotik',
        'description': 'x',
        'category': 'Teknoloji',
        'memberCount': 4,
        'visibility': 'PUBLIC',
        'joinPolicy': 'OPEN',
        'myStatus': 'ACTIVE',
        'myRole': 'OWNER',
      })
      ..on('/communities/7/posts*', {'items': [], 'nextCursor': null})
      ..on('/communities/7/requests*', {'items': [], 'nextCursor': null})
      ..on('/events*', {'items': [], 'nextCursor': null});

    testWidgets('yalnız görsel: satır içi uyarı, upload/POST atılmaz; metin yazınca uyarı kalkar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = be();
      await tester.pumpWidget(buildApp(
          ClubDetailPage(session: makeSession(b), communityId: 7, imageService: _FakeImages()),
          size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('Görsel ekle'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('clubPostTextRequired')), findsOneWidget);
      await tester.tap(find.text('Paylaş'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Görselle paylaşmak için bir yazı da ekleyin.'), findsOneWidget);
      expect(b.requests.where((r) => r.startsWith('POST') || r.contains('upload')), isEmpty);
      await tester.enterText(find.byType(TextField).first, 'Merhaba');
      await tester.pump();
      expect(find.byKey(const ValueKey('clubPostTextRequired')), findsNothing);
      await unmount(tester);
    });

    testWidgets('yalnız metin: POST {text} gönderilir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = be()..on('/communities/7/posts', {'id': 1});
      await tester.pumpWidget(buildApp(ClubDetailPage(session: makeSession(b), communityId: 7), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.enterText(find.byType(TextField).first, 'Merhaba kulüp');
      await tester.pump();
      await tester.tap(find.text('Paylaş'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.bodies['POST /communities/7/posts'], {'text': 'Merhaba kulüp'});
      await unmount(tester);
    });
  });

  group('QR yoklama (L31)', () {
    final event = {
      'id': 5,
      'title': 'Kariyer Günü',
      'startsAt': '2098-11-14T14:00:00',
      'location': 'Salon',
    };
    FakeBackend be() => FakeBackend()
      ..on('/events/5/attendance', <Object>[])
      ..on('/events/5/checkin-code', {
        'code': 'AAA.1',
        'qrPayload': 'bingol-checkin:AAA.1',
        'validForSeconds': 10,
      });

    testWidgets('ilk yükleme hatasında 5 sn sonra otomatik yeniden dener', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = be()..fail('/events/5/checkin-code', status: 500);
      await tester.pumpWidget(buildApp(Etkinlik2QrPage(session: makeSession(b), event: event), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('AAA.1'), findsNothing);
      expect(b.count('GET /events/5/checkin-code'), 1);
      b.on('/events/5/checkin-code', {'code': 'AAA.1', 'qrPayload': 'bingol-checkin:AAA.1', 'validForSeconds': 10});
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 200));
      expect(b.count('GET /events/5/checkin-code'), 2);
      expect(find.text('AAA.1'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('yenileme hatasında eski kodun üstünde hata şeridi + yeniden deneme', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = be();
      await tester.pumpWidget(buildApp(Etkinlik2QrPage(session: makeSession(b), event: event), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('AAA.1'), findsOneWidget);
      b.fail('/events/5/checkin-code', status: 500);
      await tester.pump(const Duration(seconds: 7)); // validFor 10 sn -> 7. sn'de yenileme
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('AAA.1'), findsOneWidget); // kod ekranda kalır
      expect(find.byKey(const ValueKey('et2-qr-error')), findsOneWidget); // hata kartı
      b.on('/events/5/checkin-code', {'code': 'BBB.2', 'qrPayload': 'bingol-checkin:BBB.2', 'validForSeconds': 10});
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('BBB.2'), findsOneWidget);
      expect(find.byKey(const ValueKey('et2-qr-error')), findsNothing);
      await unmount(tester);
    });
  });

  group('Zorunlu güncelleme (L33)', () {
    testWidgets('mağaza adresi yokken de "Tekrar kontrol et" vardır', (tester) async {
      var n = 0;
      await tester.pumpWidget(buildApp(UpdateRequiredScreen(storeUrl: null, onRetry: () => n++)));
      expect(find.text('Güncelle'), findsNothing);
      expect(find.byKey(const ValueKey('update-recheck')), findsOneWidget);
      await tester.tap(find.text('Tekrar kontrol et'));
      expect(n, 1);
    });

    testWidgets('mağaza adresi varken ikisi de görünür; onRetry yoksa düğme yok', (tester) async {
      await tester.pumpWidget(buildApp(UpdateRequiredScreen(storeUrl: 'https://x.example/app', onRetry: () {})));
      expect(find.text('Güncelle'), findsOneWidget);
      expect(find.text('Tekrar kontrol et'), findsOneWidget);
      await tester.pumpWidget(buildApp(const UpdateRequiredScreen(storeUrl: 'https://x.example/app')));
      expect(find.text('Tekrar kontrol et'), findsNothing);
    });
  });

  group('Erişilebilirlik: kontrast ve dokunma hedefi (L34, L35)', () {
    testWidgets('AuthPasswordGuide: güç etiketi renkle değil sözcükle anlatılır; etiket ink belirtecidir ve AA kontrastı sağlar', (tester) async {
      // Stitch v3: zayıf/orta/güçlü için kırmızı/amber/yeşil kullanılmaz; etiket ink rengindedir.
      Future<Color?> labelColor(String pw, Brightness br) async {
        await tester.pumpWidget(buildApp(Scaffold(body: AuthPasswordGuide(password: pw)), brightness: br));
        await tester.pumpAndSettle(); // AnimatedTheme geçişi
        final label = {'Zayıf', 'Orta', 'Güçlü'}.map((s) => find.text(s)).firstWhere((f) => f.evaluate().isNotEmpty);
        return tester.widget<Text>(label).style?.color;
      }

      double ratio(Color a, Color b) {
        final l1 = a.computeLuminance(), l2 = b.computeLuminance();
        return (l1 > l2 ? l1 + .05 : l2 + .05) / (l1 > l2 ? l2 + .05 : l1 + .05);
      }

      for (final (br, tk) in [(Brightness.light, BuTokens.light), (Brightness.dark, BuTokens.dark)]) {
        for (final pw in ['abc', 'abcdefg1', 'Abcdefghijk1!']) {
          final c = await labelColor(pw, br);
          expect(c, tk.ink, reason: '$pw / ${br.name}: etiket rengi ink olmalı');
          expect(c, isNot(tk.danger));
          expect(c, isNot(tk.ok));
        }
        expect(ratio(tk.ink, tk.bg), greaterThanOrEqualTo(4.5));
      }
      // Uyarı bandı metin belirteci (RefBanner warn) hâlâ AA kontrastlı olmalı.
      expect(ratio(BuTokens.light.onWarnSoft, BuTokens.light.bg), greaterThanOrEqualTo(4.5));
      expect(ratio(BuTokens.dark.onWarnSoft, BuTokens.dark.bg), greaterThanOrEqualTo(4.5));
    });

    for (final rtl in [false, true]) {
      testWidgets('BuButton compact: dokunma hedefi >= 44 dp, kenar boşluğundaki dokunuş tek kez çalışır (rtl=$rtl)', (tester) async {
        var n = 0;
        await tester.pumpWidget(buildApp(Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(body: Center(child: BuButton(label: 'Katıl', compact: true, onPressed: () => n++))),
        )));
        final r = tester.getRect(find.byType(BuButton));
        expect(r.height, greaterThanOrEqualTo(44));
        expect(r.width, greaterThanOrEqualTo(44));
        await tester.tapAt(r.center);
        expect(n, 1, reason: 'hapın üstüne dokunuş tek çağrı');
        await tester.tapAt(Offset(r.center.dx, r.top + 2)); // görsel hapın dışındaki 4 dp bant
        expect(n, 2);
        // Anlamsal ağaçta tek düğme.
        expect(find.bySemanticsLabel('Katıl'), findsOneWidget);
      });
    }

    testWidgets('BuButton compact busy/devre dışı iken dokunuş çağırmaz', (tester) async {
      var n = 0;
      await tester.pumpWidget(buildApp(Scaffold(body: Center(child: BuButton(label: 'A', compact: true, busy: true, onPressed: () => n++)))));
      await tester.tapAt(tester.getRect(find.byType(BuButton)).center);
      await tester.tapAt(tester.getRect(find.byType(BuButton)).topCenter + const Offset(0, 1));
      expect(n, 0);
    });
  });

  group('Yerel hata günlüğü (M44, ErrorLog)', () {
    late Session session;
    late FakeBackend backend;
    var clock = DateTime(2026, 10, 28, 12);
    late ErrorLog log;

    setUp(() {
      backend = FakeBackend();
      session = makeSession(backend);
      Analytics.instance.attach(session);
      Analytics.instance.discard();
      clock = DateTime(2026, 10, 28, 12);
      log = ErrorLog(now: () => clock, quiet: true);
    });

    tearDown(() => Analytics.instance.discard());

    test('kayıt yalnız tür/kaynak/ekran/sürüm taşır; mesaj ve yığın yok', () {
      log.currentScreen = '/events/42';
      log.report(StateError('ayse@bingol.edu.tr 05321234567 gizli mesaj'));
      expect(log.entries, hasLength(1));
      final j = log.entries.single.toJson();
      expect(j.keys.toSet(), {'at', 'type', 'source', 'screen', 'version'});
      expect(j['type'], 'StateError');
      expect(j['screen'], '/events/42');
      expect(j.toString(), isNot(contains('@')));
      expect(j.toString(), isNot(contains('gizli')));
    });

    test('geçersiz ekran adı ve kişisel veri benzeri tür adı temizlenir', () {
      expect(ErrorLog.sanitizeScreen('/a b'), isNull);
      expect(ErrorLog.sanitizeScreen('ali@x.com'), isNull);
      expect(ErrorLog.sanitizeScreen('/chat/7'), '/chat/7');
      expect(ErrorLog.sanitizeScreen('x' * 61), isNull);
      expect(ErrorLog.sanitizeType(_Weird()), isNot(contains('@')));
      expect(ErrorLog.sanitizeType(const [1]), isNotEmpty);
    });

    test('oturum açıkken analitiğe anonim app_error olayı gider', () async {
      log.currentScreen = '/news';
      expect(log.report(StateError('x'), source: 'platform'), isTrue);
      await Analytics.instance.flush();
      final body = backend.bodies['POST /analytics/events'] as Map;
      final ev = (body['events'] as List).single as Map;
      expect(ev['name'], 'app_error');
      expect(ev['screen'], '/news');
      expect(ev['props'], {'type': 'StateError', 'source': 'platform', 'version': isNotNull});
    });

    test('oturum kapalıyken olay gitmez, yerel kayıt kalır', () async {
      final out = makeSession(backend, signedIn: false);
      Analytics.instance.attach(out);
      log.report(StateError('x'));
      await Analytics.instance.flush();
      expect(log.entries, hasLength(1));
      expect(backend.count('/analytics/events'), 0);
      Analytics.instance.attach(session);
    });

    test('aynı hata 60 sn içinde tekrar gönderilmez; saatte en çok 10 olay', () {
      expect(log.report(StateError('a')), isTrue);
      expect(log.report(StateError('b')), isFalse); // aynı tür+ekran
      expect(log.entries, hasLength(2)); // yerel günlük yine yazar
      clock = clock.add(const Duration(seconds: 61));
      expect(log.report(StateError('c')), isTrue);
      var sent = 2;
      for (var i = 0; i < 20; i++) {
        clock = clock.add(const Duration(seconds: 61));
        log.currentScreen = '/s$i';
        if (log.report(StateError('d'))) sent++;
      }
      expect(sent, ErrorLog.maxEventsPerHour);
    });

    test('günlük en çok 50 kayıt tutar; report asla fırlatmaz', () {
      for (var i = 0; i < 80; i++) {
        clock = clock.add(const Duration(seconds: 61));
        log.report(i);
      }
      expect(log.entries.length, ErrorLog.maxEntries);
      expect(() => log.report(Object()), returnsNormally);
    });
  });
}

class _Weird {
  @override
  String toString() => 'ali@x.com';
}
