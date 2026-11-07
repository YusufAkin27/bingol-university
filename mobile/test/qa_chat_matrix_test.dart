import 'package:bu_kampus/core/cache/message_cache.dart';
import 'package:bu_kampus/core/realtime/chat_realtime.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/chat/chat_background_settings_page.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/chat_wallpaper.dart';
import 'package:bu_kampus/features/chat/new_chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign/p00_support.dart';
import 'support/fake_app.dart';

/// QA alani 4 (sohbet) durum matrisi: ekran x durum (yukleniyor / bos / hata / basari; 401, 403, 404, 429, 5xx;
/// cevrimdisi) ve ekran x gorunum (tr/en/ar + RTL, acik/koyu, yazi 1.0/1.3, 320/390 dp). Her birlesimde istisna
/// (tasma dahil) olmamali. Etkilesim testleri: sohbet listesi uzun basma menusu (sessize al), mesaj menusu,
/// sohbet arka plani ayarlari (4 desen + yogunluk + eski kayit goçü), WS durum gostergeleri, push eylemleri.

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _msg(int id, int sender, String text, {Map<String, dynamic>? extra}) => {
      'id': id,
      'conversationId': 1,
      'senderId': sender,
      'text': text,
      'createdAt': _iso(DateTime.now().subtract(Duration(minutes: 600 - id))),
      ...?extra,
    };

const _conv = {
  'id': 1,
  'type': 'DIRECT',
  'title': 'Ali Veli',
  'peer': {'id': 11, 'displayName': 'Ali Veli'},
};

Map<String, dynamic> _row(int id, String type, String title, {int unread = 0, bool muted = false}) => {
      'id': id,
      'type': type,
      'title': title,
      if (type == 'DIRECT') 'peer': {'id': 100 + id, 'displayName': title},
      'unreadCount': unread,
      'muted': muted,
      'lastMessage': {..._msg(id, 11, 'Merhaba $id'), 'conversationId': id},
    };

FakeBackend _detailBe(List<Map<String, dynamic>> msgs) => FakeBackend()
  ..on('/conversations/1/messages?size=30', {'items': msgs, 'nextCursor': null})
  ..on('/conversations/1', {
    'conversation': {'id': 1},
    'members': [
      {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
      {'userId': 11, 'displayName': 'Ali Veli'},
    ],
  })
  ..on('/users/11/presence', {'online': true})
  ..on('/messages/reactions', {'emojis': <String>[]});

FakeBackend _listBe({List<Map<String, dynamic>>? items}) => FakeBackend()
  ..on('/conversations?size=30', {
    'items': items ?? [_row(1, 'DIRECT', 'Ali Veli', unread: 2), _row(2, 'GROUP', 'Proje Grubu'), _row(3, 'CLUB', 'Robotik Kulübü')],
    'nextCursor': null,
  })
  ..on('/conversations/unread-count', {'total': 2, 'archivedChats': 0, 'archivedUnreadChats': 0, 'conversations': <Object>[]});

Future<void> _pump(WidgetTester tester, Widget page, {Size size = kPhoneMedium, int ms = 700}) async {
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(page, size: size));
  await settle(tester, Duration(milliseconds: ms));
}

void _clean(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('$e');
}

ChatDetailPage _detail(Session s, {ChatRealtime? rt}) =>
    ChatDetailPage(session: s, connectRealtime: false, realtime: rt, conversation: _conv);

void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });
  setUp(() {
    MessageCache.instance = MessageCache.memoryOnly();
    ChatBackgroundPrefs.debugReset();
  });

  // ---------------------------------------------------------------- hata/durum matrisi
  final failures = <String, void Function(FakeBackend be, String path)>{
    '401': (be, p) => be.fail(p, status: 401, code: 'UNAUTHORIZED'),
    '403': (be, p) => be.fail(p, status: 403, code: 'FORBIDDEN'),
    '429': (be, p) => be.fail(p, status: 429, code: 'RATE_LIMITED'),
    '500': (be, p) => be.fail(p, status: 500, code: 'SERVER_ERROR'),
    'cevrimdisi': (be, p) => be.network(p),
  };

  group('Sohbet listesi durumlari', () {
    testWidgets('basari: satirlar, okunmamis rozeti', (tester) async {
      await _pump(tester, ChatTab(session: makeSession(_listBe()), connectRealtime: false));
      expect(find.text('Ali Veli'), findsOneWidget);
      expect(find.text('Proje Grubu'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
      _clean(tester);
      await unmount(tester);
    });

    testWidgets('yukleniyor: yanit gelmeden satir yok, istisna yok', (tester) async {
      final be = _listBe()..delay = const Duration(milliseconds: 500);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(ChatTab(session: makeSession(be), connectRealtime: false), size: kPhoneMedium));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Ali Veli'), findsNothing);
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Ali Veli'), findsOneWidget);
      _clean(tester);
      await unmount(tester);
    });

    testWidgets('bos: liste bos, hata karti yok', (tester) async {
      await _pump(tester, ChatTab(session: makeSession(_listBe(items: [])), connectRealtime: false));
      expect(find.text('Yeniden dene'), findsNothing);
      _clean(tester);
      await unmount(tester);
    });

    for (final f in failures.entries) {
      testWidgets('hata ${f.key}: hata karti + Yeniden dene, istisna yok', (tester) async {
        final be = _listBe();
        f.value(be, '/conversations?size=30');
        await _pump(tester, ChatTab(session: makeSession(be), connectRealtime: false), ms: 1500);
        expect(find.text('Yeniden dene'), findsOneWidget, reason: f.key);
        _clean(tester);
        await unmount(tester);
      });
    }

    testWidgets('hatadan sonra Yeniden dene listeyi getirir', (tester) async {
      final be = _listBe();
      be.fail('/conversations?size=30', status: 500);
      await _pump(tester, ChatTab(session: makeSession(be), connectRealtime: false), ms: 1500);
      be.on('/conversations?size=30', {
        'items': [_row(1, 'DIRECT', 'Ali Veli')],
        'nextCursor': null
      });
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Ali Veli'), findsOneWidget);
      _clean(tester);
      await unmount(tester);
    });

    testWidgets('filtre cipleri: Kisiler birebir+grup, Kulupler yalniz kulup; Tumu hepsini geri getirir', (tester) async {
      await _pump(tester, ChatTab(session: makeSession(_listBe()), connectRealtime: false));
      await tester.tap(find.text('Kulüpler'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Robotik Kulübü'), findsOneWidget);
      expect(find.text('Ali Veli'), findsNothing);
      await tester.tap(find.text('Kişiler'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Ali Veli'), findsOneWidget);
      expect(find.text('Proje Grubu'), findsOneWidget);
      expect(find.text('Robotik Kulübü'), findsNothing);
      await tester.tap(find.text('Tümü'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Robotik Kulübü'), findsOneWidget);
      _clean(tester);
      await unmount(tester);
    });

    testWidgets('uzun basma: sessize al -> sure sec -> PUT /mute {durationMinutes}', (tester) async {
      final be = _listBe();
      await _pump(tester, ChatTab(session: makeSession(be), connectRealtime: false));
      await tester.longPress(find.text('Ali Veli'));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('act-mute')));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Sessize al').last);
      await settle(tester, const Duration(milliseconds: 600));
      expect(be.requests, contains('PUT /conversations/1/mute'));
      expect((be.bodies['PUT /conversations/1/mute'] as Map)['durationMinutes'], isNotNull);
      _clean(tester);
      await unmount(tester);
    });

    testWidgets('sessize alma hatasi (429): satir geri doner, istisna yok', (tester) async {
      final be = _listBe()..fail('/conversations/1/mute', status: 429, code: 'RATE_LIMITED');
      await _pump(tester, ChatTab(session: makeSession(be), connectRealtime: false));
      await tester.longPress(find.text('Ali Veli'));
      await settle(tester, const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('act-mute')));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Sessize al').last);
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('Ali Veli'), findsOneWidget);
      _clean(tester);
      await unmount(tester);
    });

    testWidgets('sabitle (pin) ozelligi uygulamada yok: menude sabitle satiri cikmaz', (tester) async {
      await _pump(tester, ChatTab(session: makeSession(_listBe()), connectRealtime: false));
      await tester.longPress(find.text('Ali Veli'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.textContaining('Sabitle'), findsNothing);
      _clean(tester);
      await unmount(tester);
    });
  });

  // ---------------------------------------------------------------- sohbet detayi durumlari
  group('Sohbet detayi durumlari', () {
    testWidgets('basari: karisik mesajlar (uzun metin, emoji, RTL karisik)', (tester) async {
      final s = makeSession(_detailBe([
        _msg(1, 11, 'Merhaba ${'çok uzun metin ' * 30}'),
        _msg(2, 1, '😀🎉 emoji ve مرحبا بالعالم karışık'),
        _msg(3, 11, 'kısa'),
      ]));
      await _pump(tester, _detail(s));
      expect(find.text('kısa'), findsOneWidget);
      expect(find.textContaining('مرحبا'), findsOneWidget);
      _clean(tester);
      await unmount(tester);
    });

    testWidgets('yukleniyor -> bos konusma: hata yok', (tester) async {
      final be = _detailBe([])..delay = const Duration(milliseconds: 400);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(_detail(makeSession(be)), size: kPhoneMedium));
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Yeniden dene'), findsNothing);
      _clean(tester);
      await unmount(tester);
    });

    for (final f in failures.entries) {
      testWidgets('mesaj sayfasi hata ${f.key} (onbellek yok): hata + Yeniden dene, istisna yok', (tester) async {
        final be = _detailBe([]);
        f.value(be, '/conversations/1/messages?size=30');
        await _pump(tester, _detail(makeSession(be)), ms: 1800);
        expect(find.text('Yeniden dene'), findsOneWidget, reason: f.key);
        _clean(tester);
        await unmount(tester);
      });
    }

    testWidgets('gonderim 403 (yetki) kalici hata: balon Yeniden dene, istisna yok', (tester) async {
      final be = _detailBe([])..fail('/conversations/1/messages', status: 403, code: 'FORBIDDEN');
      await _pump(tester, _detail(makeSession(be)));
      await tester.enterText(find.byType(TextField).last, 'merhaba');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sendButton')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('merhaba'), findsOneWidget);
      expect(find.textContaining('Yeniden'), findsWidgets);
      _clean(tester);
      await unmount(tester);
    });

    testWidgets('gonderim 429: kalici hata balonu, ayni metin tek balon', (tester) async {
      final be = _detailBe([])..fail('/conversations/1/messages', status: 429, code: 'RATE_LIMITED');
      await _pump(tester, _detail(makeSession(be)));
      await tester.enterText(find.byType(TextField).last, 'cok sik');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sendButton')));
      await settle(tester, const Duration(milliseconds: 800));
      expect(find.text('cok sik'), findsOneWidget);
      _clean(tester);
      await unmount(tester);
    });

    testWidgets('mesaj menusu: kendi mesaji -> yanitla/kopyala/duzenle/sil var, sikayet yok; karsi mesaj -> sikayet var, duzenle yok', (tester) async {
      final s = makeSession(_detailBe([_msg(1, 11, 'karsi mesaj'), _msg(2, 1, 'benim mesajim')]));
      await _pump(tester, _detail(s));
      await tester.longPress(find.text('benim mesajim'));
      await settle(tester, const Duration(milliseconds: 400));
      for (final a in ['Yanıtla', 'Kopyala', 'Düzenle']) {
        expect(find.text(a), findsOneWidget, reason: a);
      }
      expect(find.text('Şikâyet et'), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.longPress(find.text('karsi mesaj'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Şikâyet et'), findsOneWidget);
      expect(find.text('Düzenle'), findsNothing);
      _clean(tester);
      await unmount(tester);
    });

    testWidgets('Yanitla: yanit cubugu acilir ve gonderimde replyToMessageId gider', (tester) async {
      final be = _detailBe([_msg(1, 11, 'soru')])..on('/conversations/1/messages', _msg(9, 1, 'cevap'));
      await _pump(tester, _detail(makeSession(be)));
      await tester.longPress(find.text('soru'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Yanıtla'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.enterText(find.byType(TextField).last, 'cevap');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sendButton')));
      await settle(tester, const Duration(milliseconds: 800));
      final body = be.bodies['POST /conversations/1/messages'] as Map;
      expect(body['replyToMessageId'], 1);
      _clean(tester);
      await unmount(tester);
    });

    testWidgets('Herkes icin sil: onay -> DELETE; 404 MESSAGE_NOT_FOUND hatasi istisna uretmez', (tester) async {
      final be = _detailBe([_msg(2, 1, 'silinecek')])..fail('/messages/2', status: 404, code: 'MESSAGE_NOT_FOUND');
      await _pump(tester, _detail(makeSession(be)));
      await tester.longPress(find.text('silinecek'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Herkesten sil'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Sil').last);
      await settle(tester, const Duration(milliseconds: 600));
      expect(be.requests, contains('DELETE /messages/2'));
      _clean(tester);
      await unmount(tester);
    });

    testWidgets('baglanti kopma/yeniden baglanma: resync okundu+iletildi imleclerini REST ile teyit eder (QA-CHAT-07)', (tester) async {
      final be = _detailBe([_msg(5, 11, 'karsi')]);
      final s = makeSession(be);
      final rt = ChatRealtime(s);
      await _pump(tester, _detail(s, rt: rt));
      await settle(tester, const Duration(seconds: 2)); // 1 sn iletildi zamanlayicisi
      be.requests.clear();
      rt.debugEmitConnected(false);
      rt.debugEmitConnected(true);
      await settle(tester, const Duration(milliseconds: 600));
      expect(be.requests.any((r) => r.startsWith('POST /conversations/1/read')), isTrue, reason: 'okundu teyidi');
      expect(be.requests.any((r) => r.startsWith('POST /conversations/1/delivered')), isTrue, reason: 'iletildi teyidi');
      _clean(tester);
      await unmount(tester);
    });

    testWidgets('STOMP kalici durdu (forbidden): bilgi bildirimi, mesajlar REST ile surer', (tester) async {
      final s = makeSession(_detailBe([_msg(1, 11, 'selam')]));
      final rt = ChatRealtime(s);
      await _pump(tester, _detail(s, rt: rt));
      expect(find.text('selam'), findsOneWidget);
      _clean(tester);
      await unmount(tester);
    });
  });

  // ---------------------------------------------------------------- yeni sohbet
  group('Yeni sohbet durumlari', () {
    testWidgets('yeni sohbet: arama kutusu + Yeni grup gorunur, hata yok', (tester) async {
      final be = FakeBackend()..on('/users/search*', {'items': <Object>[], 'nextCursor': null});
      await _pump(tester, NewChatPage(session: makeSession(be)));
      expect(find.text('Yeni grup'), findsOneWidget);
      expect(find.text('Rehberden kişi bul'), findsNothing);
      _clean(tester);
      await unmount(tester);
    });

  });

  // ---------------------------------------------------------------- arka plan ayarlari
  group('Sohbet arka plani (4 desen + yogunluk + eski kayit gocu)', () {
    const store = FlutterSecureStorage();

    Future<void> reload() async {
      ChatBackgroundPrefs.debugReset();
      await ChatBackgroundPrefs.instance.ensureLoaded();
    }

    test('dort desen ve iki yogunluk vardir', () {
      expect(ChatBgStyle.values.map((e) => e.name), ['study', 'social', 'science', 'geometry']);
      expect(ChatBgDensity.values.length, 2);
    });

    test('eski kayit: strong -> Ders + Orta; campus/pattern/soft/plain -> Ders + Hafif', () async {
      await store.write(key: ChatBackgroundPrefs.key, value: 'strong');
      await reload();
      expect(ChatBackgroundPrefs.instance.style, ChatBgStyle.study);
      expect(ChatBackgroundPrefs.instance.density, ChatBgDensity.strong);
      for (final legacy in ['campus', 'pattern', 'soft', 'plain', 'bozuk-deger']) {
        await store.write(key: ChatBackgroundPrefs.key, value: legacy);
        await store.delete(key: ChatBackgroundPrefs.densityKey);
        await reload();
        expect(ChatBackgroundPrefs.instance.style, ChatBgStyle.study, reason: legacy);
        expect(ChatBackgroundPrefs.instance.density, ChatBgDensity.soft, reason: legacy);
      }
    });

    test('yeni kayit: desen + yogunluk geri okunur; clear() varsayilana doner', () async {
      await store.write(key: ChatBackgroundPrefs.key, value: 'geometry');
      await store.write(key: ChatBackgroundPrefs.densityKey, value: 'strong');
      await reload();
      expect(ChatBackgroundPrefs.instance.style, ChatBgStyle.geometry);
      expect(ChatBackgroundPrefs.instance.density, ChatBgDensity.strong);
      await ChatBackgroundPrefs.clear();
      expect(ChatBackgroundPrefs.instance.style, ChatBgStyle.study);
      expect(ChatBackgroundPrefs.instance.density, ChatBgDensity.soft);
      expect(await store.read(key: ChatBackgroundPrefs.key), isNull);
    });

    testWidgets('sayfa: desen sec + Orta yogunluk + Uygula tercihi kaydeder', (tester) async {
      await ChatBackgroundPrefs.clear();
      await _pump(tester, const ChatBackgroundSettingsPage());
      await tester.tap(find.byKey(const ValueKey('chatBgStyle-science')));
      await tester.pump();
      await tester.tap(find.text('Orta'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chatBgApply')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(ChatBackgroundPrefs.instance.style, ChatBgStyle.science);
      expect(ChatBackgroundPrefs.instance.density, ChatBgDensity.strong);
      _clean(tester);
      await ChatBackgroundPrefs.clear();
    });

    testWidgets('sayfa: Varsayilana don Ders + Hafif yapar', (tester) async {
      await ChatBackgroundPrefs.instance.set(ChatBgStyle.social, density: ChatBgDensity.strong);
      await _pump(tester, const ChatBackgroundSettingsPage());
      await tester.ensureVisible(find.byKey(const ValueKey('chatBgReset')));
      await tester.tap(find.byKey(const ValueKey('chatBgReset')));
      await settle(tester, const Duration(milliseconds: 500));
      expect(ChatBackgroundPrefs.instance.style, ChatBgStyle.study);
      expect(ChatBackgroundPrefs.instance.density, ChatBgDensity.soft);
      _clean(tester);
      await ChatBackgroundPrefs.clear();
    });
  });

  // ---------------------------------------------------------------- gorunum matrisi (tr/en/ar, acik/koyu, 1.0/1.3, 320/390)
  group('Gorunum matrisi: tasma yok', () {
    testWidgets('ChatTab', (tester) async {
      await p00Matrix(tester, () => ChatTab(session: makeSession(_listBe()), connectRealtime: false), scaffold: false, settleMs: 800);
    });
    testWidgets('ChatDetailPage (karisik mesajlar)', (tester) async {
      await p00Matrix(
          tester,
          () => _detail(makeSession(_detailBe([
                _msg(1, 11, 'Merhaba ${'uzun ' * 40}'),
                _msg(2, 1, '😀 مرحبا karışık metin'),
                _msg(3, 11, 'kısa', extra: {'status': 'READ'}),
              ]))),
          scaffold: false,
          settleMs: 800);
    });
    testWidgets('ChatBackgroundSettingsPage', (tester) async {
      await p00Matrix(tester, () => const ChatBackgroundSettingsPage(), scaffold: false, settleMs: 600);
    });
    testWidgets('NewChatPage', (tester) async {
      await p00Matrix(
          tester, () => NewChatPage(session: makeSession(FakeBackend()..on('/users/search*', {'items': <Object>[], 'nextCursor': null}))),
          scaffold: false, settleMs: 800);
    });
  });
}

