import 'dart:typed_data';

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/discover/discover_masonry.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/core/platform/image_service.dart' show ImageSource;
import 'package:bu_kampus/features/media_crop/media_crop.dart';
import 'package:bu_kampus/features/posts/compose_post_page.dart';
import 'package:bu_kampus/features/posts/post_card.dart';
import 'package:bu_kampus/features/posts/post_detail_page.dart';
import 'package:bu_kampus/features/posts/post_media_uploader.dart';
import 'package:bu_kampus/features/posts/post_models.dart' show PostMedia;
import 'package:bu_kampus/features/posts/user_posts_page.dart';
import 'package:bu_kampus/widgets/bu.dart' show BuButton, LucideIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

// P3-FEED: Keşfet + gönderi minimal tasarım testleri (kaldırılanlar, tek vurgu, 320 dp x1.3 taşma).

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split(String.fromCharCode(10)).take(30).join(String.fromCharCode(10))}');
}

class _Up extends PostMediaUploader {
  _Up(super.session);

  @override
  Future<PostMedia> upload(Uint8List bytes) async => PostMedia.fromJson(samplePostMedia(id: 4242));
}

/// Alt ağaçtaki gölgeli DecoratedBox sayısı (kart yüzeyi ölçütü).
int shadowBoxes(WidgetTester tester, Finder scope) => find
    .descendant(of: scope, matching: find.byType(DecoratedBox))
    .evaluate()
    .where((e) => ((e.widget as DecoratedBox).decoration is BoxDecoration) && ((e.widget as DecoratedBox).decoration as BoxDecoration).boxShadow != null)
    .length;

void main() {
  setUpAll(loadTestFonts);

  group('PostMetaLine', () {
    testWidgets('tek satir; uzun bolum + duzenlendi dar genislikte tasmaz, duzenlendi satir ici metin', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(buildApp(const Scaffold(
        body: Center(
          child: SizedBox(
            width: 150,
            child: PostMetaLine(department: 'Bilgisayar ve Öğretim Teknolojileri Eğitimi', time: '2 sa önce', edited: true),
          ),
        ),
      )));
      await tester.pump();
      noErr(tester);
      final h = tester.getSize(find.byType(PostMetaLine)).height;
      expect(h, lessThan(30), reason: 'tek satir (1.3x yazida bile)');
      expect(find.byKey(const ValueKey('post-edited')), findsOneWidget);
    });

    testWidgets('duzenlenmemis: rozet yok; bos bolum ve zaman: hicbir sey cizilmez', (tester) async {
      await tester.pumpWidget(buildApp(const Scaffold(body: Column(children: [
        PostMetaLine(department: '', time: '3 g önce'),
        PostMetaLine(department: '', time: ''),
      ]))));
      expect(find.byKey(const ValueKey('post-edited')), findsNothing);
      expect(find.text('3 g önce'), findsOneWidget);
      expect(tester.getSize(find.byType(PostMetaLine).last).height, 0);
    });
  });

  group('Kesfet sade durumlar', () {
    testWidgets('bos durum: kart/golge/illustrasyon yok, iki cumle, tek birincil dugme (48 dp)', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(buildApp(Scaffold(body: DiscoverEmptyCard(onCompose: () {}))));
      await tester.pump();
      expect(shadowBoxes(tester, find.byKey(const ValueKey('discoverEmpty'))), 0);
      expect(find.byType(BuButton), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('discoverEmpty')), matching: find.byType(Icon)), findsNothing);
      expect(tester.getSize(find.byType(BuButton)).height, 48);
      noErr(tester);
    });

    testWidgets('hata: baslik + soluk aciklama + metin dugmesi Yeniden dene (illustrasyon yok, 48 dp hedef)', (tester) async {
      useScreen(tester, const Size(390, 844));
      var retried = 0;
      await tester.pumpWidget(buildApp(Scaffold(body: DiscoverErrorCard(offline: true, onRetry: () => retried++))));
      await tester.pump();
      expect(find.text('Yüklenemedi'), findsOneWidget);
      expect(find.text('Bağlantını kontrol edip tekrar dene.'), findsOneWidget);
      expect(shadowBoxes(tester, find.byKey(const ValueKey('discoverError'))), 0);
      expect(find.byIcon(LucideIcons.refreshCw), findsNothing);
      expect(find.descendant(of: find.byKey(const ValueKey('discoverError')), matching: find.byType(Icon)), findsNothing);
      expect(tester.getSize(find.byKey(const ValueKey('discoverRetry'))).height, greaterThanOrEqualTo(48));
      await tester.tap(find.byKey(const ValueKey('discoverRetry')));
      expect(retried, 1);
      noErr(tester);
    });

    testWidgets('cevrimdisi notu: ag yokken yenileme basarisiz olursa warnSoft not (ikonsuz) + eski gonderiler; ag donunce kalkar', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      b.on('/users/me/follow-suggestions*', {'items': <Object>[]});
      await tester.pumpWidget(buildApp(DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null))));
      await settle(tester, const Duration(milliseconds: 1000));
      expect(find.byKey(const ValueKey('discoverOffline')), findsNothing);
      b.offline = true;
      await tester.fling(find.byType(CustomScrollView).last, const Offset(0, 500), 2000);
      await settle(tester, const Duration(milliseconds: 1500));
      expect(find.byKey(const ValueKey('discoverOffline')), findsOneWidget);
      expect(find.text('Çevrimdışısın. Gösterilen gönderiler eski olabilir.'), findsOneWidget);
      expect(find.byType(DiscoverPostCard), findsWidgets);
      final box = tester.widget<DecoratedBox>(find.descendant(of: find.byKey(const ValueKey('discoverOffline')), matching: find.byType(DecoratedBox)).first);
      expect((box.decoration as BoxDecoration).color, BuTokens.light.warnSoft);
      expect(find.descendant(of: find.byKey(const ValueKey('discoverOffline')), matching: find.byType(Icon)), findsNothing);
      b.offline = false;
      await tester.fling(find.byType(CustomScrollView).last, const Offset(0, 500), 2000);
      await settle(tester, const Duration(milliseconds: 1500));
      expect(find.byKey(const ValueKey('discoverOffline')), findsNothing);
      noErr(tester);
    });

    testWidgets('oneriler: Takip et ince cerceveli hap (dolgu yok, bdStrong); takipte bd cerceve + soluk', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      b.on('/users/me/follow-suggestions*', {
        'items': [
          {'id': 31, 'displayName': 'Deniz Aksoy', 'department': 'Bilgisayar Müh.', 'followedByMe': false},
          {'id': 32, 'displayName': 'Ece Yılmaz', 'department': 'İktisat', 'followedByMe': true},
        ],
      });
      await tester.pumpWidget(buildApp(DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null))));
      await settle(tester, const Duration(milliseconds: 1200));
      // Öneri şeridi akışın 3. gönderisinden sonra; oraya kaydır.
      await tester.dragUntilVisible(find.byKey(const ValueKey('discover-follow-31')), find.byType(CustomScrollView).last, const Offset(0, -300));
      await settle(tester, const Duration(milliseconds: 300));
      Border border(int id) {
        final c = tester.widget<AnimatedContainer>(find.descendant(of: find.byKey(ValueKey('discover-follow-$id')), matching: find.byType(AnimatedContainer)));
        final d = c.decoration! as BoxDecoration;
        expect(d.color, isNull, reason: 'dolgu yok (tek birincil: + dugmesi)');
        return d.border! as Border;
      }

      expect(border(31).top.color, BuTokens.light.bdStrong);
      expect(border(32).top.color, BuTokens.light.bd);
      expect(tester.getSize(find.descendant(of: find.byKey(const ValueKey('discover-follow-31')), matching: find.byType(AnimatedContainer))).height, 36);
      noErr(tester);
    });
  });

  group('Kesfet gorsel oncelikli kart (Stitch v3 yon A)', () {
    testWidgets('gorsel karti tam kaplar, 24 dp kose, alt %28 gradyan, ad onMedia 15, hap 44, kart sarmalayici/golge yok, metin tek satir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null))));
      await settle(tester, const Duration(milliseconds: 1200));
      final card = find.byKey(const ValueKey('discover-post-999'));
      expect(card, findsOneWidget);
      // Kenar 20 dp: kart genisligi 350.
      expect(tester.getSize(card).width, 350);
      final ratio = find.descendant(of: card, matching: find.byType(AspectRatio)).first;
      expect(tester.widget<AspectRatio>(ratio).aspectRatio, closeTo(.8, .001));
      expect(tester.getSize(ratio).width, 350);
      final clip = tester.widget<ClipRRect>(find.descendant(of: card, matching: find.byType(ClipRRect)).first);
      expect(clip.borderRadius, BorderRadius.circular(24));
      final grad = find.descendant(of: card, matching: find.byWidgetPredicate((w) => w is FractionallySizedBox && w.heightFactor == .28));
      expect(grad, findsOneWidget);
      // Beyaz kart yuzeyi yok: gorsel disinda sf dolgulu DecoratedBox bulunmaz.
      expect(find.descendant(of: card, matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == BuTokens.light.sf)), findsNothing);
      final heart = find.descendant(of: card, matching: find.byKey(const ValueKey('like-heart')));
      expect(tester.getSize(heart).height, 44);
      final name = tester.widget<Text>(find.descendant(of: card, matching: find.text('Ayşe Yılmaz')).first);
      expect(name.style?.color, BuTokens.light.onMedia);
      expect(name.style?.fontSize, 15);
      noErr(tester);
    });

    testWidgets('gonderi metni gorselin altinda tek satir (ellipsis), 15 sp', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final fp = fakePosts(b);
      fp.posts[1]['text'] = 'Yedi kelimelik bir metin burada yaziyor gercekten';
      await tester.pumpWidget(buildApp(DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null))));
      await settle(tester, const Duration(milliseconds: 1200));
      final t = tester.widget<Text>(find.descendant(of: find.byKey(const ValueKey('discover-post-999')), matching: find.byKey(const ValueKey('post-text'))));
      expect(t.maxLines, 1);
      expect(t.style?.fontSize, 15);
      expect(t.overflow, TextOverflow.ellipsis);
      noErr(tester);
    });
  });

  group('Gonderi olustur sade', () {
    testWidgets('onizlemede 4:5 rozeti ve alt yardim satiri yok; bos secicide ikincil ipucu', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      final s = makeSession(b);
      await tester.pumpWidget(buildApp(ComposePostPage(
        session: s,
        uploader: _Up(s),
        cropPhoto: (c, bytes, spec) async => CropOutcome.cropped(bytes),
        pickPhoto: (_) async => Uint8List.fromList(kFakePng),
      )));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('composePicker')), findsOneWidget);
      // Stitch v3 01: tek birincil + metin dugmesi Kamera; baska oge yok.
      expect(find.byType(BuButton), findsOneWidget);
      expect(find.byKey(const ValueKey('composeCamera')), findsOneWidget);
      expect(find.byIcon(LucideIcons.camera), findsNothing);
      await tester.tap(find.byKey(const ValueKey('composeGallery')));
      // Stitch v3 02: Fotoğraf seç -> iki satırlık kaynak sayfası
      await settle(tester, const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const ValueKey('photoSrcGallery')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('composePreview')), findsOneWidget);
      expect(find.text('4:5'), findsNothing);
      expect(find.byKey(const ValueKey('composeSingleHint')), findsNothing);
      // Tek birincil düğme: Paylaş (Material dolgusu) + sayaç sessiz.
      final counter = tester.widget<Text>(find.byKey(const ValueKey('composeCounter')));
      expect(counter.style?.fontWeight ?? FontWeight.w400, isNot(FontWeight.w700), reason: 'sayac sinirdan once sessiz');
      noErr(tester);
    });

    testWidgets('metin var, fotograf yok: tek ipucu cumlesi (baslik + format satiri yok)', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(ComposePostPage(session: makeSession(b))));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.enterText(find.byKey(const ValueKey('composeText')), 'merhaba');
      await tester.pump();
      expect(find.byKey(const ValueKey('composePhotoHint')), findsOneWidget);
      expect(find.text('Görsel seçilmedi'), findsNothing);
      expect(find.textContaining('4:5'), findsNothing);
      noErr(tester);
    });
  });

  group('Gonderi detay / Gonderilerim sade', () {
    testWidgets('bulunamadi: kart/golge yok, tek cumle', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(PostDetailPage(session: makeSession(b), postId: 99999)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('postNotFound')), findsOneWidget);
      expect(shadowBoxes(tester, find.byKey(const ValueKey('postNotFound'))), 0);
      noErr(tester);
    });

    testWidgets('Gonderilerim bos (kendi): kart yok, tek eylem', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b, empty: true);
      await tester.pumpWidget(buildApp(UserPostsPage(session: makeSession(b))));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byKey(const ValueKey('userPostsEmpty')), findsOneWidget);
      expect(shadowBoxes(tester, find.byKey(const ValueKey('userPostsEmpty'))), 0);
      expect(find.descendant(of: find.byKey(const ValueKey('userPostsEmpty')), matching: find.byType(BuButton)), findsOneWidget);
      noErr(tester);
    });
  });

  group('Kaynak sayfasi (Stitch v3 02)', () {
    testWidgets('Fotograf sec: basliksiz iki satir (Galeriden sec / Fotograf cek, 56 dp); Fotograf cek kamera ister', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      final s = makeSession(b);
      final asked = <ImageSource>[];
      await tester.pumpWidget(buildApp(ComposePostPage(
        session: s,
        uploader: _Up(s),
        cropPhoto: (c, bytes, spec) async => CropOutcome.cropped(bytes),
        pickPhoto: (src) async {
          asked.add(src);
          return Uint8List.fromList(kFakePng);
        },
      )));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Fotoğraf seç'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('composeGallery')));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('photoSrcGallery')), findsOneWidget);
      expect(find.byKey(const ValueKey('photoSrcCamera')), findsOneWidget);
      expect(find.byKey(const ValueKey('photoSrcClose')), findsNothing, reason: 'sade sayfada kapat/baslik yok');
      expect(find.text('Galeriden seç'), findsOneWidget);
      expect(find.text('Fotoğraf çek'), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('photoSrcGallery'))).height, greaterThanOrEqualTo(56));
      await tester.tap(find.byKey(const ValueKey('photoSrcCamera')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(asked, [ImageSource.camera]);
      expect(find.byKey(const ValueKey('composePreview')), findsOneWidget);
      noErr(tester);
    });

    testWidgets('kaynak sayfasi kapatilirsa hicbir sey secilmez', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      final s = makeSession(b);
      var asked = 0;
      await tester.pumpWidget(buildApp(ComposePostPage(
        session: s,
        uploader: _Up(s),
        cropPhoto: (c, bytes, spec) async => CropOutcome.cropped(bytes),
        pickPhoto: (src) async {
          asked++;
          return null;
        },
      )));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('composeGallery')));
      await settle(tester, const Duration(milliseconds: 900));
      await tester.tapAt(const Offset(195, 120)); // karartma
      await settle(tester, const Duration(milliseconds: 500));
      expect(asked, 0);
      expect(find.byKey(const ValueKey('composePicker')), findsOneWidget);
      noErr(tester);
    });
  });

  group('Gonderi detayi (Stitch v3 kategori 3)', () {
    Future<FakeBackend> openDetail(WidgetTester tester, {bool mine = false, bool edited = true, double w = 390}) async {
      useScreen(tester, Size(w, 844));
      final b = FakeBackend();
      final post = samplePost(id: 999, text: 'Bahar geldi kampüse', media: [samplePostMedia(id: 9990)], likeCount: 128, mine: mine, authorId: mine ? 1 : 12);
      (post['author'] as Map)['department'] = 'Makine Mühendisliği';
      if (edited) post['editedAt'] = '2026-10-26T10:00:00Z';
      if (mine) {
        post['canEdit'] = true;
        post['canDelete'] = true;
      }
      b.on('/posts/999', post);
      await tester.pumpWidget(buildApp(PostDetailPage(session: makeSession(b), postId: 999)));
      await settle(tester, const Duration(milliseconds: 1000));
      return b;
    }

    testWidgets('yerlesim: 20 dp kenar, 4:5 fotograf kose 16 kart/golge yok, kalp 22 + sayi + metin, duzenlendi 12 mut altta', (tester) async {
      await openDetail(tester);
      final photo = find.byKey(const ValueKey('post-photo-999'));
      final ratio = find.ancestor(of: photo, matching: find.byType(AspectRatio)).first;
      final r = tester.getRect(ratio);
      expect(r.left, 20);
      expect(r.width, 350);
      expect((r.width / r.height - .8).abs(), lessThan(.01));
      final clips = tester.widgetList<ClipRRect>(find.ancestor(of: photo, matching: find.byType(ClipRRect)));
      expect(clips.any((c) => c.borderRadius == BorderRadius.circular(16)), isTrue);
      // Kart yuzeyi / golge yok
      expect(find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).boxShadow != null && (w.decoration as BoxDecoration).boxShadow!.isNotEmpty), findsNothing);
      // Yazar satiri: 40 dp avatar, 'bolum · zaman'
      expect(find.textContaining('Makine Mühendisliği · '), findsOneWidget);
      // Kalp 22 + sayi 15/600 + metin
      final count = tester.widget<Text>(find.byKey(const ValueKey('like-count')));
      expect(count.style?.fontSize, 15);
      expect(count.style?.fontWeight, FontWeight.w600);
      expect(find.text('·'), findsOneWidget);
      expect(find.text('Bahar geldi kampüse'), findsOneWidget);
      final edited = find.byKey(const ValueKey('post-edited'));
      expect(edited, findsOneWidget);
      expect(tester.widget<Text>(edited).style?.fontSize, 12);
      expect(tester.getTopLeft(edited).dy, greaterThan(tester.getBottomLeft(find.text('Bahar geldi kampüse')).dy));
      noErr(tester);
    });

    testWidgets('tam ekran: saf siyah zemin, yalniz sol ustte 24 dp beyaz x (48 dp hedef)', (tester) async {
      await openDetail(tester);
      await tester.tap(find.byKey(const ValueKey('post-photo-999')), warnIfMissed: false);
      await settle(tester, const Duration(milliseconds: 1000));
      final close = find.byKey(const ValueKey('postViewerClose'));
      expect(close, findsOneWidget);
      expect(tester.getSize(close).width, greaterThanOrEqualTo(48));
      expect(tester.getTopLeft(close).dx, lessThan(20)); // sol ust
      final icon = tester.widget<Icon>(find.descendant(of: close, matching: find.byType(Icon)));
      expect(icon.size, 24);
      expect(icon.color, BuTokens.light.onMedia);
      noErr(tester);
    });

    testWidgets('menu: alt sayfa; kendi: Duzenle + Sil (danger), 56 dp, ikinci satir danger rengi', (tester) async {
      await openDetail(tester, mine: true);
      await tester.tap(find.byKey(const ValueKey('post-menu-button')));
      await settle(tester, const Duration(milliseconds: 900));
      expect(tester.getSize(find.byKey(const ValueKey('post-act-edit'))).height, greaterThanOrEqualTo(56));
      final del = tester.widget<Text>(find.descendant(of: find.byKey(const ValueKey('post-act-delete')), matching: find.byType(Text)));
      expect(del.style?.color, BuTokens.light.danger);
      expect(find.byKey(const ValueKey('post-act-report')), findsNothing);
      noErr(tester);
    });

    testWidgets('duzenle diyalogu: alan 16 kose 1 dp bdStrong, sayac alanin altinda sagda 12 mut; Vazgec + Kaydet', (tester) async {
      await openDetail(tester, mine: true);
      await tester.tap(find.byKey(const ValueKey('post-menu-button')));
      await settle(tester, const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const ValueKey('post-act-edit')));
      await settle(tester, const Duration(milliseconds: 600));
      final counter = find.byKey(const ValueKey('edit-post-counter'));
      expect(counter, findsOneWidget);
      expect(tester.widget<Text>(counter).style?.fontSize, 12);
      expect(tester.getTopLeft(counter).dy, greaterThan(tester.getBottomLeft(find.byKey(const ValueKey('edit-post-text'))).dy));
      expect(find.byKey(const ValueKey('post-dialog-cancel')), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('edit-post-save'))).height, greaterThanOrEqualTo(48));
      noErr(tester);
    });

    testWidgets('silme onayi: ikon karosu yok, Vazgec + Sil (danger dolu 48 dp)', (tester) async {
      await openDetail(tester, mine: true);
      await tester.tap(find.byKey(const ValueKey('post-menu-button')));
      await settle(tester, const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const ValueKey('post-act-delete')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Gönderi silinsin mi?'), findsOneWidget);
      expect(find.byIcon(LucideIcons.trash2), findsNothing);
      expect(tester.getSize(find.byKey(const ValueKey('post-dialog-confirm'))).height, greaterThanOrEqualTo(48));
      noErr(tester);
    });

    testWidgets('bulunamadi: baslik 18/600 + soluk ikinci satir, simge/kart yok', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(PostDetailPage(session: makeSession(b), postId: 99999)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Gönderi bulunamadı'), findsOneWidget);
      expect(find.text('silinmiş veya gizlenmiş olabilir'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('postNotFound')), matching: find.byType(Icon)), findsNothing);
      noErr(tester);
    });

    for (final w in [320.0, 390.0]) {
      testWidgets('tasma: detay + menu + duzenle $w x1.3', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await openDetail(tester, mine: true, w: w);
        noErr(tester);
        await tester.tap(find.byKey(const ValueKey('post-menu-button')));
        await settle(tester, const Duration(milliseconds: 900));
        noErr(tester);
        await tester.tap(find.byKey(const ValueKey('post-act-edit')));
        await settle(tester, const Duration(milliseconds: 600));
        noErr(tester);
      });
    }
  });

  group('Tasma matrisi 320 dp x1.3 (acik + koyu)', () {
    for (final dark in [false, true]) {
      final mode = dark ? 'koyu' : 'acik';
      for (final w in [320.0, 390.0]) {
        testWidgets('Kesfet akisi + detay $w $mode', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          useScreen(tester, Size(w, 780));
          final b = FakeBackend();
          fakePosts(b);
          b.on('/users/me/follow-suggestions*', {
            'items': [
              {'id': 31, 'displayName': 'Deniz Aksoy Karaçelik', 'department': 'Bilgisayar Müh.', 'followedByMe': false},
            ],
          });
          final s = makeSession(b);
          await tester.pumpWidget(buildApp(DiscoverTab(session: s, typeRequest: ValueNotifier<String?>(null)), brightness: dark ? Brightness.dark : Brightness.light));
          await settle(tester, const Duration(milliseconds: 1200));
          noErr(tester);
          await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -900));
          await settle(tester, const Duration(milliseconds: 400));
          noErr(tester);
          // Detay (yalnız ayrı sayfa): düzenlenmiş + bölüm adı uzun.
          final d = FakeBackend();
          final post = samplePost(id: 999, text: 'Güzel bir gün', media: [samplePostMedia(id: 9990)], mine: true);
          (post['author'] as Map)['department'] = 'Bilgisayar ve Öğretim Teknolojileri Eğitimi';
          post['editedAt'] = '2026-10-26T10:00:00Z';
          d.on('/posts/999', post);
          await tester.pumpWidget(buildApp(PostDetailPage(session: makeSession(d), postId: 999), brightness: dark ? Brightness.dark : Brightness.light));
          await settle(tester, const Duration(milliseconds: 1000));
          noErr(tester);
          expect(find.byKey(const ValueKey('post-edited')), findsOneWidget);
        });

        testWidgets('Olustur + bos/hata durumlari $w $mode', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          useScreen(tester, Size(w, 780));
          final b = FakeBackend();
          fakePosts(b);
          final br = dark ? Brightness.dark : Brightness.light;
          await tester.pumpWidget(buildApp(ComposePostPage(session: makeSession(b)), brightness: br));
          await settle(tester, const Duration(milliseconds: 300));
          noErr(tester);
          await tester.pumpWidget(buildApp(Scaffold(body: SingleChildScrollView(child: DiscoverEmptyCard(onCompose: () {}))), brightness: br));
          await tester.pump();
          noErr(tester);
          await tester.pumpWidget(buildApp(Scaffold(body: SingleChildScrollView(child: DiscoverErrorCard(offline: false, onRetry: () {}))), brightness: br));
          await tester.pump();
          noErr(tester);
        });
      }
    }
  });
}
