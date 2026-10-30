import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/cache/image_disk_cache.dart';
import 'package:bu_kampus/features/chat/chat_media.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:bu_kampus/features/chat/photo_autosave.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:gal/gal.dart' show GalException, GalExceptionType;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'support/fake_app.dart';

// P22: sohbet balonu görseli (sabit kare, net kaynak seçimi) + fotoğrafları otomatik galeriye kaydetme.

Map<String, dynamic> _att(int id, {int w = 1200, int h = 1600, int? thumbEdge, bool thumb = true, String kind = 'IMAGE'}) => {
      'id': id,
      'kind': kind,
      'url': '/api/conversations/1/media/$id',
      if (thumb) 'thumbUrl': '/api/conversations/1/media/$id/thumb',
      'width': w,
      'height': h,
      'contentType': 'image/jpeg',
      if (thumbEdge != null) 'thumbEdge': thumbEdge,
    };

void main() {
  group('pickChatImageSource', () {
    test('eski kayit (thumbEdge yok = 320 px) 224 dp x DPR3 icin yetmez: ana gorsel', () {
      final s = pickChatImageSource(_att(1), boxW: 224, boxH: 224, dpr: 3)!;
      expect(s.path, '/api/conversations/1/media/1');
      expect(s.full, isTrue);
      // kare cover: kutu 672 px, kaynak 1200x1600 -> en kisa kenar 672 px olacak sekilde genislik 672
      expect(s.decodeWidth, 672);
    });

    test('yeni kayit (thumbEdge 800) yeterli: kucuk resim (az veri)', () {
      final s = pickChatImageSource(_att(2, thumbEdge: 960), boxW: 224, boxH: 224, dpr: 3)!;
      expect(s.path, endsWith('/thumb'));
      expect(s.full, isFalse);
      expect(s.decodeWidth, greaterThanOrEqualTo(672));
    });

    test('yeni kayit ama cok yuksek DPR veya cok ince panorama: ana gorsel', () {
      expect(pickChatImageSource(_att(3, w: 4000, h: 800, thumbEdge: 960), boxW: 224, boxH: 224, dpr: 3)!.full, isTrue);
      expect(pickChatImageSource(_att(3, thumbEdge: 960), boxW: 224, boxH: 224, dpr: 4)!.full, isTrue);
    });

    test('kucuk kaynak: kucuk resim kaynakla aynidir (eski kayit olsa da)', () {
      final s = pickChatImageSource(_att(4, w: 300, h: 200), boxW: 224, boxH: 224, dpr: 3)!;
      expect(s.full, isFalse);
    });

    test('thumb yoksa ana gorsel; video yalniz poster; boyut bilinmiyorsa kutuya gore', () {
      expect(pickChatImageSource(_att(5, thumb: false), boxW: 224, boxH: 224, dpr: 3)!.path, '/api/conversations/1/media/5');
      final v = _att(6, kind: 'VIDEO', w: 1280, h: 720);
      expect(pickChatImageSource(v, boxW: 224, boxH: 224, dpr: 3)!.path, endsWith('/thumb'));
      expect(pickChatImageSource({'kind': 'VIDEO', 'url': '/v'}, boxW: 224, boxH: 224, dpr: 3), isNull);
      final unk = pickChatImageSource({'url': '/u', 'thumbUrl': '/t'}, boxW: 224, boxH: 224, dpr: 3)!;
      expect(unk.full, isTrue); // 320 < 672*.85
      expect(unk.decodeWidth, 672);
    });

    test('decode genisligi en cok 1600', () {
      final s = pickChatImageSource(_att(7, w: 6000, h: 6000), boxW: 500, boxH: 500, dpr: 4)!;
      expect(s.decodeWidth, 1600);
    });

    test('chatMediaSide: 224 dp, dar ekranda sinirli', () {
      expect(chatMediaSide(390 * .78), 224);
      expect(chatMediaSide(320 * .78), 224); // 320 dp ekranda alanin ~%70'i = 224
      expect(chatMediaSide(280 * .78), closeTo(280 * .78 * .9, .001));
      expect(chatMediaSide(280 * .78), lessThan(224));
    });
  });

  group('Balon gorseli (DPR 3)', () {
    Future<void> pumpBubble(WidgetTester tester, Map<String, dynamic> m, Size size) async {
      useScreen(tester, Size(size.width * 3, size.height * 3));
      tester.view.devicePixelRatio = 3;
      await tester.pumpWidget(buildApp(
        Scaffold(
          body: MessageBubble(
            message: m,
            mine: false,
            senderName: null,
            replyName: null,
            seen: false,
            authHeaders: const {},
            onMenu: () {},
            onRetry: () {},
            onOpenImage: (_) {},
            onReact: (_) {},
          ),
        ),
      ));
      await tester.pump();
    }

    Map<String, dynamic> msg(List<Map<String, dynamic>> atts, {String text = ''}) =>
        {'id': 1, 'senderId': 11, 'text': text, 'createdAt': '2026-01-01T10:00:00Z', 'attachments': atts};

    Finder networkImages() => find.byWidgetPredicate((w) => w is Image && w.image is ResizeImage);

    testWidgets('dikey, yatay ve kare gorsel AYNI kare kutuda (224x224); decode >= 224 x DPR', (tester) async {
      for (final dim in [(1200, 1600, 960), (1600, 900, 1280), (900, 900, 720)]) {
        await pumpBubble(tester, msg([_att(1, w: dim.$1, h: dim.$2, thumbEdge: dim.$3)]), kPhoneMedium);
        final im = networkImages();
        expect(im, findsOneWidget);
        final box = tester.getSize(find.ancestor(of: im, matching: find.byType(SizedBox)).first);
        expect(box, const Size(224, 224), reason: '${dim.$1}x${dim.$2}');
        final rz = tester.widget<Image>(im).image as ResizeImage;
        expect(rz.width, greaterThanOrEqualTo(224 * 3));
        expect(rz.width, lessThanOrEqualTo(1600));
        expect((rz.imageProvider as DiskNetworkImage).url, endsWith('/thumb'));
        expect(tester.widget<Image>(im).filterQuality, FilterQuality.medium);
        expect(tester.widget<Image>(im).fit, BoxFit.cover);
      }
    });

    testWidgets('eski mesaj (thumbEdge yok) ana gorseli kullanir; bulanik 320 px thumb kullanilmaz', (tester) async {
      await pumpBubble(tester, msg([_att(2, w: 1200, h: 1600)]), kPhoneMedium);
      final rz = tester.widget<Image>(networkImages()).image as ResizeImage;
      expect((rz.imageProvider as DiskNetworkImage).url, isNot(endsWith('/thumb')));
      expect(rz.width, 672);
    });

    testWidgets('video posteri de ayni kare', (tester) async {
      await pumpBubble(tester, msg([_att(3, kind: 'VIDEO', w: 1280, h: 720)]), kPhoneMedium);
      final box = tester.getSize(find.ancestor(of: networkImages(), matching: find.byType(SizedBox)).first);
      expect(box, const Size(224, 224));
    });

    testWidgets('dar ekranda (260 dp) kare mesaj alanina sigar', (tester) async {
      await pumpBubble(tester, msg([_att(4, thumbEdge: 960)]), const Size(260, 640));
      final box = tester.getSize(find.ancestor(of: networkImages(), matching: find.byType(SizedBox)).first);
      expect(box.width, box.height);
      expect(box.width, lessThan(224));
      expect(tester.takeException(), isNull);
    });

    testWidgets('coklu izgara hucreleri kare', (tester) async {
      await pumpBubble(tester, msg([for (var i = 1; i <= 4; i++) _att(i, thumbEdge: 960)]), kPhoneMedium);
      for (final e in networkImages().evaluate()) {
        final s = tester.getSize(find.byWidget(e.widget).first);
        expect(s.width, s.height);
      }
    });
  });

  test('gercek decode: secilen genislikte cozulen kaynak >= kutu x DPR (1080x1920 foto)', () async {
    final big = img.Image(width: 1080, height: 1920);
    img.fill(big, color: img.ColorRgb8(200, 80, 60));
    final png = Uint8List.fromList(img.encodePng(big));
    final a = _att(9, w: 1080, h: 1920); // eski kayit: ana gorsel secilir
    final s = pickChatImageSource(a, boxW: 224, boxH: 224, dpr: 3)!;
    expect(s.full, isTrue);
    final codec = await ui.instantiateImageCodec(png, targetWidth: s.decodeWidth);
    final f = await codec.getNextFrame();
    expect(f.image.width, greaterThanOrEqualTo(224 * 3));
    // onceki davranis: 320 px'lik kucuk resim 672 px kutuya olceklenirdi
    expect(320 / (224 * 3), lessThan(.5));
  });

  group('PhotoAutoSave', () {
    final t0 = DateTime.utc(2026, 1, 1, 12);
    final after = t0.add(const Duration(minutes: 5)).toIso8601String();
    final before = t0.subtract(const Duration(minutes: 5)).toIso8601String();

    late List<String> saved;
    late int fetches;
    PhotoAutoSave make({MemoryAutoSaveStore? store, Object? putError}) {
      saved = [];
      fetches = 0;
      return PhotoAutoSave(
        store: store ?? MemoryAutoSaveStore(),
        now: () => t0,
        supported: true,
        fetch: (u, h) async {
          fetches++;
          return Uint8List.fromList([1, 2, 3]);
        },
        put: (b, name) async {
          if (putError != null) throw putError;
          saved.add(name);
        },
      );
    }

    Map<String, dynamic> m(int id, List<Map<String, dynamic>> atts, {String? at, Map<String, dynamic>? extra, int sender = 11}) =>
        {'id': id, 'senderId': sender, 'createdAt': at ?? after, 'attachments': atts, ...?extra};

    Future<List<AutoSaveResult>> recv(PhotoAutoSave s, List<Map<String, dynamic>> msgs, {bool blocked = false}) =>
        s.considerReceived(msgs, headers: const {}, isMine: (x) => x['senderId'] == 1, blocked: blocked);

    test('gelen fotograf kaydedilir; ayni ek ikinci kez kaydedilmez (kalici)', () async {
      final store = MemoryAutoSaveStore();
      final s = make(store: store);
      expect(await s.enabled(), isTrue); // varsayilan acik
      expect(await recv(s, [m(1, [_att(10)])]), [AutoSaveResult.saved]);
      expect(saved, ['bu_kampus_10']);
      expect(await recv(s, [m(1, [_att(10)])]), isEmpty);
      // uygulama yeniden acilir (yeni ornek, ayni depo)
      final s2 = make(store: store);
      expect(await recv(s2, [m(1, [_att(10)])]), isEmpty);
      expect(fetches, 0);
    });

    test('tek gosterimlik, video, kaldirilmis ek ve silinen/kaldirilan mesaj kaydedilmez', () async {
      final s = make();
      final once = {..._att(11), 'viewOnce': true};
      final video = _att(12, kind: 'VIDEO');
      final removedAtt = {..._att(13), 'removed': true};
      final noUrl = {..._att(14), 'url': null};
      await recv(s, [
        m(1, [once, video, removedAtt, noUrl]),
        m(2, [_att(15)], extra: {'deleted': true}),
        m(3, [_att(16)], extra: {'removed': true}),
      ]);
      expect(saved, isEmpty);
      expect(fetches, 0);
    });

    test('ayar kapaliyken kaydedilmez; acilinca yalniz SONRAKI mesajlar kaydedilir', () async {
      final store = MemoryAutoSaveStore();
      final s = make(store: store);
      await s.setEnabled(false);
      expect(await recv(s, [m(1, [_att(20)])]), isEmpty);
      await s.setEnabled(true); // since = t0
      expect(await recv(s, [m(2, [_att(21)], at: before), m(3, [_att(22)])]), [AutoSaveResult.saved]);
      expect(saved, ['bu_kampus_22']); // eski mesaj (ayar oncesi) yigilmaz
    });

    test('ilk kullanimda eski mesajlar kaydedilmez', () async {
      final s = make();
      await recv(s, [m(1, [_att(30)], at: before), m(2, [_att(31)], at: before)]);
      expect(saved, isEmpty);
    });

    test('engelli sohbet ve kendi mesajlarim (gonderimde kaydedilir) atlanir', () async {
      final s = make();
      expect(await recv(s, [m(1, [_att(40)])], blocked: true), isEmpty);
      expect(await recv(s, [m(2, [_att(41)], sender: 1)]), isEmpty);
      expect(saved, isEmpty);
    });

    test('gonderilen fotograf yerel baytlardan kaydedilir, ayni ek iki kez degil', () async {
      final s = make();
      expect(await s.saveSent(50, Uint8List.fromList([9])), AutoSaveResult.saved);
      expect(await s.saveSent(50, Uint8List.fromList([9])), AutoSaveResult.skipped);
      expect(saved, ['bu_kampus_50']);
      await s.setEnabled(false);
      expect(await s.saveSent(51, Uint8List.fromList([9])), AutoSaveResult.skipped);
    });

    test('izin reddi: sessiz sonuc + tek seferlik bilgi; ayar kapanmaz', () async {
      final s = make(
          putError: GalException(
              type: GalExceptionType.accessDenied, platformException: PlatformException(code: 'ACCESS_DENIED'), stackTrace: StackTrace.empty));
      expect(await recv(s, [m(1, [_att(60)])]), [AutoSaveResult.denied]);
      expect(await s.enabled(), isTrue);
      expect(await s.takeDeniedNotice(), isTrue);
      expect(await s.takeDeniedNotice(), isFalse);
      // diger hata: failed; ayni oturumda ayni ek tekrar denenmez (hata yigilmaz)
      final f = make(putError: UnsupportedError('x'));
      expect(await recv(f, [m(1, [_att(61)])]), [AutoSaveResult.failed]);
      expect(await recv(f, [m(1, [_att(61)])]), isEmpty);
    });

    test('indirme basarisiz: kaydedilmez, kayit isaretlenmez', () async {
      final store = MemoryAutoSaveStore();
      final s = PhotoAutoSave(
          store: store, now: () => t0, supported: true, fetch: (u, h) async => null, put: (b, n) async => fail('cagrilmamali'));
      expect(await recv(s, [m(1, [_att(70)])]), [AutoSaveResult.failed]);
      expect((store.data['saved'] as List?) ?? [], isEmpty);
    });
  });
}
