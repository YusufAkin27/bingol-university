import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/profile/profile_inline_edit.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign/p00_support.dart';
import 'support/fake_app.dart';

/// Profilim satır içi düzenleme: ad / hakkımda yerinde, bölüm-sınıf seçici; alan başına kısmi PATCH,
/// iyimser güncelleme + hata halinde geri alma, tek anda tek alan, çift istek yok.

const _patch = 'PATCH /users/me';

Map<String, dynamic> _profile({String bio = 'Yazılım ve satranç.'}) => {
      'id': 1,
      'displayName': 'Ayşe Kaya',
      'email': 'ayse@bingol.edu.tr',
      'faculty': 'Mühendislik Fakültesi',
      'department': 'Bilgisayar Mühendisliği',
      'grade': '3',
      'bio': bio,
      'showEmail': false,
    };

/// ProfileTab'ın birleştirme davranışını taklit eden küçük kap.
class _Harness extends StatefulWidget {
  const _Harness({required this.session, required this.initial, required this.out});

  final Session session;
  final Map<String, dynamic> initial;
  final ValueNotifier<Map<String, dynamic>> out;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late Map<String, dynamic> p = widget.initial;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(padding: const EdgeInsets.all(20), children: [
          InlineProfileHero(
            session: widget.session,
            profile: p,
            avatar: const SizedBox(width: 88, height: 88),
            onPatch: (x) => setState(() {
              p = {...p, ...x};
              widget.out.value = p;
            }),
          ),
        ]),
      );
}

Future<ValueNotifier<Map<String, dynamic>>> _open(WidgetTester tester, FakeBackend b,
    {Map<String, dynamic>? profile, Size size = kPhoneMedium}) async {
  useScreen(tester, size);
  fakeCatalog(b);
  final out = ValueNotifier<Map<String, dynamic>>(profile ?? _profile());
  final session = _lastSession = makeSession(b);
  await tester.pumpWidget(buildApp(_Harness(session: session, initial: profile ?? _profile(), out: out), size: size));
  await settle(tester, const Duration(milliseconds: 400));
  return out;
}

Session? _lastSession;

Finder _k(String key) => find.byKey(ValueKey(key));

Future<void> _tap(WidgetTester tester, Finder f, [int ms = 500]) async {
  await tester.tap(f);
  await settle(tester, Duration(milliseconds: ms));
}

void _failPatch(FakeBackend b, {int status = 422, String code = 'CONTENT_PROFANITY', String message = 'Uygunsuz ifade'}) {
  b.handlers.add((req, path) =>
      req.method == 'PATCH' && path == '/users/me' ? FakeResult.json({'code': code, 'message': message}, status: status) : null);
}

void main() {
  setUpAll(loadTestFonts);

  group('Ad soyad', () {
    testWidgets('dokununca yerinde açılır, odaklanır; Başlık Harfi uygulanır; ✓ yalnız displayName gönderir', (tester) async {
      final b = FakeBackend();
      final out = await _open(tester, b);
      expect(_k('inline-name-field'), findsNothing);
      await _tap(tester, _k('inline-name'));
      expect(_k('inline-name-field'), findsOneWidget);
      expect(tester.widget<TextField>(_k('inline-name-field')).focusNode!.hasFocus, isTrue);
      await tester.enterText(_k('inline-name-field'), '  ahmet yılmaz ');
      await tester.pump();
      await _tap(tester, _k('inline-save'));
      final body = b.bodies[_patch] as Map;
      expect(body, {'displayName': 'Ahmet Yılmaz'}); // kırpıldı + Başlık Harfi; başka alan yok
      expect(out.value['displayName'], 'Ahmet Yılmaz');
      expect(_k('inline-name-field'), findsNothing);
      expect(find.text('Ahmet Yılmaz'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('✕ vazgeçer: istek yok, eski ad kalır', (tester) async {
      final b = FakeBackend();
      await _open(tester, b);
      await _tap(tester, _k('inline-name'));
      await tester.enterText(_k('inline-name-field'), 'Başka Ad');
      await _tap(tester, _k('inline-cancel'));
      expect(b.bodies.containsKey(_patch), isFalse);
      expect(find.text('Ayşe Kaya'), findsOneWidget);
      expect(_k('inline-name-field'), findsNothing);
      await unmount(tester);
    });

    testWidgets('değişmeden ✓: istek yok', (tester) async {
      final b = FakeBackend();
      await _open(tester, b);
      await _tap(tester, _k('inline-name'));
      await _tap(tester, _k('inline-save'));
      expect(b.bodies.containsKey(_patch), isFalse);
      expect(_k('inline-name-field'), findsNothing);
      await unmount(tester);
    });

    testWidgets('doğrulama: 2 karakterden kısa ad kaydedilmez, mesaj gösterilir, alan açık kalır', (tester) async {
      final b = FakeBackend();
      await _open(tester, b);
      await _tap(tester, _k('inline-name'));
      await tester.enterText(_k('inline-name-field'), ' A ');
      await _tap(tester, _k('inline-save'));
      expect(find.text('Ad en az 2 karakter olmalı.'), findsOneWidget);
      expect(b.bodies.containsKey(_patch), isFalse);
      expect(_k('inline-name-field'), findsOneWidget);
      // Yazmaya devam edince hata kalkar.
      await tester.enterText(_k('inline-name-field'), 'Al');
      await tester.pump();
      expect(find.text('Ad en az 2 karakter olmalı.'), findsNothing);
      await unmount(tester);
    });

    testWidgets('sunucu reddederse (422) eski değere döner, toast gösterir, yazılan metin tekrar açılır', (tester) async {
      final b = FakeBackend();
      _failPatch(b);
      final out = await _open(tester, b);
      await _tap(tester, _k('inline-name'));
      await tester.enterText(_k('inline-name-field'), 'Kötü Ad');
      await _tap(tester, _k('inline-save'), 1200);
      expect(out.value['displayName'], 'Ayşe Kaya', reason: 'iyimser değer geri alınmalı');
      expect(find.text(errorText(ApiError(422, 'CONTENT_PROFANITY', 'Uygunsuz ifade'))), findsWidgets);
      // Kullanıcı yazdığını kaybetmesin: alan taslakla yeniden açık.
      expect(_k('inline-name-field'), findsOneWidget);
      expect(tester.widget<TextField>(_k('inline-name-field')).controller!.text, 'Kötü Ad');
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('geri tuşu açık düzenlemeyi iptal eder', (tester) async {
      final b = FakeBackend();
      await _open(tester, b);
      await _tap(tester, _k('inline-name'));
      expect(_k('inline-name-field'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester, const Duration(milliseconds: 400));
      expect(_k('inline-name-field'), findsNothing);
      expect(b.bodies.containsKey(_patch), isFalse);
      await unmount(tester);
    });
  });

  group('Hakkımda', () {
    testWidgets('boşken "Kendini tanıt" satırı; sayaç 0/300; 300 sınırı; ✓ yalnız bio gönderir', (tester) async {
      final b = FakeBackend();
      final out = await _open(tester, b, profile: _profile(bio: ''));
      expect(find.text('Kendini tanıt'), findsOneWidget);
      await _tap(tester, _k('inline-bio-empty'));
      expect(find.text('0/300'), findsOneWidget);
      await tester.enterText(_k('inline-bio-field'), 'Merhaba');
      await tester.pump();
      expect(find.text('7/300'), findsOneWidget);
      await tester.enterText(_k('inline-bio-field'), 'a' * 400);
      await tester.pump();
      expect(find.text('300/300'), findsOneWidget);
      await tester.enterText(_k('inline-bio-field'), '  Merhaba dünya  ');
      await tester.pump();
      await _tap(tester, _k('inline-save'));
      expect(b.bodies[_patch], {'bio': 'Merhaba dünya'});
      expect(out.value['bio'], 'Merhaba dünya');
      expect(find.text('Merhaba dünya'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('temizlenince boş bio gönderilir ve "Kendini tanıt" geri gelir', (tester) async {
      final b = FakeBackend();
      await _open(tester, b);
      await _tap(tester, _k('inline-bio'));
      await tester.enterText(_k('inline-bio-field'), '');
      await _tap(tester, _k('inline-save'));
      expect(b.bodies[_patch], {'bio': ''});
      expect(find.text('Kendini tanıt'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('hata: eski bio geri gelir', (tester) async {
      final b = FakeBackend();
      _failPatch(b, status: 500, code: 'SERVER_ERROR', message: '');
      final out = await _open(tester, b);
      await _tap(tester, _k('inline-bio'));
      await tester.enterText(_k('inline-bio-field'), 'Yeni');
      await _tap(tester, _k('inline-save'), 1200);
      expect(out.value['bio'], 'Yazılım ve satranç.');
      expect(find.text('İşlem şu anda tamamlanamıyor. Lütfen biraz sonra tekrar deneyin.'), findsWidgets);
      await unmount(tester);
    });
  });

  group('Bölüm, sınıf', () {
    testWidgets('bölüm seçimi anında kaydedilir (fakülte birlikte); geri alma yok', (tester) async {
      final b = FakeBackend();
      final out = await _open(tester, b);
      await tester.tap(_k('inline-department'));
      await pickFromSearch(tester, 'biyo', 'Biyoloji');
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.bodies[_patch], {'faculty': 'Fen-Edebiyat Fakültesi', 'department': 'Biyoloji'});
      expect(out.value['department'], 'Biyoloji');
      expect(find.text('Biyoloji'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('bölüm hatası: eski bölüm geri döner', (tester) async {
      final b = FakeBackend();
      _failPatch(b, status: 500, code: 'SERVER_ERROR', message: '');
      final out = await _open(tester, b);
      await tester.tap(_k('inline-department'));
      await pickFromSearch(tester, 'biyo', 'Biyoloji');
      await settle(tester, const Duration(milliseconds: 1200));
      expect(out.value['department'], 'Bilgisayar Mühendisliği');
      expect(out.value['faculty'], 'Mühendislik Fakültesi');
      expect(find.text('Bilgisayar Mühendisliği'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('sınıf seçimi yalnız grade gönderir', (tester) async {
      final b = FakeBackend();
      final out = await _open(tester, b);
      await tester.tap(_k('inline-grade'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('4. sınıf').last);
      await settle(tester, const Duration(milliseconds: 800));
      expect(b.bodies[_patch], {'grade': '4'});
      expect(out.value['grade'], '4');
      await unmount(tester);
    });

    testWidgets('bölüm/sınıf kaydı ders programını yeniler: sinyal artar, /timetable yeniden çekilir; ad kaydı artırmaz', (tester) async {
      final b = FakeBackend();
      await _open(tester, b);
      final s = _lastSession!;
      expect(s.academicProfileSignal.value, 0);
      await tester.tap(_k('inline-department'));
      await pickFromSearch(tester, 'biyo', 'Biyoloji');
      await settle(tester, const Duration(milliseconds: 500));
      expect(s.academicProfileSignal.value, 1, reason: 'bölüm değişince açık ekranlar yeniden yüklenmeli');
      await tester.tap(_k('inline-grade'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('4. sınıf').last);
      await settle(tester, const Duration(milliseconds: 800));
      expect(s.academicProfileSignal.value, 2);
      expect(b.requests.any((r) => r.startsWith('GET /timetable')), isTrue, reason: 'hatırlatıcılar yeni programdan kurulur');
      await unmount(tester);
    });

    testWidgets('boş bölüm/sınıf "seçin" çipi gösterir', (tester) async {
      final b = FakeBackend();
      await _open(tester, b, profile: {'displayName': 'Ayşe Kaya', 'showEmail': false});
      expect(find.text('Bölüm seçin'), findsOneWidget);
      expect(find.text('Sınıf seçin'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kimlik kartında e-posta anahtarı yok (Ayarlar > Gizlilik ve veriler sayfasındadır)', (tester) async {
      final b = FakeBackend();
      await _open(tester, b);
      expect(_k('inline-show-email'), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.text('E-postamı diğer kullanıcılara göster'), findsNothing);
      await unmount(tester);
    });
  });

  group('Tek alan ve çift istek', () {
    testWidgets('başka alana dokunulunca açık düzenleme önce kaydedilir; tek anda tek metin kutusu', (tester) async {
      final b = FakeBackend();
      final out = await _open(tester, b);
      await _tap(tester, _k('inline-name'));
      await tester.enterText(_k('inline-name-field'), 'Zeynep Aksoy');
      await tester.pump();
      await _tap(tester, _k('inline-bio'), 800);
      expect(b.bodies[_patch], {'displayName': 'Zeynep Aksoy'});
      expect(out.value['displayName'], 'Zeynep Aksoy');
      expect(_k('inline-name-field'), findsNothing);
      expect(_k('inline-bio-field'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('geçersiz açık düzenleme başka alanı açtırmaz', (tester) async {
      final b = FakeBackend();
      await _open(tester, b);
      await _tap(tester, _k('inline-name'));
      await tester.enterText(_k('inline-name-field'), 'A');
      await _tap(tester, _k('inline-bio'));
      expect(_k('inline-name-field'), findsOneWidget);
      expect(_k('inline-bio-field'), findsNothing);
      expect(find.text('Ad en az 2 karakter olmalı.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('kayıt sürerken çift dokunma ve başka kayıt tek istek üretir', (tester) async {
      final b = FakeBackend();
      final out = await _open(tester, b);
      await _tap(tester, _k('inline-name'));
      await tester.enterText(_k('inline-name-field'), 'Zeynep Aksoy');
      await tester.pump();
      b.delay = const Duration(milliseconds: 600);
      await tester.tap(_k('inline-save'));
      await tester.pump(const Duration(milliseconds: 10)); // iyimser durum çizilir, geçiş başlar
      await tester.pump(const Duration(milliseconds: 300)); // düzenleyici soldu, yanıt (600 ms) henüz yok
      // iyimser: yanıt gelmeden yeni ad görünür + ilerleme göstergesi
      expect(find.text('Zeynep Aksoy'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      // sürerken: aynı alana, anahtara ve çipe dokunmak yeni istek başlatmaz
      await tester.tap(_k('inline-name'), warnIfMissed: false);
      await tester.tap(_k('inline-grade'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      await settle(tester, const Duration(seconds: 2));
      expect(b.bodyLog[_patch]!.length, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await unmount(tester);
    });
  });

  group('ProfileTab', () {
    FakeBackend backend() {
      final b = FakeBackend()
        ..on('/me/summary', {'communities': 3, 'events': 4, 'bookmarks': 12})
        ..on('/users/me', _profile())
        ..on('/users/1', {'id': 1, 'followerCount': 128, 'followingCount': 94, 'followedByMe': false});
      fakeCatalog(b);
      fakePosts(b, count: 4);
      return b;
    }

    testWidgets('"Düzenle" düğmesi yok; alanlar kimlik kartında düzenlenir', (tester) async {
      useScreen(tester, kPhoneLarge);
      final b = backend();
      await tester.pumpWidget(buildApp(ProfileTab(session: makeSession(b), themeController: ThemeController()), size: kPhoneLarge));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Düzenle'), findsNothing);
      expect(find.text('Profili düzenle'), findsNothing);
      expect(_k('profile-edit'), findsNothing);
      expect(_k('inline-name'), findsOneWidget);
      await _tap(tester, _k('inline-name'));
      await tester.enterText(_k('inline-name-field'), 'Elif Demir');
      await _tap(tester, _k('inline-save'));
      expect(b.bodies[_patch], {'displayName': 'Elif Demir'});
      expect(find.text('Elif Demir'), findsWidgets);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('Erişilebilirlik ve matris', () {
    testWidgets('anlamsal etiketler ve >= 44 dp dokunma hedefleri', (tester) async {
      final h = tester.ensureSemantics();
      final b = FakeBackend();
      await _open(tester, b);
      expect(find.bySemanticsLabel('Ad soyadı düzenle'), findsOneWidget);
      expect(find.bySemanticsLabel('Hakkımda alanını düzenle'), findsOneWidget);
      expect(find.bySemanticsLabel('Bölümü değiştir'), findsOneWidget);
      expect(find.bySemanticsLabel('Sınıfı değiştir'), findsOneWidget);
      for (final k in ['inline-name', 'inline-bio', 'inline-department', 'inline-grade']) {
        expect(tester.getSize(_k(k)).height, greaterThanOrEqualTo(44), reason: k);
      }
      await _tap(tester, _k('inline-name'));
      for (final k in ['inline-save', 'inline-cancel']) {
        expect(tester.getSize(_k(k)), const Size(44, 44), reason: k);
      }
      h.dispose();
      await unmount(tester);
    });

    testWidgets('matris tr/en/ar x açık/koyu x 1.0/1.3 x 320/390: okuma + ad düzenleme + bio düzenleme taşmaz', (tester) async {
      final b = FakeBackend();
      fakeCatalog(b);
      final profile = {
        ..._profile(),
        'displayName': 'Ayşe Yılmaz Çok Uzun Bir Soyadı Olan Öğrenci',
        'department': 'Çok Uzun Bir Bölüm Adı Bilgisayar ve Yazılım Mühendisliği (İngilizce)',
        'bio': 'Biyografi metni ' * 18,
      };
      await p00Matrix(
        tester,
        () => _Harness(session: makeSession(b), initial: profile, out: ValueNotifier(profile)),
        scaffold: false,
        settleMs: 300,
        check: (t, lang, dark, scale) async {
          await t.tap(_k('inline-name'));
          await t.pump(const Duration(milliseconds: 400));
          expect(_k('inline-name-field'), findsOneWidget);
          await t.tap(_k('inline-bio'));
          await t.pump(const Duration(milliseconds: 500));
          await t.pump(const Duration(milliseconds: 500));
        },
      );
    });
  });
}
