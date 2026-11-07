import 'dart:async';
import 'dart:convert';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/connectivity/connectivity_service.dart';
import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/outbox/outbox.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:bu_kampus/features/share/share_api.dart';
import 'package:bu_kampus/features/share/share_button.dart';
import 'package:bu_kampus/features/share/share_card.dart';
import 'package:bu_kampus/features/share/share_links.dart';
import 'package:bu_kampus/features/share/share_models.dart';
import 'package:bu_kampus/features/share/share_sheet.dart';
import 'package:bu_kampus/features/posts/post_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:share_plus/share_plus.dart';

import 'support/fake_app.dart';

/// SH-MB: paylaşım (alt sayfa, sohbet kartı, derin bağlantı, çevrimdışı kuyruk).

void noErr(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(30).join('\n')}');
}

Map<String, dynamic> conv(int id, String name, {String type = 'DIRECT', int? peer, bool blocked = false, bool closed = false}) => {
      'id': id,
      'type': type,
      'title': type == 'DIRECT' ? null : name,
      if (type == 'DIRECT') 'peer': {'id': peer ?? id + 100, 'displayName': name},
      'blocked': blocked,
      'closed': closed,
    };

FakeBackend sheetBackend({List<Map<String, dynamic>>? chats, bool authorPrivate = false}) {
  final b = FakeBackend();
  b.on('/conversations?size=50', {
    'items': chats ??
        [
          conv(1, 'Ali Veli'),
          conv(2, 'Zeynep Kaya'),
          conv(3, 'Kampüs Kulübü', type: 'GROUP'),
          conv(4, 'Engelli Kişi', blocked: true),
          conv(5, 'Kapalı Sohbet', closed: true),
        ],
    'nextCursor': null,
  });
  b.on('/users/search*', {
    'items': [
      {'id': 77, 'displayName': 'Mert Yeni', 'department': 'Bilgisayar'},
      {'id': 101, 'displayName': 'Ali Veli'}, // Ali'nin sohbeti var (peer 101): yinelenmez
      {'id': 1, 'displayName': 'Ayşe Yılmaz'}, // ben
    ],
    'nextCursor': null,
  });
  b.on('/users/12', {'id': 12, 'displayName': 'Yazar', 'isPrivate': authorPrivate});
  b.on('/conversations', {'id': 90, 'type': 'DIRECT'});
  return b;
}

const kPost = ShareContent(
  type: ShareType.post,
  id: 7,
  title: 'Kampüste güz manzarası',
  source: 'Ayşe Yılmaz',
);

Future<void> openSheet(WidgetTester tester, FakeBackend b, ShareContent c,
    {Size size = kPhoneMedium, Brightness br = Brightness.light, Session? session}) async {
  useScreen(tester, size);
  final s = session ?? makeSession(b);
  await tester.pumpWidget(buildApp(
    Builder(
      builder: (context) => Scaffold(
        body: Center(child: TextButton(key: const ValueKey('open'), onPressed: () => showShareSheet(context, s, c), child: const Text('aç'))),
      ),
    ),
    brightness: br,
    size: size,
  ));
  await tester.tap(find.byKey(const ValueKey('open')));
  await settle(tester, const Duration(milliseconds: 700));
}

Future<void> unmountSheet(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(loadTestFonts);

  group('bağlantı biçimi', () {
    test('https, www, eğik çizgi ve sorgu kabul edilir', () {
      expect(parseShareLink('https://bukampus.com.tr/s/p/12'), const ShareTarget(ShareType.post, 12));
      expect(parseShareLink('https://www.bukampus.com.tr/s/r/5/'), const ShareTarget(ShareType.reel, 5));
      expect(parseShareLink('https://bukampus.com.tr/s/n/300?utm=x#a'), const ShareTarget(ShareType.news, 300));
      expect(parseShareLink(Uri.parse('https://bukampus.com.tr/s/e/9')), const ShareTarget(ShareType.event, 9));
      expect(parseShareLink('  https://bukampus.com.tr/s/p/1  '), const ShareTarget(ShareType.post, 1));
    });

    test('özel şema: bukampus://s/{t}/{id} ve bukampus:///s/{t}/{id}', () {
      expect(parseShareLink('bukampus://s/p/12'), const ShareTarget(ShareType.post, 12));
      expect(parseShareLink('bukampus:///s/e/4'), const ShareTarget(ShareType.event, 4));
      expect(parseShareLink('BUKAMPUS://s/n/8'), const ShareTarget(ShareType.news, 8));
    });

    test('geçersiz biçimler null döner, exception fırlatmaz', () {
      for (final bad in [
        null,
        '',
        'merhaba',
        'https://example.com/s/p/12',
        'https://bukampus.com.tr.evil.com/s/p/12',
        'https://bukampus.com.tr/x/p/12',
        'https://bukampus.com.tr/s/x/12',
        'https://bukampus.com.tr/s/p/abc',
        'https://bukampus.com.tr/s/p/0',
        'https://bukampus.com.tr/s/p/-3',
        'https://bukampus.com.tr/s/p/99999999999999999999',
        'https://bukampus.com.tr/s/p',
        'https://bukampus.com.tr/s/p/12/extra',
        'https://user@bukampus.com.tr/s/p/12',
        'ftp://bukampus.com.tr/s/p/12',
        'bukampus://x/p/12',
        'bukampus://s/p',
        42,
        '::::',
      ]) {
        expect(parseShareLink(bad), isNull, reason: '$bad');
      }
    });

    test('hedef bağlantısı ve harici paylaşım metni', () {
      expect(const ShareTarget(ShareType.reel, 3).url, 'https://bukampus.com.tr/s/r/3');
      expect(kPost.externalText(), 'Kampüste güz manzarası\nhttps://bukampus.com.tr/s/p/7');
      expect(const ShareContent(type: ShareType.event, id: 2).externalText(), 'https://bukampus.com.tr/s/e/2');
      final long = ShareContent(type: ShareType.news, id: 1, title: 'a' * 300).externalText();
      expect(long.split('\n').first.runes.length, 120);
      expect(long.endsWith('/s/n/1'), isTrue);
      expect(isShareLinkText('https://bukampus.com.tr/s/p/12'), isTrue);
      expect(isShareLinkText('Bak şuna https://bukampus.com.tr/s/p/12'), isFalse);
      expect(isShareLinkText(null), isFalse);
    });

    test('mesajdaki share alanı', () {
      final i = ShareInfo.fromMessage({
        'share': {'type': 'NEWS', 'id': 5, 'title': ' Başlık ', 'subtitle': 'bingol.edu.tr', 'imageUrl': '/files/a.jpg', 'available': true, 'kind': 'DUYURU'}
      })!;
      expect(i.type, ShareType.news);
      expect(i.id, 5);
      expect(i.title, 'Başlık');
      expect(i.isAnnouncement, isTrue);
      expect(i.available, isTrue);
      expect(ShareInfo.fromMessage({'share': {'type': 'REEL', 'id': '9', 'available': false}})!.available, isFalse);
      expect(ShareInfo.fromMessage({'share': {'type': 'REEL', 'id': '9'}})!.showPlay, isTrue);
      expect(ShareInfo.fromMessage({'share': {'type': 'POST', 'id': 3, 'kind': 'VIDEO'}})!.showPlay, isTrue);
      expect(ShareInfo.fromMessage({'share': {'type': 'POST', 'id': 3, 'kind': 'PHOTO'}})!.showPlay, isFalse);
      expect(ShareInfo.fromMessage({'share': {'type': 'BILINMEYEN', 'id': 1}}), isNull);
      expect(ShareInfo.fromMessage({'share': {'type': 'POST'}}), isNull);
      expect(ShareInfo.fromMessage({'share': 'x'}), isNull);
      expect(ShareInfo.fromMessage({'text': 'merhaba'}), isNull);
      expect(ShareInfo.fromMessage(null), isNull);
    });
  });

  group('derin bağlantı yakalayıcı', () {
    setUp(() => ShareLinks.instance.reset());
    tearDown(() => ShareLinks.instance.reset());

    test('geçerli bağlantı bekleyen hedef olur; geçersiz yok sayılır; take temizler', () {
      final l = ShareLinks.instance;
      l.ingest(Uri.parse('https://example.com/x'));
      expect(l.pending.value, isNull);
      l.ingest(Uri.parse('https://bukampus.com.tr/s/e/4'));
      expect(l.pending.value, const ShareTarget(ShareType.event, 4));
      expect(l.take(), const ShareTarget(ShareType.event, 4));
      expect(l.pending.value, isNull);
    });

    test('ilk bağlantı + akış yinelemesi 2 sn içinde tek sayılır; sonra yeniden tetiklenir', () {
      final l = ShareLinks.instance;
      var fired = 0;
      l.pending.addListener(() {
        if (l.pending.value != null) fired++;
      });
      final t0 = DateTime(2026, 11, 5, 12);
      final u = Uri.parse('https://bukampus.com.tr/s/p/1');
      l.ingest(u, now: t0);
      l.ingest(u, now: t0.add(const Duration(milliseconds: 300)));
      expect(fired, 1);
      l.take();
      l.ingest(u, now: t0.add(const Duration(seconds: 5)));
      expect(fired, 2);
    });

    test('start: eklenti akışındaki bağlantılar hedef olur (soğuk açılış bağlantısı da akıştan gelir); hata akışı bozmaz', () async {
      final l = ShareLinks.instance;
      await l.stop();
      final c = StreamController<Uri>();
      await l.start(stream: c.stream);
      c.add(Uri.parse('https://bukampus.com.tr/s/r/21'));
      await Future<void>.delayed(Duration.zero);
      expect(l.pending.value, const ShareTarget(ShareType.reel, 21));
      c.addError(StateError('eklenti hatası'));
      c.add(Uri.parse('bukampus://s/e/3'));
      await Future<void>.delayed(Duration.zero);
      expect(l.pending.value, const ShareTarget(ShareType.event, 3));
      await l.stop();
      await c.close();
    });

    testWidgets('oturum açık değilken beklenir; kabuk (oturum açık) çizilince açılır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/news/5', {'id': 5, 'title': 'Derin bağlantı haberi', 'content': 'Gövde metni', 'url': 'https://www.bingol.edu.tr/h/5'});
      final session = makeSession(b, signedIn: false);
      ShareLinks.instance.ingest(Uri.parse('https://bukampus.com.tr/s/n/5')); // soğuk açılış: oturum yok
      await tester.pumpWidget(MaterialApp(
        theme: BuTheme.light(),
        navigatorKey: rootNavigatorKey,
        home: ShareLinkHost(session: session, child: const Scaffold(body: Text('kabuk'))),
      ));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('kabuk'), findsOneWidget);
      expect(find.text('Derin bağlantı haberi'), findsNothing);
      expect(ShareLinks.instance.pending.value, isNotNull, reason: 'oturum yok: hedef korunur');
      // Giriş tamamlanır; yeni bağlantı gelince (ya da kabuk yeniden kurulunca) bekleyen açılır.
      session.state = SessionState.signedIn;
      session.userId = 1;
      ShareLinks.instance.ingest(Uri.parse('https://bukampus.com.tr/s/n/5'), now: DateTime(2030));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.text('Derin bağlantı haberi'), findsWidgets);
      expect(ShareLinks.instance.pending.value, isNull);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('oturum açıkken soğuk açılışta bekleyen hedef kabuk çizilince açılır', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..on('/news/6', {'id': 6, 'title': 'Soğuk açılış haberi', 'content': 'x', 'url': 'https://www.bingol.edu.tr/h/6'});
      ShareLinks.instance.ingest(Uri.parse('bukampus://s/n/6'));
      await tester.pumpWidget(MaterialApp(
        theme: BuTheme.light(),
        navigatorKey: rootNavigatorKey,
        home: ShareLinkHost(session: makeSession(b), child: const Scaffold(body: Text('kabuk'))),
      ));
      await settle(tester, const Duration(milliseconds: 900));
      expect(find.text('Soğuk açılış haberi'), findsWidgets);
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('sıcak durum: açık kabukta gelen bağlantı hemen açılır; bulunamayan içerikte çökme yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..fail('/news/404', status: 404, code: 'NEWS_NOT_FOUND');
      await tester.pumpWidget(MaterialApp(
        theme: BuTheme.light(),
        navigatorKey: rootNavigatorKey,
        home: ShareLinkHost(session: makeSession(b), child: const Scaffold(body: Text('kabuk'))),
      ));
      await settle(tester, const Duration(milliseconds: 300));
      ShareLinks.instance.ingest(Uri.parse('https://bukampus.com.tr/s/n/404'));
      await settle(tester, const Duration(milliseconds: 900));
      expect(b.count('GET /news/404'), greaterThan(0));
      noErr(tester);
      await unmount(tester);
    });
  });

  group('çevrimdışı kuyruk', () {
    test('paylaşım kartı boş notla kuyruğa alınır, yeniden açılışta korunur, gönderimde share gövdesi gider', () async {
      final store = MemoryOutboxStore();
      final bodies = <Map<String, dynamic>>[];
      var online = false;
      final api = ApiClient(
        client: MockClient((r) async {
          if (!online) throw http.ClientException('yok');
          bodies.add(Map<String, dynamic>.from(jsonDecode((r as http.Request).body)));
          return http.Response('{"id":1}', 200, headers: {'content-type': 'application/json'});
        }),
        retryDelay: Duration.zero,
        connectivity: ConnectivityService(),
      );
      final ob = Outbox(store: store, autoSchedule: false);
      api.outbox = ob;
      ob.attach(api, ConnectivityService());
      await expectLater(
          api.post('/conversations/7/messages', {'text': '', 'clientId': 'c-1', 'share': {'type': 'POST', 'id': 12}}), throwsA(isA<ApiError>()));
      expect(ob.pendingCount, 1);
      expect(ob.items.single.share, {'type': 'POST', 'id': 12});
      await Future<void>.delayed(Duration.zero);

      final ob2 = Outbox(store: store, autoSchedule: false)..attach(api, ConnectivityService());
      await ob2.load();
      expect(ob2.items.single.share, {'type': 'POST', 'id': 12});
      expect(ob2.items.single.text, '');

      online = true;
      await ob2.nudge();
      expect(bodies.single['share'], {'type': 'POST', 'id': 12});
      expect(bodies.single['clientId'], 'c-1');
      expect(ob2.pendingCount, 0);
    });

    test('kartsız boş metin ve bozuk share yine kuyruğa alınmaz', () {
      final ob = Outbox(store: MemoryOutboxStore(), autoSchedule: false);
      expect(ob.captureRequest('/conversations/7/messages', {'text': '', 'clientId': 'a'}), isFalse);
      expect(ob.captureRequest('/conversations/7/messages', {'text': '', 'clientId': 'a', 'share': {'type': 'POST', 'id': 0}}), isFalse);
      expect(ob.captureRequest('/conversations/7/messages', {'text': '', 'clientId': 'a', 'share': {'type': 'POST', 'id': 'x'}}), isFalse);
      expect(ob.captureRequest('/conversations/7/messages', {'text': 'not', 'clientId': 'a', 'share': {'type': 'EVENT', 'id': 3}}), isTrue);
    });

    test('sendShare: ağ yokken kuyruğa alınır (queued), sunucu hatasında failed', () async {
      final ob = Outbox(store: MemoryOutboxStore(), autoSchedule: false);
      final api = ApiClient(
          client: MockClient((r) async => throw http.ClientException('yok')),
          retryDelay: Duration.zero,
          connectivity: ConnectivityService())
        ..outbox = ob;
      final sum = await sendShare(api,
          to: const [ShareRecipient.conversation(conversationId: 4, label: 'Ali')], target: const ShareTarget(ShareType.news, 9), note: 'bak');
      expect(sum.queued, 1);
      expect(ob.items.single.share, {'type': 'NEWS', 'id': 9});
      expect(ob.items.single.text, 'bak');

      final api2 = ApiClient(
          client: MockClient((r) async => http.Response('{"code":"X","message":"m"}', 403, headers: {'content-type': 'application/json'})),
          retryDelay: Duration.zero,
          connectivity: ConnectivityService());
      final sum2 = await sendShare(api2,
          to: const [ShareRecipient.conversation(conversationId: 4, label: 'Ali')], target: const ShareTarget(ShareType.news, 9));
      expect(sum2.failed, 1);
      expect(sum2.allFailed, isTrue);
    });
  });

  group('paylaşım alt sayfası', () {
    testWidgets('önizleme kartı, son sohbetler şeridi (engelli/kapalı sohbet yok), eylemler görünür', (tester) async {
      final b = sheetBackend();
      await openSheet(tester, b, kPost);
      expect(find.byKey(const ValueKey('share-preview')), findsOneWidget);
      expect(find.text('Kampüste güz manzarası'), findsOneWidget);
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('GÖNDERİ'), findsOneWidget);
      expect(find.byKey(const ValueKey('share-strip')), findsOneWidget);
      expect(find.byKey(const ValueKey('share-pick-c1')), findsOneWidget);
      expect(find.byKey(const ValueKey('share-pick-c3')), findsOneWidget);
      expect(find.byKey(const ValueKey('share-pick-c4')), findsNothing, reason: 'engelli');
      expect(find.byKey(const ValueKey('share-pick-c5')), findsNothing, reason: 'kapalı');
      expect(find.byKey(const ValueKey('share-copy')), findsOneWidget);
      expect(find.byKey(const ValueKey('share-external')), findsOneWidget);
      // Seçim yokken gönder pasif, not alanı yok.
      expect(find.byKey(const ValueKey('share-note')), findsNothing);
      noErr(tester);
      await unmountSheet(tester);
    });

    testWidgets('çoklu seçim + not: istek gövdesinde share ve not; her alıcıya ayrı clientId', (tester) async {
      final b = sheetBackend();
      await openSheet(tester, b, kPost);
      await tester.tap(find.byKey(const ValueKey('share-pick-c1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('share-pick-c3')));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Gönder (2)'), findsOneWidget);
      expect(find.byKey(const ValueKey('share-note')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('share-note')), 'Buna bak');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('share-send')));
      await settle(tester, const Duration(milliseconds: 800));
      final m1 = b.bodies['POST /conversations/1/messages'] as Map;
      final m3 = b.bodies['POST /conversations/3/messages'] as Map;
      expect(m1['share'], {'type': 'POST', 'id': 7});
      expect(m3['share'], {'type': 'POST', 'id': 7});
      expect(m1['text'], 'Buna bak');
      expect(m1['clientId'], isNot(m3['clientId']));
      expect(find.byKey(const ValueKey('share-send')), findsNothing, reason: 'gönderince sayfa kapanır');
      expect(find.text('2 sohbete gönderildi'), findsOneWidget);
      noErr(tester);
      await unmountSheet(tester);
    });

    testWidgets('reels türü REEL olarak gider', (tester) async {
      final b = sheetBackend();
      await openSheet(tester, b, const ShareContent(type: ShareType.reel, id: 21, title: 'Reel', isVideo: true));
      await tester.tap(find.byKey(const ValueKey('share-pick-c2')));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('share-send')));
      await settle(tester, const Duration(milliseconds: 700));
      expect((b.bodies['POST /conversations/2/messages'] as Map)['share'], {'type': 'REEL', 'id': 21});
      expect(find.text('Gönderildi'), findsOneWidget);
      await unmountSheet(tester);
    });

    testWidgets('arama: sohbet filtrelenir, sohbeti olmayan kişi seçilince önce sohbet açılır, kopya kişi yok', (tester) async {
      final b = sheetBackend();
      await openSheet(tester, b, kPost);
      await tester.enterText(find.byType(TextField).first, 'ali');
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('share-results')), findsOneWidget);
      expect(find.byKey(const ValueKey('share-pick-c1')), findsOneWidget);
      expect(find.byKey(const ValueKey('share-pick-u101')), findsNothing, reason: 'Ali zaten sohbette');
      expect(find.byKey(const ValueKey('share-pick-u1')), findsNothing, reason: 'kendim');
      await tester.enterText(find.byType(TextField).first, 'mert');
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('share-pick-u77')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('share-pick-u77')));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('share-send')));
      await settle(tester, const Duration(milliseconds: 800));
      expect((b.bodies['POST /conversations'] as Map)['userId'], 77);
      expect((b.bodies['POST /conversations/90/messages'] as Map)['share'], {'type': 'POST', 'id': 7});
      noErr(tester);
      await unmountSheet(tester);
    });

    testWidgets('en fazla $kShareMaxRecipients alıcı', (tester) async {
      final b = sheetBackend(chats: [for (var i = 1; i <= 12; i++) conv(i, 'Kişi $i')]);
      await openSheet(tester, b, kPost);
      for (var i = 1; i <= 12; i++) {
        final f = find.byKey(ValueKey('share-pick-c$i'));
        await tester.ensureVisible(f);
        await tester.tap(f, warnIfMissed: false);
        await tester.pump();
      }
      expect(find.text('Gönder ($kShareMaxRecipients)'), findsOneWidget);
      expect(find.text('En fazla $kShareMaxRecipients sohbet seçilebilir.'), findsOneWidget);
      await unmountSheet(tester);
    });

    testWidgets('422 SHARE_TARGET_INVALID: sunucunun istek dilindeki mesajı gösterilir', (tester) async {
      final b = sheetBackend();
      b.fail('/conversations/1/messages', status: 422, code: 'SHARE_TARGET_INVALID', message: 'Bu içerik paylaşılamıyor.');
      await openSheet(tester, b, kPost);
      await tester.tap(find.byKey(const ValueKey('share-pick-c1')));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('share-send')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text('Bu içerik paylaşılamıyor.'), findsOneWidget);
      expect(find.byKey(const ValueKey('share-send')), findsOneWidget);
      await unmountSheet(tester);
    });

    testWidgets('hepsi başarısız: sayfa açık kalır ve hata gösterilir', (tester) async {
      final b = sheetBackend();
      b.fail('/conversations/1/messages', status: 403, code: 'FORBIDDEN');
      await openSheet(tester, b, kPost);
      await tester.tap(find.byKey(const ValueKey('share-pick-c1')));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('share-send')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('share-send')), findsOneWidget);
      expect(find.text('Gönderilemedi. Tekrar deneyin.'), findsOneWidget);
      await unmountSheet(tester);
    });

    testWidgets('bağlantıyı kopyala panoya https bağlantıyı yazar', (tester) async {
      String? clip;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clip = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final b = sheetBackend();
      await openSheet(tester, b, kPost);
      await tester.tap(find.byKey(const ValueKey('share-copy')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(clip, 'https://bukampus.com.tr/s/p/7');
      expect(find.text('Bağlantı kopyalandı'), findsOneWidget);
      await unmountSheet(tester);
    });

    testWidgets('diğer uygulamalar: sistem paylaşım sayfası başlık + bağlantıyla çağrılır', (tester) async {
      ShareParams? got;
      debugExternalShare = (p) async => got = p;
      addTearDown(() => debugExternalShare = null);
      final b = sheetBackend();
      await openSheet(tester, b, kPost);
      await tester.tap(find.byKey(const ValueKey('share-external')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(got, isNotNull);
      expect(got!.text, 'Kampüste güz manzarası\nhttps://bukampus.com.tr/s/p/7');
      expect(got!.subject, 'Kampüste güz manzarası');
      await unmountSheet(tester);
    });

    testWidgets('gizli hesap (gönderide bilgi var): kopyala/harici yok, yalnız mesajla + uyarı', (tester) async {
      final b = sheetBackend();
      await openSheet(tester, b, const ShareContent(type: ShareType.post, id: 7, title: 'Gizli', restricted: true));
      expect(find.byKey(const ValueKey('share-copy')), findsNothing);
      expect(find.byKey(const ValueKey('share-external')), findsNothing);
      expect(find.text('Gizli hesabın gönderisi yalnızca kişilere mesajla paylaşılabilir.'), findsOneWidget);
      expect(find.byKey(const ValueKey('share-pick-c1')), findsOneWidget);
      await unmountSheet(tester);
    });

    testWidgets('gizli hesap (yazardan doğrulanır): /users/{id} isPrivate ise bağlantı eylemleri kapalı', (tester) async {
      final b = sheetBackend(authorPrivate: true);
      await openSheet(tester, b, const ShareContent(type: ShareType.post, id: 7, title: 'X', authorId: 12));
      expect(b.count('GET /users/12'), 1);
      expect(find.byKey(const ValueKey('share-copy')), findsNothing);
      expect(find.text('Gizli hesabın gönderisi yalnızca kişilere mesajla paylaşılabilir.'), findsOneWidget);
      await unmountSheet(tester);
    });

    testWidgets('herkese açık hesap: doğrulama sonrası eylemler açılır; doğrulanamazsa kapalı kalır', (tester) async {
      final b = sheetBackend();
      await openSheet(tester, b, const ShareContent(type: ShareType.post, id: 7, title: 'X', authorId: 12));
      expect(find.byKey(const ValueKey('share-copy')), findsOneWidget);
      await unmountSheet(tester);

      final b2 = sheetBackend()..fail('/users/12');
      await openSheet(tester, b2, const ShareContent(type: ShareType.post, id: 7, title: 'X', authorId: 12));
      expect(find.byKey(const ValueKey('share-copy')), findsNothing, reason: 'doğrulanamadı: kapalı taraf');
      await unmountSheet(tester);
    });

    testWidgets('haber ve etkinlikte yazar doğrulaması yapılmaz', (tester) async {
      final b = sheetBackend();
      await openSheet(tester, b, const ShareContent(type: ShareType.event, id: 3, title: 'Etkinlik', authorId: 12));
      expect(b.count('GET /users/12'), 0);
      expect(find.byKey(const ValueKey('share-copy')), findsOneWidget);
      await unmountSheet(tester);
    });

    testWidgets('sohbet listesi hatası: hata durumu + yeniden dene', (tester) async {
      final b = sheetBackend()..fail('/conversations?size=50');
      await openSheet(tester, b, kPost);
      expect(find.byKey(const ValueKey('share-strip')), findsNothing);
      expect(find.byKey(const ValueKey('share-copy')), findsOneWidget, reason: 'sohbet olmasa da bağlantı eylemleri çalışır');
      await unmountSheet(tester);
    });

    for (final size in [kPhoneSmall, kPhoneMedium]) {
      for (final br in [Brightness.light, Brightness.dark]) {
        testWidgets('taşma yok: ${size.width.toInt()} dp ${br.name}, yazı x1.3, uzun başlık', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final b = sheetBackend();
          await openSheet(tester, b, ShareContent(type: ShareType.news, id: 1, title: 'Çok uzun bir haber başlığı ' * 8, source: 'bingol.edu.tr'),
              size: size, br: br);
          await tester.tap(find.byKey(const ValueKey('share-pick-c1')));
          await settle(tester, const Duration(milliseconds: 400));
          noErr(tester);
          await unmountSheet(tester);
        });
      }
    }

    testWidgets('RTL (ar): taşma yok', (tester) async {
      useScreen(tester, kPhoneSmall);
      final b = sheetBackend();
      final s = makeSession(b);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        theme: BuTheme.light(),
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(key: const ValueKey('open'), onPressed: () => showShareSheet(context, s, kPost), child: const Text('aç')),
          ),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('open')));
      await settle(tester, const Duration(milliseconds: 700));
      await tester.tap(find.byKey(const ValueKey('share-pick-c1')));
      await settle(tester, const Duration(milliseconds: 400));
      noErr(tester);
      await unmountSheet(tester);
    });
  });

  group('sohbet paylaşım kartı', () {
    Map<String, dynamic> msg(Map<String, dynamic> share, {String text = '', int id = 1}) => {
          'id': id,
          'text': text,
          'senderId': 11,
          'createdAt': '2026-11-05T10:00:00Z',
          'share': share,
        };

    Widget bubble(Map<String, dynamic> m, {bool mine = false, void Function(ShareInfo)? onOpen, bool preview = false}) => Center(
          child: MessageBubble(
            message: m,
            mine: mine,
            senderName: null,
            replyName: null,
            seen: false,
            authHeaders: const {},
            onMenu: () {},
            onRetry: () {},
            onOpenImage: (_) {},
            onReact: (_) {},
            onOpenShare: onOpen,
            preview: preview,
          ),
        );

    Future<void> pumpBubble(WidgetTester tester, Widget w, {Size size = kPhoneMedium, Brightness br = Brightness.light}) async {
      useScreen(tester, size);
      await tester.pumpWidget(buildApp(Scaffold(body: w), brightness: br, size: size));
      await settle(tester, const Duration(milliseconds: 300));
    }

    testWidgets('kullanılabilir gönderi: yalnız görsel + sahibinin adı (etiket/açıklama yok); dokununca onOpenShare', (tester) async {
      ShareInfo? opened;
      await pumpBubble(
          tester,
          bubble(msg({'type': 'POST', 'id': 7, 'title': 'Güz manzarası', 'subtitle': 'Ayşe Yılmaz', 'available': true}), onOpen: (i) => opened = i));
      expect(find.byKey(const ValueKey('share-card-kind')), findsNothing);
      expect(find.text('GÖNDERİ'), findsNothing);
      expect(find.text('Güz manzarası'), findsNothing, reason: 'açıklama kartta gösterilmez');
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('share-card-source')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(opened?.target, const ShareTarget(ShareType.post, 7));
      noErr(tester);
      await unmount(tester);
    });

    testWidgets('tür etiketleri: Haber, Duyuru, Etkinlik (gönderi/Reels kartında etiket yok)', (tester) async {
      await pumpBubble(tester, bubble(msg({'type': 'REEL', 'id': 1, 'title': 'R', 'subtitle': 'Yazar'})));
      expect(find.text('REELS'), findsNothing);
      expect(find.text('Yazar'), findsOneWidget);
      await unmount(tester);
      for (final c in [
        ({'type': 'NEWS', 'id': 2, 'title': 'N'}, 'HABER'),
        ({'type': 'NEWS', 'id': 3, 'title': 'D', 'kind': 'DUYURU'}, 'DUYURU'),
        ({'type': 'EVENT', 'id': 4, 'title': 'E'}, 'ETKİNLİK'),
      ]) {
        await pumpBubble(tester, bubble(msg(c.$1)));
        expect(find.text(c.$2), findsOneWidget, reason: '${c.$1}');
        await unmount(tester);
      }
    });

    testWidgets('içerik kullanılamıyor: yer tutucu metin, başlık yok, dokunma kapalı', (tester) async {
      ShareInfo? opened;
      await pumpBubble(tester, bubble(msg({'type': 'POST', 'id': 7, 'title': 'Silinmiş', 'available': false}), onOpen: (i) => opened = i));
      expect(find.byKey(const ValueKey('share-card-unavailable')), findsOneWidget);
      expect(find.text('Bu gönderi görüntülenemiyor. Gizli bir hesaba ait olabilir.'), findsOneWidget);
      expect(find.text('Silinmiş'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('share-card-unavailable')), warnIfMissed: false);
      await tester.pump();
      expect(opened, isNull);
      await unmount(tester);
    });

    testWidgets('gizli hesap gönderisi (available:false): içerik/ad/görsel sızmaz; tr metin', (tester) async {
      await pumpBubble(
          tester,
          bubble(msg({'type': 'POST', 'id': 9, 'available': false, 'url': 'https://bukampus.com.tr/s/p/9'})));
      expect(find.byKey(const ValueKey('share-card-unavailable')), findsOneWidget);
      expect(find.byKey(const ValueKey('share-card-source')), findsNothing);
      expect(find.byKey(const ValueKey('share-card-title')), findsNothing);
      await unmount(tester);
    });

    for (final c in [(const Locale('en'), 'This post is unavailable. It may belong to a private account.'), (const Locale('ar'), 'هذا المنشور غير متاح. قد يعود إلى حساب خاص.')]) {
      testWidgets('gönderi kullanılamıyor metni ${c.$1.languageCode}', (tester) async {
        useScreen(tester, kPhoneMedium);
        await tester.pumpWidget(MaterialApp(
          locale: c.$1,
          theme: BuTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ShareCard(
                info: const ShareInfo(type: ShareType.post, id: 9, available: false),
                mine: false,
                width: 260,
              ),
            ),
          ),
        ));
        await settle(tester, const Duration(milliseconds: 300));
        expect(find.text(c.$2), findsOneWidget);
        noErr(tester);
        await unmount(tester);
      });
    }

    testWidgets('sunucu sözleşmesindeki örnek yük (PHOTO + göreli /api görsel + url) çizilir', (tester) async {
      await pumpBubble(
          tester,
          bubble(msg({
            'type': 'POST',
            'id': 123,
            'available': true,
            'title': 'Kampüste bahar',
            'subtitle': 'Ayşe Yılmaz',
            'imageUrl': '/api/posts/media/55?thumb=true',
            'kind': 'PHOTO',
            'url': 'https://bukampus.com.tr/s/p/123',
          })));
      expect(find.text('Kampüste bahar'), findsNothing); // gönderi kartında açıklama yok
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('not metni kartın altında; yedek bağlantı metni gizlenir', (tester) async {
      await pumpBubble(tester, bubble(msg({'type': 'NEWS', 'id': 2, 'title': 'Haber'}, text: 'Şuna bak')));
      expect(find.text('Şuna bak'), findsOneWidget);
      await unmount(tester);
      await pumpBubble(tester, bubble(msg({'type': 'NEWS', 'id': 2, 'title': 'Haber'}, text: 'https://bukampus.com.tr/s/n/2')));
      expect(find.text('https://bukampus.com.tr/s/n/2'), findsNothing);
      expect(find.text('Haber'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('önizleme (menü) modunda kart etkileşimsiz', (tester) async {
      var n = 0;
      await pumpBubble(tester, bubble(msg({'type': 'EVENT', 'id': 2, 'title': 'Etkinlik'}), onOpen: (_) => n++, preview: true));
      await tester.tap(find.byKey(const ValueKey('share-card-title')), warnIfMissed: false);
      await tester.pump();
      expect(n, 0);
      await unmount(tester);
    });

    for (final size in [kPhoneSmall, kPhoneMedium]) {
      for (final br in [Brightness.light, Brightness.dark]) {
        for (final mine in [false, true]) {
          testWidgets('taşma yok: ${size.width.toInt()} dp ${br.name} ${mine ? 'giden' : 'gelen'}, x1.3, uzun başlık + not', (tester) async {
            tester.platformDispatcher.textScaleFactorTestValue = 1.3;
            addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
            await pumpBubble(
                tester,
                bubble(
                    msg({
                      'type': 'NEWS',
                      'id': 2,
                      'title': 'Çok uzun bir haber başlığı ' * 8,
                      'subtitle': 'çok-uzun-bir-kaynak-alan-adi.bingol.edu.tr/yol/yol',
                      'available': true,
                    }, text: 'Uzun bir not metni ' * 6),
                    mine: mine),
                size: size,
                br: br);
            noErr(tester);
            await unmount(tester);
          });
        }
      }
    }

    testWidgets('RTL taşma yok', (tester) async {
      useScreen(tester, kPhoneSmall);
      await tester.pumpWidget(MaterialApp(
        theme: BuTheme.light(),
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        home: Scaffold(body: bubble(msg({'type': 'EVENT', 'id': 2, 'title': 'فعالية الحرم الجامعي الكبرى ' * 4, 'subtitle': 'نادي'}, text: 'ملاحظة'))),
      ));
      await settle(tester, const Duration(milliseconds: 300));
      noErr(tester);
      await unmount(tester);
    });
  });

  group('sohbet listesi önizleme metni (ChatTab)', () {
    testWidgets('notsuz paylaşım nötr metin; sunucunun 🔗 yedek metni ve bağlantı da nötr; not varsa not görünür', (tester) async {
      Future<void> pumpList(Map<String, dynamic> last) async {
        useScreen(tester, kPhoneMedium);
        final b = FakeBackend()
          ..on('/conversations', {
            'items': [
              {
                'id': 1,
                'type': 'DIRECT',
                'peer': {'id': 11, 'displayName': 'Ali Veli'},
                'unreadCount': 0,
                'lastMessage': {'id': 9, 'senderId': 11, 'createdAt': '2026-11-05T10:00:00Z', ...last},
              }
            ],
            'nextCursor': null,
          });
        await tester.pumpWidget(buildApp(ChatTab(session: makeSession(b)), size: kPhoneMedium));
        await settle(tester, const Duration(milliseconds: 700));
      }

      await pumpList({'text': '', 'share': {'type': 'POST', 'id': 5, 'available': true, 'url': 'https://bukampus.com.tr/s/p/5'}});
      expect(find.textContaining('Gönderi paylaştı'), findsOneWidget);
      await unmount(tester);
      await pumpList({'text': '🔗 Gönderi paylaştı', 'share': {'type': 'POST', 'id': 5, 'available': true}});
      expect(find.textContaining('Gönderi paylaştı'), findsOneWidget);
      await unmount(tester);
      await pumpList({'text': 'Buna bak!', 'share': {'type': 'EVENT', 'id': 5, 'available': true}});
      expect(find.textContaining('Buna bak!'), findsOneWidget);
      expect(find.textContaining('Etkinlik paylaştı'), findsNothing);
      await unmount(tester);
      await pumpList({'text': 'https://bukampus.com.tr/s/n/8'});
      expect(find.textContaining('Haber paylaştı'), findsOneWidget);
      expect(find.textContaining('bukampus.com.tr'), findsNothing);
      await unmount(tester);
    });
  });

  group('sohbet listesi önizleme metni', () {
    testWidgets('share varsa nötr metin; yalnız bağlantı metniyse türden', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(buildApp(Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })));
      expect(sharePreviewText(ctx, {'share': {'type': 'POST', 'id': 1}}), 'Gönderi paylaştı');
      expect(sharePreviewText(ctx, {'share': {'type': 'REEL', 'id': 1}}), 'Reels paylaştı');
      expect(sharePreviewText(ctx, {'share': {'type': 'NEWS', 'id': 1}}), 'Haber paylaştı');
      expect(sharePreviewText(ctx, {'share': {'type': 'NEWS', 'id': 1, 'kind': 'DUYURU'}}), 'Duyuru paylaştı');
      expect(sharePreviewText(ctx, {'share': {'type': 'EVENT', 'id': 1}}), 'Etkinlik paylaştı');
      expect(sharePreviewText(ctx, {'text': 'https://bukampus.com.tr/s/e/3'}), 'Etkinlik paylaştı');
      expect(sharePreviewText(ctx, {'text': 'merhaba'}), isNull);
      expect(sharePreviewText(ctx, null), isNull);
    });
  });

  group('paylaş içeriği üreticileri', () {
    testWidgets('gönderi: başlık metin, yoksa yazar; video Reels; gizli yazar kısıtlı; kendi gönderim serbest', (tester) async {
      final s = makeSession(FakeBackend());
      Post post({String? text, bool video = false, bool priv = false, int author = 12, bool mine = false}) => Post(
            id: 5,
            author: PostAuthor(id: author, displayName: 'Yazar', isPrivate: priv),
            text: text,
            video: video ? const PostVideo(url: 'https://x/v.mp4', posterUrl: 'https://x/p.jpg') : null,
            mine: mine,
          );
      var c = shareContentForPost(s, post(text: 'Merhaba'));
      expect((c.type, c.title, c.source, c.restricted, c.authorId), (ShareType.post, 'Merhaba', 'Yazar', false, 12));
      c = shareContentForPost(s, post());
      expect((c.title, c.source), ('Yazar', null));
      expect(shareContentForPost(s, post(video: true)).type, ShareType.reel);
      expect(shareContentForPost(s, post(priv: true)).restricted, isTrue);
      final own = shareContentForPost(s, post(priv: true, mine: true));
      expect((own.restricted, own.authorId), (false, null));
    });

    test('haber ve etkinlik', () {
      final n = shareContentForNews({'id': 4, 'type': 'DUYURU', 'title': 'D', 'url': 'https://www.bingol.edu.tr/a'}, detail: {'imageUrl': '/files/x.jpg'});
      expect((n.type, n.id, n.isAnnouncement, n.imageUrl, n.source), (ShareType.news, 4, true, '/files/x.jpg', 'bingol.edu.tr'));
      final e = shareContentForEvent({'id': 9, 'title': 'Konser', 'communityName': 'Müzik Kulübü', 'coverUrl': '/files/c.jpg'});
      expect((e.type, e.title, e.source, e.imageUrl), (ShareType.event, 'Konser', 'Müzik Kulübü', '/files/c.jpg'));
    });

    test('yetkili başlıklar yalnız kendi sunucumuzun /api adreslerine gider', () {
      const h = {'Authorization': 'Bearer x'};
      expect(shareImageHeaders('/api/posts/media/3', h), h);
      expect(shareImageHeaders('https://evil.example/a.jpg', h), isNull);
      expect(shareImageHeaders('/files/a.jpg', h), isNull);
      expect(shareImageHeaders(null, h), isNull);
    });
  });

  group('ekranlarda Paylaş düğmesi', () {
    // Gönderi kartı / detay / haber / etkinlik / Reels düğmeleri ilgili ekran testlerinde (share_screens_test.dart).
    testWidgets('ShareIconButton: 44 dp+ dokunma hedefi ve erişilebilir ad', (tester) async {
      var n = 0;
      await tester.pumpWidget(buildApp(Center(child: ShareIconButton(onTap: () => n++))));
      final size = tester.getSize(find.byType(ShareIconButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      expect(find.bySemanticsLabel('Paylaş'), findsOneWidget);
      await tester.tap(find.byType(ShareIconButton));
      expect(n, 1);
    });
  });
}
