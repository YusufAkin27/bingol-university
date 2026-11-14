import 'package:bu_kampus/features/chat/chat_attach_sheet.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/media_library.dart';
import 'package:bu_kampus/features/chat/media_picker_page.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_media.dart';
import 'p00_support.dart';

/// P3-CHAT: giriş çubuğu (tek "+", gönder), "+" menüsü, galeri ızgarası.
FakeBackend _be() => FakeBackend()
  ..on('/conversations/1/messages?size=30', {'items': <Object>[], 'nextCursor': null})
  ..on('/conversations/1', {
    'conversation': {'id': 1},
    'members': [
      {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
      {'userId': 11, 'displayName': 'Ali Veli'},
    ],
  })
  ..on('/users/11/presence', {'online': false})
  ..on('/messages/reactions', {'emojis': <String>[]});

ChatDetailPage _page({MediaLibrary? library, bool granted = true}) => ChatDetailPage(
      session: makeSession(_be()),
      connectRealtime: false,
      mediaLibrary: library ?? FakeMediaLibrary.photos(14),
      ensureAccess: (c, p, {rationale}) async => granted,
      conversation: const {
        'id': 1,
        'type': 'DIRECT',
        'title': 'Ali Veli',
        'peer': {'id': 11, 'displayName': 'Ali Veli'},
      },
    );

Future<void> _pump(WidgetTester tester, Widget page, {bool dark = false, bool rtl = false, double scale = 1.0, Size size = kPhoneMedium}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(p00App(
      Directionality(textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, child: page),
      dark: dark,
      scale: scale,
      lang: rtl ? 'ar' : 'tr',
      scaffold: false));
  await settle(tester, const Duration(milliseconds: 700));
}

void main() {
  setUpAll(loadTestFonts);

  group('giriş çubuğu', () {
    testWidgets('tek "+" düğmesi var; kamera düğmesi girişte yok; 48 dp ve etiketli', (tester) async {
      final h = tester.ensureSemantics();
      await _pump(tester, _page());
      expect(find.byKey(const ValueKey('attachButton')), findsOneWidget);
      expect(find.byIcon(BuIcons.camera), findsNothing);
      expect(find.byIcon(LucideIcons.paperclip), findsNothing);
      expect(find.byIcon(BuIcons.plus), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('attachButton'))), const Size(48, 48));
      expect(find.bySemanticsLabel('Ekle'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      h.dispose();
    });

    testWidgets('gönder: boşken görünmez, yazınca kırmızı yukarı ok belirir (ölçek+solma), silinince kaybolur; semantik "Gönder"', (tester) async {
      final h = tester.ensureSemantics();
      await _pump(tester, _page());
      final bu = tester.element(find.byType(ChatDetailPage)).bu;
      expect(find.byKey(const ValueKey('sendButton')), findsNothing);
      expect(find.byIcon(BuIcons.arrowUp), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('composerField')), 'selam');
      await tester.pump();
      // Ara kare: ölçek/solma sürerken düğme vardır ve dokunulabilir (başlangıç ölçeği 0.6).
      expect(find.byKey(const ValueKey('sendButton')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 250));
      final box = tester.widget<Container>(find.descendant(of: find.byKey(const ValueKey('sendButton')), matching: find.byType(Container)).last);
      expect((box.decoration as BoxDecoration).color, bu.pr);
      expect(find.byIcon(BuIcons.arrowUp), findsOneWidget);
      expect(find.byIcon(BuIcons.send), findsNothing);
      expect(find.bySemanticsLabel('Gönder'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('composerField')), '');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('sendButton')), findsNothing);
      h.dispose();
    });

    testWidgets('"+" menü açılınca 45 derece döner, kapanınca geri döner', (tester) async {
      await _pump(tester, _page());
      double turns() => tester.widget<AnimatedRotation>(find.descendant(of: find.byKey(const ValueKey('attachButton')), matching: find.byType(AnimatedRotation))).turns;
      expect(turns(), 0);
      await tester.tap(find.byKey(const ValueKey('attachButton')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ChatAttachCard), findsOneWidget);
      expect(turns(), .125);
      await tester.tapAt(const Offset(200, 300)); // mesaj alanı: kapanır
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ChatAttachCard), findsNothing);
      expect(turns(), 0);
    });
  });

  group('klavye + "+" menüsü', () {
    Future<void> setKeyboard(WidgetTester tester, double logical) async {
      tester.view.viewInsets =
          FakeViewPadding(bottom: logical * tester.view.devicePixelRatio);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('klavye açıkken "+": odak düşer, klavye kapanınca çubuk alta iner, menü düğmenin hemen üstünde kalır', (tester) async {
      addTearDown(tester.view.resetViewInsets);
      await _pump(tester, _page());
      final plus = find.byKey(const ValueKey('attachButton'));
      final restingBottom = tester.getRect(plus).bottom;
      await tester.tap(find.byKey(const ValueKey('composerField')));
      await setKeyboard(tester, 300);
      expect(tester.getRect(plus).bottom, lessThan(restingBottom - 200), reason: 'klavye açıkken çubuk klavyenin üstünde');
      await tester.tap(plus);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>(), isNull, reason: 'odak bırakıldı');
      await setKeyboard(tester, 0); // klavye kapandı
      await settle(tester, const Duration(milliseconds: 400));
      expect(tester.getRect(plus).bottom, restingBottom, reason: 'çubuk havada kalmadı');
      final card = tester.getRect(find.byKey(const ValueKey('attachCamera')));
      expect(card.bottom, lessThanOrEqualTo(tester.getRect(plus).top), reason: 'menü eski klavye koordinatında değil');
      expect(tester.getRect(plus).top - tester.getRect(find.byType(ChatAttachCard)).bottom, closeTo(8, 1.5));
      expect(card.top, greaterThanOrEqualTo(0));
    });

    testWidgets('menü açıkken yazma alanına dokunmak menüyü kapatır; X ve mesaj alanı da kapatır; çubuk yerinde kalır', (tester) async {
      await _pump(tester, _page());
      final plus = find.byKey(const ValueKey('attachButton'));
      final rest = tester.getRect(plus);
      Future<void> open() async {
        await tester.tap(plus);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(ChatAttachCard), findsOneWidget);
      }
      await open();
      await tester.tap(find.byKey(const ValueKey('composerField')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ChatAttachCard), findsNothing);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await open();
        await tester.tap(plus); // X
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(ChatAttachCard), findsNothing);
        expect(tester.getRect(plus), rest, reason: 'tur $i: çubuk kımıldamadı');
      }
      await open();
      await tester.tap(find.byKey(const ValueKey('attachBarrier')), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ChatAttachCard), findsNothing);
      expect(tester.getRect(plus), rest);
      expect(tester.takeException(), isNull);
    });
  });

  group('"+" menüsü', () {
    testWidgets('"+" üstünde küçük yüzen menü: Kamera + Fotoğraflar (tam ekran değil); dışarı dokununca kapanır', (tester) async {
      await _pump(tester, _page());
      await tester.tap(find.byKey(const ValueKey('attachButton')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('attachGallery')), findsOneWidget);
      expect(find.byKey(const ValueKey('attachCamera')), findsOneWidget);
      expect(find.text('Fotoğraflar'), findsOneWidget);
      expect(find.text('Kamera'), findsOneWidget);
      // Ses/dosya backend'de yok: sahte satır yok; eski şerit/izin satırı yok.
      expect(find.text('Dosyalar'), findsNothing);
      expect(find.byKey(const ValueKey('attachStrip')), findsNothing);
      // Küçük panel: genişlik 232, "+" düğmesinin üstünde.
      final panel = tester.getRect(find.byKey(const ValueKey('attachCamera')));
      expect(panel.width, lessThan(260));
      expect(panel.bottom, lessThan(tester.getRect(find.byKey(const ValueKey('attachButton'))).top));
      await tester.tapAt(const Offset(200, 120));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('attachCamera')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Fotoğraflar satırı galeri panelini açar (alttan, tutamaçlı; sohbette kamera karosu yok)', (tester) async {
      await _pump(tester, _page());
      await tester.tap(find.byKey(const ValueKey('attachButton')));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey('attachGallery')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(MediaPickerPage), findsOneWidget);
      expect(find.byKey(const ValueKey('galleryPanel')), findsOneWidget);
      expect(find.byKey(const ValueKey('sheetHandle')), findsOneWidget);
      expect(find.byKey(const ValueKey('cameraTile')), findsNothing);
      expect(find.byKey(const ValueKey('galleryTile_p1')), findsOneWidget);
      // İlk açılış ~%58: panel üstü ekranın ~%42'sinde.
      final top = tester.getTopLeft(find.byKey(const ValueKey('pickerSheet'))).dy;
      expect(top, inInclusiveRange(844 * .38, 844 * .46));
    });

    for (final rtl in [false, true]) {
      for (final dark in [false, true]) {
        testWidgets('320 dp x1.3 taşma yok ${dark ? 'koyu' : 'açık'} ${rtl ? 'RTL' : 'LTR'}', (tester) async {
          await _pump(tester, _page(), dark: dark, rtl: rtl, scale: 1.3, size: kPhoneSmall);
          await tester.tap(find.byKey(const ValueKey('attachButton')));
          await settle(tester, const Duration(milliseconds: 700));
          expect(find.byType(ChatAttachCard), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('galeri ızgarası', () {
    Future<void> openPicker(WidgetTester tester, {int max = 10, Size size = kPhoneMedium, bool dark = false, double scale = 1.0}) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(p00App(
          MediaPickerPage(library: FakeMediaLibrary.photos(20), ensureAccess: (c, p, {rationale}) async => true, maxItems: max, showCameraTile: false),
          dark: dark,
          scale: scale,
          scaffold: false));
      await settle(tester, const Duration(milliseconds: 800));
    }

    testWidgets('3 sütun, 2 dp aralık, 10 dp köşe (Stitch v3); kamera karosu kapalıyken ilk hücre ilk fotoğraf', (tester) async {
      await openPicker(tester);
      final a = tester.getRect(find.byKey(const ValueKey('galleryTile_p1')));
      final b = tester.getRect(find.byKey(const ValueKey('galleryTile_p2')));
      final c = tester.getRect(find.byKey(const ValueKey('galleryTile_p3')));
      final d = tester.getRect(find.byKey(const ValueKey('galleryTile_p4')));
      expect(b.left - a.right, closeTo(2, .01));
      expect(c.left - b.right, closeTo(2, .01));
      expect(d.top - a.bottom, closeTo(2, .01));
      expect(d.left, a.left, reason: 'dördüncü hücre ikinci satırın başı (3 sütun)');
      final clip = tester.widgetList<ClipRRect>(find.descendant(of: find.byKey(const ValueKey('galleryTile_p1')), matching: find.byType(ClipRRect))).first;
      expect(clip.borderRadius, BorderRadius.circular(10));
      expect(find.byKey(const ValueKey('pickerPreview')), findsNothing, reason: 'alt çubuk yok');
      expect(find.textContaining('En fazla 10 öğe', skipOffstage: false), findsOneWidget, reason: 'izgaranın altında düz not');
    });

    testWidgets('seçim sayacı: dolu daire + sıra sayısı, "Gönder (n)" hapı; kare küçülür', (tester) async {
      await openPicker(tester);
      final bu = tester.element(find.byType(MediaPickerPage)).bu;
      expect(find.text('Gönder'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('galleryTile_p1')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('galleryTile_p2')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Gönder (2)'), findsOneWidget);
      final one = find.descendant(of: find.byKey(const ValueKey('galleryTile_p1')), matching: find.text('1'));
      expect(one, findsOneWidget);
      final circle = tester.widget<AnimatedContainer>(find.ancestor(of: one, matching: find.byType(AnimatedContainer)).first);
      expect((circle.decoration as BoxDecoration).color, bu.pr);
      // Stitch PNG'si: seçili karede çerçeve/kararma/küçülme yok, yalnız sayılı daire (seçilmemiş karede halka yok).
      expect(find.descendant(of: find.byKey(const ValueKey('galleryTile_p3')), matching: find.byType(AnimatedContainer)), findsNothing);
      // Seçimi kaldır: sayaç düşer.
      await tester.tap(find.byKey(const ValueKey('galleryTile_p1')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Gönder (1)'), findsOneWidget);
    });

    testWidgets('tekli seçim (sınır 1): onay işareti, sayı yok', (tester) async {
      await openPicker(tester, max: 1);
      await tester.tap(find.byKey(const ValueKey('galleryTile_p1')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.descendant(of: find.byKey(const ValueKey('galleryTile_p1')), matching: find.byIcon(BuIcons.check)), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('galleryTile_p1')), matching: find.text('1')), findsNothing);
    });

    testWidgets('sınır aşılınca seçim eklenmez; 320 dp x1.3 koyu taşma yok', (tester) async {
      await openPicker(tester, max: 2, size: kPhoneSmall, dark: true, scale: 1.3);
      for (var i = 1; i <= 3; i++) {
        await tester.tap(find.byKey(ValueKey('galleryTile_p$i')));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('Gönder (2)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    });
  });
}
