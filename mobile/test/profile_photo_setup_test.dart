import 'dart:typed_data';

import 'package:bu_kampus/core/platform/image_service.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/auth/profile_photo_setup_page.dart';
import 'package:bu_kampus/features/auth/profile_setup_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
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

/// Kayıt sonrası İSTEĞE BAĞLI "Profil fotoğrafı eklemek ister misiniz?" adımı ve kapıdaki yeri.
void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });

  FakeBackend backend() {
    final b = FakeBackend()..on('/users/me/avatar', {'avatarUrl': '/files/avatars/new.jpg'});
    fakeCatalog(b);
    return b;
  }

  Widget page(FakeBackend b, Session s, {VoidCallback? onDone, Future<Uint8List?> Function(ImageSource)? crop}) => buildApp(
        ProfilePhotoSetupPage(
          session: s,
          onDone: onDone ?? () {},
          cropPhoto: crop ?? (_) async => _png(),
          uploader: MultipartUploader(s, client: b.client),
        ),
      );

  Future<void> choose(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('photo-setup-avatar')));
    await settle(tester, const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('photoSrcGallery')));
    await settle(tester, const Duration(milliseconds: 800));
  }

  group('ProfilePhotoSetupPage', () {
    testWidgets('başlık, kısa alt başlık, avatar, "Fotoğraf seç" ve her zaman "Şimdilik atla"; bilgilendirme paragrafı yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend();
      await tester.pumpWidget(page(b, makeSession(b)));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Profil fotoğrafı eklemek ister misiniz?'), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-setup-avatar')), findsOneWidget);
      expect(find.text('Fotoğraf seç'), findsOneWidget);
      expect(find.text('Şimdilik atla'), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-setup-change')), findsNothing);
      // Avatar büyük ve yuvarlak alan (>= 140 dp).
      expect(tester.getSize(find.byKey(const ValueKey('photo-setup-avatar'))).width, greaterThanOrEqualTo(140));
      await unmount(tester);
    });

    testWidgets('"Şimdilik atla" onDone çağırır (istek atılmaz)', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend();
      var done = 0;
      await tester.pumpWidget(page(b, makeSession(b), onDone: () => done++));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('photo-setup-skip')));
      await tester.pump();
      expect(done, 1);
      expect(b.count('POST /users/me/avatar'), 0);
      await unmount(tester);
    });

    testWidgets('sistem geri tuşu atlama sayılır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend();
      var done = 0;
      await tester.pumpWidget(page(b, makeSession(b), onDone: () => done++));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(done, 1);
      await unmount(tester);
    });

    testWidgets('fotoğraf seçilince yüklenir, önizleme güncellenir; düğme "Devam"a döner, "Değiştir" çıkar', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend();
      final s = makeSession(b);
      var done = 0;
      await tester.pumpWidget(page(b, s, onDone: () => done++));
      await settle(tester, const Duration(milliseconds: 400));
      await choose(tester);
      expect(b.count('POST /users/me/avatar'), 1);
      expect(s.avatarUrl.value, '/files/avatars/new.jpg');
      expect(find.byKey(const ValueKey('photo-setup-preview')), findsOneWidget);
      expect(find.text('Fotoğraf seç'), findsNothing);
      expect(find.text('Devam'), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-setup-change')), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-setup-skip')), findsOneWidget, reason: 'atla yine görünür');
      await tester.tap(find.byKey(const ValueKey('photo-setup-primary')));
      await tester.pump();
      expect(done, 1);
      await unmount(tester);
    });

    testWidgets('düzenleyiciden vazgeçilirse yükleme yok, durum aynı', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend();
      await tester.pumpWidget(page(b, makeSession(b), crop: (_) async => null));
      await settle(tester, const Duration(milliseconds: 400));
      await choose(tester);
      expect(b.count('POST /users/me/avatar'), 0);
      expect(find.text('Fotoğraf seç'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('sunucu hatası (413) bantla gösterilir; atla yine çalışır; fotoğraf eklenmemiş kalır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend()..fail('/users/me/avatar', status: 413, code: 'PAYLOAD_TOO_LARGE', message: 'x');
      var done = 0;
      await tester.pumpWidget(page(b, makeSession(b), onDone: () => done++));
      await settle(tester, const Duration(milliseconds: 400));
      await choose(tester);
      expect(find.byKey(const ValueKey('photo-setup-preview')), findsNothing);
      expect(find.text('Fotoğraf seç'), findsOneWidget);
      expect(find.textContaining('MB'), findsWidgets, reason: 'boyut hatası metni');
      await tester.tap(find.byKey(const ValueKey('photo-setup-skip')));
      await tester.pump();
      expect(done, 1);
      await unmount(tester);
    });

    testWidgets('ağ hatası bantla gösterilir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend()..network('/users/me/avatar');
      await tester.pumpWidget(page(b, makeSession(b)));
      await settle(tester, const Duration(milliseconds: 400));
      await choose(tester);
      expect(find.byKey(const ValueKey('photo-setup-preview')), findsNothing);
      expect(find.text('Fotoğraf seç'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('yükleme sürerken çift dokunuş engellenir (tek istek, ikinci kaynak sayfası açılmaz)', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend(delay: const Duration(milliseconds: 600))..on('/users/me/avatar', {'avatarUrl': '/files/avatars/new.jpg'});
      await tester.pumpWidget(page(b, makeSession(b)));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('photo-setup-avatar')));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('photoSrcGallery')));
      await tester.pump(const Duration(milliseconds: 300));
      // yükleniyor
      await tester.tap(find.byKey(const ValueKey('photo-setup-avatar')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('photoSrcGallery')), findsNothing);
      await settle(tester, const Duration(seconds: 2));
      expect(b.count('POST /users/me/avatar'), 1);
      // yükleniyor sırasında atla yine çalışır
      await unmount(tester);
    });

    for (final lang in ['tr', 'ar']) {
      for (final dark in [false, true]) {
        for (final size in [kPhoneSmall, kPhoneMedium]) {
          for (final scale in [1.0, 1.3]) {
            testWidgets('taşma yok | $lang ${dark ? 'koyu' : 'açık'} ${size.width.toInt()} x$scale (boş + fotoğraflı)', (tester) async {
              useScreen(tester, size);
              final b = backend();
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
                home: ProfilePhotoSetupPage(
                  session: makeSession(b),
                  onDone: () {},
                  cropPhoto: (_) async => _png(),
                  uploader: MultipartUploader(makeSession(b), client: b.client),
                ),
              ));
              await settle(tester, const Duration(milliseconds: 500));
              expect(tester.takeException(), isNull);
              await choose(tester);
              expect(tester.takeException(), isNull);
              expect(find.byKey(const ValueKey('photo-setup-preview')), findsOneWidget);
              await unmount(tester);
            });
          }
        }
      }
    }
  });

  group('ProfileCompletionGate -> fotoğraf adımı', () {
    Widget gate(Session s) => buildApp(ProfileCompletionGate(session: s, child: const Scaffold(body: Text('KABUK'))));

    testWidgets('avatarı zaten olan kullanıcıda adım gösterilmez (bölüm kaydı sonrası doğrudan kabuk)', (tester) async {
      useScreen(tester, const Size(390, 1200));
      final b = backend()..on('/users/me', {'id': 1, 'department': null, 'grade': null, 'avatarUrl': '/files/avatars/x.jpg'});
      await tester.pumpWidget(gate(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 400));
      await fillAcademic(tester);
      await tester.tap(find.byKey(const ValueKey('profile-setup-submit')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(ProfilePhotoSetupPage), findsNothing);
      expect(find.text('KABUK'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('profil zaten tamam: fotoğraf adımı hiç sorulmaz', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = backend()..on('/users/me', {'id': 1, 'department': 'Biyoloji', 'grade': '2'});
      await tester.pumpWidget(gate(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byType(ProfilePhotoSetupPage), findsNothing);
      expect(find.text('KABUK'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('fotoğraf adımında bağlantı gelse de adım yerinde kalır (yeniden sorgu atlamaz)', (tester) async {
      useScreen(tester, const Size(390, 1200));
      final b = backend()..on('/users/me', {'id': 1, 'department': null, 'grade': null});
      final s = makeSession(b);
      await tester.pumpWidget(gate(s));
      await settle(tester, const Duration(milliseconds: 400));
      await fillAcademic(tester);
      await tester.tap(find.byKey(const ValueKey('profile-setup-submit')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(ProfilePhotoSetupPage), findsOneWidget);
      b.on('/users/me', {'id': 1, 'department': 'Biyoloji', 'grade': '2'});
      s.api.connectivity.reconnects.value++;
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(ProfilePhotoSetupPage), findsOneWidget);
      expect(find.text('KABUK'), findsNothing);
      await unmount(tester);
    });

    testWidgets('akış: bölüm + sınıf -> fotoğraf adımı -> geri tuşu atlar -> kabuk', (tester) async {
      useScreen(tester, const Size(390, 1200));
      final b = backend()..on('/users/me', {'id': 1, 'department': null, 'grade': null});
      await tester.pumpWidget(gate(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 400));
      await fillAcademic(tester);
      await tester.tap(find.byKey(const ValueKey('profile-setup-submit')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(ProfilePhotoSetupPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('KABUK'), findsOneWidget);
      await unmount(tester);
    });
  });
}
