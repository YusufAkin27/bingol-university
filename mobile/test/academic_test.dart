import 'package:bu_kampus/core/academic_catalog.dart';
import 'package:bu_kampus/features/auth/register_page.dart';
import 'package:bu_kampus/features/auth/verify_code_page.dart';
import 'package:bu_kampus/features/profile/edit_profile_page.dart';
import 'package:bu_kampus/features/profile/privacy_data_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/widgets/academic_picker.dart';
import 'package:bu_kampus/widgets/bu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Seçici için basit ana bilgisayar: durumu kendisi tutar.
class _Host extends StatefulWidget {
  const _Host(this.catalog, {this.faculty, this.department, this.grade});

  final AcademicCatalog catalog;
  final String? faculty, department, grade;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late String? f = widget.faculty, d = widget.department, g = widget.grade;

  @override
  void initState() {
    super.initState();
    widget.catalog.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AcademicFields(
              catalog: widget.catalog,
              faculty: f,
              department: d,
              grade: g,
              onChanged: (a, b, c) => setState(() {
                f = a;
                d = b;
                g = c;
              }),
            ),
            Text('SONUC f=$f d=$d g=$g'),
          ],
        ),
      );
}

final _search = find.descendant(of: find.byType(BuSearchField), matching: find.byType(TextField));

void main() {
  setUpAll(loadTestFonts);

  group('AcademicCatalog', () {
    test('foldTr: aksan ve büyük/küçük harf duyarsız', () {
      expect(foldTr('Mühendislik'), 'muhendislik');
      expect(foldTr('İSTANBUL ŞEHİR'), 'istanbul sehir');
      expect(foldTr('Işık Çağrı Ğ'), 'isik cagri g');
    });

    test('yükleme: ready olur ve arama aksan duyarsızdır', () async {
      final b = FakeBackend()..on('/catalog/academic', kFakeAcademic);
      final cat = AcademicCatalog(makeSession(b, signedIn: false));
      expect(cat.state, CatalogState.idle);
      final f = cat.load();
      expect(cat.state, CatalogState.loading);
      await f;
      expect(cat.ready, isTrue);
      expect(cat.faculties.length, 2);
      expect(cat.searchFaculties('MUH').single.name, 'Mühendislik Fakültesi');
      expect(cat.searchDepartments('turk').single.name, 'Türk Dili ve Edebiyatı');
      expect(cat.searchDepartments('BİLG').single.name, 'Bilgisayar Mühendisliği');
      expect(cat.searchDepartments('mühendis').length, 2);
      // Yeniden çağrı ikinci istek atmaz.
      await cat.load();
      expect(b.count('/catalog/academic'), 1);
    });

    test('hata sonra yeniden dene', () async {
      final b = FakeBackend()..network('/catalog/academic');
      final cat = AcademicCatalog(makeSession(b, signedIn: false));
      await cat.load();
      expect(cat.state, CatalogState.error);
      fakeCatalog(b);
      await cat.retry();
      expect(cat.ready, isTrue);
    });
  });

  group('AcademicFields', () {
    testWidgets('yükleniyor -> dolu', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend(delay: const Duration(milliseconds: 200));
      fakeCatalog(b);
      final cat = AcademicCatalog(makeSession(b, signedIn: false));
      await tester.pumpWidget(buildApp(_Host(cat)));
      await tester.pump();
      expect(find.text('Yükleniyor…'), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Fakülte seçin'), findsNothing);
      expect(find.text('Bölüm seçin'), findsOneWidget);
      // Sınıf artık satır içi çip değil, bölüm seçici gibi liste sayfası: açılınca seçenekler görünür.
      expect(find.text('Sınıf seçin'), findsOneWidget);
      await tester.tap(find.text('Sınıf seçin'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Hazırlık'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('hata + yeniden dene', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..network('/catalog/academic');
      final cat = AcademicCatalog(makeSession(b, signedIn: false));
      await tester.pumpWidget(buildApp(_Host(cat)));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Bölüm listesi yüklenemedi.'), findsOneWidget);
      fakeCatalog(b);
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Bölüm listesi yüklenemedi.'), findsNothing);
      expect(cat.ready, isTrue);
      await unmount(tester);
    });

    testWidgets('bölüm araması aksan duyarsız; satırda fakülte adı; fakülte seçici yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeCatalog(b);
      final cat = AcademicCatalog(makeSession(b, signedIn: false));
      await tester.pumpWidget(buildApp(_Host(cat)));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Fakülte seçin'), findsNothing);
      expect(find.text('Mühendislik Fakültesi'), findsNothing);
      await tester.tap(find.text('Bölüm seçin'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      // Boş aramada tüm bölümler, altında fakülte adı.
      expect(find.text('Biyoloji'), findsOneWidget);
      expect(find.text('Bilgisayar Mühendisliği'), findsOneWidget);
      expect(find.text('Fen-Edebiyat Fakültesi'), findsNWidgets(2));
      await tester.enterText(_search, 'MÜHENDİS');
      await tester.pump();
      expect(find.text('Biyoloji'), findsNothing);
      expect(find.text('Mühendislik Fakültesi'), findsNWidgets(2));
      await tester.tap(find.text('Bilgisayar Mühendisliği'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('f=Mühendislik Fakültesi d=Bilgisayar Mühendisliği'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('bölüm seçilince fakülte bilgi satırı otomatik dolar ve dokunulamaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      fakeCatalog(b);
      final cat = AcademicCatalog(makeSession(b, signedIn: false));
      await tester.pumpWidget(buildApp(_Host(cat)));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Bölüm seçin'));
      await pickFromSearch(tester, 'biyo', 'Biyoloji');
      expect(find.textContaining('f=Fen-Edebiyat Fakültesi d=Biyoloji'), findsOneWidget);
      // Bilgi satırı: düz metin + ikon; üstünde dokunma hedefi yok.
      final info = find.text('Fen-Edebiyat Fakültesi');
      expect(info, findsOneWidget);
      expect(find.ancestor(of: info, matching: find.byType(InkWell)), findsNothing);
      expect(find.ancestor(of: info, matching: find.byType(GestureDetector)), findsNothing);
      await unmount(tester);
    });

    testWidgets('aynı isimli bölüm iki fakültede ayrı satır; seçim fakülteyi belirler', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/catalog/academic', {
          'version': 1,
          'faculties': [
            {
              'id': 'a',
              'name': 'Mühendislik Fakültesi',
              'departments': [
                {'id': 'a-ing', 'name': 'İngilizce'}
              ],
            },
            {
              'id': 'b',
              'name': 'Eğitim Fakültesi',
              'departments': [
                {'id': 'b-ing', 'name': 'İngilizce'}
              ],
            },
          ],
        });
      final cat = AcademicCatalog(makeSession(b, signedIn: false));
      await tester.pumpWidget(buildApp(_Host(cat)));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.text('Bölüm seçin'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('İngilizce'), findsNWidgets(2));
      expect(find.text('Eğitim Fakültesi'), findsOneWidget);
      await tester.tap(find.text('Eğitim Fakültesi'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('f=Eğitim Fakültesi d=İngilizce'), findsOneWidget);
      await unmount(tester);
    });

    for (final br in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('AcademicFields ${br.name} ${size.width.toInt()} taşma yok', (tester) async {
          useScreen(tester, size);
          final b = FakeBackend();
          fakeCatalog(b);
          final cat = AcademicCatalog(makeSession(b, signedIn: false));
          await tester.pumpWidget(buildApp(
            _Host(cat,
                faculty: 'Mühendislik Fakültesi Çok Uzun Bir Fakülte Adı Olabilir Burada Da Devam Eder',
                department: 'Çok Uzun Bir Bölüm Adı Bilgisayar ve Yazılım Mühendisliği (İngilizce) (Uzaktan)',
                grade: 'MASTER'),
            brightness: br,
            size: size,
          ));
          await settle(tester, const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });

  group('RegisterPage akademik', () {
    testWidgets('adım adım: boş adım ilerletmez, hatalar gösterilir; istek atılmaz', (tester) async {
      useScreen(tester, const Size(390, 1800));
      final b = FakeBackend();
      fakeCatalog(b);
      await tester.pumpWidget(buildApp(RegisterPage(session: makeSession(b, signedIn: false))));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Adım 1/3'), findsOneWidget);
      await tester.tap(find.text('Devam'));
      await tester.pump();
      expect(find.text('Bölümünüzü seçin.'), findsOneWidget);
      expect(find.text('Sınıfınızı seçin.'), findsOneWidget);
      expect(find.text('Adım 1/3'), findsOneWidget);
      await fillAcademic(tester);
      await tester.tap(find.text('Devam'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Adım 2/3'), findsOneWidget);
      await tester.tap(find.text('Devam'));
      await tester.pump();
      expect(find.text('Adınızı ve soyadınızı girin.'), findsOneWidget);
      expect(find.text('Okul numaranızı veya e-posta adresinizi girin.'), findsOneWidget);
      expect(find.text('Adım 2/3'), findsOneWidget);
      expect(b.count('/auth/register'), 0);
      await unmount(tester);
    });

    testWidgets('sınıf seçici bölüm seçici gibi liste; fakülte seçici ve şifre tekrar alanı yok', (tester) async {
      useScreen(tester, const Size(390, 1800));
      final b = FakeBackend();
      fakeCatalog(b);
      await tester.pumpWidget(buildApp(RegisterPage(session: makeSession(b, signedIn: false))));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Fakülte seçin'), findsNothing);
      expect(find.text('Şifre (tekrar)'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.text('Bölüm seçin'));
      await pickFromSearch(tester, 'bilg', 'Bilgisayar Mühendisliği');
      expect(find.text('Mühendislik Fakültesi'), findsOneWidget);
      // Otomatik sınıf önerilmez: sınıf seçilmeden ilerlenemez.
      await tester.tap(find.text('Devam'));
      await tester.pump();
      expect(find.text('Sınıfınızı seçin.'), findsOneWidget);
      expect(find.text('Bölümünüzü seçin.'), findsNothing);
      await unmount(tester);
    });

    testWidgets('son adımda onay kutusu yok, bilgi satırı var; gövdeye faculty/department/grade/acceptTerms eklenir', (tester) async {
      useScreen(tester, const Size(390, 1800));
      final b = FakeBackend();
      fakeCatalog(b);
      await tester.pumpWidget(buildApp(RegisterPage(session: makeSession(b, signedIn: false))));
      await settle(tester, const Duration(milliseconds: 300));
      await fillRegister(tester);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.textContaining('kabul etmiş sayılırsınız', findRichText: true), findsOneWidget);
      await tester.tap(find.text('Kayıt ol').last);
      await settle(tester, const Duration(milliseconds: 500));
      final body = b.bodies['POST /auth/register'] as Map;
      expect(body['faculty'], 'Mühendislik Fakültesi');
      expect(body['department'], 'Bilgisayar Mühendisliği');
      expect(body['grade'], '3');
      expect(body['acceptTerms'], true);
      // Parola kaniti: doğrulama adımında kayıtta girilen şifre yeniden gönderilir (parola alanı çıkmaz)
      b.on('/auth/verify-email', {'accessToken': 'a', 'refreshToken': 'r'});
      expect(find.byType(VerifyCodePage), findsOneWidget);
      expect(find.text('Kayıtta belirlediğiniz şifre'), findsNothing);
      await tester.enterText(find.byType(EditableText).first, '123456');
      await settle(tester, const Duration(milliseconds: 600));
      expect((b.bodies['POST /auth/verify-email'] as Map)['password'], 'Sifre1234');
      await unmount(tester);
    });

    testWidgets('katalog yüklenemezse açık hata gösterilir', (tester) async {
      useScreen(tester, const Size(390, 1800));
      final b = FakeBackend()..network('/catalog/academic');
      await tester.pumpWidget(buildApp(RegisterPage(session: makeSession(b, signedIn: false))));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Yeniden dene'), findsOneWidget);
      await tester.tap(find.text('Devam'));
      await tester.pump();
      expect(find.textContaining('yüklenemedi'), findsWidgets);
      expect(b.count('/auth/register'), 0);
      await unmount(tester);
    });

    for (final br in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('RegisterPage ${br.name} ${size.width.toInt()} taşma yok', (tester) async {
          useScreen(tester, size);
          final b = FakeBackend();
          fakeCatalog(b);
          await tester.pumpWidget(buildApp(RegisterPage(session: makeSession(b, signedIn: false)),
              brightness: br, size: size));
          await settle(tester, const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });

  group('EditProfilePage akademik', () {
    Map<String, dynamic> profile() => {
          'displayName': 'Ayşe Yılmaz',
          'faculty': 'Eski Serbest Fakülte',
          'department': 'Eski Serbest Bölüm',
          'grade': '2',
          'language': 'tr',
          'showEmail': false,
        };

    Future<FakeBackend> open(WidgetTester tester, {Map<String, dynamic>? p}) async {
      useScreen(tester, const Size(390, 1400));
      final b = FakeBackend();
      fakeCatalog(b);
      await tester.pumpWidget(buildApp(EditProfilePage(session: makeSession(b), profile: p ?? profile())));
      await settle(tester, const Duration(milliseconds: 300));
      return b;
    }

    testWidgets('serbest metin olduğu gibi gösterilir; değişmediyse gönderilmez', (tester) async {
      final b = await open(tester);
      expect(find.text('Eski Serbest Fakülte'), findsOneWidget);
      expect(find.text('Eski Serbest Bölüm'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Ayşe Y.');
      await tester.tap(find.text('Kaydet').last);
      await settle(tester, const Duration(milliseconds: 500));
      final body = b.bodies['PATCH /users/me'] as Map;
      expect(body['displayName'], 'Ayşe Y.');
      expect(body.containsKey('faculty'), isFalse);
      expect(body.containsKey('department'), isFalse);
      expect(body.containsKey('grade'), isFalse);
      expect(body.containsKey('classYear'), isFalse);
      // Bayat dil sunucudaki güncel dili ezmesin (L32).
      expect(body.containsKey('language'), isFalse);
      await unmount(tester);
    });

    testWidgets('yalnızca sınıf değişirse yalnızca grade gider', (tester) async {
      final b = await open(tester);
      // Sınıf seçici liste sayfası: mevcut sınıf satırına dokun, listeden 3. sınıfı seç.
      await tester.tap(find.text('2. sınıf'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('3. sınıf').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Kaydet').last);
      await settle(tester, const Duration(milliseconds: 500));
      final body = b.bodies['PATCH /users/me'] as Map;
      expect(body['grade'], '3');
      expect(body.containsKey('faculty'), isFalse);
      expect(body.containsKey('department'), isFalse);
      await unmount(tester);
    });

    testWidgets('bölüm seçilince fakülte otomatik değişir; fakülte seçici yok', (tester) async {
      final b = await open(tester);
      expect(find.text('Fakülte seçin'), findsNothing);
      await tester.tap(find.text('Eski Serbest Bölüm'));
      await pickFromSearch(tester, 'biyo', 'Biyoloji');
      expect(find.text('Eski Serbest Fakülte'), findsNothing);
      expect(find.text('Fen-Edebiyat Fakültesi'), findsOneWidget);
      await tester.tap(find.text('Kaydet').last);
      await settle(tester, const Duration(milliseconds: 500));
      final body = b.bodies['PATCH /users/me'] as Map;
      expect(body['faculty'], 'Fen-Edebiyat Fakültesi');
      expect(body['department'], 'Biyoloji');
      expect(body.containsKey('grade'), isFalse);
      await unmount(tester);
    });

    for (final br in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('EditProfilePage akademik ${br.name} ${size.width.toInt()} taşma yok', (tester) async {
          useScreen(tester, size);
          final b = FakeBackend();
          fakeCatalog(b);
          await tester.pumpWidget(buildApp(
              EditProfilePage(session: makeSession(b), profile: {
                ...profile(),
                'faculty': 'Mühendislik-Mimarlık Fakültesi Çok Uzun Bir Fakülte Adı',
                'department': 'Çok Uzun Bir Bölüm Adı Bilgisayar ve Yazılım Mühendisliği (İngilizce)',
              }),
              brightness: br,
              size: size));
          await settle(tester, const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });

  group('Profil özeti ve gizlilik', () {
    testWidgets('profil sekmesi "Bölüm · sınıf" özeti gösterir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/users/me', {
          'id': 1,
          'displayName': 'Ayşe Yılmaz',
          'email': 'ayse@bingol.edu.tr',
          'faculty': 'Mühendislik Fakültesi',
          'department': 'Bilgisayar Mühendisliği',
          'grade': '3',
        });
      await tester.pumpWidget(
          buildApp(ProfileTab(session: makeSession(b), themeController: ThemeController())));
      await settle(tester);
      expect(find.text('Bilgisayar Mühendisliği · 3. sınıf'), findsOneWidget);
      await unmount(tester);
    });

    for (final br in Brightness.values) {
      for (final size in kPhoneSizes) {
        testWidgets('PrivacyDataPage ${br.name} ${size.width.toInt()} taşma yok', (tester) async {
          useScreen(tester, size);
          final b = FakeBackend()..on('/users/me/privacy', {'bio': 'SHARED_CONTEXT'});
          await tester.pumpWidget(
              buildApp(PrivacyDataPage(session: makeSession(b)), brightness: br, size: size));
          await settle(tester);
          expect(find.text('Profil görünürlüğü'), findsOneWidget);
          expect(find.text('Verilerim ve hesap', skipOffstage: false), findsOneWidget);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });
}

