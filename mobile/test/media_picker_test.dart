import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/media_camera_page.dart';
import 'package:bu_kampus/features/chat/media_library.dart';
import 'package:bu_kampus/features/chat/media_pick.dart';
import 'package:bu_kampus/features/chat/media_picker_page.dart';
import 'package:bu_kampus/features/chat/media_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_media.dart';

/// Sayfayı bir düğmeyle açan ana sayfa; sayfanın döndürdüğü sonuç [result]'a yazılır.
Widget _host(Widget Function() page, List<Object?> result) => Builder(
      builder: (c) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async => result.add(await Navigator.push<Object?>(c, MaterialPageRoute(builder: (_) => page()))),
            child: const Text('aç'),
          ),
        ),
      ),
    );

Future<void> _openHost(WidgetTester tester, Widget Function() page, List<Object?> result,
    {Brightness b = Brightness.light, Size size = kPhoneMedium}) async {
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(_host(page, result), brightness: b, size: size));
  await tester.tap(find.text('aç'));
  await settle(tester, const Duration(milliseconds: 500));
}

MediaPickerPage _picker(MediaLibrary lib, {MediaCameraLauncher? camera, int pageSize = 60}) => MediaPickerPage(
      library: lib,
      ensureAccess: (c, p, {rationale}) async => true,
      openCamera: camera,
      pageSize: pageSize,
    );

Finder _tile(String id) => find.byKey(ValueKey('galleryTile_$id'));
Finder _badge(String id, String n) => find.descendant(of: _tile(id), matching: find.text(n));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pump();
}

void _ok(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('$e');
}

FakeBackend _chatBackend() => FakeBackend()
  ..on('/conversations/1/messages?size=30', {'items': <Object>[], 'nextCursor': null})
  ..on('/conversations/1', {
    'conversation': {'id': 1},
    'members': [
      {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
      {'userId': 11, 'displayName': 'Ali Veli'},
    ],
  })
  ..on('/users/11/presence', {'online': true})
  ..on('/messages/reactions', {'emojis': <String>[]})
  ..on('/conversations/1/media', {'id': 77})
  ..on('/conversations/1/messages', {
    'id': 9,
    'conversationId': 1,
    'senderId': 1,
    'text': '',
    'createdAt': DateTime.now().toUtc().toIso8601String(),
  });

ChatDetailPage _chat(FakeBackend be, FakeMediaLibrary lib, {MediaCameraLauncher? camera}) => ChatDetailPage(
      session: makeSession(be),
      connectRealtime: false,
      uploadClient: be.client,
      mediaLibrary: lib,
      openCamera: camera,
      ensureAccess: (c, p, {rationale}) async => true,
      conversation: const {
        'id': 1,
        'type': 'DIRECT',
        'title': 'Ali Veli',
        'peer': {'id': 11, 'displayName': 'Ali Veli'},
      },
    );

void main() {
  setUpAll(loadTestFonts);

  group('Galeri izgarasi', () {
    testWidgets('ilk karo kamera; en yeni once; videoda sure rozeti', (tester) async {
      final lib = FakeMediaLibrary.photos(5, videos: [FakeMediaLibrary.video('v1', ms: 12000)]);
      final res = <Object?>[];
      await _openHost(tester, () => _picker(lib), res);
      expect(find.text('Son eklenenler'), findsOneWidget);
      expect(find.text('KAMERA'), findsOneWidget);
      expect(find.text('En fazla 10 öğe seçebilirsiniz. Video en fazla 60 saniye olabilir.'), findsOneWidget);
      final cam = tester.getRect(find.byKey(const ValueKey('cameraTile')));
      final first = tester.getRect(_tile('v1'));
      final second = tester.getRect(_tile('p1'));
      expect(cam.left, lessThan(first.left)); // kamera ilk karo
      expect(cam.top, first.top);
      expect(first.left, lessThan(second.left)); // sonra en yeni (v1), sonra p1
      expect(find.descendant(of: _tile('v1'), matching: find.text('0:12')), findsOneWidget);
      expect(find.textContaining('1 / 10', findRichText: true), findsNothing);
      _ok(tester);
    });

    testWidgets('sayfalama: yalniz ilk sayfa yuklenir, kaydirinca devami gelir', (tester) async {
      final lib = FakeMediaLibrary.photos(150);
      await _openHost(tester, () => _picker(lib), []);
      expect(lib.pagesRequested, [0]);
      await tester.drag(find.byKey(const ValueKey('galleryGrid')), const Offset(0, -4000));
      await settle(tester, const Duration(milliseconds: 400));
      expect(lib.pagesRequested.contains(1), isTrue);
      expect(lib.pagesRequested.contains(2), isFalse);
      await tester.drag(find.byKey(const ValueKey('galleryGrid')), const Offset(0, -9000));
      await settle(tester, const Duration(milliseconds: 400));
      expect(lib.pagesRequested.contains(2), isTrue);
      _ok(tester);
    });

    testWidgets('coklu secim: numaralar sirayla, tekrar dokununca kalkar ve yeniden numaralanir', (tester) async {
      final lib = FakeMediaLibrary.photos(6);
      await _openHost(tester, () => _picker(lib), []);
      await _tap(tester, _tile('p1'));
      await _tap(tester, _tile('p2'));
      await _tap(tester, _tile('p3'));
      expect(_badge('p1', '1'), findsOneWidget);
      expect(_badge('p2', '2'), findsOneWidget);
      expect(_badge('p3', '3'), findsOneWidget);
      expect(find.textContaining('3 / 10', findRichText: true), findsOneWidget);
      await _tap(tester, _tile('p2'));
      expect(_badge('p3', '2'), findsOneWidget);
      expect(find.textContaining('2 / 10', findRichText: true), findsOneWidget);
      _ok(tester);
    });

    testWidgets('en fazla 10 oge: 11. icin toast', (tester) async {
      final lib = FakeMediaLibrary.photos(12);
      await _openHost(tester, () => _picker(lib), []);
      for (var i = 1; i <= 10; i++) {
        await _tap(tester, _tile('p$i'));
      }
      expect(find.textContaining('10 / 10', findRichText: true), findsOneWidget);
      await _tap(tester, _tile('p11'));
      expect(find.text('En fazla 10 öğe seçebilirsin'), findsOneWidget);
      expect(find.textContaining('10 / 10', findRichText: true), findsOneWidget);
      _ok(tester);
    });

    testWidgets('birden cok video ve karisik secim serbest', (tester) async {
      final lib = FakeMediaLibrary.photos(2, videos: [FakeMediaLibrary.video('v1'), FakeMediaLibrary.video('v2')]);
      await _openHost(tester, () => _picker(lib), []);
      await _tap(tester, _tile('v1'));
      await _tap(tester, _tile('v2'));
      await _tap(tester, _tile('p1'));
      expect(find.textContaining('3 / 10', findRichText: true), findsOneWidget);
      _ok(tester);
    });

    testWidgets('60 sn uzeri video secilmez: uyari, onizleme cubugu yok', (tester) async {
      final lib = FakeMediaLibrary.photos(1, videos: [FakeMediaLibrary.video('long', ms: 75000)]);
      await _openHost(tester, () => _picker(lib), []);
      await _tap(tester, _tile('long'));
      expect(find.text('Video en fazla 60 saniye olabilir'), findsOneWidget);
      expect(find.byKey(const ValueKey('pickerPreview')), findsNothing);
      _ok(tester);
    });

    testWidgets('kamera karosu: cekilen oge secime eklenir ve onizleme acilir', (tester) async {
      final lib = FakeMediaLibrary.photos(2);
      final res = <Object?>[];
      await _openHost(tester, () => _picker(lib, camera: (c) async => fakePhotoPick('cam1')), res);
      await _tap(tester, find.byKey(const ValueKey('cameraTile')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('previewCounter')), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
      // Önizlemeyi kapat: seçici açık kalır, kamera öğesi seçili.
      await _tap(tester, find.byKey(const ValueKey('previewClose')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.textContaining('1 / 10', findRichText: true), findsOneWidget);
      _ok(tester);
    });

    testWidgets('albumler yalniz birden fazla albüm varsa gorunur', (tester) async {
      final one = FakeMediaLibrary.photos(2);
      await _openHost(tester, () => _picker(one), []);
      expect(find.byKey(const ValueKey('albumButton')), findsNothing);
      await unmount(tester);
      final many = FakeMediaLibrary(
        [for (var i = 1; i <= 2; i++) GalleryItem(id: 'p$i', isVideo: false)],
        albumList: const [
          GalleryAlbum(id: 'all', name: 'Recent', count: 2, isAll: true),
          GalleryAlbum(id: 'a', name: 'WhatsApp', count: 1),
        ],
      );
      await _openHost(tester, () => _picker(many), []);
      expect(find.byKey(const ValueKey('albumButton')), findsOneWidget);
      _ok(tester);
    });

    testWidgets('sinirli erisim: baglanti gorunur; reddedilince Ayarlardan ac', (tester) async {
      final lim = FakeMediaLibrary([const GalleryItem(id: 'p1', isVideo: false)], access: LibraryAccess.limited);
      await _openHost(tester, () => _picker(lim), []);
      expect(find.byKey(const ValueKey('limitedBanner')), findsOneWidget);
      expect(_tile('p1'), findsOneWidget);
      await _tap(tester, find.text('Daha fazla seç'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(lim.limitedOpened, 1);
      await unmount(tester);

      final denied = FakeMediaLibrary(const [], access: LibraryAccess.denied);
      await _openHost(tester, () => _picker(denied), []);
      expect(find.text('Ayarlardan aç'), findsOneWidget);
      await _tap(tester, find.text('Ayarlardan aç'));
      expect(denied.settingsOpened, 1);
      _ok(tester);
    });

    for (final size in kPhoneSizes) {
      for (final b in Brightness.values) {
        testWidgets('tasma yok: secici ${size.width.toInt()} $b', (tester) async {
          final lib = FakeMediaLibrary.photos(8, videos: [FakeMediaLibrary.video('v1')]);
          await _openHost(tester, () => _picker(lib), [], b: b, size: size);
          await _tap(tester, _tile('v1'));
          await _tap(tester, _tile('p1'));
          _ok(tester);
        });
      }
    }
  });

  group('RTL (ar)', () {
    Widget rtl(Widget w) => Directionality(textDirection: TextDirection.rtl, child: w);

    testWidgets('secici ve onizleme RTL 320 dp tasma yok', (tester) async {
      final lib = FakeMediaLibrary.photos(8, videos: [FakeMediaLibrary.video('v1')]);
      await _openHost(tester, () => rtl(_picker(lib)), [], size: const Size(320, 640));
      await _tap(tester, _tile('v1'));
      await _tap(tester, _tile('p1'));
      expect(find.byKey(const ValueKey('pickerPreview')), findsOneWidget);
      _ok(tester);
      await unmount(tester);
      await _openHost(tester, () => rtl(MediaPreviewPage(picks: [fakePhotoPick('a'), fakeVideoPick('v')])), [],
          b: Brightness.dark, size: const Size(320, 640));
      expect(find.byKey(const ValueKey('previewThumb_1')), findsOneWidget);
      _ok(tester);
    });
  });

  group('Onizleme', () {
    MediaPreviewPage preview(List<MediaPick> picks) => MediaPreviewPage(picks: picks);

    testWidgets('serit: gecis ve sayac', (tester) async {
      await _openHost(tester, () => preview([fakePhotoPick('a'), fakePhotoPick('b'), fakePhotoPick('c')]), []);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('3 öğeyi gönder'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('previewThumb_2')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('3 / 3'), findsOneWidget);
      _ok(tester);
    });

    testWidgets('kapatinca sayfa kapanir ve sonuc bos doner', (tester) async {
      final res = <Object?>[];
      await _openHost(tester, () => preview([fakePhotoPick('a')]), res);
      await _tap(tester, find.byKey(const ValueKey('previewClose')));
      await settle(tester, const Duration(milliseconds: 400));
      await settle(tester, const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('previewPages')), findsNothing);
      expect(res, [null]);
    });

    testWidgets('tek gonderimlik dugmesi yalniz gorselde; basinca isaretlenir ve toast; plan once tasir', (tester) async {
      final res = <Object?>[];
      await _openHost(tester, () => preview([fakePhotoPick('a'), fakeVideoPick('v')]), res);
      expect(find.byKey(const ValueKey('onceButton_0')), findsOneWidget);
      final onceRect = tester.getRect(find.byKey(const ValueKey('onceButton_0')));
      final pageRect = tester.getRect(find.byKey(const ValueKey('previewPages')));
      final capRect = tester.getRect(find.byKey(const ValueKey('previewCaption')));
      expect(onceRect.top, greaterThanOrEqualTo(pageRect.bottom)); // referans: gorselin altinda, aciklama satirinda
      expect(onceRect.left, greaterThan(capRect.left)); // aciklama alaninin yaninda
      await _tap(tester, find.byKey(const ValueKey('onceButton_0')));
      expect(find.text('Tek gönderimlik: alıcı yalnızca bir kez görebilir'), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 300));
      await _tap(tester, find.byKey(const ValueKey('previewNoteClose')));
      expect(find.text('Tek gönderimlik: alıcı yalnızca bir kez görebilir'), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('previewThumb_1')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('onceButton_1')), findsNothing); // videoda yok
      await _tap(tester, find.byKey(const ValueKey('previewSend')));
      await settle(tester, const Duration(milliseconds: 300));
      final plan = res.single as MediaSendPlan;
      expect(plan.items.map((i) => i.once), [true, false]);
      _ok(tester);
    });

    testWidgets('aciklama plana yazilir', (tester) async {
      final res = <Object?>[];
      await _openHost(tester, () => preview([fakePhotoPick('a')]), res);
      await tester.enterText(find.byKey(const ValueKey('previewCaption')), 'Merhaba');
      await _tap(tester, find.byKey(const ValueKey('previewSend')));
      await settle(tester, const Duration(milliseconds: 300));
      expect((res.single as MediaSendPlan).caption, 'Merhaba');
    });

    for (final size in kPhoneSizes) {
      for (final b in Brightness.values) {
        testWidgets('tasma yok: onizleme ${size.width.toInt()} $b', (tester) async {
          await _openHost(
              tester, () => preview([fakePhotoPick('a'), fakeVideoPick('v'), fakePhotoPick('c'), fakePhotoPick('d')]), [],
              b: b, size: size);
          await _tap(tester, find.byKey(const ValueKey('onceButton_0')));
          _ok(tester);
        });
      }
    }
  });

  group('Mesaj plani (planMessages)', () {
    MediaSendItem ph(String k, {bool once = false}) => MediaSendItem(fakePhotoPick(k), once: once);
    MediaSendItem vid(String k) => MediaSendItem(fakeVideoPick(k));
    List<String> keys(PlannedMessage m) => [for (final p in m.picks) p.key];

    test('isaretsizler (video dahil) 10 arli gruplanir, once ayri, sira korunur', () {
      final plan = MediaSendPlan([
        ph('1'), ph('2', once: true), vid('v'),
        for (var i = 3; i <= 14; i++) ph('$i'),
      ], '');
      final m = planMessages(plan);
      expect(m.map(keys), [
        ['1', 'v', '3', '4', '5', '6', '7', '8', '9', '10'],
        ['2'],
        ['11', '12', '13', '14'],
      ]);
      expect(m.map((e) => e.once), [false, true, false]);
    });

    test('karisik 10 oge tek mesaj', () {
      final plan = MediaSendPlan([for (var i = 0; i < 5; i++) ph('p$i'), for (var i = 0; i < 5; i++) vid('v$i')], '');
      final m = planMessages(plan);
      expect(m.length, 1);
      expect(m.first.picks.length, 10);
    });

    test('video bayt toplami 120 MB altinda kalacak sekilde bolunur', () {
      const mb = 1024 * 1024;
      final sizes = [40 * mb, 40 * mb, 40 * mb, 40 * mb, 0, 10 * mb];
      final parts = splitByVideoBytes<int>(sizes, (e) => e);
      expect(parts.map((p) => p.length), [3, 3]);
      expect(parts.expand((e) => e).toList(), sizes);
      for (final p in parts) {
        expect(p.fold<int>(0, (a, b) => a + b), lessThanOrEqualTo(maxVideoBytesPerMessage));
      }
    });

    test('aciklama ilk isaretsiz mesaja, yoksa ilk mesaja gider', () {
      var m = planMessages(MediaSendPlan([ph('1', once: true), ph('2')], ' selam '));
      expect(m.map((e) => e.caption), ['', 'selam']);
      m = planMessages(MediaSendPlan([ph('1', once: true), ph('2', once: true)], 'x'));
      expect(m.map((e) => e.caption), ['x', '']);
    });
  });

  group('Sohbet: yazma cubugu ve gonderim', () {
    Future<void> openChat(WidgetTester tester, FakeBackend be, FakeMediaLibrary lib,
        {MediaCameraLauncher? camera, Size size = kPhoneMedium, Brightness b = Brightness.light}) async {
      useScreen(tester, size);
      await tester.pumpWidget(buildApp(_chat(be, lib, camera: camera), brightness: b, size: size));
      await settle(tester, const Duration(milliseconds: 600));
    }

    testWidgets('yazma cubugu (ref 20): + ve kamera tonal daire, ortada metin kutusu, ayri gonder; bos iken devre disi', (tester) async {
      await openChat(tester, _chatBackend(), FakeMediaLibrary.photos(3));
      expect(find.byKey(const ValueKey('viewOnceToggle')), findsNothing);
      expect(find.byTooltip('Görsel gönder'), findsNothing);
      final plus = tester.getRect(find.byKey(const ValueKey('attachButton')));
      final cam = tester.getRect(find.byKey(const ValueKey('cameraShortcut')));
      final field = tester.getRect(find.byKey(const ValueKey('composerField')));
      final send = tester.getRect(find.byKey(const ValueKey('sendButton')));
      expect(cam.left, greaterThanOrEqualTo(plus.right - 1)); // artı, sonra kamera (ayrı daireler)
      expect(field.left, greaterThanOrEqualTo(cam.right - 1)); // ortada metin kutusu
      expect(send.left, greaterThanOrEqualTo(field.right)); // gönder düğmesi kutunun dışında, sağda
      expect(find.ancestor(of: find.byKey(const ValueKey('sendButton')), matching: find.byType(TextField)), findsNothing);
      expect(find.descendant(of: find.byType(TextField), matching: find.byKey(const ValueKey('sendButton'))), findsNothing);
      expect(tester.widget<GestureDetector>(find.byKey(const ValueKey('sendButton'))).onTap, isNull);
      await tester.enterText(find.byKey(const ValueKey('composerField')), 'Selam');
      await tester.pump();
      expect(tester.widget<GestureDetector>(find.byKey(const ValueKey('sendButton'))).onTap, isNotNull);
      _ok(tester);
    });

    testWidgets('+ dogrudan galeriyi acar (eski 4 secenekli menu yok)', (tester) async {
      await openChat(tester, _chatBackend(), FakeMediaLibrary.photos(3));
      await _tap(tester, find.byKey(const ValueKey('attachButton')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byType(MediaPickerPage), findsOneWidget);
      for (final l in ['Galeriden seç', 'Fotoğraf çek', 'Galeriden video seç', 'Video çek']) {
        expect(find.text(l), findsNothing);
      }
      _ok(tester);
    });

    testWidgets('kamera kisayolu kamerayi acar, sonra onizleme', (tester) async {
      var opened = 0;
      await openChat(tester, _chatBackend(), FakeMediaLibrary.photos(1), camera: (c) async {
        opened++;
        return fakePhotoPick('c1');
      });
      await _tap(tester, find.byKey(const ValueKey('cameraShortcut')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(opened, 1);
      expect(find.byType(MediaPreviewPage), findsOneWidget);
      _ok(tester);
    });

    testWidgets('karisik secim: isaretsizler tek mesajda, tek gonderimlik ayri; aciklama ilk isaretsize; sayfa kapanir', (tester) async {
      final be = _chatBackend();
      await openChat(tester, be, FakeMediaLibrary.photos(4));
      await _tap(tester, find.byKey(const ValueKey('attachButton')));
      await settle(tester, const Duration(milliseconds: 400));
      for (final id in ['p1', 'p2', 'p3']) {
        await _tap(tester, _tile(id));
      }
      await _tap(tester, find.byKey(const ValueKey('pickerPreview')));
      await settle(tester, const Duration(milliseconds: 400));
      await _tap(tester, find.byKey(const ValueKey('previewThumb_1')));
      await settle(tester, const Duration(milliseconds: 400));
      await _tap(tester, find.byKey(const ValueKey('onceButton_1')));
      await tester.enterText(find.byKey(const ValueKey('previewCaption')), 'Tatil');
      await _tap(tester, find.byKey(const ValueKey('previewSend')));
      await settle(tester, const Duration(seconds: 2));
      expect(find.byType(MediaPreviewPage), findsNothing);
      expect(find.byType(MediaPickerPage), findsNothing);
      final sent = be.bodyLog['POST /conversations/1/messages']!.cast<Map>();
      expect(sent.length, 2);
      // Sıra: grup (p1+p3) ilk öğenin yerinde, sonra tek gönderimlik p2.
      expect(sent[0]['attachmentIds'], hasLength(2));
      expect(sent[0]['text'], 'Tatil');
      expect(sent[0].containsKey('viewOnce'), isFalse);
      expect(sent[1]['attachmentIds'], hasLength(1));
      expect(sent[1]['viewOnce'], true);
      expect(sent[1]['text'], '');
      expect(be.count('POST /conversations/1/media'), 3);
      _ok(tester);
    });

    for (final size in kPhoneSizes) {
      for (final b in Brightness.values) {
        testWidgets('tasma yok: yazma cubugu ${size.width.toInt()} $b', (tester) async {
          await openChat(tester, _chatBackend(), FakeMediaLibrary.photos(1), size: size, b: b);
          await tester.enterText(find.byKey(const ValueKey('composerField')), 'Çok satırlı\nmetin\nüç\ndört\nbeş\naltı');
          await tester.pump();
          // Çok satıra büyüyünce + ve gönder düğmeleri altta kalır.
          final field = tester.getRect(find.byKey(const ValueKey('composerField')));
          final plus = tester.getRect(find.byKey(const ValueKey('attachButton')));
          final send = tester.getRect(find.byKey(const ValueKey('sendButton')));
          expect(plus.bottom, send.bottom);
          expect(field.height, greaterThan(46 - 1));
          _ok(tester);
        });
      }
    }
  });
}
