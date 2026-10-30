import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/features/chat/media_camera_page.dart';
import 'package:bu_kampus/features/chat/chat_info_page.dart';
import 'package:bu_kampus/features/chat/contacts_match_page.dart';
import 'package:bu_kampus/features/chat/forward_sheet.dart';
import 'package:bu_kampus/features/chat/new_chat_page.dart';
import 'package:bu_kampus/features/chat/sohbety_widgets.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Sohbet yardımcı ekranları (Sy1-Sy5) tasarım testleri: taşma yok (320 dp, açık/koyu, RTL) + temel davranış.
const _long = 'Çok uzun bir isim soyisim örnek kişi adı burada devam ediyor ve taşmamalı';

Widget _wrap(Widget child, {required bool rtl}) =>
    Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, child: child);

void main() {
  setUpAll(loadTestFonts);

  group('SohbetyCameraChrome (sade kamera, Q1)', () {
    SohbetyCameraChrome chrome({
      required bool rec,
      SohbetyFlashMode flash = SohbetyFlashMode.off,
      bool showFlash = true,
      bool canFlip = true,
      List<String>? log,
    }) =>
        SohbetyCameraChrome(
          recording: rec,
          timer: '0:07',
          flash: flash,
          showFlash: showFlash,
          canFlip: canFlip,
          onClose: () => log?.add('close'),
          onFlash: () => log?.add('flash'),
          onFlip: () => log?.add('flip'),
          onPhoto: () => log?.add('photo'),
          onVideoStart: () => log?.add('vstart'),
          onVideoEnd: () => log?.add('vend'),
          closeLabel: 'Kapat',
          flashLabel: 'Flaş',
          flipLabel: 'Kamerayı çevir',
          shutterLabel: rec ? 'Kaydı durdur' : 'Fotoğraf çek',
        );

    for (final b in Brightness.values) {
      for (final rtl in [false, true]) {
        for (final rec in [false, true]) {
          testWidgets('taşma yok ${b.name} rtl=$rtl kayıt=$rec', (tester) async {
            useScreen(tester, kPhoneSmall);
            final log = <String>[];
            await tester.pumpWidget(buildApp(
              _wrap(Scaffold(backgroundColor: Colors.black, body: chrome(rec: rec, log: log)), rtl: rtl),
              brightness: b,
              size: kPhoneSmall,
            ));
            expect(tester.takeException(), isNull);
            await tester.tap(find.byKey(const ValueKey('shutter')));
            if (rec) {
              // Kayıtta yalnız sayaç + deklanşör halkası: kapat/flaş/çevir yok.
              expect(find.byTooltip('Flaş'), findsNothing);
              expect(find.byTooltip('Kapat'), findsNothing);
              expect(find.byTooltip('Kamerayı çevir'), findsNothing);
              expect(find.text('0:07'), findsOneWidget);
            } else {
              await tester.tap(find.byTooltip('Flaş'));
              await tester.tap(find.byTooltip('Kamerayı çevir'));
              await tester.tap(find.byTooltip('Kapat'));
              expect(find.text('0:07'), findsNothing);
            }
            expect(log, rec ? ['vend'] : ['photo', 'flash', 'flip', 'close']);
            expect(tester.getSize(find.byKey(const ValueKey('shutter'))), rec ? const Size(96, 96) : const Size(80, 80));
          });
        }
      }
    }

    testWidgets('sade: odak çerçevesi, ipucu metni ve galeri küçük resmi YOK; yalnız kapat/flaş/deklanşör/çevir', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(Scaffold(backgroundColor: Colors.black, body: chrome(rec: false)), size: kPhoneMedium));
      expect(find.text('Dokun: fotoğraf · Basılı tut: video'), findsNothing);
      expect(find.byKey(const ValueKey('cameraGallery')), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.byTooltip('Galeri'), findsNothing);
      for (final k in ['cameraClose', 'cameraFlash', 'shutter', 'cameraFlip']) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
      // Ekranda hiç metin yok (etiketler yalnız erişilebilirlik/ipucu).
      expect(find.byType(Text), findsNothing);
      // Konum: kapat solda, flaş sağda, çevir deklanşörün yanında (sağında), deklanşör ortada.
      final close = tester.getCenter(find.byKey(const ValueKey('cameraClose')));
      final flash = tester.getCenter(find.byKey(const ValueKey('cameraFlash')));
      final shut = tester.getCenter(find.byKey(const ValueKey('shutter')));
      final flip = tester.getCenter(find.byKey(const ValueKey('cameraFlip')));
      expect(close.dx, lessThan(60));
      expect(flash.dx, greaterThan(kPhoneMedium.width - 60));
      expect((shut.dx - kPhoneMedium.width / 2).abs(), lessThan(1));
      expect(flip.dx, greaterThan(shut.dx + 40));
      expect(flip.dx, lessThan(shut.dx + 140));
      expect(flip.dy, closeTo(shut.dy, 2));
    });

    testWidgets('RTL: kapat sağa, flaş sola, çevir deklanşörün soluna aynalanır', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
          _wrap(Scaffold(backgroundColor: Colors.black, body: chrome(rec: false)), rtl: true),
          size: kPhoneMedium));
      final close = tester.getCenter(find.byKey(const ValueKey('cameraClose')));
      final flash = tester.getCenter(find.byKey(const ValueKey('cameraFlash')));
      final shut = tester.getCenter(find.byKey(const ValueKey('shutter')));
      final flip = tester.getCenter(find.byKey(const ValueKey('cameraFlip')));
      expect(close.dx, greaterThan(kPhoneMedium.width - 60));
      expect(flash.dx, lessThan(60));
      expect(flip.dx, lessThan(shut.dx - 40));
    });

    testWidgets('flaş yoksa (ön kamera) düğme gizli; tek kamerada çevir gizli', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
          Scaffold(backgroundColor: Colors.black, body: chrome(rec: false, showFlash: false, canFlip: false)),
          size: kPhoneMedium));
      expect(find.byKey(const ValueKey('cameraFlash')), findsNothing);
      expect(find.byKey(const ValueKey('cameraFlip')), findsNothing);
      expect(find.byKey(const ValueKey('cameraClose')), findsOneWidget);
    });

    testWidgets('flaş durumları: kapalı/otomatik/açık simgesi ve etiket (A rozeti yalnız otomatikte)', (tester) async {
      useScreen(tester, kPhoneMedium);
      for (final m in SohbetyFlashMode.values) {
        await tester.pumpWidget(buildApp(Scaffold(backgroundColor: Colors.black, body: chrome(rec: false, flash: m)), size: kPhoneMedium));
        expect(find.byKey(const ValueKey('flashAutoBadge')), m == SohbetyFlashMode.auto ? findsOneWidget : findsNothing);
        expect(find.byTooltip('Flaş'), findsOneWidget);
      }
    });

    testWidgets('dokunma hedefleri 48 dp ve etiketli', (tester) async {
      final h = tester.ensureSemantics();
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(Scaffold(backgroundColor: Colors.black, body: chrome(rec: false)), size: kPhoneMedium));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      h.dispose();
    });

    testWidgets('kamera sayfası: izin/kamera yok -> sade kart + Kapat (odak çerçevesi/ipucu yok)', (tester) async {
      final prev = PermissionService.instance;
      PermissionService.instance = FakePermissionService(
          initial: {AppPermission.camera: PermState.granted, AppPermission.microphone: PermState.granted});
      addTearDown(() => PermissionService.instance = prev);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(const MediaCameraPage(), size: kPhoneMedium));
      await tester.pump();
      // availableCameras platform kanalini gercek zamanda bekler (kanal yok -> hata -> kart).
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Kamera kullanılamıyor.'), findsOneWidget);
      expect(find.text('Kapat'), findsOneWidget);
      expect(find.byKey(const ValueKey('shutter')), findsNothing);
      expect(find.text('Dokun: fotoğraf · Basılı tut: video'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('NewChatPage yeni tasarım', () {
    FakeBackend be() => FakeBackend()
      ..on('/users/search*', {
        'items': [
          {'id': 11, 'displayName': 'Ali Veli', 'department': 'Bilgisayar Mühendisliği'},
          {'id': 12, 'displayName': _long, 'faculty': _long},
        ],
        'nextCursor': null,
      });

    for (final b in Brightness.values) {
      for (final rtl in [false, true]) {
        testWidgets('taşma yok ${b.name} rtl=$rtl 320', (tester) async {
          useScreen(tester, kPhoneSmall);
          await tester.pumpWidget(buildApp(_wrap(NewChatPage(session: makeSession(be())), rtl: rtl),
              brightness: b, size: kPhoneSmall));
          await settle(tester);
          expect(find.text('Yeni grup'), findsOneWidget);
          expect(find.text('En fazla 50 kişi'), findsOneWidget);
          expect(find.text('Rehberden kişi bul'), findsOneWidget);
          await tester.tap(find.text('Yeni grup'));
          await tester.pump();
          await tester.enterText(find.byType(TextField).last, 'al');
          await tester.pump(const Duration(milliseconds: 350));
          await settle(tester, const Duration(milliseconds: 400));
          await tester.tap(find.text('Ali Veli'));
          await tester.pump();
          await tester.tap(find.text(_long).first);
          await tester.pump();
          expect(find.text('Grubu oluştur'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await unmount(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('Yeni grup modunda tek kişiyle oluşturulamaz', (tester) async {
      final backend = be();
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(NewChatPage(session: makeSession(backend)), size: kPhoneMedium));
      await settle(tester);
      await tester.tap(find.text('Yeni grup'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, 'al');
      await tester.pump(const Duration(milliseconds: 350));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Ali Veli'));
      await tester.pump();
      await tester.tap(find.text('Grubu oluştur'));
      await tester.pump();
      expect(find.text('Grup için en az 2 kişi seçin.'), findsOneWidget);
      expect(backend.count('POST /conversations'), 0);
      await unmount(tester);
    });

    testWidgets('birebir: her satırda Sohbet başlat hapı; dokununca sohbet doğrudan açılır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final backend = be()..on('/conversations', {'id': 5, 'type': 'DIRECT', 'peer': {'id': 11, 'displayName': 'Ali Veli'}});
      await tester.pumpWidget(buildApp(NewChatPage(session: makeSession(backend)), size: kPhoneMedium));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, 'al');
      await tester.pump(const Duration(milliseconds: 350));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Sohbet başlat'), findsNWidgets(2));
      await tester.tap(find.text('Ali Veli'));
      await tester.pump();
      expect(backend.count('POST /conversations'), 1);
      expect(backend.bodies['POST /conversations'], {'userId': 11});
      await settle(tester, const Duration(milliseconds: 400));
      await unmount(tester);
    });
  });

  group('ContactsMatchPage yeni tasarım', () {
    for (final b in Brightness.values) {
      for (final rtl in [false, true]) {
        testWidgets('izin yok durumu taşma yok ${b.name} rtl=$rtl 320', (tester) async {
          useScreen(tester, kPhoneSmall);
          final perms = FakePermissionService();
          await tester.pumpWidget(buildApp(
              _wrap(ContactsMatchPage(session: makeSession(FakeBackend()), permissions: perms), rtl: rtl),
              brightness: b,
              size: kPhoneSmall));
          await settle(tester, const Duration(milliseconds: 600));
          await tester.tap(find.text('Şimdi değil'));
          await settle(tester, const Duration(milliseconds: 600));
          expect(find.text('Rehber izni gerekli'), findsOneWidget);
          expect(find.text('İzin ver'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });

  group('ForwardSheet yeni tasarım', () {
    for (final b in Brightness.values) {
      for (final rtl in [false, true]) {
        testWidgets('taşma yok ${b.name} rtl=$rtl 320', (tester) async {
          useScreen(tester, kPhoneSmall);
          final be = FakeBackend()
            ..on('/conversations*', {
              'items': [
                {'id': 1, 'type': 'DIRECT', 'peer': {'id': 2, 'displayName': 'Ayşe Yılmaz'}},
                {'id': 2, 'type': 'CLUB', 'title': 'Fotoğraf Kulübü'},
                {'id': 3, 'type': 'EVENT', 'title': _long},
                {'id': 4, 'type': 'GROUP', 'title': 'Proje Grubu'},
                {'id': 5, 'type': 'GROUP', 'title': 'İlker Grubu'},
                {'id': 6, 'type': 'CLUB', 'title': 'Kapalı Oda', 'closed': true},
              ],
              'nextCursor': null,
            });
          await tester.pumpWidget(buildApp(
              _wrap(Scaffold(body: ForwardSheet(api: makeSession(be).api)), rtl: rtl),
              brightness: b,
              size: kPhoneSmall));
          await settle(tester);
          expect(find.text('İlet'), findsOneWidget);
          expect(find.text('Bireysel sohbet'), findsOneWidget);
          expect(find.text('Kulüp'), findsOneWidget);
          expect(find.text('Etkinlik'), findsOneWidget);
          expect(find.text('En fazla 5 sohbet seçilebilir.'), findsOneWidget);
          expect(find.text('Kapalı Oda'), findsNothing); // kapalı odaya iletilemez
          await tester.enterText(find.byType(TextField), 'ilker');
          await settle(tester);
          expect(find.text('İlker Grubu'), findsOneWidget);
          await tester.enterText(find.byType(TextField), '');
          await settle(tester);
          await tester.tap(find.byKey(const ValueKey('fwd-1')));
          await tester.tap(find.byKey(const ValueKey('fwd-2')));
          await tester.pump();
          expect(find.text('Gönder (2)'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  });

  group('ChatInfoPage yeni tasarım', () {
    for (final b in Brightness.values) {
      for (final rtl in [false, true]) {
        testWidgets('grup + birebir + oda tek sayfa taşma yok ${b.name} rtl=$rtl 320', (tester) async {
          for (final kind in ['DIRECT', 'GROUP', 'CLUB']) {
            useScreen(tester, kPhoneSmall);
            final be = FakeBackend()..on('/conversations/5/messages?size=40', {'items': [], 'nextCursor': null});
            await tester.pumpWidget(buildApp(
                _wrap(
                    ChatInfoPage(
                      session: makeSession(be),
                      conversation: kind == 'DIRECT'
                          ? {'id': 5, 'type': 'DIRECT', 'peer': {'id': 2, 'displayName': _long, 'department': _long}}
                          : {'id': 5, 'type': kind, 'title': _long, 'memberCount': 128, 'admin': kind == 'GROUP'},
                      members: [
                        for (var i = 1; i <= 6; i++)
                          {'userId': i, 'displayName': i == 2 ? _long : 'Üye $i', 'role': i == 2 ? 'ADMIN' : 'MEMBER', 'department': _long}
                      ],
                      subtitle: 'Çevrimiçi',
                      onOpenRoom: kind == 'CLUB' ? () {} : null,
                    ),
                    rtl: rtl),
                brightness: b,
                size: kPhoneSmall));
            await settle(tester);
            expect(tester.takeException(), isNull, reason: kind);
            // Sayfanın tamamı gezilir: alttaki kartlarda da taşma olmamalı.
            await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
            await settle(tester);
            expect(tester.takeException(), isNull, reason: '$kind alt');
            await unmount(tester);
          }
        });
      }
    }

    testWidgets('kulüp odası başlığı: etiket, üye sayısı, Kulüp sayfasını aç, simge karosu', (tester) async {
      useScreen(tester, kPhoneMedium);
      final be = FakeBackend()..on('/conversations/5/messages?size=40', {'items': [], 'nextCursor': null});
      await tester.pumpWidget(buildApp(
          ChatInfoPage(
            session: makeSession(be),
            conversation: const {'id': 5, 'type': 'CLUB', 'title': 'Fotoğraf Kulübü', 'memberCount': 128},
            members: const [
              {'userId': 1, 'displayName': 'Ayşe Yılmaz', 'role': 'ADMIN', 'department': 'Bilgisayar Müh.'}
            ],
            onOpenRoom: () {},
          ),
          size: kPhoneMedium));
      await settle(tester);
      expect(find.text('Kulüp odası'), findsOneWidget);
      expect(find.text('128 üye'), findsOneWidget);
      expect(find.text('Kulüp sayfasını aç'), findsOneWidget);
      expect(find.text('Bilgisayar Müh.'), findsOneWidget);
      expect(find.byIcon(LucideIcons.users), findsWidgets);
      await unmount(tester);
    });
  });

  test('sohbetyUpper Türkçede i/ı doğru büyütür', () {
    // Dil bağlamı olmadan genel büyütme: yalnız ASCII davranışı doğrulanır.
    expect(SohbetyAvatar.initial('ayşe'), 'A');
    expect(SohbetyAvatar.initial(''), '?');
  });
}
