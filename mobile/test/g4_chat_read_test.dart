import 'package:bu_kampus/core/cache/message_cache.dart';
import 'package:bu_kampus/core/push/active_conversation.dart';
import 'package:bu_kampus/core/realtime/chat_realtime.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign/p00_support.dart';
import 'support/fake_app.dart';

/// G4: "Görüldü" yalnız sunucu `receipt`/`status=READ` bilgisine dayanır (I4-01), okundu imleci yalnız ön plan + alt uç
/// iken gider (I4-02), yanıt alıntısı bulunamazsa bildirim (I4-06), açık sohbette liste sayacı artmaz (I4-12).
/// UYARI: iki gerçek hesap/cihazla uçtan uca okuma doğrulaması bu testlerle YAPILAMAZ; sunucu olayları taklit edilir.

String _iso(int minsAgo) => DateTime.now().subtract(Duration(minutes: minsAgo + 300)).toUtc().toIso8601String();

Map<String, dynamic> _msg(int id, int sender, String text, {String? status, Map<String, dynamic>? extra}) => {
      'id': id,
      'conversationId': 1,
      'senderId': sender,
      'text': text,
      'createdAt': _iso(200 - id),
      if (status != null) 'status': status,
      ...?extra,
    };

Map<String, dynamic> _conv(String type) => {
      'id': 1,
      'type': type,
      'title': type == 'DIRECT' ? 'Ali Veli' : 'Grup',
      if (type == 'DIRECT') 'peer': {'id': 11, 'displayName': 'Ali Veli'},
    };

FakeBackend _be(List<Map<String, dynamic>> msgs) => FakeBackend()
  ..on('/conversations/1/messages?size=30', {'items': msgs, 'nextCursor': null})
  ..on('/conversations/1', {
    'conversation': {'id': 1},
    'members': [
      {'userId': 1, 'displayName': 'Ayşe'},
      {'userId': 11, 'displayName': 'Ali'},
      {'userId': 12, 'displayName': 'Veli'},
    ],
  })
  ..on('/users/11/presence', {'online': true})
  ..on('/messages/reactions', {'emojis': <String>[]});

Future<void> _pump(WidgetTester tester, Widget page) async {
  useScreen(tester, kPhoneMedium);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BuTheme.light(),
    locale: const Locale('tr'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: page,
  ));
  await settle(tester, const Duration(milliseconds: 700));
}

final _lines = find.byKey(const ValueKey('msg-status-line'));

void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });
  setUp(() {
    MessageCache.instance = MessageCache.memoryOnly();
    debugResetChatSeen();
  });

  for (final type in ['GROUP', 'DIRECT']) {
    testWidgets('I4-01 $type: eski read-receipts olayı (tek üye / gölge engel) Görüldü göstermez', (tester) async {
      final s = makeSession(_be([_msg(5, 1, 'merhaba', status: 'SENT')]));
      final rt = ChatRealtime(s);
      await _pump(tester, ChatDetailPage(session: s, connectRealtime: false, realtime: rt, conversation: _conv(type)));
      expect(find.descendant(of: _lines, matching: find.textContaining('Gönderildi')), findsOneWidget);
      rt.debugEmitReadReceipt(1, 12, 5); // tek üye okudu (ya da gölge engelli alıcı)
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.descendant(of: _lines, matching: find.textContaining('Görüldü')), findsNothing);
      expect(find.descendant(of: _lines, matching: find.textContaining('Gönderildi')), findsOneWidget);
      // Sunucunun hesapladığı READ (grupta politika / birebirde karşı taraf) gelince Görüldü çıkar.
      rt.debugEmitMessageEvent({'type': 'receipt', 'conversationId': 1, 'kind': 'read', 'upToMessageId': 5, 'status': 'READ'});
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.descendant(of: _lines, matching: find.textContaining('Görüldü')), findsOneWidget);
    });
  }

  testWidgets('I4-02: arka plandayken gelen mesaj okundu sayılmaz; öne gelince gider', (tester) async {
    final be = _be([_msg(5, 11, 'selam')]);
    final s = makeSession(be);
    final rt = ChatRealtime(s);
    await _pump(tester, ChatDetailPage(session: s, connectRealtime: false, realtime: rt, conversation: _conv('DIRECT')));
    final base = be.count('POST /conversations/1/read');
    expect(base, 1); // açılışta mevcut mesaj okundu
    for (final st in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(st);
    }
    rt.debugEmitMessage(_msg(6, 11, 'arka planda geldi'));
    await settle(tester, const Duration(milliseconds: 400));
    expect(be.count('POST /conversations/1/read'), base);
    for (final st in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(st);
    }
    await settle(tester, const Duration(milliseconds: 600));
    expect(be.count('POST /conversations/1/read'), base + 1);
    expect((be.bodies['POST /conversations/1/read'] as Map)['lastMessageId'], 6);
  });

  testWidgets('I4-02: yukarı kaydırılmışken gelen mesaj okunmamış kalır; alta inince okundu gider', (tester) async {
    final msgs = [for (var i = 40; i >= 1; i--) _msg(i, 11, 'mesaj numara $i uzunca bir metin')];
    final be = _be(msgs);
    final s = makeSession(be);
    final rt = ChatRealtime(s);
    await _pump(tester, ChatDetailPage(session: s, connectRealtime: false, realtime: rt, conversation: _conv('DIRECT')));
    final base = be.count('POST /conversations/1/read');
    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await settle(tester, const Duration(milliseconds: 400));
    rt.debugEmitMessage(_msg(41, 11, 'yeni gelen'));
    await settle(tester, const Duration(milliseconds: 400));
    expect(be.count('POST /conversations/1/read'), base);
    await tester.drag(find.byType(ListView).first, const Offset(0, -2500));
    await settle(tester, const Duration(seconds: 6));
    expect(be.count('POST /conversations/1/read'), base + 1);
    expect((be.bodies['POST /conversations/1/read'] as Map)['lastMessageId'], 41);
  });

  testWidgets('I4-06: silinmiş/yüklenemeyen yanıt hedefinde kullanıcıya bildirim gösterilir', (tester) async {
    final be = _be([
      _msg(30, 1, 'yanit', extra: {
        'replyTo': {'id': 3, 'senderId': 11, 'text': 'silinmis alinti'}
      }),
    ])
      ..on('/conversations/1/messages?size=30&around=3', {'items': <Object>[], 'nextCursor': null});
    final s = makeSession(be);
    await _pump(tester, ChatDetailPage(session: s, connectRealtime: false, realtime: ChatRealtime(s), conversation: _conv('DIRECT')));
    await tester.tap(find.text('silinmis alinti'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.textContaining('artık mevcut değil'), findsOneWidget);
  });

  group('sohbet listesi', () {
    FakeBackend listBe() {
      final be = FakeBackend();
      be.handlers.add((req, path) {
        if (req.method == 'GET' && path == '/conversations/unread-count') {
          return const FakeResult.json({'total': 3, 'mutedTotal': 0, 'conversations': [], 'archivedChats': 0, 'archivedUnreadChats': 0});
        }
        if (req.method == 'GET' && path == '/conversations') {
          return FakeResult.json({
            'items': [
              {
                'id': 1,
                'type': 'DIRECT',
                'title': 'Ali Veli',
                'peer': {'id': 11, 'displayName': 'Ali Veli'},
                'unreadCount': 3,
                'lastMessage': _msg(103, 11, 'Son mesaj burada'),
              }
            ],
            'nextCursor': null,
          });
        }
        return null;
      });
      return be;
    }

    Future<Session> pumpList(WidgetTester tester) async {
      useScreen(tester, kPhoneMedium);
      final s = makeSession(listBe());
      s.realtime = ChatRealtime(s);
      await tester.pumpWidget(buildApp(ChatTab(session: s, connectRealtime: false), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      return s;
    }

    testWidgets('I4-12: açık (ön plandaki) sohbette gelen mesaj sayaç artırmaz; başka sohbette artırır', (tester) async {
      final s = await pumpList(tester);
      expect(find.text('3'), findsWidgets);
      ActiveConversation.instance.enter(1);
      addTearDown(() => ActiveConversation.instance.leave(1));
      s.realtime!.debugEmitMessage(_msg(104, 11, 'ekranda gorulen'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('4'), findsNothing);
      ActiveConversation.instance.leave(1);
      s.realtime!.debugEmitMessage(_msg(105, 11, 'gorulmeyen'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('4'), findsWidgets);
    });

    testWidgets('I4-09: canlı okundu olayı listede Görüldü yazar', (tester) async {
      final s = await pumpList(tester);
      s.realtime!.debugEmitMessage(_msg(104, 1, 'benim giden'));
      await settle(tester, const Duration(milliseconds: 400));
      s.realtime!.debugEmitMessageEvent({'type': 'receipt', 'conversationId': 1, 'kind': 'read', 'upToMessageId': 104, 'status': 'READ'});
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.textContaining('Görüldü'), findsWidgets);
    });
  });
}
