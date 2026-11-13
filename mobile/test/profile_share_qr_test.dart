
import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/features/events/qr_painter.dart' show QrCode;
import 'package:bu_kampus/features/profile/profile_qr_logic.dart';
import 'package:bu_kampus/features/profile/profile_qr_page.dart';
import 'package:bu_kampus/features/scan/scan_page.dart';
import 'package:bu_kampus/features/profile/profile_qr_style.dart';
import 'package:bu_kampus/features/profile/profile_qr_widgets.dart';
import 'package:bu_kampus/features/profile/profile_share.dart';
import 'package:bu_kampus/features/share/share_card.dart';
import 'package:bu_kampus/features/share/share_models.dart';
import 'package:bu_kampus/features/share/share_sheet.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import 'support/fake_app.dart';

/// Profil paylaşma + QR: bağlantı biçimi, tarama sonucu çözümleme (kendi/başkası/yanlış/yabancı alan adı), QR ekranı,
/// paylaşım sayfası, sohbet kartı ve tarama ekranı (kamera tarafı sahte).
void main() {
  setUpAll(loadTestFonts);

  group('bağlantı ve tarama çözümleme', () {
    test('profil bağlantısı /s/u/{kimlik} ve parseShareLink gidiş-dönüş', () {
      expect(profileLinkFor(42), 'https://bukampus.com.tr/s/u/42');
      expect(parseShareLink(profileLinkFor(42)), const ShareTarget(ShareType.user, 42));
      expect(parseShareLink('bukampus://s/u/42'), const ShareTarget(ShareType.user, 42));
      expect(ShareType.fromApi('USER'), ShareType.user);
    });

    test('başkasının kodu: other + kimlik', () {
      final r = resolveProfileQr('https://bukampus.com.tr/s/u/7', selfId: 1);
      expect(r.kind, ProfileQrKind.other);
      expect(r.userId, 7);
      expect(resolveProfileQr('  https://www.bukampus.com.tr/s/u/7?x=1 ', selfId: 1).userId, 7);
      expect(resolveProfileQr('bukampus://s/u/7', selfId: 1).kind, ProfileQrKind.other);
    });

    test('kendi kodu: own', () {
      final r = resolveProfileQr(profileLinkFor(1), selfId: 1);
      expect(r.kind, ProfileQrKind.own);
      expect(r.userId, 1);
      expect(resolveProfileQr(profileLinkFor(1)).kind, ProfileQrKind.other, reason: 'oturum kimliği yoksa başkası');
    });

    test('yanlış / yabancı değerler reddedilir (açık yönlendirme, phishing yok)', () {
      const bad = <String?>[
        null,
        '',
        '   ',
        'merhaba',
        '12345',
        'https://evil.com/s/u/7',
        'https://bukampus.com.tr.evil.com/s/u/7',
        'https://evilbukampus.com.tr/s/u/7',
        'https://bukampus.com.tr@evil.com/s/u/7',
        'https://user:pw@bukampus.com.tr/s/u/7',
        'javascript:alert(1)',
        'intent://s/u/7#Intent;scheme=bukampus;end',
        'file:///etc/passwd',
        'tel:+905551112233',
        'https://bukampus.com.tr/s/p/7', // başka içerik türü: profil kodu değil
        'https://bukampus.com.tr/s/f/7',
        'https://bukampus.com.tr/s/u/abc',
        'https://bukampus.com.tr/s/u/0',
        'https://bukampus.com.tr/s/u/-5',
        'https://bukampus.com.tr/s/u/99999999999999999999',
        'https://bukampus.com.tr/s/u/7/extra',
        'https://bukampus.com.tr/admin',
        'bukampus://menu',
        'WIFI:T:WPA;S:ag;P:sifre;;',
      ];
      for (final v in bad) {
        final r = resolveProfileQr(v, selfId: 1);
        expect(r.valid, isFalse, reason: '$v');
        expect(r.userId, isNull, reason: '$v');
      }
      expect(resolveProfileQr('https://bukampus.com.tr/s/u/7${'a' * 400}', selfId: 1).valid, isFalse, reason: 'çok uzun');
    });
  });

  group('QR üretimi', () {
    test('profil bağlantısı QR olarak kodlanır (en büyük kimlik dahil) ve yeniden üretimde aynıdır', () {
      for (final id in [1, 123456, 9007199254740991]) {
        final a = buildProfileQr(profileLinkFor(id));
        final b = buildProfileQr(profileLinkFor(id));
        expect(a, isNotNull);
        expect(a!.size, lessThanOrEqualTo(41), reason: 'sürüm <= 6: telefon kamerası rahat okur');
        for (var y = 0; y < a.size; y++) {
          for (var x = 0; x < a.size; x++) {
            expect(a.isDark(x, y), b!.isDark(x, y));
          }
        }
      }
      expect(QrCode.tryEncode(profileLinkFor(5)), isNotNull);
    });

    test('QR siyah-beyazdır: her iki temada aynı mürekkep/zemin', () {
      expect(kQrInk, const Color(0xFF000000));
      expect(kQrPaper, const Color(0xFFFFFFFF));
    });

    testWidgets('PNG hazırlanır (imza + boyut)', (tester) async {
      final png = await tester.runAsync(() => renderQrPng(profileLinkFor(9), px: 256));
      expect(png, isNotNull);
      expect(png!.take(8).toList(), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      expect(png.length, greaterThan(200));
    });
  });

  group('QR kodum ekranı', () {
    FakeBackend backend() {
      final b = FakeBackend();
      b.on('/users/me', {'id': 1, 'displayName': 'Ayşe Yılmaz', 'username': 'ayse', 'avatarUrl': null});
      return b;
    }

    Future<void> open(WidgetTester tester, FakeBackend b, {Brightness br = Brightness.light, Size size = kPhoneMedium}) async {
      useScreen(tester, size);
      await tester.pumpWidget(buildApp(ProfileQrPage(session: makeSession(b)), brightness: br, size: size));
      await settle(tester, const Duration(milliseconds: 500));
    }

    testWidgets('ad, @kullanıcı adı, QR ve eylemler görünür; QR beyaz zeminlidir', (tester) async {
      await open(tester, backend());
      expect(find.byKey(const ValueKey('qr-name')), findsOneWidget);
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('@ayse'), findsOneWidget);
      expect(find.byType(ProfileQrView), findsOneWidget);
      expect(find.byKey(const ValueKey('qr-share')), findsOneWidget);
      expect(find.byKey(const ValueKey('qr-copy')), findsOneWidget);
      expect(find.byKey(const ValueKey('qr-image')), findsOneWidget);
      expect(find.byKey(const ValueKey('qr-scan')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('koyu tema + büyük yazı + dar ekran: taşma yok', (tester) async {
      await open(tester, backend(), br: Brightness.dark, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      final painter = tester.widget<CustomPaint>(find.descendant(of: find.byType(ProfileQrView), matching: find.byType(CustomPaint)).first);
      expect(painter.painter, isNotNull);
    });

    testWidgets('bağlantıyı kopyala panoya profil bağlantısını yazar', (tester) async {
      String? clip;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clip = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await open(tester, backend());
      await tester.tap(find.byKey(const ValueKey('qr-copy')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(clip, 'https://bukampus.com.tr/s/u/1');
      expect(find.text('Bağlantı kopyalandı'), findsOneWidget);
    });

    testWidgets('Profili paylaş: paylaşım sayfası açılır (profil önizleme kartı)', (tester) async {
      final b = backend();
      b.on('/conversations?size=50', {'items': <dynamic>[], 'nextCursor': null});
      await open(tester, b);
      await tester.tap(find.byKey(const ValueKey('qr-share')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byType(ShareSheet), findsOneWidget);
    });
  });

  group('paylaşım sayfası (profil)', () {
    test('içerik: ad, @kullanıcı adı, bağlantı /s/u/', () {
      final c = shareContentForUser(id: 5, displayName: ' Ali Veli ', username: 'ali', avatarUrl: '/files/a.jpg');
      expect(c.type, ShareType.user);
      expect(c.title, 'Ali Veli');
      expect(c.source, '@ali');
      expect(c.url, 'https://bukampus.com.tr/s/u/5');
      expect(c.restricted, isFalse);
      expect(c.externalText(), 'Ali Veli\nhttps://bukampus.com.tr/s/u/5');
      expect(shareContentForUser(id: 5).source, isNull);
      expect(shareContentForUser(id: 5, username: '@x').source, '@x');
    });

    testWidgets('harici paylaşım: sistem sayfası ad + bağlantıyla çağrılır', (tester) async {
      ShareParams? got;
      debugExternalShare = (p) async => got = p;
      addTearDown(() => debugExternalShare = null);
      final b = FakeBackend();
      b.on('/conversations?size=50', {'items': <dynamic>[], 'nextCursor': null});
      useScreen(tester, kPhoneMedium);
      final s = makeSession(b);
      await tester.pumpWidget(buildApp(
        Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              key: const ValueKey('open'),
              onPressed: () => shareUserProfile(ctx, s, id: 5, displayName: 'Ali Veli', username: 'ali'),
              child: const Text('aç'),
            ),
          ),
        ),
        size: kPhoneMedium,
      ));
      await tester.tap(find.byKey(const ValueKey('open')));
      await settle(tester, const Duration(milliseconds: 700));
      await tester.tap(find.byKey(const ValueKey('share-external')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(got?.text, 'Ali Veli\nhttps://bukampus.com.tr/s/u/5');
    });
  });

  group('sohbet kartı (profil)', () {
    Future<void> pump(WidgetTester tester, ShareInfo info, {bool mine = false, Brightness br = Brightness.light, VoidCallback? onTap}) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
        Scaffold(body: Center(child: ShareCard(info: info, mine: mine, width: 240, onTap: onTap))),
        brightness: br,
        size: kPhoneMedium,
      ));
      await settle(tester, const Duration(milliseconds: 300));
    }

    ShareInfo info(Map<String, dynamic> share) => ShareInfo.fromMessage({'share': share})!;

    testWidgets('kullanılabilir profil: ad + @kullanıcı adı; dokununca onTap', (tester) async {
      var tapped = 0;
      await pump(tester, info({'type': 'USER', 'id': 5, 'title': 'Ali Veli', 'subtitle': '@ali', 'available': true}), onTap: () => tapped++);
      expect(find.text('Ali Veli'), findsOneWidget);
      expect(find.text('@ali'), findsOneWidget);
      expect(find.text('PROFİL'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('share-card-title')));
      await settle(tester, const Duration(milliseconds: 200));
      expect(tapped, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('erişilemeyen profil (engel/gizli/askı/yok): içerik sızmaz', (tester) async {
      await pump(tester, info({'type': 'USER', 'id': 5, 'available': false}));
      expect(find.byKey(const ValueKey('share-card-unavailable')), findsOneWidget);
      expect(find.byKey(const ValueKey('share-card-title')), findsNothing);
      expect(find.byKey(const ValueKey('share-card-source')), findsNothing);
    });

    testWidgets('giden + koyu tema + uzun ad: taşma yok', (tester) async {
      await pump(tester, info({'type': 'USER', 'id': 5, 'title': 'Çok Uzun Bir Görünen Ad ' * 5, 'subtitle': '@${'u' * 30}', 'available': true}),
          mine: true, br: Brightness.dark);
      expect(tester.takeException(), isNull);
    });
  });

  group('QR tasarımı (profil stili)', () {
    testWidgets('stilli PNG: her modülün merkezi matrisle birebir (koyu/açık), sessiz bölge açık', (tester) async {
      for (final id in [1, 424242, 9007199254740991]) {
        final link = profileLinkFor(id);
        final qr = buildProfileQr(link)!;
        const px = 900;
        final png = await tester.runAsync(() => renderStyledQrPng(link, px: px));
        final codec = await tester.runAsync(() => ui.instantiateImageCodec(png!));
        final frame = await tester.runAsync(() => codec!.getNextFrame());
        final bd = await tester.runAsync(() => frame!.image.toByteData(format: ui.ImageByteFormat.rawRgba));
        int lum(double x, double y) {
          final i = ((y.floor() * px) + x.floor()) * 4;
          return (bd!.getUint8(i) + bd.getUint8(i + 1) + bd.getUint8(i + 2)) ~/ 3;
        }

        final cell = px / (qr.size + 8);
        var bad = 0;
        for (var y = 0; y < qr.size; y++) {
          for (var x = 0; x < qr.size; x++) {
            final l = lum((x + 4 + .5) * cell, (y + 4 + .5) * cell);
            if (qr.isDark(x, y) ? l > 60 : l < 200) bad++;
          }
        }
        expect(bad, 0, reason: 'id $id');
        // 4 modüllük sessiz bölge tamamen açık.
        for (final q in [(.5, .5), (3.5, 3.5), (qr.size + 4.5, 3.5), (3.5, qr.size + 4.5), (qr.size + 7.5, qr.size + 7.5)]) {
          expect(lum(q.$1 * cell, q.$2 * cell), greaterThan(240), reason: 'sessiz bölge $q');
        }
      }
    });

    testWidgets('paylaşım kartı PNG 4:5 üretilir (tr/ar)', (tester) async {
      for (final rtl in [false, true]) {
        final png = await tester.runAsync(() => renderProfileCardPng(
            profileLinkFor(12),
            ProfileCardTexts(
                brand: 'BÜ Kampüs', name: 'Ayşe Yılmaz ' * 6, username: '@ayse', findMe: 'Beni BÜ Kampüs’te bul', link: profileLinkFor(12), rtl: rtl)));
        expect(png, isNotNull);
        final codec = await tester.runAsync(() => ui.instantiateImageCodec(png!));
        final f = await tester.runAsync(() => codec!.getNextFrame());
        expect(f!.image.width * 5, f.image.height * 4);
      }
    });

    for (final c in [(const Size(320, 640), 1.3, Brightness.dark, false), (const Size(390, 844), 1.0, Brightness.light, true)]) {
      testWidgets('QR kodum taşma yok: ${c.$1.width.toInt()} dp x${c.$2} ${c.$3.name} rtl=${c.$4}', (tester) async {
        final b = FakeBackend();
        b.on('/users/me', {'id': 1, 'displayName': 'Çok Uzun Bir Görünen Ad Soyad ' * 3, 'username': 'kullanici_adi_uzun', 'avatarUrl': null});
        useScreen(tester, c.$1);
        await tester.pumpWidget(buildApp(
          Directionality(
            textDirection: c.$4 ? TextDirection.rtl : TextDirection.ltr,
            child: MediaQuery(
              data: MediaQueryData(size: c.$1, textScaler: TextScaler.linear(c.$2)),
              child: ProfileQrPage(session: makeSession(b)),
            ),
          ),
          brightness: c.$3,
          size: c.$1,
        ));
        await settle(tester, const Duration(milliseconds: 700));
        expect(tester.takeException(), isNull);
        expect(find.byType(ProfileQrPlate), findsOneWidget);
      });

      testWidgets('QR tara taşma yok: ${c.$1.width.toInt()} dp x${c.$2} ${c.$3.name}', (tester) async {
        useScreen(tester, c.$1);
        final perms = FakePermissionService(initial: {AppPermission.camera: PermState.granted});
        await tester.pumpWidget(buildApp(
          MediaQuery(
            data: MediaQueryData(size: c.$1, textScaler: TextScaler.linear(c.$2)),
            child: QrScanHubPage(
                session: makeSession(FakeBackend()), permissionService: perms, scannerBuilder: (ctx, _) => const ColoredBox(color: Color(0xFF222222))),
          ),
          brightness: c.$3,
          size: c.$1,
        ));
        await settle(tester, const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('pqr-torch')), findsOneWidget);
        expect(find.byKey(const ValueKey('pqr-gallery')), findsOneWidget);
      });
    }
  });

  group('QR tara ekranı', () {
    late FakePermissionService perms;
    final opened = <int>[];

    Future<void> open(WidgetTester tester, {PermState cam = PermState.granted}) async {
      opened.clear();
      perms = FakePermissionService(initial: {AppPermission.camera: cam}, onRequest: {AppPermission.camera: cam});
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
        QrScanHubPage(
          session: makeSession(FakeBackend()),
          permissionService: perms,
          openProfile: (_, id) => opened.add(id),
          scannerBuilder: (ctx, onValue) => Column(children: [
            TextButton(key: const ValueKey('scan-other'), onPressed: () => onValue('https://bukampus.com.tr/s/u/7'), child: const Text('a')),
            TextButton(key: const ValueKey('scan-own'), onPressed: () => onValue('https://bukampus.com.tr/s/u/1'), child: const Text('b')),
            TextButton(key: const ValueKey('scan-bad'), onPressed: () => onValue('https://evil.com/s/u/7'), child: const Text('c')),
          ]),
        ),
        size: kPhoneMedium,
      ));
      await settle(tester, const Duration(milliseconds: 500));
    }

    testWidgets('geçerli başkasının kodu profili açar', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('pqr-hint')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('scan-other')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(opened, [7]);
    });

    testWidgets('kendi kodu kendi profilini açar', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('scan-own')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(opened, [1]);
    });

    testWidgets('yabancı alan adı: anlaşılır hata, profil açılmaz', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('scan-bad')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(opened, isEmpty);
      expect(find.text('Bu bir BÜ Kampüs kodu değil.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4)); // ileti kendiliğinden temizlenir
      expect(find.text('Bu bir BÜ Kampüs kodu değil.'), findsNothing);
    });

    testWidgets('kamera izni reddedilince açıklayıcı durum + ayarlara git', (tester) async {
      await open(tester, cam: PermState.permanentlyDenied);
      // Ayarlar alt sayfası (ensurePermission) kapatılır; ardından sayfanın kendi reddedilmiş durumu görünür.
      await tester.tapAt(const Offset(10, 10));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('pqr-open-settings')), findsOneWidget);
      expect(find.byKey(const ValueKey('pqr-torch')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('pqr-open-settings')));
      await settle(tester, const Duration(milliseconds: 200));
      expect(perms.settingsOpened, 1);
    });
  });
}
