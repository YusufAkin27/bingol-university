import 'dart:typed_data';

import 'package:bu_kampus/features/discover/discover_masonry.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/media_crop/crop_engine.dart';
import 'package:bu_kampus/features/posts/user_posts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../support/fake_app.dart';

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split(String.fromCharCode(10)).take(30).join(String.fromCharCode(10))}');
}

Widget discover(FakeBackend b) => DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null));

/// UI-K4: Kesfet durumlari (referans 12), Kesfet kart menusu (referans 11), kullanici gonderileri izgarasi, kirpma motoru.
void main() {
  setUpAll(loadTestFonts);

  group('kesfet durumlari', () {
    testWidgets('bos: kamera karti + "Gonderi olustur" (kendi olusturucuyu acar), sahte icerik yok', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b, empty: true);
      b.on('/users/me/follow-suggestions*', {'items': <Object>[]});
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('discoverEmpty')), findsOneWidget);
      expect(find.text('Henüz gönderi yok. İlk gönderiyi sen paylaş!'), findsOneWidget);
      expect(find.byKey(const ValueKey('discoverEmptyCompose')), findsOneWidget);
      expect(find.byType(DiscoverPostCard), findsNothing);
      await tester.tap(find.byKey(const ValueKey('discoverEmptyCompose')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Yeni gönderi'), findsOneWidget);
      noErr(tester);
    });

    testWidgets('hata: Sunucuya ulasilamadi karti + Yeniden dene; ag hatasinda cevrimdisi seridi, 500\'de serit yok', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend()..network('/feed');
      b.on('/users/me/follow-suggestions*', {'items': <Object>[]});
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Keşfet'), findsOneWidget); // baslik hata durumunda da var
      expect(find.byKey(const ValueKey('discoverOfflineStrip')), findsOneWidget);
      expect(find.text('Sunucuya ulaşılamadı'), findsOneWidget);
      expect(find.byKey(const ValueKey('discoverRetry')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      final b2 = FakeBackend();
      b2.fail('/feed', status: 500);
      b2.on('/users/me/follow-suggestions*', {'items': <Object>[]});
      await tester.pumpWidget(buildApp(discover(b2)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('discoverOfflineStrip')), findsNothing);
      expect(find.byKey(const ValueKey('discoverError')), findsOneWidget);
      noErr(tester);
    });

    testWidgets('yukleniyor: iki sutun beyaz iskelet kartlari', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend()..delay = const Duration(milliseconds: 300);
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await tester.pump(const Duration(milliseconds: 50));
      final sk = tester.getTopLeft(find.descendant(of: find.byKey(const ValueKey('discoverSkeleton')), matching: find.byType(DecoratedBox)).first);
      expect(sk.dx, 16);
      expect(find.byType(DiscoverFeedSkeleton), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 800));
      noErr(tester);
    });
  });

  group('kesfet kart menusu (referans 11)', () {
    testWidgets('uzun basma ve ⋯: baskasinin gonderisinde Profili gor / Sikayet et / Engelle; kendininkinde Duzenle / Sil', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final fp = fakePosts(b, count: 4);
      for (final p in fp.posts) {
        p['media'] = [samplePostMedia(id: (p['id'] as int) * 10)];
      }
      fp.posts[0]['mine'] = true;
      fp.posts[0]['canEdit'] = true;
      fp.posts[0]['canDelete'] = true;
      fp.posts[0]['author'] = {'id': 1, 'displayName': 'Elif Yıldız', 'avatarUrl': null, 'department': null};
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      // Ilk kart benim: ⋯ ile Duzenle/Sil.
      final first = find.byKey(const ValueKey('discover-post-1000'));
      await tester.tap(find.descendant(of: first, matching: find.byKey(const ValueKey('post-menu-button'))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('post-act-edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('post-act-delete')), findsOneWidget);
      // Menü dışında (sol kenar) bir noktaya dokunarak kapat; merkez noktası menü kartına denk gelebilir.
      await tester.tapAt(const Offset(20, 300));
      await tester.pump(const Duration(milliseconds: 300));
      // Ikinci kart baskasinin: uzun basma.
      final second = find.byKey(const ValueKey('discover-post-999'));
      await tester.ensureVisible(second);
      await tester.pump();
      await tester.longPress(find.descendant(of: second, matching: find.byKey(const ValueKey('post-photo-999'))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('post-act-profile')), findsOneWidget);
      expect(find.byKey(const ValueKey('post-act-report')), findsOneWidget);
      expect(find.byKey(const ValueKey('post-act-block')), findsOneWidget);
      noErr(tester);
    });
  });

  group('kullanici gonderileri (referans 11/6)', () {
    testWidgets('3 sutun izgara + kalp sayaci; kare 4:5', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      final fp = fakePosts(b, count: 6);
      for (final p in fp.posts) {
        p['media'] = [samplePostMedia(id: (p['id'] as int) * 10)];
        p['likeCount'] = 129;
      }
      await tester.pumpWidget(buildApp(UserPostsPage(session: makeSession(b), userId: 12, name: 'Ayşe')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Gönderiler'), findsOneWidget);
      final tile = find.byKey(const ValueKey('upost-1000'));
      final s = tester.getSize(tile);
      expect((s.width / s.height - .8).abs(), lessThan(.02));
      final lefts = {for (final i in [1000, 999, 998]) tester.getTopLeft(find.byKey(ValueKey('upost-$i'))).dx.round()};
      expect(lefts.length, 3);
      expect(find.text('129'), findsWidgets);
      noErr(tester);
    });

    testWidgets('bos: kamera karti (+ Gonderi olustur yalniz kendiminkinde); hata: Yuklenemedi satiri + yenile; iskelet', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b, empty: true);
      await tester.pumpWidget(buildApp(UserPostsPage(session: makeSession(b))));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('userPostsEmpty')), findsOneWidget);
      expect(find.byKey(const ValueKey('userPostsCompose')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      final b1 = FakeBackend();
      fakePosts(b1, empty: true);
      await tester.pumpWidget(buildApp(UserPostsPage(session: makeSession(b1), userId: 12, name: 'Ayşe')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('userPostsEmpty')), findsOneWidget);
      expect(find.byKey(const ValueKey('userPostsCompose')), findsNothing);
      await tester.pumpWidget(const SizedBox());

      final b2 = FakeBackend()..delay = const Duration(milliseconds: 300);
      fakePosts(b2);
      await tester.pumpWidget(buildApp(UserPostsPage(session: makeSession(b2), userId: 12)));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byKey(const ValueKey('userPostsSkeleton')), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 800));
      await tester.pumpWidget(const SizedBox());

      final b3 = FakeBackend();
      fakePosts(b3);
      var down = true;
      b3.handlers.insert(0, (req, path) => down && path == '/users/12/posts' ? const FakeResult.json({'code': 'SERVER_ERROR', 'message': ''}, status: 500) : null);
      await tester.pumpWidget(buildApp(UserPostsPage(session: makeSession(b3), userId: 12)));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Yüklenemedi, tekrar dene'), findsOneWidget);
      down = false;
      await tester.tap(find.byKey(const ValueKey('userPostsRetry')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('userPostsError')), findsNothing);
      noErr(tester);
    });
  });

  group('kirpma motoru: EXIF ve saydamlik', () {
    test('EXIF yonu 6 (90 derece) bir kez uygulanir: 40x20 -> 20x40', () {
      final im = img.Image(width: 40, height: 20);
      for (var y = 0; y < 20; y++) {
        for (var x = 0; x < 40; x++) {
          im.setPixelRgb(x, y, x < 20 ? 255 : 0, 0, x < 20 ? 0 : 255);
        }
      }
      im.exif.imageIfd.orientation = 6;
      final jpg = Uint8List.fromList(img.encodeJpg(im, quality: 95));
      final out = cropJpegSync(jpg, quarterTurns: 0, rect: const CropRect(0, 0, 20, 40), maxEdge: 100)!;
      final d = img.decodeJpg(out)!;
      expect((d.width, d.height), (20, 40));
      // Yon 6: sol (kirmizi) yari yeniden ust yari olur.
      expect(d.getPixel(10, 5).r, greaterThan(180));
      expect(d.getPixel(10, 35).b, greaterThan(180));
    });

    test('saydam PNG alani JPEG\'de siyah degil beyaz', () {
      final im = img.Image(width: 20, height: 20, numChannels: 4); // tamamen saydam
      final png = Uint8List.fromList(img.encodePng(im));
      final out = cropJpegSync(png, quarterTurns: 0, rect: const CropRect(0, 0, 20, 20), maxEdge: 100)!;
      final p = img.decodeJpg(out)!.getPixel(10, 10);
      expect(p.r, greaterThan(240));
      expect(p.g, greaterThan(240));
      expect(p.b, greaterThan(240));
    });
  });
}
