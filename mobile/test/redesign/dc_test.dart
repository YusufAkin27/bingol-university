import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/chatd_parts.dart';
import 'package:bu_kampus/features/clubs/clubs_tab.dart';
import 'package:bu_kampus/features/home/home_parts.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:bu_kampus/features/news/news_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// DC (mimar cilasi: Kesfet/haber/arama/sohbet) davranissal testleri.
String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _row(int id, String type, String title) => {
      'id': id,
      'type': type,
      'title': title,
      if (type == 'DIRECT') 'peer': {'id': 10 + id, 'displayName': title},
      'unreadCount': 2,
      'lastMessage': {
        'id': 100 + id,
        'conversationId': id,
        'senderId': 10 + id,
        'senderName': 'Ahmet Yilmaz',
        'text': 'Toplanti 18.00da',
        'attachments': const <Object>[],
        'createdAt': _iso(DateTime.now()),
      },
    };

FakeBackend _chatBe() => FakeBackend()
  ..on('/conversations/unread-count', {'total': 2})
  ..on('/conversations*', {
    'items': [_row(1, 'CLUB', 'Fotografcilik Kulubu Duyurulari'), _row(2, 'DIRECT', 'Zeynep Demir')],
    'nextCursor': null,
  });

Map<String, dynamic> _news(int id, String type) => {
      'id': id,
      'type': type,
      'title': 'Baslik $id',
      'publishedDate': '2026-10-20',
      'url': 'https://www.bingol.edu.tr/x/$id',
    };

void main() {
  setUpAll(loadTestFonts);

  testWidgets('sohbet listesi T-114: dar ekranda tur cipi kalkar, baslik 2 satira acilir', (tester) async {
    addTearDown(tester.view.reset);
    Future<void> pump(double w, double scale) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(w, 800);
      await tester.pumpWidget(p00App(ChatTab(session: makeSession(_chatBe()), connectRealtime: false), scale: scale));
      await settle(tester, const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    }

    await pump(390, 1.0);
    expect(find.text('Kulüp'), findsOneWidget, reason: 'genis ekranda cip gorunur');
    await pump(390, 1.3);
    expect(find.text('Kulüp'), findsNothing, reason: 'buyuk yazida cip kalkar');
    final title = tester.widget<Text>(find.text('Fotografcilik Kulubu Duyurulari'));
    expect(title.maxLines, 2);
    expect(title.semanticsLabel, contains('Kulüp'), reason: 'tur ekran okuyucuya yine soylenir');
    // Birebir sohbet başlığı da büyük yazıda 2 satıra açılır (3 harfe sıkışmaz).
    final direct = tester.widget<Text>(find.text('Zeynep Demir'));
    expect(direct.maxLines, 2);
    await pump(320, 1.0);
    expect(find.text('Kulüp'), findsNothing);
  });

  testWidgets('haber listesi: sekme turu her satirda rozet olarak tekrarlanmaz', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    final be = FakeBackend()
      ..on('/status', {'NEWS': {'maintenance': false}})
      ..on('/bookmarks/news/ids', {'ids': <int>[]})
      ..on('/news*', {
        'items': [_news(1, 'DUYURU'), _news(2, 'DUYURU')],
        'totalPages': 1,
      });
    await tester.pumpWidget(p00App(NewsListPage(session: makeSession(be), initialType: 'DUYURU'), scaffold: false));
    await settle(tester, const Duration(seconds: 1));
    expect(find.text('Baslik 1'), findsOneWidget);
    // "Duyuru" yalniz sekme etiketinde (rozet yok).
    expect(find.text('Duyuru'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('yaziyor noktalari: 3 nokta cizilir, hareket azaltilinca durağan', (tester) async {
    for (final reduced in [false, true]) {
      await tester.pumpWidget(p00App(const Center(child: ChatTypingDots(color: Colors.red)), disableAnimations: reduced));
      await tester.pump(const Duration(milliseconds: 300));
      final dots = find.descendant(of: find.byType(ChatTypingDots), matching: find.byType(Opacity));
      expect(dots, findsNWidgets(3));
      expect(tester.takeException(), isNull);
      if (reduced) {
        final ops = tester.widgetList<Opacity>(dots).map((o) => o.opacity).toSet();
        expect(ops, {.7});
        // Durağan: ek kare istemez.
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      }
    }
  });

  for (final inset in [24.0, 36.0, 48.0]) {
    testWidgets('sohbet sekmesi baslik ust guvenli alanin (status bar $inset dp) altinda baslar', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 800);
      tester.view.padding = FakeViewPadding(top: inset);
      tester.view.viewPadding = FakeViewPadding(top: inset);
      await tester.pumpWidget(p00App(ChatTab(session: makeSession(_chatBe()), connectRealtime: false), scaffold: false));
      await settle(tester, const Duration(seconds: 1));
      expect(tester.getTopLeft(find.text('Sohbet')).dy, greaterThanOrEqualTo(inset), reason: 'baslik durum cubuguna binmemeli');
      expect(tester.getTopLeft(find.byTooltip('Yeni sohbet')).dy, greaterThanOrEqualTo(inset), reason: '+ dugmesi durum cubuguna binmemeli');
      // Arsiv gorunumu (BuHeader) da ayni inset'i alir.
      await tester.tap(find.byTooltip('Arşiv'));
      await settle(tester, const Duration(milliseconds: 600));
      expect(tester.getTopLeft(find.text('Arşiv')).dy, greaterThanOrEqualTo(inset));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('kulupler sekmesi: kategori cipleri 48 dp kutuda, yazi kirpilmaz', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    final be = FakeBackend()
      ..on('/communities/categories', [
        {'category': 'tech', 'count': 3, 'key': 'tech', 'name': 'Technology', 'icon': 'tag', 'sortOrder': 10},
      ])
      ..on('/me/communities*', {'items': <Object>[], 'nextCursor': null})
      ..on('/communities*', {'items': <Object>[], 'nextCursor': null});
    await tester.pumpWidget(p00App(ClubsTab(session: makeSession(be)), scaffold: false));
    await settle(tester, const Duration(milliseconds: 800));
    final chip = find.widgetWithText(BuChip, 'Technology');
    expect(chip, findsOneWidget);
    final row = find.ancestor(of: chip, matching: find.byWidgetPredicate((w) => w is SizedBox && w.height != null && w.height! >= 40));
    expect(tester.getSize(row.first).height, greaterThanOrEqualTo(tester.getSize(chip).height), reason: 'cip satir kutusundan yuksek olamaz (kirpilir)');
    expect(tester.takeException(), isNull);
  });

  testWidgets('ana sayfa bos menu karti kompakt: tek satir, ~180 dp degil', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    await tester.pumpWidget(p00App(const SingleChildScrollView(
      child: HomeEmptyCard(
          title: 'Menu', subtitle: 'Lunch', icon: Icons.restaurant, headline: 'No menu for today', body: 'Not entered yet.', compact: true),
    )));
    await tester.pump();
    expect(find.text('Menu'), findsNothing, reason: 'kompakt kartta bolum basligi satiri yok');
    expect(tester.getSize(find.byType(HomeEmptyCard)).height, lessThan(100));
    final full = await _fullHeight(tester);
    expect(full, greaterThan(160), reason: 'kompakt olmayan kart degismedi');
    expect(tester.takeException(), isNull);
  });
}

Future<double> _fullHeight(WidgetTester tester) async {
  await tester.pumpWidget(p00App(const SingleChildScrollView(
    child: HomeEmptyCard(title: 'Menu', subtitle: 'Lunch', icon: Icons.restaurant, headline: 'No menu for today', body: 'Not entered yet.'),
  )));
  await tester.pump();
  return tester.getSize(find.byType(HomeEmptyCard)).height;
}
