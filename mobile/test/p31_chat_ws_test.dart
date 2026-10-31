import 'dart:async';
import 'dart:typed_data';

import 'package:bu_kampus/core/api.dart' show ApiError;
import 'package:bu_kampus/core/cache/message_cache.dart';
import 'package:bu_kampus/core/outbox/outbox.dart';
import 'package:bu_kampus/core/realtime/chat_realtime.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/photo_autosave.dart';
import 'package:bu_kampus/features/chat/view_once_viewer.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// W1-H: WS ack/Outbox (T-093), tek soket (T-095), rebuild sayacı (T-096), kod noktası sınırı (T-097),
/// yer tutucu dili (T-034), moderatör silme (T-032), çıkarılan üye (T-031).

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _msg(int id, int sender, String text, {Map<String, dynamic>? extra}) => {
      'id': id,
      'conversationId': 1,
      'senderId': sender,
      'text': text,
      'createdAt': _iso(DateTime.now().subtract(Duration(minutes: 600 - id))),
      ...?extra,
    };

Map<String, dynamic> _page(List<Map<String, dynamic>> items, {int? next}) => {'items': items, 'nextCursor': next};

FakeBackend _backend(List<Map<String, dynamic>> msgs) => FakeBackend()
  ..on('/conversations/1/messages?size=30', _page(msgs))
  ..on('/conversations/1', {
    'conversation': {'id': 1},
    'members': [
      {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
      {'userId': 11, 'displayName': 'Ali Veli'},
    ],
  })
  ..on('/users/11/presence', {'online': true})
  ..on('/messages/reactions', {'emojis': <String>[]});

// 1x1 PNG
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, //
  0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

const _directConv = {
  'id': 1,
  'type': 'DIRECT',
  'title': 'Ali Veli',
  'peer': {'id': 11, 'displayName': 'Ali Veli'},
};

/// Bağlı görünen sahte gerçek zamanlı katman: gönderilenleri kaydeder (gerçek soket yok).
class _FakeRt extends ChatRealtime {
  _FakeRt(super.session);
  bool up = true;
  final sent = <String>[];

  @override
  bool get isConnected => up;

  @override
  bool sendMessage(int conversationId, String text, String clientId) {
    if (!up) return false;
    sent.add(clientId);
    debugMarkAwaitingAck(clientId);
    return true;
  }
}

ChatDetailPage _detail(Session s, {ChatRealtime? rt, Map<String, dynamic> conv = _directConv}) =>
    ChatDetailPage(session: s, connectRealtime: false, realtime: rt, conversation: conv);

Future<void> _pump(WidgetTester tester, Widget page) async {
  useScreen(tester, kPhoneMedium);
  await tester.pumpWidget(buildApp(page, size: kPhoneMedium));
  await settle(tester, const Duration(milliseconds: 600));
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).last, text);
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('sendButton')));
  await settle(tester, const Duration(milliseconds: 300));
}

Map<String, dynamic> _delivered(OutboxItem i) => {
      'id': 900,
      'conversationId': i.conversationId,
      'senderId': 1,
      'text': i.text,
      'clientId': i.clientId,
      'createdAt': _iso(DateTime.now()),
      'status': 'SENT',
    };

Widget _localized(Widget home, Locale locale) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

void main() {
  setUpAll(loadTestFonts);
  setUp(() => MessageCache.instance = MessageCache.memoryOnly());

  group('T-093 WS ack Outbox yedegi', () {
    testWidgets('ack gelmeden sayfa kapanirsa metin Outbox ta kalir; baglantida REST e gider', (tester) async {
      final s = makeSession(_backend([]));
      final sentRest = <String>[];
      final ob = Outbox(
          store: MemoryOutboxStore(),
          autoSchedule: false,
          sender: (i) async {
            sentRest.add(i.clientId);
            return _delivered(i);
          });
      s.api.outbox = ob;
      final rt = _FakeRt(s);
      await _pump(tester, _detail(s, rt: rt));

      await _type(tester, 'merhaba');
      expect(rt.sent, hasLength(1), reason: 'WS ile gönderildi');
      final cid = rt.sent.single;
      expect(ob.items.map((e) => e.clientId), [cid], reason: 'ack gelene kadar kalıcı yedek');
      expect(ob.items.single.text, 'merhaba');

      await unmount(tester); // ack yok, kullanıcı geri tuşuna bastı
      expect(ob.items.map((e) => e.clientId), [cid], reason: 'sayfa kapanınca kayıt kaybolmaz');
      expect(sentRest, isEmpty);

      await ob.nudge(); // bağlantı geri geldi / ack süresi doldu
      expect(sentRest, [cid]);
      expect(ob.items, isEmpty);
      ob.dispose();
    });

    testWidgets('ack sayfa kapaliyken gelse de Outbox kaydi silinir (cift gonderim olmaz)', (tester) async {
      final s = makeSession(_backend([]));
      final sentRest = <String>[];
      final ob = Outbox(
          store: MemoryOutboxStore(),
          autoSchedule: false,
          sender: (i) async {
            sentRest.add(i.clientId);
            return _delivered(i);
          });
      s.api.outbox = ob;
      final rt = _FakeRt(s);
      await _pump(tester, _detail(s, rt: rt));
      await _type(tester, 'selam');
      final cid = rt.sent.single;
      await unmount(tester);
      expect(ob.items, hasLength(1));

      rt.debugEmitMessage({..._msg(5, 1, 'selam'), 'clientId': cid});
      await tester.pump();
      expect(ob.items, isEmpty, reason: 'ChatRealtime ack ta kuyruğu temizler');
      await ob.nudge();
      expect(sentRest, isEmpty);
      ob.dispose();
    });

    testWidgets('baskasinin mesaji ya da clientId siz mesaj Outbox kaydini silmez', (tester) async {
      final s = makeSession(_backend([]));
      final ob = Outbox(store: MemoryOutboxStore(), autoSchedule: false, sender: (i) async => _delivered(i));
      s.api.outbox = ob;
      ob.enqueue(conversationId: 1, clientId: 'c-1', text: 'x');
      final rt = ChatRealtime(s);
      rt.debugEmitMessage({..._msg(5, 11, 'x'), 'clientId': 'c-1'}); // başka gönderen
      rt.debugEmitMessage(_msg(6, 1, 'y')); // clientId yok
      await tester.pump();
      expect(ob.items.map((e) => e.clientId), ['c-1']);
      ob.dispose();
    });

    testWidgets('konusmada gercek birikim varsa yeni mesaj WS ye atlamaz, siraya girer; WS ack bekleyen birikim sayilmaz',
        (tester) async {
      final s = makeSession(_backend([]));
      final ob = Outbox(
          store: MemoryOutboxStore(),
          autoSchedule: false,
          sender: (i) async => throw ApiError(0, 'NETWORK', ''));
      s.api.outbox = ob;
      ob.enqueue(conversationId: 1, clientId: 'c-old', text: 'eski bekleyen');
      final rt = _FakeRt(s);
      await _pump(tester, _detail(s, rt: rt));

      await _type(tester, 'yeni');
      expect(rt.sent, isEmpty, reason: 'sıra bozulmasın: WS ye atlama yok');
      expect(ob.items.map((e) => e.text), ['eski bekleyen', 'yeni']);
      await unmount(tester);
      ob.dispose();

      // Birikim yok, yalnız WS ack bekleyen öğe: ikinci mesaj yine WS ile gider.
      final s2 = makeSession(_backend([]));
      final ob2 = Outbox(store: MemoryOutboxStore(), autoSchedule: false, sender: (i) async => _delivered(i));
      s2.api.outbox = ob2;
      final rt2 = _FakeRt(s2);
      await _pump(tester, _detail(s2, rt: rt2));
      await _type(tester, 'bir');
      await _type(tester, 'iki');
      expect(rt2.sent, hasLength(2));
      expect(ob2.items, hasLength(2));
      await unmount(tester);
      ob2.dispose();
    });
  });

  group('T-033 tek gosterimlik: ag hatasinda BIR kez yeniden dene', () {
    const path = '/conversations/1/media/50';

    testWidgets('ag kopmasi: ikinci deneme basarili olunca goruntulenir (tam 2 istek)', (tester) async {
      final be = FakeBackend()..network(path);
      final s = makeSession(be);
      var consumed = 0;
      await tester.pumpWidget(buildApp(
          ViewOnceViewer(api: s.api, conversationId: 1, attachmentId: 50, onConsumed: () => consumed++)));
      await settle(tester, const Duration(milliseconds: 700));
      expect(be.count('GET $path'), 1, reason: 'ilk deneme; sunucunun 2 sn kuralı için bekleniyor');
      expect(consumed, 0);
      be.onBytes(path, _png);
      await settle(tester, const Duration(milliseconds: 2500));
      expect(be.count('GET $path'), 2);
      expect(find.byType(Image), findsOneWidget);
      expect(consumed, 1);
      await unmount(tester);
    });

    testWidgets('iki ag hatasi: hata kartı; uc kez denenmez', (tester) async {
      final be = FakeBackend()..network(path);
      final s = makeSession(be);
      await tester.pumpWidget(buildApp(ViewOnceViewer(api: s.api, conversationId: 1, attachmentId: 50)));
      await settle(tester, const Duration(milliseconds: 4000));
      expect(be.count('GET $path'), 2);
      expect(find.byType(Image), findsNothing);
      await unmount(tester);
    });

    testWidgets('410 yeniden denenmez', (tester) async {
      final be = FakeBackend()..fail(path, status: 410, code: 'MEDIA_VIEW_ONCE_EXPIRED');
      final s = makeSession(be);
      await tester.pumpWidget(buildApp(ViewOnceViewer(api: s.api, conversationId: 1, attachmentId: 50)));
      await settle(tester, const Duration(milliseconds: 3000));
      expect(be.count('GET $path'), 1);
      await unmount(tester);
    });
  });

  group('W1-G birlesimi: otomatik galeri kaydi yalniz birebir sohbette', () {
    final t0 = DateTime.now();
    late List<String> saved;
    late PhotoAutoSave prev;
    setUp(() {
      prev = PhotoAutoSave.instance;
      saved = [];
      PhotoAutoSave.instance = PhotoAutoSave(
        store: MemoryAutoSaveStore({'enabled': true, 'since': t0.subtract(const Duration(hours: 1)).millisecondsSinceEpoch}),
        supported: true,
        fetch: (u, h) async => Uint8List.fromList([1, 2, 3]),
        put: (b, name) async => saved.add(name),
      );
    });
    tearDown(() => PhotoAutoSave.instance = prev);

    Map<String, dynamic> photoMsg(int id) => _msg(id, 11, '', extra: {
          'createdAt': _iso(t0),
          'attachments': [
            {'id': 70 + id, 'kind': 'IMAGE', 'url': '/api/conversations/1/media/${70 + id}', 'contentType': 'image/jpeg', 'width': 10, 'height': 10},
          ],
        });

    Future<void> recvIn(WidgetTester tester, Map<String, dynamic> conv) async {
      final s = makeSession(_backend([]));
      final rt = ChatRealtime(s);
      await _pump(tester, _detail(s, rt: rt, conv: conv));
      rt.debugEmitMessage(photoMsg(1));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await settle(tester, const Duration(milliseconds: 300));
      await unmount(tester);
    }

    testWidgets('birebir: gelen fotograf kaydedilir', (tester) async {
      await recvIn(tester, _directConv);
      expect(saved, ['bu_kampus_71']);
    });

    for (final type in ['GROUP', 'CLUB', 'EVENT']) {
      testWidgets('$type: gelen fotograf kaydedilmez (direct=false)', (tester) async {
        await recvIn(tester, {'id': 1, 'type': type, 'title': 'Oda'});
        expect(saved, isEmpty);
      });
    }
  });

  group('T-095 tek soket', () {
    testWidgets('ChatTab ve ChatDetail oturumun realtime ini paylasir; yeni ChatRealtime kurmaz, dispose etmez', (tester) async {
      final be = _backend([_msg(1, 11, 'Selam')])..on('/conversations', {'items': <Object>[], 'nextCursor': null});
      final s = makeSession(be);
      final shared = s.realtime!;
      final before = ChatRealtime.debugInstanceCount;

      await _pump(tester, ChatTab(session: s)); // connectRealtime varsayılan true: paylaşılanı başlatmaz
      expect(ChatRealtime.debugInstanceCount, before, reason: 'sekme yeni soket kurmadı');
      await unmount(tester);

      await _pump(tester, ChatDetailPage(session: s, conversation: _directConv));
      expect(ChatRealtime.debugInstanceCount, before, reason: 'detay yeni soket kurmadı');
      expect(shared.isConnected, isFalse, reason: 'paylaşılanı kabuk başlatır; sayfa başlatmaz');
      await unmount(tester);

      // Sayfalar kapandı ama paylaşılan örnek canlı (dispose edilmedi): akışlar hâlâ açık.
      expect(() => shared.debugEmitMessage(_msg(2, 11, 'x')), returnsNormally);
      expect(identical(s.realtime, shared), isTrue);
    });
  });

  group('T-096 yeniden kurulum', () {
    testWidgets('ayni sunucu cevabi veren yoklama balonlari yeniden kurmaz; yeni mesaj yalniz gerektigi kadar kurar',
        (tester) async {
      final msgs = [for (var i = 12; i >= 1; i--) _msg(i, i.isEven ? 11 : 1, 'Mesaj $i')];
      final be = _backend(msgs)..on('/conversations/1/messages?after=12&size=30', _page([]));
      final s = makeSession(be);
      await _pump(tester, _detail(s));
      expect(find.text('Mesaj 12'), findsOneWidget);

      final base = ChatDetailPage.debugBubbleBuilds;
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 4)); // 12 yoklama turu (5. ve 10. turda son sayfa da çekilir)
      }
      expect(ChatDetailPage.debugBubbleBuilds, base, reason: 'değişmeyen veriyle hiçbir balon yeniden kurulmamalı');
      expect(be.count('after=12'), greaterThan(0), reason: 'yoklama gerçekten çalıştı');

      // Sunucuda yeni mesaj: yeniden kurulum olur, ama sınırlı.
      be
        ..on('/conversations/1/messages?after=12&size=30', _page([_msg(13, 11, 'Yeni geldi')]))
        ..on('/conversations/1/messages?after=13&size=30', _page([]));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Yeni geldi'), findsOneWidget);
      expect(ChatDetailPage.debugBubbleBuilds, greaterThan(base));
      await unmount(tester);
    });

    testWidgets('duzenlenen mesaj (ayni id, farkli metin) yoklamada guncellenir', (tester) async {
      final be = _backend([_msg(2, 11, 'Ikinci'), _msg(1, 1, 'Birinci')])..on('/conversations/1/messages?after=2&size=30', _page([]));
      final s = makeSession(be);
      await _pump(tester, _detail(s));
      be.on('/conversations/1/messages?size=30',
          _page([_msg(2, 11, 'Ikinci'), _msg(1, 1, 'Birinci duzenlendi', extra: {'edited': true})]));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 4));
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Birinci duzenlendi'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('T-097 kod noktasi siniri', () {
    // 😀 = 1 kod noktası, 2 UTF-16 birimi: mobil eskiden UTF-16 sayıyordu.
    final emoji = String.fromCharCode(0x1F600);

    testWidgets('1500 emoji (UTF-16 3000, kod noktasi 1500) gonderilir; sayac kod noktasi sayar', (tester) async {
      final text = List.filled(1500, emoji).join();
      expect(text.length, 3000);
      expect(text.runes.length, 1500);
      final be = _backend([])..on('/conversations/1/messages', _msg(7, 1, text));
      final s = makeSession(be);
      await _pump(tester, _detail(s));
      await tester.enterText(find.byType(TextField).last, text);
      await tester.pump();
      expect(find.text('1500/2000'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sendButton')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(be.count('POST /conversations/1/messages'), 1, reason: 'sessizce yutulmadı');
      expect(((be.bodies['POST /conversations/1/messages'] as Map)['text'] as String).runes.length, 1500);
      await unmount(tester);
    });

    testWidgets('2000 kod noktasi gider, 2001 gonderilmez ve sayac kirmizi uyari verir', (tester) async {
      final be = _backend([])..on('/conversations/1/messages', _msg(7, 1, 'x'));
      final s = makeSession(be);
      await _pump(tester, _detail(s));

      await tester.enterText(find.byType(TextField).last, List.filled(2001, emoji).join());
      await tester.pump();
      expect(find.text('2001/2000'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sendButton')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(be.count('POST /conversations/1/messages'), 0);

      await tester.enterText(find.byType(TextField).last, List.filled(2000, emoji).join());
      await tester.pump();
      expect(find.text('2000/2000'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sendButton')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(be.count('POST /conversations/1/messages'), 1);
      await unmount(tester);
    });

    testWidgets('duzenleme yolunda da sinir: 2001 kod noktasi PATCH edilmez', (tester) async {
      final be = _backend([_msg(3, 1, 'Eski metin')])..on('/messages/3', _msg(3, 1, 'x'));
      final s = makeSession(be);
      await _pump(tester, _detail(s));
      await tester.longPress(find.text('Eski metin'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Düzenle'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField).last, List.filled(2001, emoji).join());
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sendButton')));
      await settle(tester, const Duration(milliseconds: 300));
      expect(be.count('PATCH /messages/3'), 0);
      await unmount(tester);
    });
  });

  group('T-034 yer tutucu dili', () {
    final blocked = _msg(2, 11, 'Engellediğiniz kullanıcının mesajı gizlendi', extra: {'placeholderKind': 'BLOCKED'});
    final unreadable = _msg(3, 11, 'Bu mesaj görüntülenemiyor', extra: {'placeholderKind': 'UNREADABLE'});

    const expected = {
      'tr': ['Engellediğiniz kullanıcının mesajı gizlendi', 'Bu mesaj görüntülenemiyor'],
      'en': ['Message from a user you blocked is hidden', 'This message cannot be displayed'],
      'ar': ['رسالة مستخدم قمت بحظره مخفية', 'تعذّر عرض هذه الرسالة'],
    };

    for (final code in ['tr', 'en', 'ar']) {
      testWidgets('placeholderKind $code', (tester) async {
        useScreen(tester, kPhoneMedium);
        final s = makeSession(_backend([unreadable, blocked, _msg(1, 11, 'Normal')]));
        await tester.pumpWidget(_localized(_detail(s), Locale(code)));
        await settle(tester, const Duration(milliseconds: 600));
        expect(find.text(expected[code]![0]), findsOneWidget, reason: code);
        expect(find.text(expected[code]![1]), findsOneWidget, reason: code);
        await unmount(tester);
      });
    }

    testWidgets('removed=true + BLOCKED de uygulama dilinde (en)', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = _msg(2, 11, 'Engellediğiniz kullanıcının mesajı gizlendi', extra: {'placeholderKind': 'BLOCKED', 'removed': true});
      final s = makeSession(_backend([b]));
      await tester.pumpWidget(_localized(_detail(s), const Locale('en')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Message from a user you blocked is hidden'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('eski sunucu (placeholderKind yok): text oldugu gibi gosterilir, cokme yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final s = makeSession(_backend([
        _msg(2, 11, 'Bu mesaj görüntülenemiyor'),
        _msg(1, 11, 'Engellediğiniz kullanıcının mesajı gizlendi'),
      ]));
      await tester.pumpWidget(_localized(_detail(s), const Locale('en')));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Bu mesaj görüntülenemiyor'), findsOneWidget);
      expect(find.text('Engellediğiniz kullanıcının mesajı gizlendi'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('T-032 moderator silme', () {
    const room = {'id': 1, 'type': 'CLUB', 'title': 'Kulüp', 'communityId': 5, 'admin': false};

    testWidgets('canModerate=true: kulup odasinda baskasinin mesaji icin Mesaji sil var', (tester) async {
      final s = makeSession(_backend([_msg(2, 11, 'Baskasi yazdi')]));
      await _pump(tester, _detail(s, conv: {...room, 'canModerate': true}));
      await tester.longPress(find.text('Baskasi yazdi'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Mesajı sil'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('canModerate yok/false (eski sunucu): silme secenegi yok', (tester) async {
      final s = makeSession(_backend([_msg(2, 11, 'Baskasi yazdi')]));
      await _pump(tester, _detail(s, conv: room));
      await tester.longPress(find.text('Baskasi yazdi'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Mesajı sil'), findsNothing);
      expect(find.text('Şikâyet et'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('T-031 cikarilan uye', () {
    Future<NavigatorState> openOnHome(WidgetTester tester, Session s, {ChatRealtime? rt}) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(const Scaffold(body: Center(child: Text('ANA'))), size: kPhoneMedium));
      final nav = Navigator.of(tester.element(find.text('ANA')));
      unawaited(nav.push(MaterialPageRoute<bool>(builder: (_) => _detail(s, rt: rt))));
      await settle(tester, const Duration(milliseconds: 800));
      return nav;
    }

    testWidgets('onbellekli acilista 404 CONVERSATION_NOT_FOUND: sayfa kapanir, kayit silinir, kullanici bilgilenir',
        (tester) async {
      final be = _backend([])..fail('/conversations/1/messages?size=30', status: 404, code: 'CONVERSATION_NOT_FOUND');
      final s = makeSession(be);
      MessageCache.instance.saveMessages(1, [_msg(1, 11, 'Eski kayitli mesaj')]);
      expect(await MessageCache.instance.readMessages(1), isNotEmpty);

      await openOnHome(tester, s);
      expect(find.byType(ChatDetailPage), findsNothing);
      expect(find.text('ANA'), findsOneWidget);
      expect(find.text('Bu sohbetten çıkarıldınız.'), findsOneWidget);
      expect(await MessageCache.instance.readMessages(1), isEmpty, reason: 'cihazdaki kayıt silindi');
    });

    testWidgets('acik sohbette conversation-removed olayi sayfayi kapatir', (tester) async {
      final s = makeSession(_backend([_msg(1, 11, 'Selam')]));
      final rt = ChatRealtime(s);
      await openOnHome(tester, s, rt: rt);
      expect(find.byType(ChatDetailPage), findsOneWidget);

      rt.debugEmitMessageEvent({'type': 'conversation-removed', 'conversationId': 99}); // başka konuşma: etkisiz
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byType(ChatDetailPage), findsOneWidget);

      rt.debugEmitMessageEvent({'type': 'conversation-removed', 'conversationId': 1});
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(ChatDetailPage), findsNothing);
      expect(find.text('ANA'), findsOneWidget);
      expect(find.text('Bu sohbetten çıkarıldınız.'), findsOneWidget);
    });

    testWidgets('yoklama sirasinda 404: sessiz olu poll yerine sayfa kapanir', (tester) async {
      final be = _backend([_msg(1, 11, 'Selam')])..on('/conversations/1/messages?after=1&size=30', _page([]));
      final s = makeSession(be);
      await openOnHome(tester, s);
      expect(find.byType(ChatDetailPage), findsOneWidget);
      be.fail('/conversations/1/messages?after=1&size=30', status: 404, code: 'CONVERSATION_NOT_FOUND');
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 4));
      }
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.byType(ChatDetailPage), findsNothing);
    });
  });
}
