import 'dart:convert';
import 'dart:typed_data';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/oauth/oauth_services.dart';
import 'package:bu_kampus/core/oauth_config.dart';
import 'package:bu_kampus/core/platform/image_service.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/auth/data/onboarding_api.dart';
import 'package:bu_kampus/features/auth/onboarding/onboarding_flow.dart';
import 'package:bu_kampus/features/auth/profile_setup_page.dart';
import 'package:bu_kampus/features/profile/account_security_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'oauth_login_test.dart' show FakeApple, FakeGoogle;
import 'support/fake_app.dart';

/// Profil tamamlama (2 aşamalı onboarding), profil kapısı (PROFILE_INCOMPLETE) ve Hesap ve güvenlik > Bağlı hesaplar.
const _first = ValueKey('ob-first');
const _last = ValueKey('ob-last');
const _user = ValueKey('ob-username');

Finder _field(Key k) => find.descendant(of: find.byKey(k), matching: find.byType(TextFormField));

Future<void> _type(WidgetTester t, Key k, String text) async {
  await t.enterText(_field(k), text);
  await t.pump();
}

void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });

  setUp(() async {
    await OnboardingDraftStore.clear();
  });

  tearDown(() {
    OAuthConfig.current = const OAuthConfig();
    OAuthServices.current = OAuthServices();
  });

  FakeBackend backend({bool usernameFree = true}) {
    final b = FakeBackend();
    fakeCatalog(b);
    b.on('/users/username-available*', {'available': usernameFree, if (!usernameFree) 'reason': 'TAKEN'});
    return b;
  }

  Future<(FakeBackend, Session, List<int>)> open(
    WidgetTester tester, {
    FakeBackend? b,
    Size size = const Size(390, 1400),
    Brightness br = Brightness.light,
  }) async {
    useScreen(tester, size);
    final back = b ?? backend();
    final s = makeSession(back);
    final done = <int>[];
    await tester.pumpWidget(buildApp(OnboardingFlow(session: s, onDone: () => done.add(1)), brightness: br));
    await settle(tester, const Duration(milliseconds: 500));
    return (back, s, done);
  }

  /// 1. aşamayı geçerli verilerle doldurup 2. aşamaya geçer.
  Future<void> toStep2(WidgetTester tester) async {
    await _type(tester, _first, 'Ayşe');
    await _type(tester, _last, 'Yılmaz');
    await _type(tester, _user, 'ayse.y');
    await settle(tester, const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('ob-next')));
    await settle(tester, const Duration(milliseconds: 600));
  }

  Future<void> pickFrom(WidgetTester tester, Key field, String row) async {
    await tester.ensureVisible(find.byKey(field));
    await tester.tap(find.byKey(field));
    await settle(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text(row).last);
    await settle(tester, const Duration(milliseconds: 500));
  }

  group('veri katmanı', () {
    test('classYearsFor: süre bilinmiyorsa TÜM seçenekler; biliniyorsa uzun sınıflar elenir', () {
      expect(classYearsFor(), ClassYear.values);
      final four = classYearsFor(programYears: 4);
      expect(four.map((c) => c.wire), ['PREP', 'Y1', 'Y2', 'Y3', 'Y4', 'POSTGRAD', 'OTHER']);
      expect(classYearsFor(programYears: 2).map((c) => c.wire), ['PREP', 'Y1', 'Y2', 'POSTGRAD', 'OTHER']);
      expect(classYearsFor(programYears: 0), ClassYear.values, reason: 'geçersiz süre yok sayılır');
    });

    test('OnboardingForm gövdesi: boş alanlar gönderilmez, kullanıcı adı küçük harf', () {
      const f = OnboardingForm(firstName: ' Ayşe ', lastName: 'Yılmaz', username: 'Ayse.Y', classYear: ClassYear.y3, bio: '  ');
      expect(f.toJson(), {
        'firstName': 'Ayşe',
        'lastName': 'Yılmaz',
        'username': 'ayse.y',
        'universityName': 'Bingöl Üniversitesi',
        'acceptTerms': true,
        'classYear': 'Y3',
      });
    });

    test('kullanıcı adı kuralı 3-24, a-z 0-9 . _', () {
      for (final ok in ['abc', 'ayse.y', 'a_b.c9', 'a' * 24]) {
        expect(kUsernameRule.hasMatch(ok), isTrue, reason: ok);
      }
      for (final bad in ['ab', 'a' * 25, 'Ayşe', 'a b', 'a-b', '']) {
        expect(kUsernameRule.hasMatch(bad), isFalse, reason: bad);
      }
    });

    test('UsernameCheck ayrıştırma ve bozuk gövde', () {
      expect(UsernameCheck.fromJson({'available': false, 'reason': 'taken'}).reason, 'TAKEN');
      expect(UsernameCheck.fromJson({'available': true}).available, isTrue);
      expect(() => UsernameCheck.fromJson('x'), throwsA(isA<ApiError>()));
    });
  });

  group('ProfileCompletionGate', () {
    Future<void> pumpGate(WidgetTester tester, FakeBackend b, Session s) async {
      useScreen(tester, const Size(390, 1400));
      await tester.pumpWidget(buildApp(ProfileCompletionGate(session: s, child: const Text('KABUK'))));
      await settle(tester, const Duration(milliseconds: 800));
    }

    testWidgets('profileCompleted:true -> kabuk', (tester) async {
      final b = backend()..on('/users/me', {'id': 1, 'profileCompleted': true, 'department': null, 'grade': null});
      final s = makeSession(b);
      await pumpGate(tester, b, s);
      expect(find.text('KABUK'), findsOneWidget);
      expect(find.text('Önce tanışalım.'), findsNothing);
      await unmount(tester);
    });

    testWidgets('profileCompleted:false -> kabuk YOK, onboarding "Önce tanışalım."', (tester) async {
      final b = backend()..on('/users/me', {'id': 1, 'profileCompleted': false, 'displayName': 'Ayşe Yılmaz'});
      final s = makeSession(b);
      await pumpGate(tester, b, s);
      expect(find.text('KABUK'), findsNothing);
      expect(find.text('Önce tanışalım.'), findsOneWidget);
      expect(find.text('BÜKampüs profilini birkaç adımda oluşturalım.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('eski sunucu (alan yok): bölüm + sınıf kuralı geçerli, tamamsa kabuk', (tester) async {
      final b = backend(); // varsayılan /users/me: bölüm + sınıf dolu, profileCompleted yok
      final s = makeSession(b);
      await pumpGate(tester, b, s);
      expect(find.text('KABUK'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('eski sunucu (alan yok) + bölüm boş: eski "Bölümünüzü seçin" ekranı', (tester) async {
      final b = backend()..on('/users/me', {'id': 1, 'displayName': 'Ayşe'});
      final s = makeSession(b);
      await pumpGate(tester, b, s);
      expect(find.text('Bölümünüzü seçin'), findsOneWidget);
      expect(find.text('Önce tanışalım.'), findsNothing);
      await unmount(tester);
    });

    testWidgets('herhangi bir uçta 403 PROFILE_INCOMPLETE -> kabuk kapanır, onboarding açılır', (tester) async {
      final b = backend()
        ..on('/users/me', {'id': 1, 'department': 'Biyoloji', 'grade': '2'}) // alan yok: kabuk açık
        ..fail('/me/summary', status: 403, code: 'PROFILE_INCOMPLETE', message: 'Profil eksik.');
      final s = makeSession(b);
      await pumpGate(tester, b, s);
      expect(find.text('KABUK'), findsOneWidget);
      expect(s.profileIncompleteSignal.value, 0);
      await expectLater(s.api.get('/me/summary'), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'PROFILE_INCOMPLETE')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(s.profileIncompleteSignal.value, 1);
      expect(s.profileCompletedHint, isFalse);
      expect(find.text('KABUK'), findsNothing);
      expect(find.text('Önce tanışalım.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('OAuth ipucu false + /users/me alanı yok -> onboarding', (tester) async {
      final b = backend();
      final s = makeSession(b)..profileCompletedHint = false;
      await pumpGate(tester, b, s);
      expect(find.text('Önce tanışalım.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('onboarding tamamlanınca kabuk açılır ve ipucu true olur', (tester) async {
      final b = backend()
        ..on('/users/me', {'id': 1, 'profileCompleted': false, 'displayName': 'Ayşe Yılmaz'});
      final s = makeSession(b);
      await pumpGate(tester, b, s);
      await toStep2(tester);
      await pickFrom(tester, const ValueKey('ob-faculty'), 'Mühendislik Fakültesi');
      await pickFrom(tester, const ValueKey('ob-department'), 'Bilgisayar Mühendisliği');
      await pickFrom(tester, const ValueKey('ob-class'), '3. sınıf');
      await tester.ensureVisible(find.byKey(const ValueKey('ob-join')));
      await tester.tap(find.byKey(const ValueKey('ob-join')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(b.count('PUT /users/me/onboarding'), 1);
      expect(find.text('KABUK'), findsOneWidget);
      expect(s.profileCompletedHint, isTrue);
      await unmount(tester);
    });
  });

  group('Aşama 1: Önce tanışalım.', () {
    testWidgets('başlık/alt metin, alanlar, isteğe bağlı fotoğraf, çıkış bağlantısı; geri/kapatma yok', (tester) async {
      await open(tester);
      expect(find.text('Önce tanışalım.'), findsOneWidget);
      expect(find.text('BÜKampüs profilini birkaç adımda oluşturalım.'), findsOneWidget);
      expect(find.text('Ad'), findsOneWidget);
      expect(find.text('Soyad'), findsOneWidget);
      expect(find.text('Kullanıcı adı'), findsOneWidget);
      expect(find.text('Profil fotoğrafı (isteğe bağlı)'), findsOneWidget);
      expect(find.text('3-24 karakter; a-z, 0-9, nokta ve alt çizgi.'), findsOneWidget);
      expect(find.byKey(const ValueKey('ob-signout')), findsOneWidget);
      expect(find.byKey(const ValueKey('ob-back')), findsNothing);
      expect(find.text('1/2'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('ad/soyad taslaktan (Apple\'ın bir kez verdiği ad) ön doldurulur ve değiştirilebilir', (tester) async {
      await OnboardingDraftStore.savePrefill(firstName: 'Zeynep', lastName: 'Kaya');
      await open(tester);
      expect(find.text('Zeynep'), findsOneWidget);
      expect(find.text('Kaya'), findsOneWidget);
      await _type(tester, _first, 'Zeynep Nur');
      expect(find.text('Zeynep Nur'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('ad, sunucudaki profilden (Google) ön doldurulur: firstName/lastName ya da displayName', (tester) async {
      final b = backend()..on('/users/me', {'id': 1, 'profileCompleted': false, 'displayName': 'Mehmet Ali Demir'});
      await open(tester, b: b);
      expect(find.text('Mehmet Ali'), findsOneWidget);
      expect(find.text('Demir'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kullanıcı adı: 400 ms debounce, 3 karakter altı istek yok, hızlı yazımda tek istek', (tester) async {
      final b = backend();
      await open(tester, b: b);
      await _type(tester, _user, 'ay');
      await settle(tester, const Duration(milliseconds: 700));
      expect(b.count('username-available'), 0, reason: '3 karakterden kısa: istek yok');
      await _type(tester, _user, 'ayse');
      await tester.pump(const Duration(milliseconds: 200));
      await _type(tester, _user, 'ayse.y');
      await tester.pump(const Duration(milliseconds: 399));
      expect(b.count('username-available'), 0, reason: 'debounce bitmeden istek yok');
      await tester.pump(const Duration(milliseconds: 5));
      await settle(tester, const Duration(milliseconds: 300));
      expect(b.count('username-available'), 1);
      expect(b.requests.where((r) => r.contains('username-available')).single, 'GET /users/username-available?u=ayse.y');
      expect(find.text('Kullanıcı adı müsait.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kullanıcı adı yalnız a-z 0-9 . _ ve küçük harf kabul eder', (tester) async {
      await open(tester);
      await _type(tester, _user, 'Ayşe Y-Z!9');
      final v = tester.widget<TextFormField>(_field(_user)).controller!.text;
      expect(v, 'ayeyz9');
      await unmount(tester);
    });

    testWidgets('TAKEN: alan altında hata, Devam ilerlemez', (tester) async {
      final b = backend(usernameFree: false);
      await open(tester, b: b);
      await _type(tester, _first, 'Ayşe');
      await _type(tester, _last, 'Yılmaz');
      await _type(tester, _user, 'ayse');
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Bu kullanıcı adı alınmış.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ob-next')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Önce tanışalım.'), findsOneWidget);
      expect(find.text('Kampüste neredesin?'), findsNothing);
      await unmount(tester);
    });

    for (final c in const {
      'INVALID': 'Kullanıcı adı 3-24 karakter olmalı; yalnız a-z, 0-9, nokta ve alt çizgi kullanılabilir.',
      'RESERVED': 'Bu kullanıcı adı kullanılamaz.',
    }.entries) {
      testWidgets('${c.key}: sunucu nedeni alan altında gösterilir', (tester) async {
        final b = backend()..on('/users/username-available*', {'available': false, 'reason': c.key});
        await open(tester, b: b);
        await _type(tester, _user, 'admin');
        await settle(tester, const Duration(milliseconds: 700));
        expect(find.text(c.value), findsOneWidget);
        await unmount(tester);
      });
    }

    testWidgets('boş alanlarla Devam: alan bazlı hatalar, istek yok', (tester) async {
      final b = backend()..on('/users/me', {'id': 1, 'profileCompleted': false});
      await open(tester, b: b);
      await tester.tap(find.byKey(const ValueKey('ob-next')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Adını yaz.'), findsOneWidget);
      expect(find.text('Soyadını yaz.'), findsOneWidget);
      expect(find.text('Bir kullanıcı adı seç.'), findsOneWidget);
      expect(b.count('username-available'), 0);
      await unmount(tester);
    });

    testWidgets('ağ hatasında müsaitlik kontrolü kullanıcıyı bloklamaz (sunucu kayıtta doğrular)', (tester) async {
      final b = backend()..network('/users/username-available*');
      await open(tester, b: b);
      await toStep2(tester);
      expect(find.text('Kampüste neredesin?'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('profil fotoğrafı: seçilince önizleme görünür; yükleme profil kaydından SONRA yapılır', (tester) async {
      final b = backend()..on('/users/me/avatar', {'avatarUrl': '/files/avatars/new.jpg'});
      useScreen(tester, const Size(390, 1400));
      final s = makeSession(b);
      await tester.pumpWidget(buildApp(OnboardingFlow(
        session: s,
        onDone: () {},
        cropPhoto: (source) async => Uint8List.fromList(kFakePng),
        uploader: MultipartUploader(s, client: b.client),
      )));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('ob-avatar')));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('photoSrcGallery')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('ob-avatar-preview')), findsOneWidget);
      expect(b.count('POST /users/me/avatar'), 0, reason: 'profil kaydından önce yükleme yok');
      await toStep2(tester);
      await pickFrom(tester, const ValueKey('ob-faculty'), 'Mühendislik Fakültesi');
      await pickFrom(tester, const ValueKey('ob-department'), 'Bilgisayar Mühendisliği');
      await pickFrom(tester, const ValueKey('ob-class'), '1. sınıf');
      await tester.ensureVisible(find.byKey(const ValueKey('ob-join')));
      await tester.tap(find.byKey(const ValueKey('ob-join')));
      await settle(tester, const Duration(milliseconds: 800));
      final put = b.requests.indexWhere((r) => r.startsWith('PUT /users/me/onboarding'));
      final up = b.requests.indexWhere((r) => r.startsWith('POST /users/me/avatar'));
      expect(put, greaterThanOrEqualTo(0));
      expect(up, greaterThan(put));
      expect(s.avatarUrl.value, '/files/avatars/new.jpg');
      await unmount(tester);
    });
  });

  group('Aşama 2: Kampüste neredesin?', () {
    testWidgets('başlık, sabit üniversite, beyan notu; "doğrulanmış öğrenci" ifadesi yok', (tester) async {
      await open(tester);
      await toStep2(tester);
      expect(find.text('Kampüste neredesin?'), findsOneWidget);
      expect(find.text('Bölümünü seç, sana uygun toplulukları keşfet.'), findsOneWidget);
      expect(find.text('Bingöl Üniversitesi'), findsOneWidget);
      expect(find.text('BÜKampüs\'e katıl'), findsOneWidget);
      expect(find.textContaining('beyan'), findsOneWidget);
      expect(find.textContaining('doğrulanmış öğrenci'), findsNothing);
      expect(find.text('2/2'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('fakülte -> bölüm süzgeci: yalnız seçili fakültenin bölümleri listelenir', (tester) async {
      await open(tester);
      await toStep2(tester);
      // Fakülte seçilmeden bölüm: yer tutucu "Önce fakülteni seç", sayfa açılmaz.
      expect(find.text('Önce fakülteni seç'), findsOneWidget);
      await pickFrom(tester, const ValueKey('ob-faculty'), 'Fen-Edebiyat Fakültesi');
      await tester.ensureVisible(find.byKey(const ValueKey('ob-department')));
      await tester.tap(find.byKey(const ValueKey('ob-department')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Biyoloji'), findsOneWidget);
      expect(find.text('Türk Dili ve Edebiyatı'), findsOneWidget);
      expect(find.text('Bilgisayar Mühendisliği'), findsNothing);
      expect(find.text('Elektrik-Elektronik Mühendisliği'), findsNothing);
      await tester.tap(find.text('Biyoloji').last);
      await settle(tester, const Duration(milliseconds: 500));
      // Fakülte değişince bölüm seçimi düşer.
      await pickFrom(tester, const ValueKey('ob-faculty'), 'Mühendislik Fakültesi');
      expect(find.text('Biyoloji'), findsNothing);
      expect(find.text('Bölüm seçin'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('sınıf seçenekleri: Hazırlık, 1.-6. sınıf, Lisansüstü, Diğer (süre bilinmiyor: hepsi)', (tester) async {
      await open(tester);
      await toStep2(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('ob-class')));
      await tester.tap(find.byKey(const ValueKey('ob-class')));
      await settle(tester, const Duration(milliseconds: 500));
      for (final t in ['Hazırlık', '1. sınıf', '2. sınıf', '3. sınıf', '4. sınıf', '5. sınıf', '6. sınıf', 'Lisansüstü', 'Diğer']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      await unmount(tester);
    });

    testWidgets('bölümün süresi katalogda varsa uygun olmayan sınıflar süzülür', (tester) async {
      final b = backend()
        ..on('/catalog/academic', {
          'version': 1,
          'faculties': [
            {
              'id': 'myo',
              'name': 'Meslek Yüksekokulu',
              'departments': [
                {'id': 'bilgisayar-prog', 'name': 'Bilgisayar Programcılığı', 'years': 2},
              ],
            },
          ],
        });
      await open(tester, b: b);
      await toStep2(tester);
      await pickFrom(tester, const ValueKey('ob-faculty'), 'Meslek Yüksekokulu');
      await pickFrom(tester, const ValueKey('ob-department'), 'Bilgisayar Programcılığı');
      await tester.ensureVisible(find.byKey(const ValueKey('ob-class')));
      await tester.tap(find.byKey(const ValueKey('ob-class')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('2. sınıf'), findsOneWidget);
      expect(find.text('3. sınıf'), findsNothing);
      expect(find.text('Lisansüstü'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('eksik alanlarla katıl: alan bazlı hata, istek yok', (tester) async {
      final b = backend();
      await open(tester, b: b);
      await toStep2(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('ob-join')));
      await tester.tap(find.byKey(const ValueKey('ob-join')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Fakültenizi seçin.'), findsOneWidget);
      expect(find.text('Sınıfınızı seçin.'), findsOneWidget);
      expect(b.count('PUT /users/me/onboarding'), 0);
      await unmount(tester);
    });

    testWidgets('katıl: sözleşmeye uygun PUT gövdesi, onDone, taslak silinir', (tester) async {
      final b = backend();
      final (_, _, done) = await open(tester, b: b);
      await toStep2(tester);
      await pickFrom(tester, const ValueKey('ob-faculty'), 'Mühendislik Fakültesi');
      await pickFrom(tester, const ValueKey('ob-department'), 'Bilgisayar Mühendisliği');
      await pickFrom(tester, const ValueKey('ob-class'), '3. sınıf');
      await tester.enterText(_field(const ValueKey('ob-bio')), 'Kısa bir tanıtım');
      await tester.pump();
      expect(await OnboardingDraftStore.load(), isNotNull, reason: 'taslak adımlar arasında saklanır');
      await tester.ensureVisible(find.byKey(const ValueKey('ob-join')));
      await tester.tap(find.byKey(const ValueKey('ob-join')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(done, [1]);
      final body = b.bodies['PUT /users/me/onboarding'] as Map;
      expect(body, {
        'firstName': 'Ayşe',
        'lastName': 'Yılmaz',
        'username': 'ayse.y',
        'universityName': 'Bingöl Üniversitesi',
        'acceptTerms': true,
        'facultyId': 'muhendislik',
        'facultyName': 'Mühendislik Fakültesi',
        'departmentId': 'bilgisayar-muhendisligi',
        'departmentName': 'Bilgisayar Mühendisliği',
        'classYear': 'Y3',
        'bio': 'Kısa bir tanıtım',
      });
      expect(await OnboardingDraftStore.load(), isNull);
      await unmount(tester);
    });

    testWidgets('geri: 1. aşamaya döner, form verisi korunur; yeniden ileri gidince seçimler yerinde', (tester) async {
      await open(tester);
      await toStep2(tester);
      await pickFrom(tester, const ValueKey('ob-faculty'), 'Mühendislik Fakültesi');
      await tester.tap(find.byKey(const ValueKey('ob-back')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Önce tanışalım.'), findsOneWidget);
      expect(find.text('Ayşe'), findsOneWidget);
      expect(find.text('Yılmaz'), findsOneWidget);
      expect(find.text('ayse.y'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ob-next')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Mühendislik Fakültesi'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('PUT 409 USERNAME_TAKEN: 1. aşamaya döner, alan altında hata', (tester) async {
      final b = backend()..fail('/users/me/onboarding', status: 409, code: 'USERNAME_TAKEN', message: 'x');
      await open(tester, b: b);
      await toStep2(tester);
      await pickFrom(tester, const ValueKey('ob-faculty'), 'Mühendislik Fakültesi');
      await pickFrom(tester, const ValueKey('ob-department'), 'Bilgisayar Mühendisliği');
      await pickFrom(tester, const ValueKey('ob-class'), '2. sınıf');
      await tester.ensureVisible(find.byKey(const ValueKey('ob-join')));
      await tester.tap(find.byKey(const ValueKey('ob-join')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('Önce tanışalım.'), findsOneWidget);
      expect(find.text('Bu kullanıcı adı alınmış.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('PUT 422: hata bandı, 2. aşamada kalır; ağ yok: ağ metni', (tester) async {
      final b = backend()..fail('/users/me/onboarding', status: 422, code: 'VALIDATION_ERROR', message: 'Alanlar geçersiz.');
      await open(tester, b: b);
      await toStep2(tester);
      await pickFrom(tester, const ValueKey('ob-faculty'), 'Mühendislik Fakültesi');
      await pickFrom(tester, const ValueKey('ob-department'), 'Bilgisayar Mühendisliği');
      await pickFrom(tester, const ValueKey('ob-class'), '2. sınıf');
      await tester.ensureVisible(find.byKey(const ValueKey('ob-join')));
      await tester.tap(find.byKey(const ValueKey('ob-join')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('Alanlar geçersiz.'), findsOneWidget);
      expect(find.text('Kampüste neredesin?'), findsOneWidget);
      b.offline = true;
      b.reset('/users/me/onboarding');
      await tester.tap(find.byKey(const ValueKey('ob-join')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text(errorText(ApiError(0, 'NETWORK', ''))), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('yarım bırakılan onboarding taslaktan devam eder (adım + seçimler)', (tester) async {
      await OnboardingDraftStore.save(const OnboardingDraft(
        firstName: 'Zeynep',
        lastName: 'Kaya',
        username: 'zeynep.k',
        facultyId: 'fen-edebiyat',
        departmentId: 'biyoloji',
        classYear: ClassYear.y2,
        step: 1,
      ));
      await open(tester);
      expect(find.text('Kampüste neredesin?'), findsOneWidget);
      expect(find.text('Fen-Edebiyat Fakültesi'), findsOneWidget);
      expect(find.text('Biyoloji'), findsOneWidget);
      expect(find.text('2. sınıf'), findsOneWidget);
      await unmount(tester);
    });

    for (final br in Brightness.values) {
      for (final size in [kPhoneSmall, kPhoneMedium]) {
        testWidgets('taşma yok: ${br.name} ${size.width.toInt()}x${size.height.toInt()} (iki aşama)', (tester) async {
          await open(tester, size: size, br: br);
          expect(tester.takeException(), isNull);
          await _type(tester, _first, 'Ayşe');
          await _type(tester, _last, 'Yılmaz');
          await _type(tester, _user, 'ayse.y');
          await settle(tester, const Duration(milliseconds: 600));
          await tester.ensureVisible(find.byKey(const ValueKey('ob-next')));
          await tester.tap(find.byKey(const ValueKey('ob-next')));
          await settle(tester, const Duration(milliseconds: 600));
          expect(find.text('Kampüste neredesin?'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });

  group('Hesap ve güvenlik > Bağlı hesaplar', () {
    const googleRow = ValueKey('sec-oauth-google');
    const appleRow = ValueKey('sec-oauth-apple');

    Future<(FakeBackend, Session)> openSec(WidgetTester tester,
        {List<Map<String, dynamic>>? identities, FakeBackend? b, bool defaultIdentities = true}) async {
      useScreen(tester, const Size(390, 1600));
      final back = b ?? FakeBackend();
      if (defaultIdentities) {
        back.on('/auth/oauth/identities', identities ?? [<String, dynamic>{'provider': 'google', 'emailMasked': 'a***@gmail.com'}]);
      }
      final s = makeSession(back);
      await tester.pumpWidget(buildApp(AccountSecurityPage(session: s)));
      await settle(tester, const Duration(milliseconds: 600));
      return (back, s);
    }

    testWidgets('yapılandırma kapalı: bölüm hiç görünmez, uç çağrılmaz', (tester) async {
      OAuthConfig.current = const OAuthConfig();
      final (b, _) = await openSec(tester);
      expect(find.text('Bağlı hesaplar'), findsNothing);
      expect(find.byKey(googleRow), findsNothing);
      expect(b.count('/auth/oauth/identities'), 0);
      await unmount(tester);
    });

    testWidgets('yalnız Google açık: Google satırı var, Apple yok; Android\'de Apple hiç gösterilmez', (tester) async {
      OAuthConfig.current = const OAuthConfig(googleFlag: true, googleServerClientId: 'web', appleFlag: true);
      await openSec(tester);
      await tester.ensureVisible(find.byKey(googleRow));
      expect(find.byKey(googleRow), findsOneWidget);
      expect(find.byKey(appleRow), findsNothing);
      await unmount(tester);
    });

    testWidgets('durumlar: Google bağlı, Apple bağlı değil', (tester) async {
      OAuthConfig.current = const OAuthConfig(googleFlag: true, googleServerClientId: 'web', appleFlag: true, appleSupportedPlatform: true);
      await openSec(tester);
      await tester.ensureVisible(find.byKey(googleRow));
      expect(find.descendant(of: find.byKey(googleRow), matching: find.text('Bağlı')), findsOneWidget);
      expect(find.descendant(of: find.byKey(appleRow), matching: find.text('Bağlı değil')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('bağla: sağlayıcı kimliği + şifre yeniden doğrulaması; gövde sözleşmeye uygun', (tester) async {
      OAuthConfig.current = const OAuthConfig(googleFlag: true, googleServerClientId: 'web', appleFlag: true, appleSupportedPlatform: true);
      OAuthServices.current = OAuthServices(google: FakeGoogle(), apple: FakeApple());
      final (b, _) = await openSec(tester);
      await tester.ensureVisible(find.byKey(appleRow));
      await tester.tap(find.byKey(appleRow));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Şifreni doğrula'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('oauth-link-password')), 'Sifre1234');
      b.on('/auth/oauth/identities', [
        {'provider': 'google'},
        {'provider': 'apple'},
      ]);
      await tester.tap(find.byKey(const ValueKey('oauth-link-confirm')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(b.bodies['POST /auth/oauth/link'], {'provider': 'apple', 'token': 'apple-identity', 'nonce': 'raw-nonce', 'password': 'Sifre1234'});
      expect(find.text('Şifreni doğrula'), findsNothing);
      expect(find.text('Apple hesabı bağlandı.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('bağla: yanlış şifre iletişim kutusunu kapatmaz, hata alan altında görünür', (tester) async {
      OAuthConfig.current = const OAuthConfig(googleFlag: true, googleServerClientId: 'web', appleFlag: true, appleSupportedPlatform: true);
      OAuthServices.current = OAuthServices(google: FakeGoogle(), apple: FakeApple());
      final b = FakeBackend()..on('/auth/oauth/link', {'code': 'WRONG_PASSWORD', 'message': 'Şifre yanlış.'}, status: 403);
      await openSec(tester, b: b);
      await tester.ensureVisible(find.byKey(appleRow));
      await tester.tap(find.byKey(appleRow));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.enterText(find.byKey(const ValueKey('oauth-link-password')), 'yanlis');
      await tester.tap(find.byKey(const ValueKey('oauth-link-confirm')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Şifreni doğrula'), findsOneWidget);
      expect(find.text('Şifre yanlış.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('bağla: sağlayıcı iptali sessiz, şifre sorulmaz, istek yok', (tester) async {
      OAuthConfig.current = const OAuthConfig(googleFlag: true, googleServerClientId: 'web', appleFlag: true, appleSupportedPlatform: true);
      final a = FakeApple()..result = null;
      OAuthServices.current = OAuthServices(google: FakeGoogle(), apple: a);
      final (b, _) = await openSec(tester);
      await tester.ensureVisible(find.byKey(appleRow));
      await tester.tap(find.byKey(appleRow));
      await settle(tester, const Duration(milliseconds: 500));
      expect(a.calls, 1);
      expect(find.text('Şifreni doğrula'), findsNothing);
      expect(b.count('POST /auth/oauth/link'), 0);
      await unmount(tester);
    });

    testWidgets('kaldır: onay sonrası DELETE /auth/oauth/link/google', (tester) async {
      OAuthConfig.current = const OAuthConfig(googleFlag: true, googleServerClientId: 'web');
      final (b, _) = await openSec(tester);
      await tester.ensureVisible(find.byKey(googleRow));
      await tester.tap(find.byKey(googleRow));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Bağlantı kaldırılsın mı?'), findsOneWidget);
      b.on('/auth/oauth/identities', <Map<String, dynamic>>[]);
      await tester.tap(find.text('Bağlantıyı kaldır'));
      await settle(tester, const Duration(milliseconds: 700));
      expect(b.count('DELETE /auth/oauth/link/google'), 1);
      expect(find.text('Google bağlantısı kaldırıldı.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kaldır: 409 OAUTH_LAST_LOGIN_METHOD -> anlaşılır mesaj, bağlantı kalır', (tester) async {
      OAuthConfig.current = const OAuthConfig(googleFlag: true, googleServerClientId: 'web');
      final b = FakeBackend()..on('/auth/oauth/link/google', {'code': 'OAUTH_LAST_LOGIN_METHOD', 'message': 'x'}, status: 409);
      await openSec(tester, b: b);
      await tester.ensureVisible(find.byKey(googleRow));
      await tester.tap(find.byKey(googleRow));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.text('Bağlantıyı kaldır'));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Bu, hesabına giriş yapabildiğin tek yöntem. Kaldırmadan önce bir şifre belirlemelisin.'), findsOneWidget);
      expect(find.descendant(of: find.byKey(googleRow), matching: find.text('Bağlı')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('liste biçimi toleransı: {items:[...]} ve bilinmeyen sağlayıcılar atlanır', (tester) async {
      OAuthConfig.current = const OAuthConfig(googleFlag: true, googleServerClientId: 'web');
      final b = FakeBackend()
        ..on('/auth/oauth/identities', {
          'items': [
            {'provider': 'GOOGLE'},
            {'provider': 'github'},
          ],
        });
      await openSec(tester, b: b);
      await tester.ensureVisible(find.byKey(googleRow));
      expect(find.descendant(of: find.byKey(googleRow), matching: find.text('Bağlı')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('liste yüklenemedi: satırda hata, dokununca yeniden dener', (tester) async {
      OAuthConfig.current = const OAuthConfig(googleFlag: true, googleServerClientId: 'web');
      final b = FakeBackend()..fail('/auth/oauth/identities', status: 500, code: 'SERVER_ERROR');
      await openSec(tester, b: b, defaultIdentities: false);
      await tester.ensureVisible(find.byKey(googleRow));
      expect(find.text('Bağlı hesaplar yüklenemedi.'), findsOneWidget);
      b.on('/auth/oauth/identities', [
        {'provider': 'google'},
      ]);
      await tester.tap(find.byKey(googleRow));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.descendant(of: find.byKey(googleRow), matching: find.text('Bağlı')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('ApiError.data', () {
    test('hata gövdesinin tamamı taşınır', () async {
      final b = FakeBackend()..on('/x', {'code': 'OAUTH_LINK_REQUIRED', 'message': 'm', 'emailMasked': 'a***'}, status: 409);
      final s = makeSession(b);
      try {
        await s.api.post('/x', {}, false);
        fail('fırlatmalı');
      } on ApiError catch (e) {
        expect(e.data?['emailMasked'], 'a***');
        expect(jsonEncode(e.data), contains('OAUTH_LINK_REQUIRED'));
      }
    });
  });
}
