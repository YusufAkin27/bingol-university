import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/forum/presentation/pages/topic_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_forum.dart';
import 'support/fake_forum_comments.dart';
import 'support/visual_b.dart';

/// Konu detayı görsel duman matrisi (MB-B): açık/koyu x 320/390/430 dp x yazı ölçeği 1/1.5/2 -> taşma ve düzen
/// istisnası yok. `VIS_SHOTS=1` ile PNG'ler `build/shots/b/` altına yazılır.
void main() {
  setUpAll(loadVisualFonts);

  Future<void> scene(
    WidgetTester tester,
    String name, {
    required Brightness br,
    required Size size,
    required double scale,
    bool thread = false,
    bool sheet = false,
    bool rtl = false,
  }) async {
    captureErrors();
    final b = FakeBackend();
    final f = fakeForum(b, count: 3);
    f.byId(500)!['title'] = 'Yemekhanede öğle yemeği sırası neden bu kadar uzun, çözüm önerisi var mı?';
    f.byId(500)!['body'] = 'Son haftalarda öğle arası yemekhane kuyruğu 40 dakikaya kadar çıkıyor. https://bingol.edu.tr/sks ' * 3;
    final c = fakeForumComments(b, f);
    c.byId(1)!['topicAuthor'] = true;
    c.byId(1)!['body'] = 'Birinci yorum metni biraz daha uzun olsun diye genişletildi, iki üç satıra yayılsın. ' * 2;
    final s = makeSession(b);
    final Widget page;
    if (thread) {
      // Zincir ekranı: kök c3 (Benim yanıtım) ve yanıtı.
      page = _ThreadHost(session: s);
    } else {
      page = TopicDetailPage(session: s, topicId: 500);
    }
    await pumpVisual(tester, page, brightness: br, size: size, scale: scale, rtl: rtl, settleFor: const Duration(milliseconds: 1500));
    if (sheet) {
      await tester.tap(find.byKey(const ValueKey('commentMore-1')));
      await settle(tester, const Duration(milliseconds: 700));
    }
    await shot(tester, name);
    expectNoErrors(tester);
    await unmount(tester);
  }

  for (final br in Brightness.values) {
    for (final size in kPhoneSizes) {
      for (final sc in const [1.0, 1.5, 2.0]) {
        testWidgets('konu detayi | ${br.name} ${size.width.toInt()} x$sc', (tester) async {
          await scene(tester, 'topic_${br.name}_${size.width.toInt()}_$sc', br: br, size: size, scale: sc);
        });
      }
    }
  }

  for (final br in Brightness.values) {
    testWidgets('eylem sayfasi | ${br.name}', (tester) async {
      await scene(tester, 'sheet_${br.name}', br: br, size: kPhoneMedium, scale: 1.0, sheet: true);
    });
    testWidgets('yanit zinciri ekrani | ${br.name}', (tester) async {
      await scene(tester, 'thread_${br.name}', br: br, size: kPhoneMedium, scale: 1.0, thread: true);
    });
  }

  testWidgets('RTL (Arapca yon) | yerlesim bozulmaz', (tester) async {
    await scene(tester, 'topic_rtl', br: Brightness.light, size: kPhoneMedium, scale: 1.0, rtl: true);
  });
}

/// Zincir ekranı sahnesi: derin yoruma (c4) bağlantıyla açılır, konu ekranı zincir ekranını kendisi iter.
class _ThreadHost extends StatelessWidget {
  const _ThreadHost({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) => TopicDetailPage(session: session, topicId: 500, commentId: 4);
}
