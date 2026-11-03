@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/platform/image_service.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/auth/profile_photo_setup_page.dart';
import 'package:bu_kampus/features/media_crop/avatar_editor_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../support/fake_app.dart';

/// Profil fotoğrafı adımı, düzenleyici ve Profil sekmesi alt sayfası ekran görüntüleri.
/// Üretim: PHOTO_OUT='C:/bu_qa/shots/photo' flutter test test/redesign/photo_shots_test.dart
/// İsteğe bağlı: PHOTO_LANG=tr,ar
void main() {
  final out = Platform.environment['PHOTO_OUT'];
  final langs = (Platform.environment['PHOTO_LANG'] ?? 'tr').split(',');
  const w = 390.0, h = 844.0, dpr = 2.0;
  setUpAll(loadTestFonts);

  /// Fotoğraf benzeri test görseli: gökyüzü gradyanı, güneş, tepeler.
  Uint8List photo({int pw = 900, int ph = 600}) {
    final im = img.Image(width: pw, height: ph);
    for (var y = 0; y < ph; y++) {
      for (var x = 0; x < pw; x++) {
        final t = y / ph;
        var r = 90 + 120 * t, g = 150 + 70 * t, b = 235 - 60 * t;
        final dx = x - pw * .72, dy = y - ph * .28;
        final sun = math.exp(-(dx * dx + dy * dy) / (2 * 55 * 55));
        r += 160 * sun;
        g += 120 * sun;
        b += 20 * sun;
        final hill = ph * (.66 + .08 * math.sin(x / 90.0) + .05 * math.sin(x / 33.0));
        if (y > hill) {
          r = 40 + 40 * ((y - hill) / ph);
          g = 120 - 30 * ((y - hill) / ph);
          b = 60;
        }
        // yüz benzeri daire (portre hissi)
        final fx = x - pw * .34, fy = y - ph * .5;
        if (fx * fx + fy * fy < 80 * 80) {
          r = 232;
          g = 190;
          b = 160;
        }
        im.setPixelRgb(x, y, r.clamp(0, 255).toInt(), g.clamp(0, 255).toInt(), b.clamp(0, 255).toInt());
      }
    }
    return Uint8List.fromList(img.encodePng(im));
  }

  Widget shell(GlobalKey key, bool dark, String lang, Widget home) => RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: BuTheme.forLocale(Brightness.light, lang),
          darkTheme: BuTheme.forLocale(Brightness.dark, lang),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          locale: Locale(lang),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: home,
        ),
      );

  Map<String, dynamic> me({String? avatar}) => {
        'id': 1,
        'displayName': 'Ayşe Yılmaz',
        'email': 'ayse@bingol.edu.tr',
        'faculty': 'Mühendislik Fakültesi',
        'department': 'Bilgisayar Mühendisliği',
        'grade': '3',
        'bio': 'Kampüste kahve ve kod.',
        'avatarUrl': avatar,
      };

  FakeBackend backend({String? avatar}) => FakeBackend()
    ..on('/users/me', me(avatar: avatar))
    ..on('/me/summary', {'communities': 2, 'events': 3, 'bookmarks': 4})
    ..on('/users/me/avatar', {'avatarUrl': '/files/avatars/new.jpg'});

  Finder k(String key) => find.byKey(ValueKey(key));

  Future<void> openEditor(WidgetTester t) async {
    await t.tap(k('open'));
    await t.pump();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await t.pump(const Duration(milliseconds: 600));
  }

  Widget editorHome(Uint8List bytes) => Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('open'),
              onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => AvatarEditorPage(bytes: bytes))),
              child: const Text('ac'),
            ),
          ),
        ),
      );

  final cases = <String, ({Widget Function(FakeBackend b, Session s) page, Future<void> Function(WidgetTester t) act})>{
    'foto_adim_bos': (page: (b, s) => ProfilePhotoSetupPage(session: s, onDone: () {}), act: (t) async {}),
    'foto_adim_secili': (
      page: (b, s) => ProfilePhotoSetupPage(
            session: s,
            onDone: () {},
            cropPhoto: (_) async => photo(),
            uploader: MultipartUploader(s, client: b.client),
          ),
      act: (t) async {
        await t.tap(k('photo-setup-avatar'));
        await settle(t, const Duration(milliseconds: 600));
        await t.tap(k('photoSrcGallery'));
        await settle(t, const Duration(milliseconds: 900));
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400))); // önizleme kodlayıcısı
        await t.pump(const Duration(milliseconds: 300));
      }
    ),
    'editor_varsayilan': (page: (b, s) => editorHome(photo()), act: (t) async => openEditor(t)),
    'editor_yakin': (
      page: (b, s) => editorHome(photo()),
      act: (t) async {
        await openEditor(t);
        // yakınlaştırma kaydırıcısı sağa
        await t.drag(k('avatarEdZoom'), const Offset(110, 0));
        await settle(t, const Duration(milliseconds: 400));
        await t.drag(k('avatarEdStage'), const Offset(-40, 10));
        await settle(t, const Duration(milliseconds: 600));
      }
    ),
    'editor_uzak_bulanik': (
      page: (b, s) => editorHome(photo()),
      act: (t) async {
        await openEditor(t);
        await t.drag(k('avatarEdZoom'), const Offset(-200, 0));
        await settle(t, const Duration(milliseconds: 600));
      }
    ),
    'editor_aci': (
      page: (b, s) => editorHome(photo()),
      act: (t) async {
        await openEditor(t);
        await t.drag(k('avatarEdAngle'), const Offset(50, 0));
        await settle(t, const Duration(milliseconds: 600));
      }
    ),
    'editor_zemin_beyaz': (
      page: (b, s) => editorHome(photo()),
      act: (t) async {
        await openEditor(t);
        await t.drag(k('avatarEdZoom'), const Offset(-200, 0));
        await settle(t, const Duration(milliseconds: 400));
        await t.tap(k('avatarEdTab-bg'));
        await settle(t, const Duration(milliseconds: 400));
        await t.tap(k('avatarEdBg-sand'));
        await settle(t, const Duration(milliseconds: 500));
      }
    ),
    'editor_filtre': (
      page: (b, s) => editorHome(photo()),
      act: (t) async {
        await openEditor(t);
        await t.tap(k('avatarEdTab-filter'));
        await settle(t, const Duration(milliseconds: 400));
        await t.tap(k('avatarEdFilter-warm'));
        await settle(t, const Duration(milliseconds: 500));
      }
    ),
    'editor_ayarla': (
      page: (b, s) => editorHome(photo()),
      act: (t) async {
        await openEditor(t);
        await t.tap(k('avatarEdTab-adjust'));
        await settle(t, const Duration(milliseconds: 400));
        await t.tap(k('avatarEdAdj-saturation'));
        await settle(t, const Duration(milliseconds: 300));
        await t.drag(k('avatarEdAdjSlider'), const Offset(70, 0));
        await settle(t, const Duration(milliseconds: 500));
      }
    ),
    'profil_sekmesi': (
      page: (b, s) => ProfileTab(session: s, themeController: ThemeController()),
      act: (t) async {}
    ),
    'profil_sayfa_fotosuz': (
      page: (b, s) => ProfileTab(session: s, themeController: ThemeController()),
      act: (t) async {
        await t.tap(k('profile-avatar'));
        await settle(t, const Duration(milliseconds: 700));
      }
    ),
    'profil_sayfa_fotolu': (
      page: (b, s) => ProfileTab(session: s, themeController: ThemeController()),
      act: (t) async {
        await t.tap(k('profile-avatar'));
        await settle(t, const Duration(milliseconds: 700));
      }
    ),
  };

  for (final lang in langs) {
    for (final dark in [false, true]) {
      for (final e in cases.entries) {
        testWidgets('photo ${e.key} ${dark ? 'koyu' : 'acik'} $lang', skip: out == null, (tester) async {
          tester.view.devicePixelRatio = dpr;
          tester.view.physicalSize = const Size(w * dpr, h * dpr);
          addTearDown(tester.view.reset);
          final b = backend(avatar: e.key == 'profil_sayfa_fotolu' ? '/files/avatars/old.jpg' : null);
          final s = makeSession(b);
          final key = GlobalKey();
          await tester.pumpWidget(shell(key, dark, lang, e.value.page(b, s)));
          await settle(tester, const Duration(milliseconds: 1200));
          await e.value.act(tester);
          await settle(tester, const Duration(milliseconds: 500));
          final err = tester.takeException();
          if (err != null) fail('Istisna: $err');
          await tester.runAsync(() async {
            final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await ro.toImage(pixelRatio: dpr);
            final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
            final dir = Directory(out!)..createSync(recursive: true);
            File('${dir.path}/${e.key}${dark ? '_koyu' : ''}_$lang.png').writeAsBytesSync(data.buffer.asUint8List());
          });
          await unmount(tester);
        });
      }
    }
  }
}
