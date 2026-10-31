import 'dart:typed_data';

import 'package:bu_kampus/features/media_crop/crop_controller.dart';
import 'package:bu_kampus/features/media_crop/crop_engine.dart';
import 'package:bu_kampus/features/media_crop/media_crop.dart';
import 'package:bu_kampus/features/posts/compose_post_page.dart';
import 'package:bu_kampus/features/posts/post_card.dart';
import 'package:bu_kampus/features/posts/post_detail_page.dart';
import 'package:bu_kampus/features/posts/post_media_uploader.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../support/fake_app.dart';

/// Sol yarısı kırmızı, sağ yarısı mavi 400x300 PNG.
Uint8List _png() {
  final im = img.Image(width: 400, height: 300);
  for (var y = 0; y < 300; y++) {
    for (var x = 0; x < 400; x++) {
      im.setPixelRgb(x, y, x < 200 ? 255 : 0, 0, x < 200 ? 0 : 255);
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split(String.fromCharCode(10)).take(30).join(String.fromCharCode(10))}');
}

/// UI-K4: kirpma (CropController/engine/sayfa), gonderi olustur, menu ve diyaloglar.
void main() {
  setUpAll(loadTestFonts);

  group('CropController geometri', () {
    test('4:5 cerceve, gorsel cerceveyi tam kaplar; yakinlastirma ve kaydirma sinirlanir', () {
      final c = CropController(spec: const CropSpec.post(), imageWidth: 400, imageHeight: 300);
      expect(c.frame.width / c.frame.height, closeTo(0.8, 1e-9));
      var r = c.toRect();
      // 4:5 cerceve 400x300 gorselde yuksekligi kaplar: 240x300 bolge, ortada.
      expect(r.h, closeTo(300, 1e-6));
      expect(r.w, closeTo(240, 1e-6));
      expect(r.x, closeTo(80, 1e-6));
      c.panBy(const Offset(1000, 0));
      r = c.toRect();
      expect(r.x, closeTo(0, 1e-6)); // sola dayali (gorsel saga kaydi: sinir)
      c.setZoom(2);
      expect(c.toRect().w, closeTo(120, 1e-6));
      c.setZoom(99);
      expect(c.zoom, CropController.maxZoom);
      c.rotate();
      expect(c.quarterTurns, 1);
      expect(c.zoom, 1);
      expect(c.rotatedWidth, 300);
      c.reset();
      expect(c.isDirty, isFalse);
    });

    test('profil 1:1, kapak 16:9, sohbet gorselin kendi orani', () {
      expect(CropController(spec: const CropSpec.profile(), imageWidth: 100, imageHeight: 200).frame.aspectRatio, 1);
      expect(CropController(spec: const CropSpec.cover(), imageWidth: 100, imageHeight: 200).frame.aspectRatio, closeTo(16 / 9, 1e-9));
      final chat = CropController(spec: const CropSpec.chat(), imageWidth: 400, imageHeight: 200);
      expect(chat.frame.aspectRatio, closeTo(2, 1e-9));
      chat.rotate();
      expect(chat.frame.aspectRatio, closeTo(.5, 1e-9));
    });
  });

  group('kirpma motoru', () {
    test('sag yarimi keser, uzun kenari sinirlar, JPEG uretir', () {
      final out = cropJpegSync(_png(), quarterTurns: 0, rect: const CropRect(200, 0, 200, 300), maxEdge: 150)!;
      expect(out[0], 0xFF);
      expect(out[1], 0xD8);
      final d = img.decodeJpg(out)!;
      expect(d.height, 150);
      expect(d.width, 100);
      final p = d.getPixel(50, 75);
      expect(p.b, greaterThan(200)); // mavi yari
      expect(p.r, lessThan(60));
    });

    test('90 derece dondurme boyutlari degistirir', () {
      final out = cropJpegSync(_png(), quarterTurns: 1, rect: const CropRect(0, 0, 300, 400), maxEdge: 2000)!;
      final d = img.decodeJpg(out)!;
      expect((d.width, d.height), (300, 400));
    });
  });

  group('kirpma sayfasi', () {
    Future<void> openCrop(WidgetTester tester, CropSpec spec, void Function(CropOutcome?) done) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(buildApp(Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('open'),
              onPressed: () async => done(await cropImage(c, _png(), spec)),
              child: const Text('ac'),
            ),
          ),
        ),
      )));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('post 4:5 (Stitch v3 03): yalniz kapat + Vazgec/Bitti, dondur/sifirla/onizleme/baslik yok; sahne tuvali doldurur; Bitti 4:5 JPEG dondurur', (tester) async {
      useScreen(tester, const Size(390, 844));
      CropOutcome? out;
      var done = false;
      await openCrop(tester, const CropSpec.post(previewName: 'Elif Yıldız', previewCaption: 'Güzel gün', allowChange: true), (o) {
        out = o;
        done = true;
      });
      expect(find.byKey(const ValueKey('cropClose')), findsOneWidget);
      expect(find.byKey(const ValueKey('cropCancel')), findsOneWidget);
      expect(find.text('Vazgeç'), findsOneWidget);
      expect(find.text('Bitti'), findsOneWidget);
      // Kaldirilanlar: baslik, ipucu hapi, onizleme karti, dondur/sifirla/olcek, fotografi degistir baglantisi.
      expect(find.text('Gönderi fotoğrafı'), findsNothing);
      expect(find.text('Sürükle ve yakınlaştır'), findsNothing);
      expect(find.text('Akışta böyle görünecek'), findsNothing);
      expect(find.byKey(const ValueKey('cropChange')), findsNothing);
      expect(find.byKey(const ValueKey('cropRotate')), findsNothing);
      expect(find.byKey(const ValueKey('cropReset')), findsNothing);
      expect(find.byKey(const ValueKey('cropZoom')), findsNothing);
      // Sahne: tam genislik; 4:5 cerceve 39 dp yan bosluk (312 dp genislik).
      // Sahne sanal birimde cizilir (FittedBox dp'ye esler): ekrandaki kutu tam genislik.
      final stage = tester.getSize(find.ancestor(of: find.byKey(const ValueKey('cropStage')), matching: find.byType(FittedBox)).first);
      expect(stage.width, closeTo(390, 0.5));
      final bar = tester.getSize(find.byKey(const ValueKey('cropSave')));
      expect(bar.height, greaterThanOrEqualTo(40));
      await tester.tap(find.byKey(const ValueKey('cropSave')));
      await tester.pump();
      await tester.runAsync(() async {
        for (var i = 0; i < 40 && !done; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      await tester.pump(const Duration(milliseconds: 400));
      expect(done, isTrue);
      final d = img.decodeJpg(out!.bytes!)!;
      expect(d.width / d.height, closeTo(0.8, 0.01));
      noErr(tester);
    });

    testWidgets('post kirpma: Vazgec null dondurur (kapatma ile ayni)', (tester) async {
      useScreen(tester, const Size(390, 844));
      CropOutcome? out;
      var done = false;
      await openCrop(tester, const CropSpec.post(), (o) {
        out = o;
        done = true;
      });
      await tester.tap(find.byKey(const ValueKey('cropCancel')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(done, isTrue);
      expect(out, isNull);
      noErr(tester);
    });

    testWidgets('profil: daire onizlemeler (96 + 40) ve kapak: "Kapagi kaldir" yan eylemi', (tester) async {
      await openCrop(tester, const CropSpec.profile(), (_) {});
      expect(find.text('Fotoğrafı kırp'), findsOneWidget);
      expect(find.text('Profilde böyle görünecek'), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('cropPreviewBig'))), const Size(96, 96));
      await tester.tap(find.byKey(const ValueKey('cropClose')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox());

      CropOutcome? out;
      await openCrop(tester, const CropSpec.cover(previewTitle: 'Bahar Şenliği', previewSubtitle: 'Müzik Kulübü', allowRemove: true), (o) => out = o);
      expect(find.text('Kapak fotoğrafı'), findsOneWidget);
      expect(find.text('Bahar Şenliği'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('cropRemove')));
      await tester.tap(find.byKey(const ValueKey('cropRemove')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(out?.removed, isTrue);
      noErr(tester);
    });

    testWidgets('bozuk gorsel: hata durumu', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(buildApp(Builder(
        builder: (c) => Scaffold(
          body: TextButton(key: const ValueKey('open'), onPressed: () => cropImage(c, Uint8List.fromList([1, 2, 3]), const CropSpec.logo()), child: const Text('ac')),
        ),
      )));
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('cropError')), findsOneWidget);
      noErr(tester);
    });
  });

  group('gonderi menusu ve diyaloglar', () {
    Post post({bool mine = false, bool edited = false, String text = 'Bahar geldi kampüse'}) {
      final j = samplePost(id: 1000, media: [samplePostMedia(id: 7)], text: text, likeCount: 128, mine: mine, authorId: mine ? 1 : 12);
      if (edited) j['editedAt'] = '2026-10-26T10:00:00Z';
      return Post.fromJson(j);
    }

    Future<(FakeBackend, List<int>)> open(WidgetTester tester, Post p) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      final deleted = <int>[];
      await tester.pumpWidget(buildApp(Scaffold(
        body: ListView(padding: const EdgeInsets.all(16), children: [
          PostCard(session: makeSession(b), post: p, onChanged: (_) {}, onDeleted: deleted.add),
        ]),
      )));
      await settle(tester, const Duration(milliseconds: 300));
      return (b, deleted);
    }

    testWidgets('baskasinin menusu (Stitch v3 05): alt sayfa, Profili gor / Sikayet et / Engelle, 56 dp satirlar (kaydet/paylas/kopyala yok)', (tester) async {
      await open(tester, post());
      await tester.tap(find.byKey(const ValueKey('post-menu-button')));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('post-act-profile')), findsOneWidget);
      expect(find.byKey(const ValueKey('post-act-report')), findsOneWidget);
      expect(find.byKey(const ValueKey('post-act-block')), findsOneWidget);
      expect(find.byKey(const ValueKey('post-act-edit')), findsNothing);
      expect(find.text('Şikâyet et'), findsOneWidget);
      for (final id in ['profile', 'report', 'block']) {
        expect(tester.getSize(find.byKey(ValueKey('post-act-$id'))).height, greaterThanOrEqualTo(56));
      }
      // Alt sayfa: ekranin alt yarisinda, tam genislikte.
      expect(tester.getRect(find.byKey(const ValueKey('post-act-report'))).width, 390);
      expect(tester.getRect(find.byKey(const ValueKey('post-act-report'))).top, greaterThan(422));
      for (final s in ['Kaydet', 'Paylaş', 'Bağlantıyı kopyala']) {
        expect(find.text(s), findsNothing);
      }
      await tester.tapAt(const Offset(195, 60)); // karartma: kapat
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('post-act-report')), findsNothing);
      noErr(tester);
    });

    testWidgets('kendi menusu: Duzenle / Sil; duzenlendi etiketi', (tester) async {
      await open(tester, post(mine: true, edited: true));
      expect(find.byKey(const ValueKey('post-edited')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('post-menu-button')));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('post-act-edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('post-act-delete')), findsOneWidget);
      expect(find.byKey(const ValueKey('post-act-report')), findsNothing);
      noErr(tester);
    });

    testWidgets('silme onayi: Vazgec iptal eder; Sil DELETE atar, onDeleted + "Gonderi silindi"', (tester) async {
      final (b, deleted) = await open(tester, post(mine: true));
      Future<void> openDelete() async {
        await tester.tap(find.byKey(const ValueKey('post-menu-button')));
        await settle(tester, const Duration(milliseconds: 900));
        await tester.tap(find.byKey(const ValueKey('post-act-delete')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      await openDelete();
      expect(find.text('Gönderi silinsin mi?'), findsOneWidget);
      expect(find.text('Bu işlem geri alınamaz.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('post-dialog-cancel')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(b.requests.any((r) => r.startsWith('DELETE /posts/1000')), isFalse);

      await openDelete();
      await tester.tap(find.byKey(const ValueKey('post-dialog-confirm')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests.any((r) => r.startsWith('DELETE /posts/1000')), isTrue, reason: b.requests.join('|'));
      expect(deleted, [1000]);
      expect(find.text('Gönderi silindi'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      noErr(tester);
    });

    testWidgets('duzenleme: bos metin kaydedilmez ("Metin bos olamaz."), 8. kelimede kirmizi sayac, kaydet PATCH atar', (tester) async {
      final (b, _) = await open(tester, post(mine: true));
      await tester.tap(find.byKey(const ValueKey('post-menu-button')));
      await settle(tester, const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const ValueKey('post-act-edit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Gönderiyi düzenle'), findsOneWidget);
      expect(find.text('3/7 kelime'), findsOneWidget);
      bool saveEnabled() => tester.widget<BuButton>(find.byKey(const ValueKey('edit-post-save'))).onPressed != null;
      final field = find.byKey(const ValueKey('edit-post-text'));
      await tester.enterText(field, '');
      await tester.pump();
      expect(find.byKey(const ValueKey('edit-post-empty')), findsOneWidget);
      expect(saveEnabled(), isFalse);
      await tester.enterText(field, 'bir iki uc dort bes alti yedi sekiz');
      await tester.pump();
      expect(find.text('8/7 kelime'), findsOneWidget);
      expect(saveEnabled(), isFalse);
      await tester.enterText(field, 'Yeni not');
      await tester.pump();
      expect(saveEnabled(), isTrue);
      await tester.tap(find.byKey(const ValueKey('edit-post-save')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(b.requests.any((r) => r.startsWith('PATCH /posts/1000')), isTrue, reason: b.requests.join('|'));
      noErr(tester);
    });
  });

  group('gonderi olustur ve detay', () {
    testWidgets('kufur 422: "Icerik uyarisi" karti; 429: bekleme satiri; ag: Tekrar Dene; vazgec diyalogu', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      b.on('/posts/media', {'id': 4242, 'kind': 'IMAGE', 'url': '/api/posts/media/4242'});
      b.on('/posts', {'code': 'CONTENT_PROFANITY', 'message': ''}, status: 422);
      final s = makeSession(b);
      await tester.pumpWidget(buildApp(ComposePostPage(
        session: s,
        pickPhoto: (_) async => Uint8List.fromList(kFakePng),
        cropPhoto: (c, bytes, spec) async => CropOutcome.cropped(bytes),
        uploader: _Up(s),
      )));
      await settle(tester, const Duration(milliseconds: 300));
      // Foto yokken metin yazilirsa zorunluluk ipucu.
      await tester.enterText(find.byKey(const ValueKey('composeText')), 'bir not');
      await tester.pump();
      expect(find.byKey(const ValueKey('composePhotoHint')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('composeGallery')));
      // Stitch v3 02: Fotoğraf seç -> iki satırlık kaynak sayfası
      await settle(tester, const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const ValueKey('photoSrcGallery')));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('composeShare')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('İçerik uyarısı'), findsOneWidget);
      expect(find.textContaining('uygunsuz ifade'), findsOneWidget);

      // Vazgec diyalogu
      await tester.tap(find.byKey(const ValueKey('composeClose')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Gönderiden vazgeçilsin mi?'), findsOneWidget);
      expect(find.byKey(const ValueKey('composeKeep')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('composeKeep')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ComposePostPage), findsOneWidget);
      noErr(tester);
    });

    testWidgets('detay: 404 -> "Gonderi bulunamadi" bilgi karti', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(PostDetailPage(session: makeSession(b), postId: 99999)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('postNotFound')), findsOneWidget);
      expect(find.textContaining('Gönderi bulunamadı'), findsWidgets);
      noErr(tester);
    });
  });
}

class _Up extends PostMediaUploader {
  _Up(super.session);

  @override
  Future<PostMedia> upload(Uint8List bytes) async => PostMedia.fromJson(samplePostMedia(id: 4242));
}
