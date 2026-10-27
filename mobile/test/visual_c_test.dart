import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/profile/edit_profile_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/features/profile/settings_page.dart';
import 'package:bu_kampus/features/search/search_page.dart';
import 'package:bu_kampus/widgets/bu_widgets.dart' show trUpper;
import 'package:bu_kampus/widgets/simple_markdown.dart';
import 'package:bu_kampus/features/profile/legal_pages.dart';
import 'package:bu_kampus/features/profile/privacy_data_page.dart';
import 'package:bu_kampus/features/profile/user_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pages_c_test.dart' show PageCase, kPageCases, noErr;
import 'support/fake_app.dart';

/// Görsel denetim (C): profil/ayarlar/destek/bildirim/arama/yemek/hukuki sayfaları.
/// Taşma regresyonu her çalıştırmada; PNG üretimi `SHOTS=1` ile (build/shots/c/).
final _shots = Platform.environment['SHOTS'] == '1';
final _boundary = GlobalKey();

Future<void> _loadLucide() async {
  final f = File('C:/pubcache/hosted/pub.dev/lucide_icons_flutter-4.0.1/assets/lucide.ttf');
  if (!f.existsSync()) return;
  final l = FontLoader('packages/lucide_icons_flutter/Lucide')
    ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  await l.load();
}

final _profile = {
  'id': 2,
  'displayName': 'Mehmet Kaya',
  'faculty': 'Mühendislik Fakültesi',
  'department': 'Bilgisayar Mühendisliği',
  'classYear': 3,
  'bio': 'Merhaba, ben Mehmet. İstanbul, ışık, Şişli, İğne ve ığdır. ' * 3,
  'avatarUrl': null,
  'email': 'mehmet@bingol.edu.tr',
};

const _md = '''# Kullanım Koşulları

## 1. Taraflar ve kapsam

Bu metin **Bingöl Üniversitesi** öğrencileri için hazırlanmıştır. İstanbul, ışık, İğne, Şişli ve ığdır sözcükleri Türkçe karakterleri sınar.

> **Özetle:** Hizmeti kullanmak için bu koşulları kabul edersiniz. Bu özet bir alıntı bloğudur ve uzun metin satır kaydırmasını da denetler.

- Kayıt yalnızca bingol.edu.tr e-postasıyla yapılır.
- Hesap size aittir ve **devredilemez**.

1. Saygılı olun: hakaret ve taciz yasaktır.
2. Spam yapmayın.

| Veri | Neden | Saklama süresi |
|---|---|---|
| **Hesap:** e-posta, ad-soyad | Üyelik ve kimlik doğrulama | Hesap açık olduğu sürece |
| **Mesajlar:** metin, fotoğraf, video | Mesajlaşma hizmeti | Silinen mesajların şifreli kopyası güvenlik için saklanır |

---

Son paragraf.''';

final _extra = <PageCase>[
  PageCase(
    'LegalDocMarkdown',
    (b, tc) => LegalDocPage(session: makeSession(b), type: 'TERMS'),
    full: (b) => b.on('/legal/TERMS',
        {'type': 'TERMS', 'title': 'Kullanım Koşulları', 'version': 3, 'publishedAt': '2026-10-01T00:00:00', 'content': _md}),
    marker: 'Sürüm 3',
    failKeys: const ['/legal/TERMS'],
  ),
  PageCase(
    'EditProfilePage',
    (b, tc) => EditProfilePage(session: makeSession(b), profile: const {
      'displayName': 'Ayşe Yılmaz Çok Uzun Bir Soyadı Olan Öğrenci',
      'faculty': 'Mühendislik-Mimarlık Fakültesi',
      'department': 'Bilgisayar Mühendisliği',
      'classYear': 3,
      'bio': 'Biyografi metni İstanbul ışık.',
      'showEmail': true,
      'language': 'tr',
    }),
    full: (b) {
      b.on('/faculties', ['Mühendislik-Mimarlık Fakültesi', 'Fen-Edebiyat Fakültesi']);
      fakeCatalog(b);
    },
    marker: 'Profili düzenle',
    failKeys: const [],
    checkLoading: false,
  ),
  PageCase(
    'UserProfilePage',
    (b, tc) => UserProfilePage(session: makeSession(b), userId: 2, initialName: 'Mehmet'),
    full: (b) => b.on('/users/2', _profile),
    marker: 'Mehmet Kaya',
    failKeys: const [],
  ),
  PageCase(
    'UserProfileWithPosts',
    (b, tc) => UserProfilePage(session: makeSession(b), userId: 2, initialName: 'Mehmet'),
    full: (b) {
      b.on('/users/2', _profile);
      fakePosts(b, count: 7);
    },
    marker: 'Mehmet Kaya',
    failKeys: const [],
  ),
  PageCase(
    'UserProfileBare',
    (b, tc) => UserProfilePage(session: makeSession(b), userId: 2, initialName: 'Mehmet'),
    full: (b) => b.on('/users/2', {'id': 2, 'displayName': 'Çok Uzun Bir İsim Soyisim Olan Kullanıcı Adı Burada'}),
    marker: 'Çok Uzun',
    failKeys: const [],
  ),
  PageCase(
    'PrivacyDataPage',
    (b, tc) => PrivacyDataPage(session: makeSession(b)),
    full: (b) => b.on('/users/me', {'id': 1, 'showEmail': true, 'language': 'tr'}),
    marker: 'Hesabımı sil',
    failKeys: const [],
    checkLoading: false,
  ),
];

Widget _wrap(Widget page, Size size, bool dark, {bool rtl = false, bool outer = false}) {
  // outer: sınır uygulamanın dışında; diyalog/alt sayfa (Navigator overlay) da PNG'ye girer.
  if (outer) {
    return RepaintBoundary(key: _boundary, child: buildApp(page, brightness: dark ? Brightness.dark : Brightness.light, size: size));
  }
  final inner = RepaintBoundary(key: _boundary, child: page);
  if (!rtl) return buildApp(inner, brightness: dark ? Brightness.dark : Brightness.light, size: size);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BuTheme.light(),
    darkTheme: BuTheme.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    locale: const Locale('ar'),
    home: inner,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(size: size),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Align(alignment: Alignment.topLeft, child: SizedBox(width: size.width, height: size.height, child: child)),
      ),
    ),
  );
}

Future<void> _shot(WidgetTester tester, String name) async {
  final b = _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final img = await b.toImage(pixelRatio: 1.5);
    final png = (await img.toByteData(format: ui.ImageByteFormat.png))!;
    final dir = Directory('build/shots/c')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(png.buffer.asUint8List());
  });
}

Future<void> _run(WidgetTester tester, PageCase c, Size size, bool dark, double scale,
    {bool rtl = false, String? shot, FakeBackend? backend}) async {
  _trace();
  useScreen(tester, size);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final b = backend ?? FakeBackend();
  if (backend == null) c.full(b);
  await tester.pumpWidget(_wrap(c.build(b, ThemeController()), size, dark, rtl: rtl));
  if (c.act != null) await c.act!(tester);
  await settle(tester, const Duration(seconds: 2));
  if (shot != null && _shots) await _shot(tester, shot);
  noErr(tester);
  await unmount(tester);
  noErr(tester);
}

void _trace() {
  final prev = FlutterError.onError;
  FlutterError.onError = (d) {
    final txt = d.toString().replaceAll(RegExp(r"s+"), " ");
    final m = RegExp(r"creator: [^<]{0,200}|The relevant error-causing widget was: [^#]{0,160}").allMatches(txt);
    // ignore: avoid_print
    print("TRACE>> ${d.exceptionAsString()} ${m.map((x) => x.group(0)).join(" | ")}");
    prev?.call(d);
  };
}

void main() {
  setUpAll(() async {
    await loadTestFonts();
    await _loadLucide();
  });

  final all = [...kPageCases, ..._extra];

  for (final c in all) {
    group('görsel C ${c.name}', () {
      for (final dark in [false, true]) {
        for (final size in kPhoneSizes) {
          for (final scale in [1.0, 1.5]) {
            testWidgets('${dark ? 'koyu' : 'acik'} ${size.width.toInt()} x$scale taşma yok', (tester) async {
              await _run(tester, c, size, dark, scale);
            });
          }
        }
      }
      if (_shots) {
        for (final dark in [false, true]) {
          for (final (size, scale) in [(kPhoneSmall, 2.0), (kPhoneMedium, 1.0), (kPhoneLarge, 1.3), (kPhoneSmall, 1.0)]) {
            testWidgets('PNG ${dark ? 'koyu' : 'acik'} ${size.width.toInt()} x$scale', (tester) async {
              await _run(tester, c, size, dark, scale,
                  shot: '${c.name}__${dark ? 'koyu' : 'acik'}_${size.width.toInt()}_x${scale.toStringAsFixed(1)}');
            });
          }
        }
        if (c.empty != null) {
          testWidgets('PNG bos', (tester) async {
            final b = FakeBackend();
            c.empty!(b);
            await _run(tester, c, kPhoneMedium, false, 1.0, shot: '${c.name}__bos_390', backend: b);
          });
        }
        testWidgets('PNG hata', (tester) async {
          final b = FakeBackend();
          c.full(b);
          for (final k in c.failKeys) {
            b.fail(k);
          }
          await _run(tester, c, kPhoneSmall, true, 1.0, shot: '${c.name}__hata_320', backend: b);
        });
      }
    });
  }

  // RTL (Arapça): en az 6 sayfa.
  const rtlPages = [
    'ProfileTab',
    'SettingsPage',
    'NotificationsPage',
    'SearchPage',
    'SupportPage',
    'MenuPage',
    'LegalDocPage',
    'LegalDocMarkdown',
    'EditProfilePage',
    'BlockedUsersPage',
    'UserProfilePage',
    'PrivacyDataPage',
  ];
  for (final n in rtlPages) {
    final c = all.firstWhere((x) => x.name == n);
    group('RTL $n', () {
      for (final size in [kPhoneSmall, kPhoneMedium]) {
        testWidgets('${size.width.toInt()} taşma yok', (tester) async {
          await _run(tester, c, size, false, 1.3,
              rtl: true, shot: _shots ? 'RTL_${c.name}_${size.width.toInt()}' : null);
        });
      }
    });
  }

  // Diyalog / alt sayfa taşmaları (320 dp, büyük yazı, klavye açık).
  group('diyalog ve alt sayfa', () {
    for (final dark in [false, true]) {
      testWidgets('hesap silme diyaloğu 320 x2.0 klavye ${dark ? 'koyu' : 'acik'}', (tester) async {
        _trace();
        useScreen(tester, kPhoneSmall);
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetViewInsets);
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final b = FakeBackend()..on('/users/me', {'id': 1, 'showEmail': true, 'language': 'tr'});
        await tester.pumpWidget(_wrap(PrivacyDataPage(session: makeSession(b)), kPhoneSmall, dark, outer: true));
        await settle(tester, const Duration(milliseconds: 500));
        await tester.scrollUntilVisible(find.text('Hesabımı sil'), 100, scrollable: find.byType(Scrollable).first);
        await tester.tap(find.text('Hesabımı sil'));
        await settle(tester, const Duration(milliseconds: 600));
        if (_shots) await _shot(tester, 'Dialog_hesapsil_${dark ? 'koyu' : 'acik'}');
        noErr(tester);
        await unmount(tester);
      });
    }

    testWidgets('ayarlar: çıkış diyaloğu 320 x1.5', (tester) async {
      _trace();
      useScreen(tester, kPhoneSmall);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final b = FakeBackend()
        ..on('/users/me', {'id': 1, 'language': 'tr', 'showEmail': false})
        ..on('/notifications/preferences',
            {'news': true, 'announcements': true, 'events': true, 'communities': true, 'messages': true});
      await tester.pumpWidget(_wrap(
          SettingsPage(session: makeSession(b), themeController: ThemeController()), kPhoneSmall, false, outer: true));
      await settle(tester);
      await tester.scrollUntilVisible(find.textContaining('cihazlardan'), 100, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.textContaining('cihazlardan').last);
      await settle(tester, const Duration(milliseconds: 600));
      if (_shots) await _shot(tester, 'Dialog_cikis_acik');
      noErr(tester);
      await unmount(tester);
    });
  });

  // Erişilebilirlik: etiketler, anahtar durumu, başlıklar.
  group('semantics', () {
    testWidgets('ayarlar: anahtarlar durumlu, segment seçili, geri etiketli', (tester) async {
      final h = tester.ensureSemantics();
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/users/me', {'id': 1, 'language': 'tr', 'showEmail': true})
        ..on('/notifications/preferences',
            {'news': true, 'announcements': false, 'events': false, 'communities': true, 'messages': true});
      await tester.pumpWidget(buildApp(SettingsPage(session: makeSession(b), themeController: ThemeController())));
      await settle(tester);
      final off = tester.getSemantics(find.text('Etkinlikler'));
      expect(off.label, contains('Etkinlikler'));
      expect(off.getSemanticsData().flagsCollection.isToggled, ui.Tristate.isFalse);
      final on = tester.getSemantics(find.text('Haberler'));
      expect(on.getSemanticsData().flagsCollection.isToggled, ui.Tristate.isTrue);
      expect(find.bySemanticsLabel('Geri'), findsWidgets);
      final seg = tester.getSemantics(find.text('Sistem'));
      expect(seg.getSemanticsData().flagsCollection.isSelected, ui.Tristate.isTrue);
      expect(seg.getSemanticsData().flagsCollection.isButton, isTrue);
      await unmount(tester);
      h.dispose();
    });

    testWidgets('arama: temizle etiketli, gönderi sekmesi var, seçili sekme işaretli', (tester) async {
      final h = tester.ensureSemantics();
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      kPageCases.firstWhere((c) => c.name == 'SearchPage').full(b);
      await tester.pumpWidget(buildApp(SearchPage(session: makeSession(b))));
      await tester.enterText(find.byType(TextField).first, 'sonuc');
      await tester.pump(const Duration(milliseconds: 500));
      await settle(tester);
      expect(find.bySemanticsLabel('Aramayı temizle'), findsOneWidget);
      expect(find.text('Gönderi'), findsWidgets);
      final all = tester.getSemantics(find.text('Tümü'));
      expect(all.getSemanticsData().flagsCollection.isSelected, ui.Tristate.isTrue);
      await unmount(tester);
      h.dispose();
    });

    testWidgets('bildirimler: okunmamış işaretli, başlık başlıktır', (tester) async {
      final h = tester.ensureSemantics();
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      kPageCases.firstWhere((c) => c.name == 'NotificationsPage').full(b);
      await tester.pumpWidget(buildApp(NotificationsPage(session: makeSession(b))));
      await settle(tester);
      expect(find.bySemanticsLabel(RegExp('Okunmamış bildirim')), findsWidgets);
      final head = tester.getSemantics(find.text('Bildirimler').first);
      expect(head.getSemanticsData().flagsCollection.isHeader, isTrue);
      await unmount(tester);
      h.dispose();
    });

    testWidgets('profil ve yemek: ikon düğmeleri etiketli', (tester) async {
      final h = tester.ensureSemantics();
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend();
      kPageCases.firstWhere((c) => c.name == 'ProfileTab').full(b);
      await tester.pumpWidget(buildApp(ProfileTab(session: makeSession(b), themeController: ThemeController())));
      await settle(tester);
      expect(find.bySemanticsLabel('Ayarlar'), findsWidgets);
      await unmount(tester);
      final b2 = FakeBackend();
      kPageCases.firstWhere((c) => c.name == 'MenuPage').full(b2);
      await tester.pumpWidget(buildApp(MenuPage(session: makeSession(b2))));
      await settle(tester);
      expect(find.bySemanticsLabel('Önceki ay'), findsWidgets);
      expect(find.bySemanticsLabel('Sonraki ay'), findsWidgets);
      await unmount(tester);
      h.dispose();
    });
  });

  // Markdown ayrıştırıcı ve Türkçe büyük harf.
  test('simple markdown: başlık, alıntı, tablo, madde ayrılır', () {
    final blocks = parseMarkdown(_md);
    final kinds = blocks.map((b) => b.kind).toSet();
    expect(kinds,
        containsAll([MdKind.heading, MdKind.quote, MdKind.bullet, MdKind.numbered, MdKind.table, MdKind.rule, MdKind.paragraph]));
    final table = blocks.firstWhere((b) => b.kind == MdKind.table);
    expect(table.header, ['Veri', 'Neden', 'Saklama süresi']);
    expect(table.rows.length, 2);
    expect(trUpper('kasım bildirim ışık'), 'KASIM BİLDİRİM IŞIK');
  });
}
