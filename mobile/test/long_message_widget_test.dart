import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

// Uzun mesaj balonu: 400 + "Devamını gör" (+700), "Daha az göster", mesaj kimliğine bağlı durum.

String _words(int n, [String prefix = 'kelime']) {
  final b = StringBuffer();
  var i = 0;
  while (b.length < n) {
    b.write('$prefix${i++} ');
  }
  return b.toString().substring(0, n);
}

Map<String, dynamic> _msg(int id, int sender, String text) => {
      'id': id,
      'conversationId': 1,
      'senderId': sender,
      'text': text,
      'createdAt': DateTime.now().subtract(Duration(minutes: 600 - id)).toUtc().toIso8601String(),
    };

/// Bubble içinde çizilen metin parçalarının düz metni (RichText), `Devamını gör` bağlantısı dahil.
List<String> _plains(WidgetTester tester, {String contains = ''}) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText())
    .where((s) => s.contains(contains))
    .toList();

class _Harness extends StatefulWidget {
  const _Harness(this.text, {this.mine = false, this.highlight});
  final String text;
  final bool mine;
  final String? highlight;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int? limit;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          child: MessageBubble(
            message: {
              'id': 5,
              'senderId': widget.mine ? 1 : 11,
              'text': widget.text,
              'createdAt': DateTime.now().toUtc().toIso8601String(),
              if (widget.mine) 'status': 'READ',
            },
            mine: widget.mine,
            senderName: null,
            replyName: null,
            seen: false,
            authHeaders: const {},
            onMenu: () {},
            onRetry: () {},
            onOpenImage: (_) {},
            onReact: (_) {},
            highlight: widget.highlight,
            expandLimit: limit,
            onExpandLimit: (l) => setState(() => limit = l),
          ),
        ),
      );
}

Future<void> _pumpBubble(WidgetTester tester, String text, {bool mine = false, Brightness b = Brightness.light, String? highlight}) async {
  useScreen(tester, const Size(390, 12000));
  await tester.pumpWidget(buildApp(_Harness(text, mine: mine, highlight: highlight), brightness: b, size: kPhoneMedium));
  await tester.pump(const Duration(milliseconds: 50));
}

/// "Daha az göster" bağlantısının ekrandaki merkezi (RenderParagraph son karakter kutularından); önce görünür kaydırılır.
Future<Offset> _linkCenter(WidgetTester tester) async {
  final rp = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byKey(const ValueKey('longMsgLess')), matching: find.byType(RichText)).first);
  final len = rp.text.toPlainText().length;
  final boxes = rp.getBoxesForSelection(TextSelection(baseOffset: len - 4, extentOffset: len));
  rp.showOnScreen(rect: boxes.last.toRect(), duration: Duration.zero);
  await tester.pump();
  return rp.localToGlobal(boxes.last.toRect().center);
}

void main() {
  setUpAll(loadTestFonts);

  for (final n in [100, 400]) {
    testWidgets('$n karakter: bağlantı yok, tam metin', (tester) async {
      await _pumpBubble(tester, _words(n));
      expect(find.text('Devamını gör'), findsNothing);
      expect(find.byKey(const ValueKey('longMsgMore')), findsNothing);
      expect(_plains(tester, contains: 'kelime0').single, _words(n));
      await unmount(tester);
    });
  }

  for (final n in [401, 800, 1100, 1101, 2000, 5000, 10000]) {
    testWidgets('$n karakter: 400 + Devamını gör; basışlar +700; tamamı açılınca Daha az göster', (tester) async {
      final text = _words(n);
      await _pumpBubble(tester, text);
      expect(tester.takeException(), isNull);
      String shown() => _plains(tester, contains: 'kelime0').single;
      expect(shown(), contains('Devamını gör'));
      expect(shown().length, lessThan(kLongMsgBaseWithLink));
      var presses = 0;
      var prev = shown().length;
      while (find.byKey(const ValueKey('longMsgMore')).evaluate().isNotEmpty) {
        await tester.ensureVisible(find.byKey(const ValueKey('longMsgMore')));
        await tester.tapAt(tester.getTopLeft(find.byKey(const ValueKey('longMsgMore'))) + const Offset(12, 12));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        presses++;
        final now = shown().length;
        expect(now, greaterThan(prev));
        // Her basışta en çok ~700 karakter + bağlantı eklenir.
        expect(now - prev, lessThanOrEqualTo(700 + 40));
        prev = now;
        expect(presses, lessThan(20));
      }
      expect(presses, ((n - 400) / 700).ceil());
      expect(shown(), contains('Daha az göster'));
      expect(shown().replaceAll('  Daha az göster', ''), text);
      // Tamamı açıkken metne dokunmak KISALTMAZ (yanlışlıkla başa dönmesin).
      await tester.ensureVisible(find.byKey(const ValueKey('longMsgLess')));
      await tester.tapAt(tester.getTopLeft(find.byKey(const ValueKey('longMsgLess'))) + const Offset(12, 12));
      await tester.pump(const Duration(milliseconds: 300));
      expect(shown(), contains('Daha az göster'), reason: 'metne dokunmak mesajı kısaltmamalı');
      expect(shown().replaceAll('  Daha az göster', ''), text);
      // Daralt: yalnız "Daha az göster" bağlantısına dokunulunca.
      await tester.tapAt(await _linkCenter(tester));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(shown(), contains('Devamını gör'));
      expect(shown().length, lessThan(kLongMsgBaseWithLink));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }

  testWidgets('Türkçe + emoji + çok satırlı + bağlantılı 1200 karakter: tasma yok, giden/gelen, koyu/açık', (tester) async {
    final text = [
      for (var i = 0; i < 40; i++) 'Öğrenci işleri çağrı 😀 👨‍👩‍👧‍👦 satır $i https://www.bingol.edu.tr/duyurular/$i',
    ].join('\n');
    for (final mine in [false, true]) {
      for (final b in Brightness.values) {
        await _pumpBubble(tester, text, mine: mine, b: b);
        expect(find.byKey(const ValueKey('longMsgMore')), findsOneWidget);
        await tester.ensureVisible(find.byKey(const ValueKey('longMsgMore')));
        await tester.tapAt(tester.getTopLeft(find.byKey(const ValueKey('longMsgMore'))) + const Offset(12, 12));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        // Saat sağ altta kalır: balonun içinde 'HH:MM' metni var.
        expect(find.textContaining(RegExp(r'\d\d:\d\d')), findsOneWidget);
        await unmount(tester);
      }
    }
  });

  testWidgets('RTL: uzun metin bağlantısı çalışır', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(
        Directionality(textDirection: TextDirection.rtl, child: _Harness(_words(900, 'مرحبا'))),
        brightness: Brightness.light,
        size: kPhoneMedium));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const ValueKey('longMsgMore')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('longMsgMore')));
    await tester.tapAt(tester.getTopLeft(find.byKey(const ValueKey('longMsgMore'))) + const Offset(12, 12));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('arama eşleşmesi kesilen kısımda ise görünür kalır', (tester) async {
    final text = '${_words(2000)} HEDEFSOZ son';
    await _pumpBubble(tester, text, highlight: 'hedefsoz');
    expect(_plains(tester, contains: 'HEDEFSOZ'), isNotEmpty);
    await unmount(tester);
  });

  testWidgets('yanıt alıntısı en çok 3 satır, üç noktalı', (tester) async {
    useScreen(tester, kPhoneMedium);
    final reply = {'id': 3, 'senderId': 11, 'text': _words(600), 'deleted': false};
    await tester.pumpWidget(buildApp(
        MessageBubble(
          message: {
            'id': 6,
            'senderId': 1,
            'text': 'cevap',
            'replyTo': reply,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
          },
          mine: true,
          senderName: null,
          replyName: 'Mehmet',
          seen: false,
          authHeaders: const {},
          onMenu: () {},
          onRetry: () {},
          onOpenImage: (_) {},
          onReact: (_) {},
        ),
        brightness: Brightness.light,
        size: kPhoneMedium));
    await tester.pump(const Duration(milliseconds: 50));
    final q = tester.widget<Text>(find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith('kelime0')));
    expect(q.maxLines, 3);
    expect(q.overflow, TextOverflow.ellipsis);
    await unmount(tester);
  });

  // ---- Sayfa düzeyi: durum mesaj kimliğine bağlı ----

  testWidgets('sayfa: bir mesajı açmak diğerini açmaz; yeni mesaj gelince durum başka mesaja kaymaz', (tester) async {
    final be = FakeBackend()
      ..on('/conversations/1/messages?size=30', {
        'items': [
          _msg(22, 11, _words(1500, 'bbb')),
          _msg(21, 1, _words(900, 'aaa')),
          _msg(20, 11, 'kısa'),
        ],
        'nextCursor': null,
      })
      ..on('/conversations/1', {
        'conversation': {'id': 1},
        'members': [
          {'userId': 1, 'displayName': 'Ayşe'},
          {'userId': 11, 'displayName': 'Mehmet'},
        ],
      })
      ..on('/users/11/presence', {'online': true})
      ..on('/messages/reactions', {'emojis': ['👍']});
    useScreen(tester, const Size(390, 3200));
    await tester.pumpWidget(buildApp(
        ChatDetailPage(
          session: makeSession(be),
          connectRealtime: false,
          conversation: const {
            'id': 1,
            'type': 'DIRECT',
            'title': 'Mehmet',
            'peer': {'id': 11, 'displayName': 'Mehmet'},
          },
        ),
        brightness: Brightness.light,
        size: const Size(390, 3200)));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('longMsgMore')), findsNWidgets(2));
    final aaaBefore = _plains(tester, contains: 'aaa0').single.length;
    final bbbBefore = _plains(tester, contains: 'bbb0').single.length;
    // Yalnız 'bbb' mesajının bağlantısına bas.
    final bbbLink = find.descendant(
        of: find.byType(MessageBubble).first, matching: find.byKey(const ValueKey('longMsgMore')));
    expect(bbbLink, findsOneWidget);
    await tester.tap(bbbLink);
    await tester.pump(const Duration(milliseconds: 300));
    expect(_plains(tester, contains: 'bbb0').single.length, greaterThan(bbbBefore));
    expect(_plains(tester, contains: 'aaa0').single.length, aaaBefore, reason: 'diğer mesaj etkilenmemeli');
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}

/// 400 karakter + '… ' + 'Devamını gör' payı.
const int kLongMsgBaseWithLink = 400 + 20;
