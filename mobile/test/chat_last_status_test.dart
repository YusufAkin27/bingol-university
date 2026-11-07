import 'package:bu_kampus/core/cache/message_cache.dart';
import 'package:bu_kampus/core/realtime/chat_realtime.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:bu_kampus/features/chat/message_status_icon.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign/p00_support.dart';
import 'support/fake_app.dart';

/// Instagram Direct düzeni: durum yazısı YALNIZ konuşmanın en güncel mesajında ve o benimse çıkar.
/// Oturum kullanıcısı 1, karşı taraf 11. Gerçek iki cihaz/hesap testi ayrıca gereklidir.

String _iso(int minsAgo) => DateTime.now().subtract(Duration(minutes: minsAgo + 300)).toUtc().toIso8601String();

Map<String, dynamic> _msg(int id, int sender, String text, {String? status, Map<String, dynamic>? extra}) => {
      'id': id,
      'conversationId': 1,
      'senderId': sender,
      'text': text,
      'createdAt': _iso(100 - id),
      if (status != null) 'status': status,
      ...?extra,
    };

const _conv = {
  'id': 1,
  'type': 'DIRECT',
  'title': 'Ali Veli',
  'peer': {'id': 11, 'displayName': 'Ali Veli'},
};

FakeBackend _be(List<Map<String, dynamic>> msgs, {int? next}) => FakeBackend()
  ..on('/conversations/1/messages?size=30', {'items': msgs, 'nextCursor': next})
  ..on('/conversations/1', {
    'conversation': {'id': 1},
    'members': [
      {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
      {'userId': 11, 'displayName': 'Ali Veli'},
    ],
  })
  ..on('/users/11/presence', {'online': true})
  ..on('/messages/reactions', {'emojis': <String>[]});

Future<void> _pump(WidgetTester tester, Widget page,
    {Brightness b = Brightness.light, Size size = kPhoneMedium, Locale? locale}) async {
  useScreen(tester, size);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BuTheme.light(),
    darkTheme: BuTheme.dark(),
    themeMode: b == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    locale: locale ?? const Locale('tr'),
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
Finder _t(String t) => find.descendant(of: _lines, matching: find.text(t));
Finder _bubbleOf(String text) => find.ancestor(of: find.text(text), matching: find.byType(MessageBubble)).first;

void main() {
  setUpAll(() async {
    await loadTestFonts();
    mockSecureStorage();
  });
  setUp(() => MessageCache.instance = MessageCache.memoryOnly());

  Widget page(FakeBackend be, {ChatRealtime? rt}) {
    final s = makeSession(be);
    return ChatDetailPage(session: s, connectRealtime: false, realtime: rt ?? ChatRealtime(s), conversation: _conv);
  }

  testWidgets('(a) tek giden mesaj: Gönderildi, okununca Görüldü; balonda tik yok', (tester) async {
    final be = _be([_msg(5, 1, 'merhaba', status: 'SENT')]);
    final s = makeSession(be);
    final rt = ChatRealtime(s);
    await _pump(tester, ChatDetailPage(session: s, connectRealtime: false, realtime: rt, conversation: _conv));
    expect(_t('Gönderildi'), findsOneWidget);
    expect(find.byType(MessageStatusIcon), findsNothing);
    rt.debugEmitMessageEvent({'type': 'receipt', 'conversationId': 1, 'kind': 'read', 'upToMessageId': 5, 'status': 'READ'});
    await settle(tester, const Duration(milliseconds: 400));
    expect(_t('Görüldü'), findsOneWidget);
    expect(_t('Gönderildi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('(b) 20 giden mesaj: yalnız en sonda yazı', (tester) async {
    final msgs = [for (var i = 20; i >= 1; i--) _msg(i, 1, 'm$i', status: 'READ')];
    await _pump(tester, page(_be(msgs)));
    expect(_lines, findsOneWidget);
    expect(_t('Görüldü'), findsOneWidget);
    expect(find.descendant(of: _bubbleOf('m20'), matching: _lines), findsOneWidget);
  });

  testWidgets('(c) yeni giden mesaj: eskinin yazısı kalkar, yenide Gönderildi', (tester) async {
    final s = makeSession(_be([_msg(5, 1, 'ilk', status: 'READ')]));
    final rt = ChatRealtime(s);
    await _pump(tester, ChatDetailPage(session: s, connectRealtime: false, realtime: rt, conversation: _conv));
    expect(_t('Görüldü'), findsOneWidget);
    rt.debugEmitMessage(_msg(6, 1, 'ikinci', status: 'SENT'));
    await settle(tester, const Duration(milliseconds: 400));
    expect(_lines, findsOneWidget);
    expect(_t('Gönderildi'), findsOneWidget);
    expect(_t('Görüldü'), findsNothing);
    expect(find.descendant(of: _bubbleOf('ikinci'), matching: _lines), findsOneWidget);
  });

  testWidgets('(d) karşıdan mesaj gelince hiçbirinde yazı yok', (tester) async {
    final s = makeSession(_be([_msg(5, 1, 'ilk', status: 'READ')]));
    final rt = ChatRealtime(s);
    await _pump(tester, ChatDetailPage(session: s, connectRealtime: false, realtime: rt, conversation: _conv));
    expect(_lines, findsOneWidget);
    rt.debugEmitMessage(_msg(6, 11, 'cevap'));
    await settle(tester, const Duration(milliseconds: 400));
    expect(_lines, findsNothing);
  });

  testWidgets('(e) başarısız son mesaj: Gönderilemedi + yeniden dene; durum yazısı yok', (tester) async {
    final be = _be([_msg(1, 11, 'selam')])..fail('/conversations/1/messages', status: 500, code: 'SERVER_ERROR');
    await _pump(tester, page(be));
    await tester.enterText(find.byType(TextField), 'giden');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Gönder'));
    await settle(tester, const Duration(seconds: 2));
    expect(_lines, findsNothing);
    expect(find.textContaining('Yeniden dene'), findsOneWidget);
    expect(find.byType(MessageStatusIcon), findsNothing);
  });

  testWidgets('(f1) eski sayfa yüklenince onlarda yazı çıkmaz', (tester) async {
    final be = _be([_msg(10, 11, 'son karsi'), _msg(9, 1, 'benim', status: 'READ')], next: 9)
      ..on('/conversations/1/messages?size=30&before=9', {
        'items': [_msg(8, 1, 'eski benim', status: 'READ'), _msg(7, 1, 'daha eski', status: 'READ')],
        'nextCursor': null,
      });
    await _pump(tester, page(be));
    expect(_lines, findsNothing); // en son mesaj karşının
    await tester.drag(find.byType(ListView).first, const Offset(0, 900));
    await settle(tester, const Duration(milliseconds: 800));
    expect(_lines, findsNothing);
  });

  testWidgets('(f2) around penceresi: gerçek en güncel mesaj bellekte değilse yazı yok', (tester) async {
    final be = _be([
      _msg(30, 1, 'son benim', status: 'READ'),
      _msg(29, 1, 'yanit', status: 'READ', extra: {
        'replyTo': {'id': 3, 'senderId': 11, 'text': 'cok eski alinti'}
      }),
    ])
      ..on('/conversations/1/messages?size=30&around=3', {
        'items': [_msg(4, 1, 'pencere son', status: 'READ'), _msg(3, 11, 'cok eski')],
        'nextCursor': null,
      });
    await _pump(tester, page(be));
    expect(_lines, findsOneWidget);
    be.delay = const Duration(milliseconds: 1500);
    await tester.tap(find.text('cok eski alinti'));
    await tester.pump(const Duration(milliseconds: 1700));
    // Pencere yüklendi, tamamlayıcı after henüz dönmedi: 'pencere son' en güncel DEĞİL -> yazı yok.
    expect(find.text('pencere son'), findsOneWidget);
    expect(_lines, findsNothing);
    be.delay = Duration.zero;
    await settle(tester, const Duration(seconds: 4));
  });

  for (final b in Brightness.values) {
    for (final loc in ['tr', 'en', 'ar']) {
      testWidgets('(g) $loc ${b.name}: yazı balonun altında, taşma yok', (tester) async {
        final be = _be([
          _msg(1, 11, 'selam'),
          _msg(2, 1, 'Merhaba nasılsın bugün hava çok güzel değil mi arkadaşım', status: 'READ'),
        ]);
        await _pump(tester, page(be), b: b, size: kPhoneSmall, locale: Locale(loc));
        expect(_lines, findsOneWidget);
        final expected = {'tr': 'Görüldü', 'en': 'Seen', 'ar': 'تمت المشاهدة'}[loc]!;
        expect(_t(expected), findsOneWidget);
        final msg = find.textContaining('Merhaba nasılsın');
        final line = tester.getRect(_lines);
        expect(line.top, greaterThanOrEqualTo(tester.getRect(msg).bottom));
        expect(line.left, greaterThanOrEqualTo(0));
        expect(line.right, lessThanOrEqualTo(kPhoneSmall.width));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
