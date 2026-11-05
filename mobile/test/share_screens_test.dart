import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:bu_kampus/features/news/news_detail_page.dart';
import 'package:bu_kampus/features/posts/post_actions.dart';
import 'package:bu_kampus/features/posts/post_card.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:bu_kampus/features/reels/reels_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'kesfet_ks_test.dart' show FakeVideoPlatformKs, videoPost;
import 'support/fake_app.dart';

/// SH-MB: her içerik ekranında Paylaş düğmesi görünür ve paylaşım alt sayfasını açar.

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(30).join('\n')}');
}

FakeBackend withChats(FakeBackend b) => b
  ..on('/conversations?size=50', {
    'items': [
      {'id': 1, 'type': 'DIRECT', 'peer': {'id': 11, 'displayName': 'Ali Veli'}},
    ],
    'nextCursor': null,
  })
  ..on('/users/12', {'id': 12, 'displayName': 'Ayşe Yılmaz', 'isPrivate': false});

void main() {
  setUpAll(loadTestFonts);

  testWidgets('gönderi kartı (liste): Paylaş düğmesi sayfa açar; başlık metin, kaynak yazar', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = withChats(FakeBackend());
    final p = Post.fromJson(samplePost(id: 91, text: 'Güz manzarası', media: [samplePostMedia(id: 5)]));
    await tester.pumpWidget(buildApp(Scaffold(
      body: ListView(children: [PostCard(session: makeSession(b), post: p, onChanged: (_) {}, onDeleted: (_) {})]),
    )));
    await settle(tester, const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('post-share-91')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('post-share-91')));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.byKey(const ValueKey('share-preview')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('share-preview')), matching: find.text('Güz manzarası')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('share-preview')), matching: find.text('Ayşe Yılmaz')), findsOneWidget);
    expect(b.count('GET /users/12'), 1, reason: 'başkasının gönderisi: gizli hesap doğrulaması');
    noErr(tester);
    await unmount(tester);
  });

  testWidgets('gönderi kartı (detay): Paylaş düğmesi var, metinli ve metinsiz', (tester) async {
    useScreen(tester, kPhoneSmall);
    final b = withChats(FakeBackend());
    for (final text in ['Detay metni', '']) {
      final p = Post.fromJson(samplePost(id: 92, text: text, media: [samplePostMedia(id: 6)]));
      await tester.pumpWidget(buildApp(
        Scaffold(body: ListView(children: [PostCard(session: makeSession(b), post: p, detail: true, onChanged: (_) {}, onDeleted: (_) {})])),
        size: kPhoneSmall,
      ));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('post-share-92')), findsOneWidget, reason: 'metin="$text"');
      noErr(tester);
      await unmount(tester);
    }
  });

  testWidgets('kendi gönderim: yazar doğrulaması yok, bağlantı eylemleri açık', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = withChats(FakeBackend());
    final p = Post.fromJson(samplePost(id: 93, text: 'Benim', media: [samplePostMedia(id: 7)], mine: true, authorId: 1));
    await tester.pumpWidget(buildApp(Scaffold(
      body: ListView(children: [PostCard(session: makeSession(b), post: p, onChanged: (_) {}, onDeleted: (_) {})]),
    )));
    await settle(tester, const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('post-share-93')));
    await settle(tester, const Duration(milliseconds: 700));
    expect(b.count('GET /users/1'), 0);
    expect(find.byKey(const ValueKey('share-copy')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('gönderi ⋯ menüsünde (Keşfet kutusu için) Paylaş satırı', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = withChats(FakeBackend());
    final s = makeSession(b);
    final p = Post.fromJson(samplePost(id: 94, text: 'Menü', media: [samplePostMedia(id: 8)]));
    await tester.pumpWidget(buildApp(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
            key: const ValueKey('menu'), onPressed: () => showPostActions(context, session: s, post: p, share: true), child: const Text('menü')),
      ),
    )));
    await tester.tap(find.byKey(const ValueKey('menu')));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('Paylaş'), findsOneWidget);
    await tester.tap(find.text('Paylaş'));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.byKey(const ValueKey('share-preview')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('haber detayı: Paylaş alt sayfayı açar (artık yalnız panoya kopyalamaz); duyuru etiketi', (tester) async {
    for (final type in ['HABER', 'DUYURU']) {
      useScreen(tester, kPhoneMedium);
      final b = withChats(FakeBackend())
        ..on('/news/3', {'id': 3, 'title': 'Sunucu başlığı', 'content': 'Gövde', 'url': 'https://www.bingol.edu.tr/h/3'});
      await tester.pumpWidget(buildApp(NewsDetailPage(
          session: makeSession(b), item: {'id': 3, 'type': type, 'title': 'Üniversite $type', 'url': 'https://www.bingol.edu.tr/h/3'}, saved: false)));
      await settle(tester, const Duration(milliseconds: 700));
      await tester.tap(find.byKey(const ValueKey('news-share')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('share-preview')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('share-preview')), matching: find.text(type == 'DUYURU' ? 'DUYURU' : 'HABER')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('share-preview')), matching: find.text('bingol.edu.tr')), findsOneWidget);
      expect(b.count('GET /users/'), 0, reason: 'haberde yazar doğrulaması yok');
      noErr(tester);
      await unmount(tester);
    }
  });

  testWidgets('haber push ile yalnız kimlikle açılınca başlık sunucudan gelir ve paylaşımda kullanılır', (tester) async {
    useScreen(tester, kPhoneMedium);
    final b = withChats(FakeBackend())
      ..on('/news/4', {'id': 4, 'title': 'Sunucudan başlık', 'content': 'Gövde', 'url': 'https://www.bingol.edu.tr/h/4'});
    await tester.pumpWidget(buildApp(NewsDetailPage(session: makeSession(b), item: const {'id': 4}, saved: false)));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.text('Sunucudan başlık'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('news-share')));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.descendant(of: find.byKey(const ValueKey('share-preview')), matching: find.text('Sunucudan başlık')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('etkinlik detayı: Paylaş düğmesi; iptal edilmiş etkinlikte yok', (tester) async {
    useScreen(tester, kPhoneMedium);
    Map<String, dynamic> ev({String status = 'ACTIVE'}) {
      final s = DateTime.now().add(const Duration(days: 2));
      return {
        'id': 5,
        'title': 'Kariyer Günleri',
        'description': 'Açıklama',
        'startsAt': s.toUtc().toIso8601String(),
        'endsAt': s.add(const Duration(hours: 2)).toUtc().toIso8601String(),
        'location': 'Konferans Salonu',
        'communityId': 7,
        'communityName': 'Müzik Kulübü',
        'goingCount': 3,
        'capacity': 50,
        'myRsvp': null,
        'status': status,
        'joinPolicy': 'OPEN',
        'canManage': false,
        'createdBy': 2,
      };
    }

    FakeBackend be(Map<String, dynamic> e) => withChats(FakeBackend())
      ..on('/events/5', e)
      ..on('/events/5/my-attendance', {'present': false, 'checkInOpen': false})
      ..on('/events/5/admission', {'eventId': 5, 'mode': 'OPEN', 'questions': <Object>[]});

    final b = be(ev());
    await tester.pumpWidget(buildApp(EventDetailPage(session: makeSession(b), eventId: 5), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 900));
    expect(find.byKey(const ValueKey('event-share')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('event-share')));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.descendant(of: find.byKey(const ValueKey('share-preview')), matching: find.text('Kariyer Günleri')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('share-preview')), matching: find.text('Müzik Kulübü')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('share-preview')), matching: find.text('ETKİNLİK')), findsOneWidget);
    await unmount(tester);

    await tester.pumpWidget(buildApp(EventDetailPage(session: makeSession(be(ev(status: 'CANCELLED'))), eventId: 5), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 900));
    expect(find.byKey(const ValueKey('event-share')), findsNothing);
    noErr(tester);
    await unmount(tester);
  });

  testWidgets('Reels eylem çubuğu: Paylaş düğmesi, video Reels olarak paylaşılır', (tester) async {
    useScreen(tester, kPhoneMedium);
    final p = FakeVideoPlatformKs();
    final prev = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = p;
    addTearDown(() => VideoPlayerPlatform.instance = prev);
    final b = withChats(FakeBackend())
      ..on('/feed/reels*', {'items': [videoPost(id: 7)], 'nextCursor': null})
      ..on('/conversations/1/messages', {'id': 5});
    await tester.pumpWidget(buildApp(Scaffold(body: ReelsFeed(session: makeSession(b), active: true))));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.byKey(const ValueKey('reel-share-7')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reel-share-7')));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.byKey(const ValueKey('share-preview')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('share-pick-c1')));
    await settle(tester, const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('share-send')));
    await settle(tester, const Duration(milliseconds: 700));
    expect((b.bodies['POST /conversations/1/messages'] as Map)['share'], {'type': 'REEL', 'id': 7});
    noErr(tester);
    await unmount(tester);
  });
}
