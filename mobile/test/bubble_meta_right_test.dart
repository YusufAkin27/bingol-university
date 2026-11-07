import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

// Saat+tik balonun SAĞ ALT kenarında: yanıt alıntısı/gönderen adı balonu genişletse bile metnin yanında kalmaz.

Widget _bubble(Map<String, dynamic> extra, {String text = 'V', bool mine = true, String? senderName}) => Padding(
      padding: const EdgeInsets.all(8),
      child: MessageBubble(
        message: {
          'id': 5,
          'senderId': mine ? 1 : 11,
          'text': text,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          if (mine) 'status': 'DELIVERED',
          ...extra,
        },
        mine: mine,
        senderName: senderName,
        replyName: 'Melisa Çiçek',
        authHeaders: const {},
        onMenu: () {},
        onRetry: () {},
        onOpenImage: (_) {},
        onReact: (_) {},
      ),
    );

void main() {
  setUpAll(loadTestFonts);

  testWidgets('yanıtlı tek karakterli mesaj: saat+tik alıntı kutusunun sağ kenarında (balonun sağ altı)', (tester) async {
    useScreen(tester, const Size(390, 800));
    await tester.pumpWidget(buildApp(
        _bubble({
          'replyTo': {'id': 1, 'senderId': 11, 'text': 'Bugün kampüste misin? Sana bir şey soracağım, akşam müsait misin?'},
        }),
        size: kPhoneMedium));
    await tester.pump(const Duration(milliseconds: 50));
    final tick = find.textContaining(RegExp(r'\d\d:\d\d'), findRichText: true);
    expect(tick, findsOneWidget);
    expect(find.byKey(const ValueKey('msg-status-DELIVERED')), findsNothing);
    final quote = find.byType(IntrinsicHeight).first;
    final tickRect = tester.getRect(tick);
    final quoteRect = tester.getRect(quote);
    expect(quoteRect.right - tickRect.right, lessThan(8), reason: 'tik balonun sağ kenarında olmalı');
    // metin sol tarafta, meta sağ altta: tik metnin ALTINDA ya da sağında, ama balonun sağ yarısında
    expect(tickRect.center.dx, greaterThan(quoteRect.center.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tek karakterli düz mesaj: saat+tik aynı satırda, balonun sağ kenarında', (tester) async {
    useScreen(tester, const Size(390, 800));
    await tester.pumpWidget(buildApp(_bubble(const {}), size: kPhoneMedium));
    await tester.pump(const Duration(milliseconds: 50));
    final tick = tester.getRect(find.textContaining(RegExp(r'\d\d:\d\d'), findRichText: true));
    final v = tester.getRect(find.text('V'));
    expect(tick.left, greaterThan(v.right), reason: 'saat metnin sağında');
    expect((tick.center.dy - v.center.dy).abs(), lessThan(12), reason: 'aynı satır');
    expect(tester.takeException(), isNull);
  });

  testWidgets('grup gönderen adı balonu genişletince de saat+tik sağ altta', (tester) async {
    useScreen(tester, const Size(390, 800));
    await tester.pumpWidget(buildApp(
        _bubble(const {}, mine: false, senderName: 'Melisa Çiçek Yılmaz Demirkıran'),
        size: kPhoneMedium));
    await tester.pump(const Duration(milliseconds: 50));
    final name = tester.getRect(find.text('Melisa Çiçek Yılmaz Demirkıran'));
    final box = tester.getRect(find.byType(IntrinsicWidth).first);
    expect(box.right - name.right, lessThan(8));
    expect(tester.takeException(), isNull);
  });
}
