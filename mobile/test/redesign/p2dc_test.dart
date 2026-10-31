import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/bubble_entry.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:bu_kampus/features/discover/discover_masonry.dart' show DiscoverPostCard;
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/posts/compose_post_page.dart';
import 'package:bu_kampus/features/posts/post_detail_page.dart';
import 'package:bu_kampus/features/posts/post_models.dart' show Post;
import 'package:bu_kampus/features/posts/post_photo_viewer.dart';
import 'package:bu_kampus/widgets/bu.dart' show BuPop, BuStaggerItem, LucideIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

// P2-DC: Keşfet / gönderi / sohbet ince detay + animasyon testleri.
// Her animasyon için: başlangıç/bitiş, "animasyonları azalt"ta anında, tekrar oynamama, semantik/dokunma bozulmaması.

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split(String.fromCharCode(10)).take(30).join(String.fromCharCode(10))}');
}

void reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Widget discover(FakeBackend b) => DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null));

/// Kademeli girişin kendi FadeTransition'ı (BuStaggerItem'ın ilk FadeTransition torunu).
Finder staggerFade(int i) => find.descendant(of: find.byType(BuStaggerItem).at(i), matching: find.byType(FadeTransition)).first;

double opacityOf(WidgetTester tester, Finder f) => tester.widget<FadeTransition>(f).opacity.value;

/// Elemanin ilk cocuk widget'i (sarmalayici katmanlarin var/yok kontrolu icin).
Widget firstChild(WidgetTester tester, Finder f) {
  late Widget w;
  tester.element(f).visitChildren((e) => w = e.widget);
  return w;
}

void main() {
  setUpAll(loadTestFonts);

  group('Kesfet kart girisi', () {
    testWidgets('ilk kartlar kademeli belirir; tamamlaninca opak; kaydirinca/yenilemede tekrar oynamaz', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      // Veri geldi ama giris suruyor: ilk karenin saydamligi 1'den kucuk olmali.
      var sawPartial = false;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        if (find.byType(BuStaggerItem).evaluate().isNotEmpty) {
          final o = opacityOf(tester, staggerFade(0));
          if (o > 0 && o < 1) {
            sawPartial = true;
            break;
          }
        }
      }
      expect(sawPartial, isTrue, reason: 'ara kare (0<opacity<1) goruldu');
      await settle(tester, const Duration(seconds: 2));
      expect(opacityOf(tester, staggerFade(0)), 1.0);
      // Asagi kaydir, geri don: ilk kart yeniden saydamlasmaz.
      await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -900));
      await settle(tester, const Duration(milliseconds: 500));
      await tester.drag(find.byType(CustomScrollView).last, const Offset(0, 900));
      await tester.pump();
      // Geri gelen ilk kart yeniden olusturuldu ama giris katmani yok (indeks zaten oynatildi).
      final first = find.byType(BuStaggerItem).first;
      expect(firstChild(tester, first), isNot(isA<FadeTransition>()));
      await settle(tester, const Duration(milliseconds: 300)); // cift dokunus izleyici zamanlayicilari bitsin
      noErr(tester);
    });

    testWidgets('animasyonlari azalt: kartlar anindan opak, saydamlik katmani yok', (tester) async {
      reduceMotion(tester);
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.byType(DiscoverPostCard), findsWidgets);
      // Kademeli giris kapali: BuStaggerItem altinda kendi FadeTransition'i yok (cocuk dogrudan Padding).
      final item = find.byType(BuStaggerItem).first;
      expect(tester.widget<BuStaggerItem>(item).child, isA<Padding>());
      expect(find.descendant(of: item, matching: find.byType(SlideTransition)), findsNothing);
      noErr(tester);
    });
  });

  group('begeni', () {
    Finder countTexts(Finder card) => find.descendant(of: card, matching: find.textContaining('beğeni'));

    testWidgets('sayi gecisi: ara karede eski+yeni sayi birlikte, sonunda tek; kalp renkli dolu kalp olur', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 1500));
      final card = find.byKey(const ValueKey('discover-post-999'));
      final like = find.descendant(of: card, matching: find.byKey(const ValueKey('like-heart')));
      await tester.ensureVisible(like);
      await tester.pump();
      expect(countTexts(card), findsOneWidget);
      await tester.tap(like);
      await tester.pump(const Duration(milliseconds: 60));
      expect(countTexts(card), findsNWidgets(2), reason: 'eski sayi solarken yenisi geliyor');
      await settle(tester, const Duration(milliseconds: 700));
      expect(countTexts(card), findsOneWidget);
      expect(find.descendant(of: card, matching: find.byIcon(Icons.favorite)), findsOneWidget);
      // Dokunma alani en az 44 dp.
      expect(tester.getSize(like).height, greaterThanOrEqualTo(44));
      noErr(tester);
    });

    testWidgets('animasyonlari azalt: sayi anında degisir (hayalet sayi yok)', (tester) async {
      reduceMotion(tester);
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 600));
      final card = find.byKey(const ValueKey('discover-post-999'));
      final like = find.descendant(of: card, matching: find.byKey(const ValueKey('like-heart')));
      await tester.ensureVisible(like);
      await tester.pump();
      await tester.tap(like);
      await tester.pump(const Duration(milliseconds: 20));
      expect(countTexts(card), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 400));
      noErr(tester);
    });

    testWidgets('cift dokunus: buyuk kalp belirir, solar, bir kez beginir (PUT)', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 1500));
      final photo = find.byKey(const ValueKey('post-photo-999'));
      await tester.ensureVisible(photo);
      await tester.pump();
      final at = tester.getCenter(photo);
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byKey(const ValueKey('double-tap-heart')), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.byKey(const ValueKey('double-tap-heart')), findsNothing);
      expect(b.requests.where((r) => r.contains('PUT') && r.contains('/posts/999/like')).length, 1, reason: b.requests.join('|'));
      noErr(tester);
    });
  });

  group('Hero ve gonderi fotografi', () {
    testWidgets('kart -> detay: ayni etiketli iki Hero, ucus sirasinda ikisi de var', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(discover(b)));
      await settle(tester, const Duration(milliseconds: 1500));
      final photo = find.byKey(const ValueKey('post-photo-999'));
      await tester.ensureVisible(photo);
      await tester.pump();
      await tester.tap(photo, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 350)); // cift dokunus bekleme suresi
      await tester.pump(const Duration(milliseconds: 100));
      final heroes = find.byWidgetPredicate((w) => w is Hero && w.tag == 'discover-post-999', skipOffstage: false);
      expect(heroes, findsAtLeastNWidgets(2));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.byType(PostDetailPage), findsOneWidget);
      noErr(tester);
    });

    testWidgets('detay: fotografa dokununca tam ekran gorunturu acilir; kapat dugmesi 48 dp; geri doner', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(PostDetailPage(session: makeSession(b), postId: 999)));
      await settle(tester, const Duration(milliseconds: 1200));
      await tester.tap(find.byKey(const ValueKey('post-photo-999')), warnIfMissed: false);
      await settle(tester, const Duration(milliseconds: 1000));
      expect(find.byType(PostPhotoViewer), findsOneWidget);
      final close = tester.getSize(find.byKey(const ValueKey('postViewerClose')));
      expect(close.width, greaterThanOrEqualTo(48));
      expect(close.height, greaterThanOrEqualTo(48));
      await tester.tap(find.byKey(const ValueKey('postViewerClose')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(PostPhotoViewer), findsNothing);
      expect(find.byType(PostDetailPage), findsOneWidget);
      noErr(tester);
    });

    Future<void> openViewer(WidgetTester tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      final post = Post.fromJson(samplePost(id: 999, media: [samplePostMedia(id: 9990)]));
      await tester.pumpWidget(buildApp(PostPhotoViewer(session: makeSession(b), post: post)));
      await settle(tester, const Duration(milliseconds: 300));
    }

    double zoom(WidgetTester tester) =>
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController!.value.getMaxScaleOnAxis();

    testWidgets('gorunturu: cift dokunus yakinlastirir ve uzaklastirir (ara karede suruyor)', (tester) async {
      await openViewer(tester);
      expect(zoom(tester), 1.0);
      final c = tester.getCenter(find.byType(InteractiveViewer));
      await tester.tapAt(c);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(c);
      await tester.pump(); // ticker ilk karesi
      await tester.pump(const Duration(milliseconds: 120));
      expect(zoom(tester), inExclusiveRange(1.0, 2.5), reason: 'ara kare: yakinlastirma suruyor');
      await settle(tester, const Duration(milliseconds: 500));
      expect(zoom(tester), closeTo(2.5, .01));
      // Yakinlastirilmisken kapat dugmesi dokunulamaz.
      final ig = find.ancestor(of: find.byKey(const ValueKey('postViewerClose')), matching: find.byType(IgnorePointer)).first;
      expect(tester.widget<IgnorePointer>(ig).ignoring, isTrue);
      await tester.tapAt(c);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(c);
      await settle(tester, const Duration(milliseconds: 600));
      expect(zoom(tester), closeTo(1.0, .01));
      noErr(tester);
    });

    testWidgets('gorunturu: kucuk asagi surukleme geri yaylanir, esigi asan surukleme kapatir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      final post = Post.fromJson(samplePost(id: 999, media: [samplePostMedia(id: 9990)]));
      final s = makeSession(b);
      await tester.pumpWidget(buildApp(Builder(
          builder: (c) => Center(child: TextButton(onPressed: () => openPostPhotoViewer(c, s, post), child: const Text('ac'))))));
      await tester.tap(find.text('ac'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(PostPhotoViewer), findsOneWidget);
      double dy() => tester
          .widget<Transform>(find.descendant(of: find.byType(PostPhotoViewer), matching: find.byType(Transform)).first)
          .transform
          .getTranslation()
          .y;
      final g = await tester.startGesture(tester.getCenter(find.byType(InteractiveViewer)));
      await g.moveBy(const Offset(0, 20));
      await g.moveBy(const Offset(0, 30));
      await tester.pump();
      expect(dy(), greaterThan(10), reason: 'surukleme sirasinda gorunum parmagi izler');
      await g.up();
      await settle(tester, const Duration(milliseconds: 500));
      expect(dy().abs(), lessThan(1), reason: 'esik altinda geri yaylandi');
      expect(find.byType(PostPhotoViewer), findsOneWidget);
      await tester.drag(find.byType(InteractiveViewer), const Offset(0, 300));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byType(PostPhotoViewer), findsNothing);
      noErr(tester);
    });

    testWidgets('animasyonlari azalt: gorunturu cift dokunus yakinlastirmasi anında', (tester) async {
      reduceMotion(tester);
      await openViewer(tester);
      final c = tester.getCenter(find.byType(InteractiveViewer));
      await tester.tapAt(c);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(c);
      await tester.pump(const Duration(milliseconds: 20));
      expect(zoom(tester), closeTo(2.5, .01));
      await settle(tester, const Duration(milliseconds: 200));
      noErr(tester);
    });
  });

  group('gonderi olustur', () {
    testWidgets('kelime sayaci: renk gecisi yumusak (AnimatedDefaultTextStyle) ve sinirda koyu; uyari satiri belirir', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend();
      fakePosts(b);
      await tester.pumpWidget(buildApp(ComposePostPage(session: makeSession(b))));
      await settle(tester, const Duration(milliseconds: 300));
      final counter = find.byKey(const ValueKey('composeCounter'));
      final bu = tester.element(counter).bu;
      TextStyle style() => tester.widget<AnimatedDefaultTextStyle>(find.ancestor(of: counter, matching: find.byType(AnimatedDefaultTextStyle)).first).style;
      expect(style().color, bu.mut);
      expect(style().fontFeatures, isNotEmpty, reason: 'tabular rakamlar');
      final field = find.byType(TextField);
      await tester.enterText(field, 'bir iki uc dort bes alti yedi');
      await tester.pump(const Duration(milliseconds: 60));
      final mid = tester.widget<AnimatedDefaultTextStyle>(find.ancestor(of: counter, matching: find.byType(AnimatedDefaultTextStyle)).first);
      expect(mid.duration, const Duration(milliseconds: 150));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('7/7 kelime'), findsOneWidget);
      // 8 kelime: uyari satiri AnimatedSize icinde belirir.
      expect(find.byKey(const ValueKey('composeLimitWarn')), findsNothing);
      await tester.enterText(field, 'bir iki uc dort bes alti yedi sekiz');
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byKey(const ValueKey('composeLimitWarn')), findsOneWidget);
      expect(find.ancestor(of: find.byKey(const ValueKey('composeLimitWarn')), matching: find.byType(AnimatedSize)), findsOneWidget);
      await settle(tester, const Duration(milliseconds: 400));
      expect(style().color, bu.danger);
      noErr(tester);
    });
  });

  group('sohbet balonu girisi', () {
    Widget bubble(Map<String, dynamic> m, {bool mine = true, bool seen = false}) => buildApp(Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: MessageBubble(
              message: m,
              mine: mine,
              senderName: null,
              replyName: null,
              seen: seen,
              authHeaders: const {},
              onMenu: () {},
              onRetry: () {},
              onOpenImage: (_) {},
              onReact: (_) {},
            ),
          ),
        ));

    Map<String, dynamic> msg(int id, String text, {Duration age = Duration.zero, String? status = 'SENT'}) => {
          'id': id,
          'conversationId': 1,
          'senderId': 1,
          'text': text,
          'status': status,
          'createdAt': DateTime.now().subtract(age).toUtc().toIso8601String(),
        };

    testWidgets('taze gonderilen balon alttan yukselerek belirir; sonunda opak ve konumunda', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(bubble(msg(5, 'Merhaba dunya')));
      final fade = find.descendant(of: find.byType(BubbleEntry), matching: find.byType(FadeTransition)).first;
      expect(opacityOf(tester, fade), lessThan(.2));
      final y0 = tester.getTopLeft(find.text('Merhaba dunya')).dy;
      await tester.pump(const Duration(milliseconds: 90));
      final mid = opacityOf(tester, fade);
      expect(mid, inExclusiveRange(0.0, 1.0));
      expect(tester.getTopLeft(find.text('Merhaba dunya')).dy, greaterThan(y0 - 14));
      await tester.pump(const Duration(milliseconds: 400));
      expect(opacityOf(tester, fade), 1.0);
      expect(tester.getTopLeft(find.text('Merhaba dunya')).dy, lessThan(y0));
      noErr(tester);
    });

    testWidgets('alinan taze balon yalniz solar (kayma yok)', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(bubble(msg(6, 'Selam', status: null), mine: false));
      final entry = find.byType(BubbleEntry);
      expect(find.descendant(of: entry, matching: find.byType(FadeTransition)), findsWidgets);
      final y0 = tester.getTopLeft(find.text('Selam')).dy;
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.getTopLeft(find.text('Selam')).dy, y0);
      await tester.pump(const Duration(milliseconds: 300));
      noErr(tester);
    });

    testWidgets('gecmis mesaj (eski) animasyonsuz: katman ve controller yok', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(bubble(msg(7, 'Eski mesaj', age: const Duration(hours: 5))));
      final entry = find.byType(BubbleEntry);
      expect(entry, findsOneWidget);
      expect(firstChild(tester, entry), isNot(isA<FadeTransition>()), reason: 'eski mesajda giris katmani yok');
      noErr(tester);
    });

    testWidgets('animasyonlari azalt: taze balon da animasyonsuz', (tester) async {
      reduceMotion(tester);
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(bubble(msg(8, 'Hizli')));
      expect(firstChild(tester, find.byType(BubbleEntry)), isNot(isA<FadeTransition>()));
      noErr(tester);
    });

    testWidgets('durum ikonu: tek tik -> cift tik gecisinde ara karede ikisi birlikte, sonunda yalniz cift tik', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(bubble(msg(9, 'Durum', age: const Duration(hours: 1), status: 'SENT')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      await tester.pumpWidget(bubble(msg(9, 'Durum', age: const Duration(hours: 1), status: 'DELIVERED')));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(find.byIcon(LucideIcons.checkCheck), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(LucideIcons.check), findsNothing);
      expect(find.byIcon(LucideIcons.checkCheck), findsOneWidget);
      noErr(tester);
    });
  });

  group('sohbet listesi', () {
    Map<String, dynamic> row(int id, String title, {int unread = 0}) => {
          'id': id,
          'type': 'DIRECT',
          'title': title,
          'peer': {'id': 10 + id, 'displayName': title},
          'unreadCount': unread,
          'lastMessage': {
            'id': 100 + id,
            'conversationId': id,
            'senderId': 10 + id,
            'text': 'Selam $id',
            'attachments': const [],
            'createdAt': DateTime.now().toUtc().toIso8601String(),
          },
        };

    FakeBackend be() => FakeBackend()
      ..on('/conversations/unread-count', {'total': 2})
      ..on('/conversations*', {
        'items': [row(1, 'Mehmet Kaya', unread: 2), row(2, 'Zeynep Demir'), row(3, 'Ahmet Yildiz')],
        'nextCursor': null,
      });

    testWidgets('satirlar kademeli girer, basinca kuculur (BuPressable), okunmamis rozet BuPop icinde', (tester) async {
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(buildApp(ChatTab(session: makeSession(be()), connectRealtime: false)));
      var partial = false;
      for (var i = 0; i < 20 && !partial; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        if (find.byType(BuStaggerItem).evaluate().isNotEmpty) {
          final o = opacityOf(tester, staggerFade(0));
          partial = o > 0 && o < 1;
        }
      }
      expect(partial, isTrue);
      await settle(tester, const Duration(seconds: 1));
      expect(opacityOf(tester, staggerFade(0)), 1.0);
      expect(find.text('Mehmet Kaya'), findsOneWidget);
      expect(find.ancestor(of: find.text('2'), matching: find.byType(BuPop)), findsOneWidget);
      // Basili tutunca satir hafifce kuculur, birakinca eski boyuta doner.
      final row1 = find.text('Mehmet Kaya');
      final w0 = tester.getSize(find.ancestor(of: row1, matching: find.byType(AnimatedScale)).first).width;
      final g = await tester.startGesture(tester.getCenter(row1));
      await tester.pump(const Duration(milliseconds: 200));
      final scale = tester.widget<AnimatedScale>(find.ancestor(of: row1, matching: find.byType(AnimatedScale)).first).scale;
      expect(scale, lessThan(1.0));
      expect(w0, greaterThan(300));
      await g.up();
      await tester.pump();
      await settle(tester, const Duration(milliseconds: 300));
      noErr(tester);
    });

    testWidgets('renk sadeligi: zaman metni ve tur etiketi notr, marka rengi yalniz okunmamis rozette', (tester) async {
      useScreen(tester, const Size(390, 844));
      final b = FakeBackend()
        ..on('/conversations/unread-count', {'total': 2})
        ..on('/conversations*', {
          'items': [
            {...row(1, 'Mehmet Kaya', unread: 2), 'lastMessage': {...row(1, 'x')['lastMessage'] as Map<String, dynamic>, 'status': 'READ', 'senderId': 1}},
            {...row(2, 'Edebiyat Kulubu', unread: 1), 'type': 'CLUB', 'peer': null},
          ],
          'nextCursor': null,
        });
      await tester.pumpWidget(buildApp(ChatTab(session: makeSession(b), connectRealtime: false)));
      await settle(tester, const Duration(milliseconds: 1200));
      final bu = tester.element(find.text('Mehmet Kaya')).bu;
      // Zaman metni (okunmamis satirda bile) notr ikincil renk.
      final stamp = tester.widgetList<Text>(find.byWidgetPredicate((w) => w is Text && RegExp(r'^\d\d:\d\d$').hasMatch(w.data ?? '')));
      expect(stamp, isNotEmpty);
      for (final t in stamp) {
        expect(t.style!.color, bu.mut);
      }
      // Tur etiketi: notr yuzey (sf2) + ikincil metin; yesil/mavi ton yok.
      final tag = find.text('Kulüp');
      expect(tag, findsOneWidget);
      expect(tester.widget<Text>(tag).style!.color, bu.mut);
      final chip = tester.widget<DecoratedBox>(find.ancestor(of: tag, matching: find.byType(DecoratedBox)).first);
      expect((chip.decoration as BoxDecoration).color, bu.sf2);
      // Okunmamis rozeti marka rengi (t.pr) kalir.
      final badge = tester.widget<DecoratedBox>(find.ancestor(of: find.text('2'), matching: find.byType(DecoratedBox)).first);
      expect((badge.decoration as BoxDecoration).color, bu.pr);
      noErr(tester);
    });

    testWidgets('animasyonlari azalt: satirlar anında, basma olcegi uygulanmaz', (tester) async {
      reduceMotion(tester);
      useScreen(tester, const Size(390, 844));
      await tester.pumpWidget(buildApp(ChatTab(session: makeSession(be()), connectRealtime: false)));
      await settle(tester, const Duration(milliseconds: 600));
      final item = find.byType(BuStaggerItem).first;
      expect(tester.widget<BuStaggerItem>(item).child, isA<ClipRect>());
      expect(firstChild(tester, item), isNot(isA<FadeTransition>()));
      final row1 = find.text('Mehmet Kaya');
      final g = await tester.startGesture(tester.getCenter(row1));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<AnimatedScale>(find.ancestor(of: row1, matching: find.byType(AnimatedScale)).first).scale, 1.0);
      await g.up();
      noErr(tester);
    });
  });
}
