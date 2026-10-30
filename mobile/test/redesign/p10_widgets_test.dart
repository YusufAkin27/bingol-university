import 'package:bu_kampus/features/chat/media_library.dart';
import 'package:bu_kampus/features/chat/media_picker_page.dart';
import 'package:bu_kampus/features/chat/media_preview_page.dart';
import 'package:bu_kampus/features/chat/sohbety_widgets.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart' show loadTestFonts;
import '../support/fake_media.dart';
import 'p00_support.dart';

/// N2 / Paket 10 (Stitch 25): medya secici, izin durumlari, album sayfasi, onizleme, kamera denetimleri,
/// video hazirlama bilesenleri; tr/en/ar x acik/koyu x yazi 1.0/1.3 x 320/390 dp: tasma yok.
Widget _picker(MediaLibrary lib) => MediaPickerPage(library: lib, ensureAccess: (c, p, {rationale}) async => true);

const _albums = [
  GalleryAlbum(id: 'all', name: 'Recent', count: 1428, isAll: true),
  GalleryAlbum(id: 'cam', name: 'Camera', count: 312),
  GalleryAlbum(id: 'shot', name: 'Screenshots', count: 84),
  GalleryAlbum(id: 'dl', name: 'Download', count: 56),
];

Widget _chrome(bool rec, {bool flash = false}) => Builder(
      builder: (c) => SohbetyCameraChrome(
        recording: rec,
        timer: '0:12 / 1:00',
        progress: .2,
        flashOn: flash,
        onClose: () {},
        onFlash: () {},
        onGallery: () {},
        onFlip: () {},
        onPhoto: () {},
        onVideoStart: () {},
        onVideoEnd: () {},
        closeLabel: 'Kapat',
        flashLabel: 'Flaş',
        galleryLabel: 'Galeri',
        flipLabel: 'Kamerayı çevir',
        shutterLabel: rec ? 'Kaydı durdur' : 'Fotoğraf çek',
        hint: 'Dokun: fotoğraf · Basılı tut: video',
      ),
    );

void main() {
  setUpAll(loadTestFonts);

  testWidgets('galeri secici (secili) matris: tasma yok', (tester) async {
    await p00Matrix(
      tester,
      () => _picker(FakeMediaLibrary.photos(8, videos: [FakeMediaLibrary.video('v1')])),
      scaffold: false,
      check: (t, lang, dark, scale) async {
        await t.tap(find.byKey(const ValueKey('galleryTile_v1')));
        await t.tap(find.byKey(const ValueKey('galleryTile_p1')));
        await t.pump(const Duration(milliseconds: 300));
      },
    );
  });

  testWidgets('sinirli erisim ve izin yok matris: tasma yok', (tester) async {
    await p00Matrix(
      tester,
      () => _picker(FakeMediaLibrary([const GalleryItem(id: 'p1', isVideo: false)], access: LibraryAccess.limited)),
      scaffold: false,
    );
    await p00Matrix(tester, () => _picker(FakeMediaLibrary(const [], access: LibraryAccess.denied)), scaffold: false);
  });

  testWidgets('album sayfasi matris: tasma yok', (tester) async {
    await p00Matrix(
      tester,
      () => _picker(FakeMediaLibrary([for (var i = 1; i <= 4; i++) GalleryItem(id: 'p$i', isVideo: false)], albumList: _albums)),
      scaffold: false,
      check: (t, lang, dark, scale) async {
        await t.tap(find.byKey(const ValueKey('albumButton')));
        await t.pump(const Duration(milliseconds: 500));
        expect(find.byKey(const ValueKey('albumRow_all')), findsOneWidget);
        expect(find.byKey(const ValueKey('albumRow_dl')), findsOneWidget);
        await t.tapAt(const Offset(10, 10)); // perdeye dokun: sayfa kapanir
        await t.pump(const Duration(milliseconds: 500));
      },
    );
  });

  testWidgets('onizleme matris: tasma yok', (tester) async {
    await p00Matrix(
      tester,
      () => MediaPreviewPage(picks: [fakePhotoPick('a'), fakeVideoPick('v'), fakePhotoPick('c')]),
      scaffold: false,
      check: (t, lang, dark, scale) async {
        await t.tap(find.byKey(const ValueKey('onceButton_0')));
        await t.pump(const Duration(milliseconds: 300));
      },
    );
  });

  testWidgets('kamera denetimleri (hazir/kayit/flas acik) matris: tasma yok', (tester) async {
    await p00Matrix(tester, () => _chrome(false), scaffold: false);
    await p00Matrix(tester, () => _chrome(false, flash: true), scaffold: false);
    await p00Matrix(tester, () => _chrome(true), scaffold: false);
  });

  testWidgets('video hazirlama penceresi ve bildirim kartlari matris: tasma yok', (tester) async {
    await p00Matrix(
      tester,
      () => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            SohbetyVideoPrepareCard(
              title: 'Video hazırlanıyor… %45',
              subtitle: 'Sıkıştırılıyor ve önbelleğe alınıyor',
              cancelLabel: 'İptal',
              progress: .45,
              onCancel: () {},
            ),
            const SizedBox(height: 12),
            SohbetyNoticeCard(message: 'Video en fazla 60 saniye olabilir', kind: SohbetyNoticeKind.warning, onClose: () {}),
            const SizedBox(height: 8),
            SohbetyNoticeCard(message: 'Video çok büyük, daha kısa bir video seçin', kind: SohbetyNoticeKind.error, onClose: () {}),
            const SizedBox(height: 8),
            SohbetyNoticeCard(
                message: 'Videolar büyük olduğu için birden fazla mesaj olarak gönderilecek',
                kind: SohbetyNoticeKind.info,
                onClose: () {}),
          ]),
        ),
      ),
    );
  });

  testWidgets('sohbet ortak bilesenleri matris: tasma yok', (tester) async {
    await p00Matrix(
      tester,
      () => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SohbetyLabel('MEDYA · 24'),
            const SohbetyCard(children: [
              SohbetyRow(
                child: Row(children: [
                  SohbetyTile(icon: LucideIcons.image),
                  SizedBox(width: 12),
                  Expanded(child: SohbetyTexts(title: 'Ali Veli', sub: 'Bilgisayar Mühendisliği')),
                  SohbetyCheck(on: true),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            SohbetyTabs(labels: const ['Medya', 'Belge', 'Bağlantı'], selected: 1, onSelect: (_) {}),
            const SizedBox(height: 12),
            const SohbetyField(hint: 'Ara'),
            const SizedBox(height: 12),
            SohbetyButton(label: 'Gönder', onPressed: () {}),
          ]),
        ),
      ),
    );
  });

  testWidgets('dokunma hedefleri ve etiketler: galeri secici (secili)', (tester) async {
    final lib = FakeMediaLibrary.photos(3);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(p00App(_picker(lib), scaffold: false));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('galleryTile_p1')));
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
