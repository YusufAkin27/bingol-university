import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/forum/forum_routes.dart';
import 'package:bu_kampus/features/forum/presentation/pages/edit_topic_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_forum.dart';
import '../support/fake_forum_compose.dart';

class _Env {
  _Env(this.topicJson) {
    b = FakeBackend();
    f = fakeForum(b, count: 2);
    c = fakeForumCompose(b, f);
    f.topics.insert(0, topicJson);
    s = makeSession(b);
  }
  final Map<String, dynamic> topicJson;
  late final FakeBackend b;
  late final FakeForum f;
  late final FakeForumCompose c;
  late final Session s;
  TopicView? result;
}

Future<_Env> _open(
  WidgetTester tester, {
  Map<String, dynamic>? topic,
  Brightness brightness = Brightness.light,
  Size size = kPhoneMedium,
}) async {
  final e = _Env(topic ?? sampleForumTopic(id: 777, mine: true, title: 'Eski başlık', body: 'Eski gövde', categoryId: 1));
  useScreen(tester, size);
  await tester.pumpWidget(buildApp(
    Builder(
      builder: (ctx) => Scaffold(
        body: Center(
          child: TextButton(
            key: const ValueKey('open'),
            onPressed: () async {
              e.result = await Navigator.of(ctx).push<TopicView>(MaterialPageRoute(
                builder: (_) => EditTopicPage(session: e.s, topic: TopicView.fromJson(e.topicJson)),
              ));
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
    brightness: brightness,
    size: size,
  ));
  await tester.tap(find.byKey(const ValueKey('open')));
  await settle(tester, const Duration(milliseconds: 600));
  return e;
}

bool _saveEnabled(WidgetTester tester) {
  final ink = find.descendant(of: find.byKey(const ValueKey('forumEditSave')), matching: find.byType(InkWell));
  return tester.widget<InkWell>(ink).onTap != null;
}

void main() {
  setUpAll(() async {
    await loadTestFonts();
  });

  testWidgets('mevcut değerler dolu; değişiklik yokken Kaydet pasif', (tester) async {
    await _open(tester);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('forumEditTitle'))).controller!.text, 'Eski başlık');
    expect(tester.widget<TextField>(find.byKey(const ValueKey('forumEditBody'))).controller!.text, 'Eski gövde');
    expect(find.text('Gündem'), findsOneWidget);
    expect(_saveEnabled(tester), isFalse);
    expect(find.text('Görseller ve anket sonradan değiştirilemez.'), findsOneWidget);
  });

  testWidgets('sahip başlığı düzenler: yalnız değişen alan PATCH edilir, güncel konu döner, "Düzenlendi"', (tester) async {
    final e = await _open(tester);
    await tester.enterText(find.byKey(const ValueKey('forumEditTitle')), 'Yeni başlık');
    await settle(tester, const Duration(milliseconds: 200));
    expect(_saveEnabled(tester), isTrue);
    await tester.tap(find.byKey(const ValueKey('forumEditSave')));
    await settle(tester, const Duration(milliseconds: 800));
    expect(e.c.patches.single, {'title': 'Yeni başlık'});
    expect(e.result, isNotNull);
    expect(e.result!.title, 'Yeni başlık');
    expect(e.result!.edited, isTrue);
    expect(find.byKey(const ValueKey('forumEditTitle')), findsNothing);
    expect(find.text('Düzenlendi'), findsOneWidget);
  });

  testWidgets('kategori değişikliği categoryId olarak gider', (tester) async {
    final e = await _open(tester);
    await tester.tap(find.byKey(const ValueKey('forumCategoryField')));
    await settle(tester, const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('forumCategory4')));
    await settle(tester, const Duration(milliseconds: 500));
    expect(_saveEnabled(tester), isTrue);
    await tester.tap(find.byKey(const ValueKey('forumEditSave')));
    await settle(tester, const Duration(milliseconds: 800));
    expect(e.c.patches.single, {'categoryId': 4});
    expect(e.result!.category!.id, 4);
  });

  testWidgets('boş başlık / açıklama kaydedilemez', (tester) async {
    await _open(tester);
    await tester.enterText(find.byKey(const ValueKey('forumEditTitle')), '   ');
    await settle(tester, const Duration(milliseconds: 200));
    expect(_saveEnabled(tester), isFalse);
    await tester.enterText(find.byKey(const ValueKey('forumEditTitle')), 'Ok');
    await tester.enterText(find.byKey(const ValueKey('forumEditBody')), '\n \n');
    await settle(tester, const Duration(milliseconds: 200));
    expect(_saveEnabled(tester), isFalse);
  });

  testWidgets('kilitli konu: alanlar pasif, açıklama banner, Kaydet pasif', (tester) async {
    await _open(tester, topic: sampleForumTopic(id: 778, mine: true, locked: true, title: 'K', body: 'G'));
    expect(find.text('Bu konu kilitli, düzenlenemez.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('forumEditTitle'))).enabled, isFalse);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('forumEditBody'))).enabled, isFalse);
    expect(_saveEnabled(tester), isFalse);
  });

  testWidgets('sahibi olmayan: banner ve pasif alanlar', (tester) async {
    await _open(tester, topic: sampleForumTopic(id: 779, mine: false, title: 'B', body: 'G'));
    expect(find.text('Bu konuyu yalnızca sahibi düzenleyebilir.'), findsOneWidget);
    expect(_saveEnabled(tester), isFalse);
  });

  testWidgets('sunucu 404: "artık yok", Kaydet pasifleşir; metin korunur', (tester) async {
    final e = await _open(tester);
    e.c.editError = const FakeResult.json({'code': 'FORUM_TOPIC_NOT_FOUND', 'message': 'x'}, status: 404);
    await tester.enterText(find.byKey(const ValueKey('forumEditTitle')), 'Yeni');
    await settle(tester, const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('forumEditSave')));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Bu konu artık yok.'), findsOneWidget);
    expect(_saveEnabled(tester), isFalse);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('forumEditTitle'))).controller!.text, 'Yeni');
    expect(e.result, isNull);
  });

  testWidgets('sunucu 409 (kaldırılmış): kısa mesaj', (tester) async {
    final e = await _open(tester);
    e.c.editError = const FakeResult.json({'code': 'FORUM_TOPIC_REMOVED', 'message': 'x'}, status: 409);
    await tester.enterText(find.byKey(const ValueKey('forumEditBody')), 'Yeni gövde');
    await settle(tester, const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('forumEditSave')));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Bu konu artık yok.'), findsOneWidget);
  });

  testWidgets('sunucu 409 FORUM_TOPIC_LOCKED: kilitli mesajı', (tester) async {
    final e = await _open(tester);
    e.c.editError = const FakeResult.json({'code': 'FORUM_TOPIC_LOCKED', 'message': 'x'}, status: 409);
    await tester.enterText(find.byKey(const ValueKey('forumEditBody')), 'Yeni gövde');
    await settle(tester, const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('forumEditSave')));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Bu konu kilitli, düzenlenemez.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('forumEditBody'))).enabled, isFalse);
  });

  testWidgets('sunucu 403 ve 500: mesaj, düzenleme sürebilir', (tester) async {
    final e = await _open(tester);
    e.c.editError = const FakeResult.json({'code': 'FORUM_NOT_OWNER', 'message': 'x'}, status: 403);
    await tester.enterText(find.byKey(const ValueKey('forumEditTitle')), 'Yeni');
    await settle(tester, const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('forumEditSave')));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Bu konuyu yalnızca sahibi düzenleyebilir.'), findsOneWidget);
    e.c.editError = const FakeResult.json({'code': 'SERVER_ERROR', 'message': 'x'}, status: 500);
    await tester.enterText(find.byKey(const ValueKey('forumEditTitle')), 'Yeni 2');
    await settle(tester, const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('forumEditSave')));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.textContaining('kaydedilemedi'), findsOneWidget);
    expect(_saveEnabled(tester), isTrue);
  });

  testWidgets('değişiklikle kapatma onay ister; Düzenlemeye devam formda tutar, At kapatır', (tester) async {
    await _open(tester);
    await tester.enterText(find.byKey(const ValueKey('forumEditTitle')), 'Değişti');
    await settle(tester, const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('forumEditClose')));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Değişiklikler atılsın mı?'), findsOneWidget);
    await tester.tap(find.text('Düzenlemeye devam'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('forumEditTitle')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('forumEditClose')));
    await settle(tester, const Duration(milliseconds: 600));
    await tester.tap(find.text('At'));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.byKey(const ValueKey('forumEditTitle')), findsNothing);
  });

  testWidgets('değişiklik yoksa kapatma sormadan kapanır', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('forumEditClose')));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('forumEditTitle')), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets('küçük ekran + büyük yazı: taşma yok (${dark ? 'koyu' : 'açık'})', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final old = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = old);
      final e = _Env(sampleForumTopic(id: 780, mine: true, title: 'Uzun başlık ' * 12, body: 'Gövde ' * 80));
      useScreen(tester, kPhoneSmall);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(buildApp(EditTopicPage(session: e.s, topic: TopicView.fromJson(e.topicJson)),
          brightness: dark ? Brightness.dark : Brightness.light));
      await settle(tester, const Duration(milliseconds: 500));
      expect(errors.where((d) => d.exceptionAsString().contains('overflowed')), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
