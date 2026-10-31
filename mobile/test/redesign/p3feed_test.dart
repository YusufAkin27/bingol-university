import 'dart:typed_data';

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/discover/discover_masonry.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
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
    testWidgets('bos durum: kart/golge yok, tek birincil dugme, dugmede simge yok', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(buildApp(Scaffold(body: DiscoverEmptyCard(onCompose: () {}))));
      await tester.pump();
      expect(shadowBoxes(tester, find.byKey(const ValueKey('discoverEmpty'))), 0);
      expect(find.byType(BuButton), findsOneWidget);
      expect(find.descendant(of: find.byType(BuButton), matching: find.byType(Icon)), findsNothing);
      noErr(tester);
    });

    testWidgets('hata: tek cumle + Yeniden dene (aciklama metni ve dugme simgesi yok)', (tester) async {
      useScreen(tester, const Size(390, 844));
      var retried = 0;
      await tester.pumpWidget(buildApp(Scaffold(body: DiscoverErrorCard(offline: true, onRetry: () => retried++))));
      await tester.pump();
      expect(find.text('Sunucuya ulaşılamadı'), findsOneWidget);
      expect(find.textContaining('Bağlantınızı kontrol'), findsNothing);
      expect(shadowBoxes(tester, find.byKey(const ValueKey('discoverError'))), 0);
      expect(find.byIcon(LucideIcons.refreshCw), findsNothing);
      await tester.tap(find.byKey(const ValueKey('discoverRetry')));
      expect(retried, 1);
      noErr(tester);
    });

    testWidgets('oneriler: Takip et dugmesi yumusak zemin (birincil kirmizi degil); takipte nötr', (tester) async {
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
      Color fill(int id) {
        final c = tester.widget<AnimatedContainer>(find.descendant(of: find.byKey(ValueKey('discover-follow-$id')), matching: find.byType(AnimatedContainer)));
        return (c.decoration as BoxDecoration).color!;
      }

      expect(fill(31), BuTokens.light.soft);
      expect(fill(31), isNot(BuTokens.light.pr));
      expect(fill(32), BuTokens.light.sf2);
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
      expect(find.text('Gönderi tek bir fotoğraftan oluşur.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('composeGallery')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('composePreview')), findsOneWidget);
      expect(find.text('4:5'), findsNothing);
      expect(find.byKey(const ValueKey('composeSingleHint')), findsNothing);
      expect(find.text('Gönderi tek bir fotoğraftan oluşur.'), findsNothing);
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
