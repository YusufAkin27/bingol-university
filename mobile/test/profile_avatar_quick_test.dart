import 'dart:typed_data';

import 'package:bu_kampus/core/platform/image_service.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/profile/avatar_crop_page.dart';
import 'package:bu_kampus/features/profile/avatar_upload.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'support/fake_app.dart';

Uint8List _png() {
  final im = img.Image(width: 120, height: 120);
  for (var y = 0; y < 120; y++) {
    for (var x = 0; x < 120; x++) {
      im.setPixelRgb(x, y, x * 2, y * 2, 150);
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

/// Profil sekmesi: kamera rozeti -> dogrudan galeri -> kirpma ekrani; uzun bas -> kucuk menu (cek / kaldir).
void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });

  Map<String, dynamic> me({String? avatar}) => {
        'id': 1,
        'displayName': 'Ayşe Yılmaz',
        'email': 'ayse@bingol.edu.tr',
        'faculty': 'Mühendislik Fakültesi',
        'department': 'Bilgisayar Mühendisliği',
        'grade': '3',
        'avatarUrl': avatar,
      };

  FakeBackend backend({String? avatar, Duration delay = Duration.zero}) => FakeBackend(delay: delay)
    ..on('/users/me', me(avatar: avatar))
    ..on('/me/summary', {'communities': 2, 'events': 3, 'bookmarks': 4})
    ..on('/users/me/avatar', {'avatarUrl': '/files/avatars/new.jpg'});

  Widget tab(FakeBackend b, Session s, {AvatarHooks? hooks}) => buildApp(
        ProfileTab(
          session: s,
          themeController: ThemeController(),
          avatarHooks: hooks ?? AvatarHooks(cropPhoto: (_) async => _png(), uploader: MultipartUploader(s, client: b.client)),
        ),
        size: kPhoneMedium,
      );

  Future<void> open(WidgetTester tester, FakeBackend b, Session s, {AvatarHooks? hooks}) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(tab(b, s, hooks: hooks));
    await settle(tester, const Duration(seconds: 1));
  }

  Future<void> longPress(WidgetTester tester) async {
    await tester.longPress(find.byKey(const ValueKey('profile-avatar')));
    await settle(tester, const Duration(milliseconds: 600));
  }

  Future<void> tapBadge(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('avatar-badge')));
    await settle(tester, const Duration(milliseconds: 800));
  }

  final noSheet = find.byType(BottomSheet);

  testWidgets('kamera rozetine dokun: ara menu/bottom sheet yok, dogrudan galeri secici cagrilir', (tester) async {
    final b = backend();
    final s = makeSession(b);
    ImageSource? asked;
    await open(
        tester,
        b,
        s,
        hooks: AvatarHooks(
            pickPhoto: (src) async {
              asked = src;
              return null; // secici kapatildi
            },
            uploader: MultipartUploader(s, client: b.client)));
    expect(find.bySemanticsLabel('Profil fotoğrafını değiştir'), findsWidgets);
    expect(tester.getSize(find.byKey(const ValueKey('profile-avatar'))).width, greaterThanOrEqualTo(48));
    await tapBadge(tester);
    expect(asked, ImageSource.gallery);
    expect(noSheet, findsNothing);
    expect(find.byType(AvatarCropPage), findsNothing);
    expect(b.count('POST /users/me/avatar'), 0);
    await unmount(tester);
  });

  testWidgets('secilince kirpma ekrani acilir; Iptal -> istek yok, eski foto korunur', (tester) async {
    final b = backend(avatar: '/files/avatars/old.jpg');
    final s = makeSession(b);
    await open(tester, b, s, hooks: AvatarHooks(pickPhoto: (_) async => _png(), uploader: MultipartUploader(s, client: b.client)));
    s.avatarUrl.value = '/files/avatars/old.jpg';
    await tapBadge(tester);
    expect(find.byType(AvatarCropPage), findsOneWidget);
    expect(find.byKey(const ValueKey('avatarCropConfirm')), findsOneWidget);
    expect(find.byKey(const ValueKey('avatarCropCancel')), findsOneWidget);
    expect(find.text('Onayla'), findsOneWidget);
    expect(find.text('İptal'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('avatarCropCancel')));
    await settle(tester, const Duration(milliseconds: 800));
    expect(find.byType(AvatarCropPage), findsNothing);
    expect(b.count('POST /users/me/avatar'), 0);
    expect(s.avatarUrl.value, '/files/avatars/old.jpg');
    expect(tester.widget<BuAvatar>(find.byType(BuAvatar).first).url, '/files/avatars/old.jpg');
    await unmount(tester);
  });

  testWidgets('kirpma sayfasi: yakinlastir + Onayla kirpilmis baytlari doner, onizleme var', (tester) async {
    Uint8List? result;
    var done = false;
    await tester.pumpWidget(buildApp(Builder(
        builder: (c) => TextButton(
            onPressed: () async {
              result = await Navigator.of(c).push<Uint8List>(MaterialPageRoute(
                  builder: (_) => AvatarCropPage(
                      bytes: _png(),
                      prepare: (b) async => AvatarSource(b, 120, 120),
                      render: (s, r) async => Uint8List.fromList([1, 2, 3]))));
              done = true;
            },
            child: const Text('ac')))));
    await tester.tap(find.text('ac'));
    await settle(tester, const Duration(milliseconds: 800));
    expect(find.byKey(const ValueKey('avatarCropPreview')), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('avatarCropZoom')), const Offset(60, 0));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('avatarCropConfirm')));
    await settle(tester, const Duration(milliseconds: 800));
    expect(done, isTrue);
    expect(result, [1, 2, 3]);
    await unmount(tester);
  });

  test('kirpma matematigi: olcek 1 kisa kenari kaplar, yakinlastirma kareyi kucultur, kaydirma sinirlanir', () {
    final r1 = avatarCropRect(width: 400, height: 200, viewport: 100, scale: 1, dx: 0, dy: 0);
    expect(r1.width, 200);
    expect(r1.center, const Offset(200, 100));
    final r2 = avatarCropRect(width: 400, height: 200, viewport: 100, scale: 2, dx: 0, dy: 0);
    expect(r2.width, 100);
    final c = clampAvatarOffset(width: 400, height: 200, viewport: 100, scale: 1, offset: const Offset(500, 500));
    expect(c.dx, 50);
    expect(c.dy, 0);
  });

  test('kirpma cikti: kare, en cok 800 px JPEG', () {
    final big = Uint8List.fromList(img.encodeJpg(img.Image(width: 1600, height: 1000), quality: 80));
    final src = prepareAvatarSource(big);
    final out = renderAvatarCrop(src, avatarCropRect(width: src.width, height: src.height, viewport: 100, scale: 1, dx: 0, dy: 0));
    final d = img.decodeJpg(out)!;
    expect(d.width, d.height);
    expect(d.width, lessThanOrEqualTo(800));
  });

  testWidgets('onaylanan foto: yukleme cagrisi, session ve avatar hemen yenilenir, toast 2 sn sonra kaybolur', (tester) async {
    final b = backend();
    final s = makeSession(b);
    await open(tester, b, s);
    await tapBadge(tester);
    await settle(tester, const Duration(seconds: 1));
    expect(b.count('POST /users/me/avatar'), 1);
    expect(s.avatarUrl.value, '/files/avatars/new.jpg');
    expect(tester.widget<BuAvatar>(find.byType(BuAvatar).first).url, '/files/avatars/new.jpg');
    expect(find.byKey(const ValueKey('profile-avatar-busy')), findsNothing);
    expect(find.text('Profil fotoğrafınız güncellendi.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await settle(tester, const Duration(seconds: 1));
    expect(find.text('Profil fotoğrafınız güncellendi.'), findsNothing);
    await unmount(tester);
  });

  testWidgets('uzun bas: fotografsiz kullanicida yalniz "Fotoğraf çek"', (tester) async {
    final b = backend();
    await open(tester, b, makeSession(b));
    await longPress(tester);
    expect(find.byKey(const ValueKey('avatarMenuCamera')), findsOneWidget);
    expect(find.byKey(const ValueKey('avatarMenuRemove')), findsNothing);
    expect(find.byType(PopupMenuItem<int>), findsOneWidget);
    expect(find.text('Mevcut fotoğrafı düzenle'), findsNothing);
    expect(noSheet, findsNothing);
    await unmount(tester);
  });

  testWidgets('uzun bas: fotografli kullanicida tam iki secenek (cek + kaldir), duzenle yok', (tester) async {
    final b = backend(avatar: '/files/avatars/old.jpg');
    await open(tester, b, makeSession(b));
    await longPress(tester);
    expect(find.byType(PopupMenuItem<int>), findsNWidgets(2));
    expect(find.text('Fotoğraf çek'), findsOneWidget);
    expect(find.text('Fotoğrafı kaldır'), findsOneWidget);
    expect(find.text('Mevcut fotoğrafı düzenle'), findsNothing);
    expect(noSheet, findsNothing);
    await unmount(tester);
  });

  testWidgets('menuden Fotoğraf çek: kamera kaynagi ile secici cagrilir', (tester) async {
    final b = backend(avatar: '/files/avatars/old.jpg');
    final s = makeSession(b);
    ImageSource? asked;
    await open(
        tester,
        b,
        s,
        hooks: AvatarHooks(
            pickPhoto: (src) async {
              asked = src;
              return null;
            },
            uploader: MultipartUploader(s, client: b.client)));
    await longPress(tester);
    await tester.tap(find.byKey(const ValueKey('avatarMenuCamera')));
    await settle(tester, const Duration(milliseconds: 600));
    expect(asked, ImageSource.camera);
    await unmount(tester);
  });

  testWidgets('Fotoğrafı kaldır: DELETE, varsayilan avatar, session temizlenir', (tester) async {
    final b = backend(avatar: '/files/avatars/old.jpg');
    final s = makeSession(b);
    await open(tester, b, s);
    s.avatarUrl.value = '/files/avatars/old.jpg';
    await longPress(tester);
    await tester.tap(find.byKey(const ValueKey('avatarMenuRemove')));
    await settle(tester, const Duration(seconds: 2));
    expect(b.count('DELETE /users/me/avatar'), 1);
    expect(s.avatarUrl.value, isNull);
    expect(tester.widget<BuAvatar>(find.byType(BuAvatar).first).url, isNull);
    expect(find.text('Profil fotoğrafınız kaldırıldı.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('yukleme sirasinda kucuk ilerleme gostergesi, cift dokunus engeli', (tester) async {
    final b = backend(delay: const Duration(milliseconds: 700));
    final s = makeSession(b);
    await open(tester, b, s);
    await settle(tester, const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('avatar-badge')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const ValueKey('profile-avatar-busy')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('avatar-badge')));
    await settle(tester, const Duration(seconds: 3));
    expect(b.count('POST /users/me/avatar'), 1);
    expect(find.byKey(const ValueKey('profile-avatar-busy')), findsNothing);
    await unmount(tester);
  });

  testWidgets('yukleme hatasi (413): toast, MEVCUT FOTO KORUNUR', (tester) async {
    final b = backend(avatar: '/files/avatars/old.jpg')..fail('/users/me/avatar', status: 413, code: 'PAYLOAD_TOO_LARGE', message: 'x');
    final s = makeSession(b);
    await open(tester, b, s);
    s.avatarUrl.value = '/files/avatars/old.jpg';
    await tapBadge(tester);
    expect(find.textContaining('MB'), findsWidgets);
    expect(s.avatarUrl.value, '/files/avatars/old.jpg');
    expect(tester.widget<BuAvatar>(find.byType(BuAvatar).first).url, '/files/avatars/old.jpg');
    expect(find.byKey(const ValueKey('profile-avatar-busy')), findsNothing);
    await unmount(tester);
  });

  testWidgets('silme hatasi (ag): toast, avatar korunur', (tester) async {
    final b = backend(avatar: '/files/avatars/old.jpg')..network('/users/me/avatar');
    final s = makeSession(b);
    await open(tester, b, s);
    s.avatarUrl.value = '/files/avatars/old.jpg';
    await longPress(tester);
    await tester.tap(find.byKey(const ValueKey('avatarMenuRemove')));
    await settle(tester, const Duration(seconds: 2));
    expect(s.avatarUrl.value, '/files/avatars/old.jpg');
    expect(tester.widget<BuAvatar>(find.byType(BuAvatar).first).url, '/files/avatars/old.jpg');
    await unmount(tester);
  });

  for (final lang in ['tr', 'ar']) {
    for (final dark in [false, true]) {
      for (final size in [kPhoneSmall, kPhoneMedium]) {
        for (final scale in [1.0, 1.3]) {
          testWidgets('tasma yok | $lang ${dark ? 'koyu' : 'acik'} ${size.width.toInt()} x$scale (profil + kucuk menu + kirpma)', (tester) async {
            useScreen(tester, size);
            final b = backend(avatar: '/files/avatars/old.jpg');
            final s = makeSession(b);
            await tester.pumpWidget(MaterialApp(
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
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: ProfileTab(session: s, themeController: ThemeController()),
            ));
            await settle(tester, const Duration(seconds: 1));
            expect(tester.takeException(), isNull);
            await longPress(tester);
            expect(tester.takeException(), isNull);
            expect(find.byKey(const ValueKey('avatarMenuRemove')), findsOneWidget);
            await tester.tapAt(const Offset(5, 5)); // menuyu kapat
            await settle(tester, const Duration(milliseconds: 500));
            await unmount(tester);
          });
        }
      }
    }
  }

  for (final lang in ['tr', 'en', 'ar']) {
    for (final dark in [false, true]) {
      testWidgets('kirpma ekrani tasma yok | $lang ${dark ? 'koyu' : 'acik'}', (tester) async {
        useScreen(tester, kPhoneSmall);
        await tester.pumpWidget(MaterialApp(
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: AvatarCropPage(bytes: _png(), prepare: (b) async => AvatarSource(b, 120, 120)),
        ));
        await settle(tester, const Duration(milliseconds: 800));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('avatarCropConfirm')), findsOneWidget);
        await unmount(tester);
      });
    }
  }
}
