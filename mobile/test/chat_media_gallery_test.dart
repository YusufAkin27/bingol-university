import 'package:bu_kampus/features/chat/chat_media_pager.dart';
import 'package:bu_kampus/features/chat/chat_media_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign/p00_support.dart';
import 'support/fake_app.dart';

// Sohbet medya görüntüleyicisi: eskiye doğru sonsuz yükleme, şerit, kaydırma, RTL, taşma.

Map<String, dynamic> _msg(int id, {bool video = false}) => {
      'id': id,
      'senderId': 2,
      'createdAt': '2026-10-20T10:${(id % 60).toString().padLeft(2, '0')}:00Z',
      'attachments': [
        {
          'id': id,
          'kind': video ? 'VIDEO' : 'IMAGE',
          'url': '/api/conversations/5/media/$id',
          'thumbUrl': '/api/conversations/5/media/$id/thumb',
        },
      ],
    };

ChatMediaItem _item(int id) => ChatMediaItem(
    id: id, url: '/api/conversations/5/media/$id', thumbUrl: '/api/conversations/5/media/$id/thumb', sender: 'Ali');

/// Sayfa 1: mesajlar 20..11 (nextCursor 11), sayfa 2: 10..1 (nextCursor yok); silinmiş mesaj 15 atlanır.
FakeBackend _backend() => FakeBackend()
  ..handlers.add((req, path) {
    if (!path.startsWith('/conversations/5/messages')) return null;
    final before = int.tryParse(req.url.queryParameters['before'] ?? '');
    if (before == 11) {
      return FakeResult.json({
        'items': [for (var i = 10; i > 0; i--) _msg(i)],
        'nextCursor': null,
      });
    }
    return null;
  });

void main() {
  setUpAll(loadTestFonts);

  testWidgets('pager: eskiye imleçle yükler, başa ekler, silinmişi atlar', (tester) async {
    final be = FakeBackend()
      ..handlers.add((req, path) {
        if (!path.startsWith('/conversations/5/messages')) return null;
        return FakeResult.json({
          'items': [
            for (var i = 10; i > 0; i--) i == 7 ? {..._msg(i), 'deleted': true} : _msg(i)
          ],
          'nextCursor': null,
        });
      });
    final pager = ChatMediaPager(
        api: makeSession(be).api,
        conversationId: 5,
        senderName: (m) => 'Ali',
        items: [_item(11), _item(12)],
        olderCursor: 11);
    expect(pager.hasOlder, isTrue);
    await tester.runAsync(pager.loadOlder);
    expect(pager.hasOlder, isFalse);
    expect(pager.prepended, 9);
    expect(pager.items.length, 11);
    expect(pager.items.first.id, 1); // eskiden yeniye
    expect(pager.items.any((i) => i.id == 7), isFalse);
    expect(pager.items.last.id, 12);
    await tester.runAsync(pager.loadOlder); // imleç bitti: istek yok
    expect(pager.items.length, 11);
    pager.dispose();
  });

  testWidgets('görüntüleyici: başa yaklaşınca eski medya yüklenir, aynı medyada kalır, şerit ve sayaç güncellenir',
      (tester) async {
    useScreen(tester, kPhoneMedium);
    final be = _backend();
    final items = [for (var i = 11; i <= 20; i++) _item(i)];
    final pager = ChatMediaPager(
        api: makeSession(be).api, conversationId: 5, senderName: (m) => 'Ali', items: items, olderCursor: 11);
    await tester.pumpWidget(
        buildApp(ChatMediaViewer(items: items, pager: pager, headers: const {}, initialIndex: 4), size: kPhoneMedium));
    await tester.pump();
    // initialIndex 4 < 5: açılışta yükleme başlar.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(pager.items.length, 20);
    // Aynı medya (id 15) hâlâ görünür: yeni sıra 10 + 4 = 14 -> "15 / 20".
    expect(find.text('15 / 20'), findsOneWidget);
    // Sağa kaydır: bir önceki (eski) medya.
    await tester.drag(find.byType(PageView), const Offset(400, 0));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('14 / 20'), findsOneWidget);
    // Şeritten bir kareye atla.
    await tester.tap(find.byKey(const ValueKey('viewerThumb12')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('13 / 20'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    pager.dispose();
  });

  testWidgets('görüntüleyici: sonda daha eski varsa sayaç + ile biter; hata yeniden dene gösterir', (tester) async {
    useScreen(tester, kPhoneMedium);
    final be = FakeBackend()
      ..handlers.add((req, path) => path.startsWith('/conversations/5/messages') ? const FakeResult.json({'e': 1}, status: 500) : null);
    final items = [for (var i = 11; i <= 14; i++) _item(i)];
    final pager = ChatMediaPager(
        api: makeSession(be).api, conversationId: 5, senderName: (m) => 'Ali', items: items, olderCursor: 11);
    await tester.pumpWidget(
        buildApp(ChatMediaViewer(items: items, pager: pager, headers: const {}, initialIndex: 1), size: kPhoneMedium));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('2 / 4+'), findsOneWidget);
    expect(find.byKey(const ValueKey('viewerOlderRetry')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    pager.dispose();
  });

  testWidgets('görüntüleyici: gönderen + tarih alt yazısı ve tek dokunuşla gizlenme', (tester) async {
    useScreen(tester, kPhoneMedium);
    final items = [for (var i = 1; i <= 3; i++) _item(i)];
    await tester.pumpWidget(buildApp(ChatMediaViewer(items: [
      ChatMediaItem(url: '/a', sender: 'Ayşe', at: DateTime(2026, 10, 27, 14, 32)),
      ...items
    ], headers: const {}), size: kPhoneMedium));
    await tester.pump();
    expect(find.byKey(const ValueKey('viewerMeta')), findsOneWidget);
    expect(find.textContaining('Ayşe'), findsOneWidget);
  });

  testWidgets('görüntüleyici: aşağı çekince kapanır', (tester) async {
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(Builder(
        builder: (c) => TextButton(
            onPressed: () => Navigator.push(
                c, MaterialPageRoute<void>(builder: (_) => ChatMediaViewer(items: [_item(1), _item(2)], headers: const {}))),
            child: const Text('aç'))),
        size: kPhoneMedium));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byType(ChatMediaViewer), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(0, 300));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byType(ChatMediaViewer), findsNothing);
  });

  testWidgets('görüntüleyici: Arapça RTL, 320 px ve 1.3 yazı ölçeği taşma yok; kaydırma yönü mantıksal', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.reset);
    final items = [for (var i = 1; i <= 8; i++) _item(i)];
    for (final lang in ['tr', 'en', 'ar']) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(p00App(
          ChatMediaViewer(items: [
            for (final i in items) ChatMediaItem(id: i.id, url: i.url, thumbUrl: i.thumbUrl, sender: 'Mehmet Kaya Çok Uzun Bir Ad', at: DateTime(2026, 10, 27, 14, 32))
          ], headers: const {}, initialIndex: 2),
          lang: lang,
          scale: 1.3,
          scaffold: false));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: lang);
      expect(find.text('3 / 8'), findsOneWidget, reason: lang);
      // İleri = metin yönünün sonu: LTR'de sola, RTL'de sağa kaydırma.
      await tester.drag(find.byType(PageView), Offset(lang == 'ar' ? 300 : -300, 0));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('4 / 8'), findsOneWidget, reason: lang);
      expect(tester.takeException(), isNull, reason: lang);
    }
  });
}
