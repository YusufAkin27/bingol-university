// A15 denetimi: arayuz seviyesi — bozuk onbellek, onbellek yok + 5xx ekran durumu, baglanti kapisi.
import 'dart:convert';
import 'dart:io';

import 'package:bu_kampus/core/cache/message_cache.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_media.dart';

Future<void> real(WidgetTester t, [int ms = 60]) async {
  await t.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  await t.pump(const Duration(milliseconds: 100));
}

List<String> texts(WidgetTester t) => [
      for (final w in t.widgetList<Text>(find.byType(Text)))
        if ((w.data ?? '').trim().isNotEmpty) w.data!.trim()
    ];

void main() {
  setUpAll(loadTestFonts);

  testWidgets('U1 bozuk (tip hatali) onbellek kaydi varken sohbet acilir mi? Sunucu mesaji gorunmeli', (tester) async {
    useScreen(tester, kPhoneMedium);
    final dir = await tester.runAsync(() => Directory.systemTemp.createTemp('a15_ui_'));
    addTearDown(() {
      try {
        dir!.deleteSync(recursive: true);
      } catch (_) {}
    });
    File('${dir!.path}/c1.json').writeAsStringSync(jsonEncode({
      'v': 99,
      'm': [
        {'id': '7', 'text': 'bozuk', 'senderId': 11}
      ]
    }));
    MessageCache.instance = MessageCache(dirProvider: () async => dir, flushDelay: const Duration(milliseconds: 5));
    final be = FakeBackend()
      ..on('/conversations/1/messages?size=30', {
        'items': [
          {'id': 5, 'conversationId': 1, 'senderId': 11, 'text': 'SUNUCU MESAJI', 'createdAt': '2026-10-30T10:00:00Z', 'status': 'SENT'}
        ],
        'nextCursor': null
      })
      ..on('/conversations/1', {
        'conversation': {'id': 1},
        'members': [
          {'userId': 1, 'displayName': 'Ayse'},
          {'userId': 11, 'displayName': 'Ali'}
        ]
      })
      ..on('/users/11/presence', {'online': true})
      ..on('/messages/reactions', {'emojis': <String>[]});
    final s = makeSession(be);
    await tester.pumpWidget(buildApp(
        ChatDetailPage(
          session: s,
          connectRealtime: false,
          mediaLibrary: FakeMediaLibrary.photos(1),
          ensureAccess: (c, p, {rationale}) async => true,
          conversation: const {
            'id': 1,
            'type': 'DIRECT',
            'title': 'Ali',
            'peer': {'id': 11, 'displayName': 'Ali'}
          },
        ),
        size: kPhoneMedium));
    // Disk okumasi + ag yaniti gercek zaman ister: mesaj gorunene kadar (en cok ~3 sn) beklenir.
    for (var i = 0; i < 40 && find.text('SUNUCU MESAJI').evaluate().isEmpty; i++) {
      await real(tester);
    }
    final shown = find.text('SUNUCU MESAJI').evaluate().isNotEmpty;
    // ignore: avoid_print
    print('U1 sunucu mesaji gorundu mu: $shown ; hata: ${tester.takeException().runtimeType}');
    expect(shown, isTrue, reason: 'bozuk onbellek sohbeti acilmaz hale getirmemeli');
  });

  for (final c in <(String, Widget Function(FakeBackend))>[
    ('ChatTab', (b) => ChatTab(session: makeSession(b), connectRealtime: false)),
    ('MenuPage', (b) => MenuPage(session: makeSession(b))),
    ('HomeTab', (b) => Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {}))),
  ]) {
    testWidgets('U2 onbellek YOK + sunucu 500: ${c.$1} ekrani ne gosteriyor', (tester) async {
      useScreen(tester, kPhoneMedium);
      final be = FakeBackend();
      for (final p in ['/conversations*', '/menu*', '/news*', '/events*', '/me/*', '/announcements*', '/discover*', '/posts*', '/users/*', '/polls*', '/notifications*', '/communities*']) {
        be.fail(p, status: 500, code: 'SERVER_ERROR', message: '');
      }
      await tester.pumpWidget(buildApp(c.$2(be), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 3));
      final t = texts(tester);
      final hasRetry = find.byType(TextButton).evaluate().isNotEmpty || find.byType(FilledButton).evaluate().isNotEmpty || find.byType(OutlinedButton).evaluate().isNotEmpty || t.any((x) => x.toLowerCase().contains('tekrar'));
      // ignore: avoid_print
      print('U2 ${c.$1} metinler: ${t.toList()} ; tekrar-dene: $hasRetry');
      expect(t.isNotEmpty, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('U3 onbellek YOK + AG YOK: ${c.$1} ekrani ne gosteriyor', (tester) async {
      useScreen(tester, kPhoneMedium);
      final be = FakeBackend()..offline = true;
      await tester.pumpWidget(buildApp(c.$2(be), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 3));
      final t = texts(tester);
      // ignore: avoid_print
      print('U3 ${c.$1} metinler: ${t.toList()}');
      expect(t.isNotEmpty, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
