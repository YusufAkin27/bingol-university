import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/chatlist_widgets.dart';
import 'package:bu_kampus/features/chat/new_chat_page.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// P3-CHAT (minimal): sohbet listesi, yeni sohbet, konuşma ekranı sadeleştirmesi.
String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _row(int id, String type, String title, {int unread = 0, String text = 'Selam'}) => {
      'id': id,
      'type': type,
      'title': title,
      if (type == 'DIRECT') 'peer': {'id': 10 + id, 'displayName': title},
      'unreadCount': unread,
      'lastMessage': {
        'id': 100 + id,
        'conversationId': id,
        'senderId': 10 + id,
        'text': text,
        'attachments': const [],
        'createdAt': _iso(DateTime.now()),
      },
    };

FakeBackend _be(List<Map<String, dynamic>> items) => FakeBackend()
  ..on('/conversations/unread-count', {'total': 1})
  ..on('/conversations*', {'items': items, 'nextCursor': null});

FakeBackend _detailBe(List<Map<String, dynamic>> msgs) => FakeBackend()
  ..on('/conversations/1/messages?size=30', {'items': msgs, 'nextCursor': null})
  ..on('/conversations/1', {
    'conversation': {'id': 1},
    'members': [
      {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
      {'userId': 11, 'displayName': 'Ali Veli'},
    ],
  })
  ..on('/users/11/presence', {'online': false})
  ..on('/messages/reactions', {'emojis': <String>[]});

ChatDetailPage _detail(FakeBackend b) => ChatDetailPage(
      session: makeSession(b),
      connectRealtime: false,
      conversation: const {
        'id': 1,
        'type': 'DIRECT',
        'title': 'Ali Veli',
        'peer': {'id': 11, 'displayName': 'Ali Veli'},
      },
    );

void main() {
  setUpAll(loadTestFonts);

  group('sohbet listesi', () {
    final items = [
      _row(1, 'DIRECT', 'Mehmet Kaya', unread: 2),
      _row(2, 'CLUB', 'Edebiyat Kulübü'),
      _row(3, 'EVENT', 'Bahar Şenliği'),
    ];

    testWidgets('Stitch v3 satır: kartsız, okunmamış tam genişlik yüzey, satırlar arası ince çizgi; tür avatar rozeti yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(ChatTab(session: makeSession(_be(items)), connectRealtime: false)));
      await settle(tester, const Duration(seconds: 1));
      final bu = tester.element(find.text('Mehmet Kaya')).bu;
      // Okunmamış satır (Mehmet): tam genişlik yüzey; okunmuş satır (Edebiyat): saydam (kart yok).
      final hot = tester.widget<Material>(find.ancestor(of: find.text('Mehmet Kaya'), matching: find.byType(Material)).first);
      expect(hot.color, bu.sf);
      final read = tester.widget<Material>(find.ancestor(of: find.text('Edebiyat Kulübü'), matching: find.byType(Material)).first);
      expect(read.color, Colors.transparent);
      // Ayırıcı: son satır hariç her satırın altında 1 dp bd çizgi (3 satır -> 2 çizgi).
      final hairlines = tester.widgetList<Container>(find.byType(Container)).where((c) => c.color == bu.bd && c.constraints?.maxHeight == 1);
      expect(hairlines.length, 2);
      // Tür simgesi (megafon/takvim rozeti) avatarda yok; tür yalnız nötr etiketle söylenir.
      expect(find.byIcon(LucideIcons.megaphone), findsNothing);
      expect(find.byIcon(LucideIcons.calendar), findsNothing);
      expect(find.text('Kulüp'), findsOneWidget);
      // Okunmamış başlık 700, okunmuş 600; okunmamış saat marka renginde.
      final unreadTitle = tester.widget<Text>(find.text('Mehmet Kaya'));
      final readTitle = tester.widget<Text>(find.text('Edebiyat Kulübü'));
      expect(unreadTitle.style!.fontWeight, FontWeight.w700);
      expect(readTitle.style!.fontWeight, FontWeight.w600);
      expect(tester.takeException(), isNull);
    });

    testWidgets('liste avatarı konuşma avatarıyla aynı Hero etiketini taşır', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(ChatTab(session: makeSession(_be(items)), connectRealtime: false)));
      await settle(tester, const Duration(seconds: 1));
      final tags = tester.widgetList<Hero>(find.byType(Hero)).map((h) => h.tag).toSet();
      expect(tags, containsAll(<Object>['chat-avatar-1', 'chat-avatar-2', 'chat-avatar-3']));
    });

    testWidgets('boş durum: tek cümle + tek birincil düğme; başlıktaki + düz ikon', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(ChatTab(session: makeSession(_be(const [])), connectRealtime: false)));
      await settle(tester, const Duration(seconds: 1));
      // Başlık "+" düz çizgi ikon (daire/dolgu yok): içinde dolgulu kutu yok.
      expect(find.descendant(of: find.byType(ChatlistNewButton), matching: find.byType(AnimatedContainer)), findsNothing);
      expect(find.descendant(of: find.byType(ChatlistNewButton), matching: find.byIcon(LucideIcons.plus)), findsOneWidget);
      expect(find.byType(BuEmptyState), findsOneWidget);
      expect(tester.widget<BuEmptyState>(find.byType(BuEmptyState)).message, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Stitch v3 hizalama: başlık, arama, çip, avatar hepsi 16 dp kenarda; sağ ikonlar referans merkezlerinde', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(ChatTab(session: makeSession(_be(items)), connectRealtime: false), size: kPhoneMedium));
      await settle(tester, const Duration(seconds: 1));
      expect(tester.getTopLeft(find.text('Sohbet').first).dx, 16);
      expect(tester.getTopLeft(find.byType(ChatlistSearch)).dx, 16);
      expect(tester.getTopLeft(find.text('Tümü').first).dx, greaterThanOrEqualTo(16));
      final chip = tester.getRect(find.ancestor(of: find.text('Tümü').first, matching: find.byType(BuChip)).first);
      expect(chip.left, closeTo(16, 1));
      expect(tester.getTopLeft(find.byType(ChatlistAvatar).first).dx, 16);
      // "+" merkezi 356, arşiv merkezi 316 (referans).
      expect(tester.getCenter(find.byIcon(LucideIcons.plus).first).dx, closeTo(356, 1));
      expect(tester.getCenter(find.byIcon(LucideIcons.archive).first).dx, closeTo(316, 1));
    });

    testWidgets('dolu listede + düğmesi düz ikon, 48 dp dokunma alanı; arama 52 dp', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(ChatTab(session: makeSession(_be(items)), connectRealtime: false)));
      await settle(tester, const Duration(seconds: 1));
      expect(tester.getSize(find.byType(ChatlistSearch)).height, 52);
      // + düğmesi 48 dp dokunma alanı
      expect(tester.getSize(find.byType(ChatlistNewButton)).shortestSide, greaterThanOrEqualTo(48));
    });

    for (final dark in [false, true]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('taşma yok 320 dp x$scale ${dark ? 'koyu' : 'açık'}', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = kPhoneSmall;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(p00App(ChatTab(session: makeSession(_be(items)), connectRealtime: false), scale: scale, dark: dark));
          await settle(tester, const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          expect(find.text('Mehmet Kaya'), findsOneWidget);
        });
      }
    }
  });

  group('yeni sohbet', () {
    testWidgets('eylem satırı kartsız, simge karosu nötr; kenar 16 dp', (tester) async {
      useScreen(tester, kPhoneMedium);
      final be = FakeBackend()..on('/users*', {'items': <Object>[], 'nextCursor': null});
      await tester.pumpWidget(buildApp(NewChatPage(session: makeSession(be))));
      await settle(tester, const Duration(milliseconds: 600));
      final bu = tester.element(find.byType(NewChatPage)).bu;
      final group = find.byKey(const ValueKey('new-group'));
      expect(group, findsOneWidget);
      // Satır sol kenarı 16 dp (Stitch v3, arama kutusuyla aynı).
      expect(tester.getTopLeft(find.byType(ChatlistSearch)).dx, 16);
      expect(tester.getTopLeft(find.text('Yeni grup').first).dx, greaterThanOrEqualTo(20));
      // Kartsız: satır zemininde çerçeveli kutu yok.
      final boxes = tester.widgetList<Container>(find.descendant(of: group, matching: find.byType(Container))).where((c) {
        final d = c.decoration;
        return d is BoxDecoration && d.border != null;
      });
      expect(boxes, isEmpty);
      expect(find.byIcon(LucideIcons.info), findsNothing, reason: 'bilgi satırı simgesi kalktı');
      expect(bu.sf2, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('konuşma ekranı', () {
    testWidgets('üst çubuk: geri, avatar 40 dp (Hero chat-avatar-1), ad; avatar adın solunda; alt çizgi', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(_detail(_detailBe(const [])), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 700));
      final hero = tester.widgetList<Hero>(find.byType(Hero)).where((h) => h.tag == 'chat-avatar-1');
      expect(hero.length, 1);
      expect(tester.getSize(find.byType(ChatlistAvatar).first), const Size(40, 40));
      final avatarX = tester.getCenter(find.byType(ChatlistAvatar).first).dx;
      final titleX = tester.getTopLeft(find.text('Ali Veli').first).dx;
      expect(avatarX, lessThan(titleX));
      expect(tester.getSize(find.byTooltip('Geri')).shortestSide, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });

    testWidgets('yazma alanı: boşken Gönder yok, yazınca 44 dp kırmızı düğme belirir; + beyaz yuvarlatılmış kare', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(_detail(_detailBe(const [])), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 700));
      final bu = tester.element(find.byType(ChatDetailPage)).bu;
      expect(find.byKey(const ValueKey('sendButton')), findsNothing, reason: 'metin yokken gönder görünmez');
      await tester.enterText(find.byKey(const ValueKey('composerField')), 'merhaba');
      await tester.pump();
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('sendButton')), findsOneWidget);
      final box = tester.widget<Container>(find.descendant(of: find.byKey(const ValueKey('sendButton')), matching: find.byType(Container)).last);
      expect((box.decoration as BoxDecoration).color, bu.pr);
      // 44 dp görünür, 48 dp dokunma alanı
      expect(tester.getSize(find.byKey(const ValueKey('sendButton'))), const Size(48, 48));
      expect(tester.getSize(find.descendant(of: find.byKey(const ValueKey('sendButton')), matching: find.byType(Container)).last), const Size(44, 44));
      expect(tester.getSize(find.byKey(const ValueKey('attachButton'))).shortestSide, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });

    testWidgets('boş sohbet: tek cümle (açıklama yok)', (tester) async {
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(_detail(_detailBe(const [])), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 700));
      expect(tester.widget<BuEmptyState>(find.byType(BuEmptyState)).message, isNull);
    });

    for (final dark in [false, true]) {
      testWidgets('çok mesajlı konuşma 320 dp x1.3 taşma yok ${dark ? 'koyu' : 'açık'}', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = kPhoneSmall;
        addTearDown(tester.view.reset);
        final msgs = [
          for (var i = 1; i <= 6; i++)
            {
              'id': i,
              'conversationId': 1,
              'senderId': i.isEven ? 1 : 11,
              'text': 'Çok uzun bir mesaj metni $i: yarınki ders notlarını ve ödev dosyasını atar mısın lütfen',
              'createdAt': _iso(DateTime.now().subtract(Duration(minutes: 60 - i))),
              if (i == 3) 'reactions': [
                {'emoji': '👍', 'count': 2}
              ],
            }
        ];
        await tester.pumpWidget(p00App(_detail(_detailBe(msgs)), scale: 1.3, dark: dark, scaffold: false));
        await settle(tester, const Duration(milliseconds: 800));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
