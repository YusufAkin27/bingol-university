import 'dart:typed_data';

import 'package:bu_kampus/core/platform/image_service.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme_controller.dart';
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

/// Profil sekmesinde avatara dokunup hızlı fotoğraf değiştirme / düzenleme / kaldırma.
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
          avatarHooks: hooks ??
              AvatarHooks(
                cropPhoto: (_) async => _png(),
                editPhoto: (bytes) async => bytes,
                fetchBytes: (_) async => _png(),
                uploader: MultipartUploader(s, client: b.client),
              ),
        ),
        size: kPhoneMedium,
      );

  Future<void> open(WidgetTester tester, FakeBackend b, Session s, {AvatarHooks? hooks}) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(tab(b, s, hooks: hooks));
    await settle(tester, const Duration(seconds: 1));
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('profile-avatar')));
    await settle(tester, const Duration(milliseconds: 600));
  }

  testWidgets('avatar dokunulabilir: anlamsal etiket + dokunma alanı >= 48; fotoğrafsız kullanıcıda Kaldır/Düzenle yok', (tester) async {
    final b = backend();
    await open(tester, b, makeSession(b));
    expect(find.bySemanticsLabel('Profil fotoğrafını değiştir'), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('profile-avatar'))).width, greaterThanOrEqualTo(48));
    await openSheet(tester);
    expect(find.text('Profil fotoğrafı'), findsOneWidget);
    expect(find.byKey(const ValueKey('photoSrcCamera')), findsOneWidget);
    expect(find.byKey(const ValueKey('photoSrcGallery')), findsOneWidget);
    expect(find.byKey(const ValueKey('photoSrcEdit')), findsNothing);
    expect(find.byKey(const ValueKey('photoSrcRemove')), findsNothing);
    // Kamera üstte.
    expect(tester.getTopLeft(find.byKey(const ValueKey('photoSrcCamera'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('photoSrcGallery'))).dy));
    await tester.tap(find.byKey(const ValueKey('photoSrcClose')));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('photoSrcCamera')), findsNothing);
    await unmount(tester);
  });

  testWidgets('fotoğraflı kullanıcıda "Mevcut fotoğrafı düzenle" ve "Fotoğrafı kaldır" var', (tester) async {
    final b = backend(avatar: '/files/avatars/old.jpg');
    await open(tester, b, makeSession(b));
    await openSheet(tester);
    expect(find.byKey(const ValueKey('photoSrcEdit')), findsOneWidget);
    expect(find.text('Mevcut fotoğrafı düzenle'), findsOneWidget);
    expect(find.byKey(const ValueKey('photoSrcRemove')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('photoSrcClose')));
    await settle(tester, const Duration(milliseconds: 500));
    await unmount(tester);
  });

  testWidgets('galeriden seç: düzenleyici kancası -> yükleme -> avatar ve session.avatarUrl güncellenir', (tester) async {
    final b = backend();
    final s = makeSession(b);
    await open(tester, b, s);
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('photoSrcGallery')));
    await settle(tester, const Duration(seconds: 2));
    expect(b.count('POST /users/me/avatar'), 1);
    expect(s.avatarUrl.value, '/files/avatars/new.jpg');
    expect(tester.widget<BuAvatar>(find.byType(BuAvatar).first).url, '/files/avatars/new.jpg');
    expect(find.byKey(const ValueKey('profile-avatar-busy')), findsNothing);
    expect(find.text('Profil fotoğrafınız güncellendi.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('düzenleyiciden vazgeçilirse yükleme yok', (tester) async {
    final b = backend();
    final s = makeSession(b);
    await open(tester, b, s, hooks: AvatarHooks(cropPhoto: (_) async => null, uploader: MultipartUploader(s, client: b.client)));
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('photoSrcCamera')));
    await settle(tester, const Duration(seconds: 1));
    expect(b.count('POST /users/me/avatar'), 0);
    expect(s.avatarUrl.value, isNull);
    await unmount(tester);
  });

  testWidgets('mevcut fotoğrafı düzenle: indirir, düzenleyiciden geçirir, yükler', (tester) async {
    final b = backend(avatar: '/files/avatars/old.jpg');
    final s = makeSession(b);
    var fetched = '';
    var edited = 0;
    await open(
        tester,
        b,
        s,
        hooks: AvatarHooks(
          fetchBytes: (u) async {
            fetched = u;
            return _png();
          },
          editPhoto: (bytes) async {
            edited++;
            return bytes;
          },
          uploader: MultipartUploader(s, client: b.client),
        ));
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('photoSrcEdit')));
    await settle(tester, const Duration(seconds: 2));
    expect(fetched, endsWith('/files/avatars/old.jpg'));
    expect(edited, 1);
    expect(b.count('POST /users/me/avatar'), 1);
    expect(s.avatarUrl.value, '/files/avatars/new.jpg');
    await unmount(tester);
  });

  testWidgets('kaldır: onay iptal edilirse silinmez; onaylanırsa DELETE ve varsayılan avatar', (tester) async {
    final b = backend(avatar: '/files/avatars/old.jpg');
    final s = makeSession(b);
    await open(tester, b, s);
    s.avatarUrl.value = '/files/avatars/old.jpg';
    // İptal
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('photoSrcRemove')));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Profil fotoğrafınız kaldırılsın mı?'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(b.count('DELETE /users/me/avatar'), 0);
    expect(s.avatarUrl.value, '/files/avatars/old.jpg');
    // Onay
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('photoSrcRemove')));
    await settle(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Kaldır'));
    await settle(tester, const Duration(seconds: 2));
    expect(b.count('DELETE /users/me/avatar'), 1);
    expect(s.avatarUrl.value, isNull);
    expect(tester.widget<BuAvatar>(find.byType(BuAvatar).first).url, isNull);
    expect(find.text('Profil fotoğrafınız kaldırıldı.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('yükleme sırasında ilerleme halkası görünür ve ikinci dokunuş sayfa açmaz (çift dokunuş engeli)', (tester) async {
    final b = backend(delay: const Duration(milliseconds: 700));
    final s = makeSession(b);
    await open(tester, b, s);
    await settle(tester, const Duration(seconds: 1));
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('photoSrcGallery')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const ValueKey('profile-avatar-busy')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-avatar')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('photoSrcCamera')), findsNothing);
    await settle(tester, const Duration(seconds: 3));
    expect(b.count('POST /users/me/avatar'), 1);
    expect(find.byKey(const ValueKey('profile-avatar-busy')), findsNothing);
    await unmount(tester);
  });

  testWidgets('sunucu hatası (413) toast ile gösterilir; avatar değişmez', (tester) async {
    final b = backend()..fail('/users/me/avatar', status: 413, code: 'PAYLOAD_TOO_LARGE', message: 'x');
    final s = makeSession(b);
    await open(tester, b, s);
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('photoSrcGallery')));
    await settle(tester, const Duration(seconds: 2));
    expect(find.textContaining('MB'), findsWidgets);
    expect(s.avatarUrl.value, isNull);
    expect(find.byKey(const ValueKey('profile-avatar-busy')), findsNothing);
    await unmount(tester);
  });

  testWidgets('silme hatası (ağ) toast ile gösterilir; avatar korunur', (tester) async {
    final b = backend(avatar: '/files/avatars/old.jpg')..network('/users/me/avatar');
    final s = makeSession(b);
    await open(tester, b, s);
    s.avatarUrl.value = '/files/avatars/old.jpg';
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('photoSrcRemove')));
    await settle(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('Kaldır'));
    await settle(tester, const Duration(seconds: 2));
    expect(s.avatarUrl.value, '/files/avatars/old.jpg');
    expect(tester.widget<BuAvatar>(find.byType(BuAvatar).first).url, '/files/avatars/old.jpg');
    await unmount(tester);
  });

  for (final lang in ['tr', 'ar']) {
    for (final dark in [false, true]) {
      for (final size in [kPhoneSmall, kPhoneMedium]) {
        for (final scale in [1.0, 1.3]) {
          testWidgets('taşma yok | $lang ${dark ? 'koyu' : 'açık'} ${size.width.toInt()} x$scale (profil + alt sayfa + onay)', (tester) async {
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
            await openSheet(tester);
            expect(tester.takeException(), isNull);
            await tester.tap(find.byKey(const ValueKey('photoSrcRemove')));
            await settle(tester, const Duration(milliseconds: 600));
            expect(tester.takeException(), isNull);
            await unmount(tester);
          });
        }
      }
    }
  }
}
