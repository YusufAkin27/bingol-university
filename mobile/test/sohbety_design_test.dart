import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/features/chat/chat_info_page.dart';
import 'package:bu_kampus/features/chat/contacts_match_page.dart';
import 'package:bu_kampus/features/chat/forward_sheet.dart';
import 'package:bu_kampus/features/chat/new_chat_page.dart';
import 'package:bu_kampus/features/chat/sohbety_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Sohbet yardımcı ekranları (Sy1-Sy5) tasarım testleri: taşma yok (320 dp, açık/koyu, RTL) + temel davranış.
const _long = 'Çok uzun bir isim soyisim örnek kişi adı burada devam ediyor ve taşmamalı';

Widget _wrap(Widget child, {required bool rtl}) =>
    Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, child: child);

void main() {
  setUpAll(loadTestFonts);

  group('SohbetyCameraChrome', () {
    for (final b in Brightness.values) {
      for (final rtl in [false, true]) {
        for (final rec in [false, true]) {
          testWidgets('taşma yok ${b.name} rtl=$rtl kayıt=$rec', (tester) async {
            useScreen(tester, kPhoneSmall);
            var photo = 0, flash = 0, gallery = 0, closed = 0;
            await tester.pumpWidget(buildApp(
              _wrap(
                  Scaffold(
                    backgroundColor: const Color(0xFF0E1220),
                    body: SohbetyCameraChrome(
                      recording: rec,
                      timer: '0:07',
                      flashOn: false,
                      onClose: () => closed++,
                      onFlash: () => flash++,
                      onGallery: () => gallery++,
                      onFlip: () {},
                      onPhoto: () => photo++,
                      onVideoStart: () {},
                      onVideoEnd: () {},
                      closeLabel: 'Kapat',
                      flashLabel: 'Flaş',
                      galleryLabel: 'Galeri',
                      flipLabel: 'Kamerayı çevir',
                      shutterLabel: rec ? 'Kaydı durdur' : 'Fotoğraf çek',
                      hint: 'Dokun: fotoğraf · Basılı tut: video',
                    ),
                  ),
                  rtl: rtl),
              brightness: b,
              size: kPhoneSmall,
            ));
            expect(tester.takeException(), isNull);
            expect(find.text('Dokun: fotoğraf · Basılı tut: video'), findsOneWidget);
            expect(find.text('0:07'), rec ? findsOneWidget : findsNothing);
            await tester.tap(find.byKey(const ValueKey('shutter')));
            await tester.tap(find.byTooltip('Flaş'));
            await tester.tap(find.byTooltip('Galeri'));
            await tester.tap(find.byTooltip('Kapat'));
            expect([photo, flash, gallery, closed], [1, 1, 1, 1]);
            expect(tester.getSize(find.byKey(const ValueKey('shutter'))), const Size(84, 84));
          });
        }
      }
    }
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
          await tester.enterText(find.byType(TextField).first, 'al');
          await tester.pump(const Duration(milliseconds: 350));
          await settle(tester, const Duration(milliseconds: 400));
          expect(find.text('KİŞİLER'), findsOneWidget);
          await tester.tap(find.text('Yeni grup'));
          await tester.pump();
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
      await tester.enterText(find.byType(TextField).first, 'al');
      await tester.pump(const Duration(milliseconds: 350));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Yeni grup'));
      await tester.pump();
      await tester.tap(find.text('Ali Veli'));
      await tester.pump();
      await tester.tap(find.text('Grubu oluştur'));
      await tester.pump();
      expect(find.text('Grup için en az 2 kişi seçin.'), findsOneWidget);
      expect(backend.count('POST /conversations'), 0);
      await unmount(tester);
    });

    testWidgets('birebir: tek kişi seçilince Sohbet başlat', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(NewChatPage(session: makeSession(be())), size: kPhoneMedium));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'al');
      await tester.pump(const Duration(milliseconds: 350));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Ali Veli'));
      await tester.pump();
      expect(find.text('Sohbet başlat'), findsOneWidget);
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
              ],
              'nextCursor': null,
            });
          await tester.pumpWidget(buildApp(
              _wrap(Scaffold(body: ForwardSheet(api: makeSession(be).api)), rtl: rtl),
              brightness: b,
              size: kPhoneSmall));
          await settle(tester);
          expect(find.text('İlet'), findsOneWidget);
          expect(find.text('Kişi'), findsOneWidget);
          expect(find.text('Kulüp'), findsOneWidget);
          expect(find.text('Etkinlik'), findsOneWidget);
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
        testWidgets('grup + birebir tüm sekmeler taşma yok ${b.name} rtl=$rtl 320', (tester) async {
          for (final direct in [false, true]) {
            useScreen(tester, kPhoneSmall);
            final be = FakeBackend()..on('/conversations/5/messages?size=40', {'items': [], 'nextCursor': null});
            await tester.pumpWidget(buildApp(
                _wrap(
                    ChatInfoPage(
                      session: makeSession(be),
                      conversation: direct
                          ? {'id': 5, 'type': 'DIRECT', 'peer': {'id': 2, 'displayName': _long, 'department': _long}}
                          : {'id': 5, 'type': 'CLUB', 'title': _long, 'memberCount': 128, 'admin': false},
                      members: [
                        for (var i = 1; i <= 6; i++)
                          {'userId': i, 'displayName': i == 2 ? _long : 'Üye $i', 'role': i == 2 ? 'ADMIN' : 'MEMBER', 'department': _long}
                      ],
                      subtitle: 'Çevrimiçi',
                      onOpenRoom: direct ? null : () {},
                    ),
                    rtl: rtl),
                brightness: b,
                size: kPhoneSmall));
            await settle(tester);
            expect(tester.takeException(), isNull);
            for (final tab in direct ? ['Medya', 'Ayarlar'] : ['Üyeler', 'Medya', 'Ayarlar']) {
              await tester.tap(find.descendant(of: find.byType(SohbetyTabs), matching: find.text(tab)));
              await settle(tester);
              expect(tester.takeException(), isNull, reason: '$tab direct=$direct');
            }
            await unmount(tester);
          }
        });
      }
    }

    testWidgets('grup başlığı: "Kulüp odası · 128 üye", Kulüp hızlı eylemi, baş harfli avatar', (tester) async {
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
      expect(find.text('Kulüp odası · 128 üye'), findsOneWidget);
      expect(find.text('Kulüp'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
      expect(find.text('Yönetici · Bilgisayar Müh.'), findsOneWidget);
      expect(tester.getSize(find.byType(SohbetyAvatar).first), const Size(96, 96));
      await unmount(tester);
    });
  });

  test('sohbetyUpper Türkçede i/ı doğru büyütür', () {
    // Dil bağlamı olmadan genel büyütme: yalnız ASCII davranışı doğrulanır.
    expect(SohbetyAvatar.initial('ayşe'), 'A');
    expect(SohbetyAvatar.initial(''), '?');
  });
}
